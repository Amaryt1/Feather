import SwiftUI
import Combine
import CoreData
import NimbleViews

@MainActor
final class CardInstallQueue: ObservableObject {
    static let shared = CardInstallQueue()
    struct Preview: Identifiable {
        let id: String
        let signed: Signed
    }
    @Published var preview: Preview?
    private var waiting: [String] = []
    private var showing = false

    func owns(_ id: String) -> Bool { waiting.contains(id) || preview?.id == id }

    func enqueue(_ id: String) {
        if !waiting.contains(id) { waiting.append(id) }
    }

    func advance(_ outcomes: SourceOutcomes) {
        waiting.removeAll { id in
            switch outcomes[id] {
            case .cancelled, .failed: return true
            default: return false
            }
        }
        guard !showing, let index = waiting.firstIndex(where: {
            if case .ready = outcomes[$0] { return true }
            return false
        }) else { return }
        let id = waiting.remove(at: index)
        guard case let .ready(uuid) = outcomes[id] else { return }
        let request = NSFetchRequest<Signed>(entityName: "Signed")
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "uuid == %@", uuid)
        guard let signed = try? Storage.shared.context.fetch(request).first else {
            DownloadManager.shared.outcomes[id] = .failed("تعذّر فتح النسخة الموقّعة.")
            return
        }
        showing = true
        preview = Preview(id: id, signed: signed)
    }

    func didDismiss() {
        showing = false
        advance(DownloadManager.shared.outcomes)
    }
}

struct CardInstallHost: ViewModifier {
    @ObservedObject private var queue = CardInstallQueue.shared
    func body(content: Content) -> some View {
        content.onReceive(DownloadManager.shared.$outcomes.receive(on: DispatchQueue.main)) { queue.advance($0) }
            .sheet(item: $queue.preview, onDismiss: queue.didDismiss) { item in
                InstallPreviewView(app: item.signed, sourceOperation: item.id)
                    .presentationDetents([.height(220)])
            }
    }
}

struct CardInstallActions: View {
    typealias Route = SourceAppsView.SourceAppRoute
    let id: String?
    let resolve: () async throws -> Route
    let details: () -> Void
    @ObservedObject private var manager = DownloadManager.shared
    @ObservedObject private var local = SourceDirectSessions.shared
    @AppStorage("Feather.installationMethod") private var method = 0
    @State private var missing = false
    @State private var certificates = false
    @State private var inspect = false
    @State private var message: String?
    @State private var resolving = false

    init(route: Route, details: @escaping () -> Void) {
        id = SourceOperationKey.make(sourceURL: route.sourceURL, repository: route.source, app: route.app).id
        resolve = { route }
        self.details = details
    }

    init(id: String?, resolve: @escaping () async throws -> Route, details: @escaping () -> Void) {
        self.id = id
        self.resolve = resolve
        self.details = details
    }

    var body: some View {
        HStack(spacing: 6) {
            Button("التفاصيل", action: details)
            if let id, let session = local.sessions[id] {
                LocalCardProgress(engine: session.engine, show: { inspect = true }, cancel: { local.close(id) })
            } else if let id, let download = manager.getDownload(by: id) {
                TransferCardProgress(download: download)
            } else if let id, manager.outcomes[id] == .signing {
                ProgressView().accessibilityLabel("جارٍ التوقيع")
                Button { manager.cancelSigning(id) } label: { Image(systemName: "xmark.circle") }.accessibilityLabel("إلغاء التوقيع")
            } else if resolving {
                ProgressView().accessibilityLabel("جارٍ التجهيز")
            } else {
                Button { Task { await start() } } label: {
                    Image(systemName: "arrow.down.circle").frame(minWidth: 36, minHeight: 44)
                }.disabled(resolving).accessibilityLabel("تنزيل وتثبيت")
                if let id {
                    switch manager.outcomes[id] {
                    case .failed(let error): Button { message = error } label: { Image(systemName: "exclamationmark.triangle") }
                    case .submitted: Image(systemName: "paperplane").accessibilityLabel("أُرسل إلى iOS")
                    case .installed: Image(systemName: "checkmark.circle").accessibilityLabel("اكتمل التثبيت")
                    case .ready: Button("جاهز") { CardInstallQueue.shared.enqueue(id); CardInstallQueue.shared.advance(manager.outcomes) }
                    default: EmptyView()
                    }
                }
            }
        }
        .buttonStyle(.borderless)
        .alert("الشهادة مطلوبة", isPresented: $missing) {
            Button("إضافة شهادة") { certificates = true }
            Button("إلغاء", role: .cancel) {}
        } message: { Text("أضف شهادة وملف تزويد صالحين، ثم أعد المحاولة.") }
        .alert("تعذّر التثبيت", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("حسنًا") { message = nil }
        } message: { Text(message ?? "") }
        .sheet(isPresented: $certificates) { NavigationStack { CertificatesView() } }
        .sheet(isPresented: $inspect) {
            if let id, let session = local.sessions[id] {
                DirectInstallView(input: session.input, sharedEngine: session.engine) { local.close(id) }
            }
        }
    }

    @MainActor private func start() async {
        guard !resolving else { return }
        let index = UserDefaults.standard.integer(forKey: "feather.selectedCert")
        guard let cert = Storage.shared.getCertificate(for: index), !cert.revoked,
              Storage.shared.getFile(.certificate, from: cert) != nil,
              let profile = Storage.shared.getFile(.provision, from: cert),
              (try? DirectProfile.read(profile)) != nil else { missing = true; return }
        resolving = true
        defer { resolving = false }
        do {
            let route = try await resolve()
            let app = route.app
            guard let url = app.currentDownloadUrl else { throw DirectError("رابط IPA غير متوفر.") }
            let key = SourceOperationKey.make(sourceURL: route.sourceURL, repository: route.source, app: app).id
            guard manager.getDownload(by: key) == nil, manager.outcomes[key] != .signing, local.sessions[key] == nil else { return }
            if method == DirectPolicy.method {
                let input = DirectInput.source(url, app.currentName, app.currentVersion, app.iconURL)
                local.open(key, input: input)
                local.sessions[key]?.engine.prepareFromCard(input)
            } else {
                CardInstallQueue.shared.enqueue(key)
                _ = manager.startDownload(from: url, id: key,
                    sourceProvenance: SourceAppProvenance(sourceURL: route.sourceURL, repository: route.source, app: app),
                    signingCertificate: cert)
            }
        } catch { message = error.localizedDescription }
    }
}

private struct TransferCardProgress: View {
    @ObservedObject var download: Download
    var body: some View {
        if download.totalBytes > 0 || download.packaging { SourceDownloadRing(download: download) }
        else { ProgressView() }
        Group {
            Button { DownloadManager.shared.cancelDownload(download) } label: { Image(systemName: "xmark.circle").frame(minHeight: 44) }
                .accessibilityLabel("إلغاء التنزيل")
        }
    }
}

private struct LocalCardProgress: View {
    @ObservedObject var engine: DirectEngine
    let show: () -> Void
    let cancel: () -> Void
    var body: some View {
        Button(action: show) {
            if engine.phase == .downloading, let fraction = engine.progress {
                StoreProgressRing(fraction).frame(width: 30, height: 30)
            } else if [.idle, .downloading, .preparing, .signing, .submitting].contains(engine.phase) { ProgressView() }
            else { Image(systemName: engine.phase == .failed ? "exclamationmark.triangle" : "paperplane") }
        }.accessibilityLabel(engine.statusText)
        if ![.sent, .submitting].contains(engine.phase) {
            Button(action: cancel) { Image(systemName: "xmark.circle").frame(minHeight: 44) }.accessibilityLabel("إلغاء")
        }
    }
}

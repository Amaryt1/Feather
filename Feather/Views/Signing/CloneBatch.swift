import SwiftUI
import CoreData

@MainActor
final class CloneBatch: ObservableObject {
    static let reservationsChanged = Notification.Name("Feather.cloneReservationsChanged")
    static private var reserved = Set<String>()
    @Published private(set) var running = false
    @Published private(set) var stage = ""
    @Published private(set) var results: [String] = []
    private var task: Task<Void, Never>?

    func cancel() { task?.cancel(); stage = "جارٍ إيقاف التوقيع عند أقرب نقطة آمنة…" }

    func start(app: AppInfoPresentable, options: Options, icon: UIImage?, certificate: CertificatePair?, count: Int, expected: [String]) {
        guard !running else { return }
        results = []
        stage = ""
        running = true
        task = Task {
            defer { running = false; task = nil }
            do {
                _ = try await sign(app: app, options: options, icon: icon, certificate: certificate, count: count, expected: expected)
                stage = "اكتمل توقيع النسخة المطلوبة. يمكنك تثبيتها من المكتبة."
            } catch is CancellationError { stage = "أُلغي التوقيع. النسخ المكتملة محفوظة في المكتبة." }
            catch { stage = stage.isEmpty ? error.localizedDescription : stage + " — " + error.localizedDescription }
        }
    }

    func sign(app: AppInfoPresentable, options: Options, icon: UIImage?, certificate: CertificatePair?, count: Int, expected: [String]? = nil) async throws -> [String] {
        var held = Set<String>()
        var uuids: [String] = []
        defer {
            if !held.isEmpty {
                Self.reserved.subtract(held)
                NotificationCenter.default.post(name: Self.reservationsChanged, object: nil)
            }
        }
        guard let base = options.appIdentifier ?? app.identifier, let certificate, !certificate.revoked,
              options.signingOption == .default,
              (certificate.expiration ?? .distantPast) > Date(),
              Storage.shared.getFile(.certificate, from: certificate) != nil,
              Storage.shared.getFile(.provision, from: certificate) != nil else {
            throw DirectError("تكرار التطبيق يتطلب شهادة وملف تزويد صالحين.")
        }
        // Same identifier edit as manual signing, except we generate the suffix.
        // Avoid the stricter ClonePolicy/profile preflight, which blocked the
        // user's manual-valid IDs before the shared signer was even invoked.
        // The signing engine and iOS remain responsible for accepting the IPA.
        let plan = try Self.plan(base: base, original: app.identifier, count: count)
        if let expected, plan != expected {
            throw DirectError("تغيرت معرّفات النسخ المتاحة. راجع المعاينة ثم أعد المحاولة.")
        }
        guard Self.reserved.isDisjoint(with: plan) else { throw DirectError("هذه النسخ قيد التوقيع بالفعل.") }
        held = Set(plan)
        Self.reserved.formUnion(held)
        NotificationCenter.default.post(name: Self.reservationsChanged, object: nil)
        for id in plan {
            try Task.checkCancellation()
            stage = "توقيع النسخة الإضافية · \(id)"
            var copy = options
            copy.appIdentifier = id
            // Do not override removeProvisioning or entitlements: manual
            // signing must use the same caller-supplied options as this route.
            let uuid = try await FR.signPackageFileAsync(app, using: copy, icon: icon, certificate: certificate)
            results.append("✓ " + id)
            uuids.append(uuid)
        }
        return uuids
    }

    static func plan(base: String, original: String?, count: Int) throws -> [String] {
        var occupied = Self.reserved
        for entity in ["Imported", "Signed"] {
            let request = NSFetchRequest<NSDictionary>(entityName: entity)
            request.resultType = .dictionaryResultType
            request.propertiesToFetch = ["identifier"]
            for row in try Storage.shared.context.fetch(request) {
                if let id = row["identifier"] as? String { occupied.insert(id) }
            }
        }
        if let store = Bundle.main.bundleIdentifier { occupied.insert(store) }
        guard base.caseInsensitiveCompare(Bundle.main.bundleIdentifier ?? "") != .orderedSame else {
            throw DirectError("لا يمكن استخدام معرّف المتجر كأساس للنسخ.")
        }
        guard count > 1 else { throw DirectError("النسخة الأصلية تُوقّع من المسار المعتاد.") }
        let target = try ClonePolicy.selectedCloneIdentifier(base: base, selection: count, occupied: occupied)
        return [target]
    }

    nonisolated static func validateIdentity(_ p12: URL, password: String, profile: URL) throws {
        switch verifyCloneIdentity(p12.path, password, profile.path) {
        case CloneIdentityValid: return
        case CloneIdentityOutsideProfile:
            throw DirectError("شهادة التوقيع غير مدرجة في ملف التزويد المختار.")
        case CloneIdentityOutsideValidity:
            throw DirectError("شهادة التوقيع خارج مدة صلاحيتها.")
        default:
            throw DirectError("تعذّر على Zsign قراءة المفتاح والشهادة من الملفات المحددة. تحقق من ملف الشهادة وكلمة مروره وملف التزويد.")
        }
    }
}

/// A preview never reserves an identifier. Signing rechecks the reviewed plan before making a copy.
struct ClonePlanView: View {
    let base: String
    let original: String?
    let count: Int
    let certificate: CertificatePair?
    @Binding var approved: [String]
    @State private var identifiers: [String] = []
    @State private var issue: String?
    @State private var warning: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !identifiers.isEmpty { Text("معرّف النسخة الإضافية التي سيتم تثبيتها").font(.caption) }
            ForEach(identifiers, id: \.self) { id in
                Text(verbatim: id).font(.caption.monospaced()).textSelection(.enabled)
            }
            if let issue { Text(issue).font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
            if let warning { Text(warning).font(.caption).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true) }
        }
        .task(id: [base, original ?? "", String(count), certificate?.objectID.uriRepresentation().absoluteString ?? ""]) {
            refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: CloneBatch.reservationsChanged)) { _ in refresh() }
        .onReceive(NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave, object: Storage.shared.context)) { _ in refresh() }
    }

    @MainActor private func refresh() {
        approved = []
        identifiers = []
        warning = nil
        do {
            guard let certificate, !certificate.revoked, (certificate.expiration ?? .distantPast) > Date(),
                  Storage.shared.getFile(.certificate, from: certificate) != nil,
                  let url = Storage.shared.getFile(.provision, from: certificate) else {
                throw DirectError("اختر شهادة صالحة وملف تزويد للنسخ.")
            }
            identifiers = try CloneBatch.plan(base: base, original: original, count: count)
            approved = identifiers
            issue = nil
            if let identifier = identifiers.first,
               let profile = try? DirectProfile.read(url),
               !profile.permits(identifier) {
                warning = "تنبيه: المعرف التلقائي خارج نطاق ملف التزويد. سيُستخدم مسار التوقيع اليدوي نفسه، لكن قد يرفض iOS تثبيت النسخة."
            }
        } catch { issue = error.localizedDescription }
    }
}

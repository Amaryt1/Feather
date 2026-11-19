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
              let key = Storage.shared.getFile(.certificate, from: certificate),
              let url = Storage.shared.getFile(.provision, from: certificate) else {
            throw DirectError("تكرار التطبيق يتطلب شهادة صالحة وتوقيعًا بملف تزويد.")
        }
        let profile = try DirectProfile.read(url)
        try Self.validateIdentity(key, password: certificate.password ?? "", profile: url)
        let plan = try Self.plan(base: base, original: app.identifier, count: count)
        try ClonePolicy.validate(plan, profile: profile)
        if let expected, plan != expected {
            throw DirectError("تغيرت معرّفات النسخ المتاحة. راجع المعاينة ثم أعد المحاولة.")
        }
        guard Self.reserved.isDisjoint(with: plan) else { throw DirectError("هذه النسخ قيد التوقيع بالفعل.") }
        held = Set(plan)
        Self.reserved.formUnion(held)
        NotificationCenter.default.post(name: Self.reservationsChanged, object: nil)
        for (offset, id) in plan.enumerated() {
            try Task.checkCancellation()
            stage = "توقيع النسخة الإضافية · \(id)"
            var copy = options
            copy.appIdentifier = id
            copy.removeProvisioning = true
            let signer = SigningHandler(app: app, options: copy)
            signer.appIcon = icon
            signer.appCertificate = certificate
            do {
                try await signer.copy()
                try await signer.signClone(expectedID: id)
                try? await signer.clean()
                results.append("✓ " + id)
                uuids.append(signer.signedUUID)
            } catch {
                try? await signer.clean()
                throw error
            }
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
        let existing = occupied.contains { $0.caseInsensitiveCompare(base) == .orderedSame }
        guard base.caseInsensitiveCompare(Bundle.main.bundleIdentifier ?? "") != .orderedSame,
              !reserved.contains(where: { $0.caseInsensitiveCompare(base) == .orderedSame }),
              !existing || base == original else {
            throw DirectError("المعرّف الأساسي مستخدم بالفعل. اختر معرّفًا آخر.")
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

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !identifiers.isEmpty { Text("معرّف النسخة الإضافية التي سيتم تثبيتها").font(.caption) }
            ForEach(identifiers, id: \.self) { id in
                Text(verbatim: id).font(.caption.monospaced()).textSelection(.enabled)
            }
            if let issue { Text(issue).font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
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
        do {
            identifiers = try CloneBatch.plan(base: base, original: original, count: count)
            guard let certificate, !certificate.revoked, (certificate.expiration ?? .distantPast) > Date(),
                  let url = Storage.shared.getFile(.provision, from: certificate) else {
                throw DirectError("اختر شهادة صالحة وملف تزويد للنسخ.")
            }
            try ClonePolicy.validate(identifiers, profile: DirectProfile.read(url))
            approved = identifiers
            issue = nil
        } catch { issue = error.localizedDescription }
    }
}

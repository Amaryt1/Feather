import SwiftUI
import CoreData

@MainActor
final class CloneBatch: ObservableObject {
    static private var reserved = Set<String>()
    @Published private(set) var running = false
    @Published private(set) var stage = ""
    @Published private(set) var results: [String] = []
    private var task: Task<Void, Never>?

    func cancel() { task?.cancel(); stage = "جارٍ إيقاف التوقيع عند أقرب نقطة آمنة…" }

    func start(app: AppInfoPresentable, options: Options, icon: UIImage?, certificate: CertificatePair?, count: Int) {
        guard !running else { return }
        results = []
        stage = ""
        running = true
        task = Task {
            defer { running = false; task = nil }
            do {
                _ = try await sign(app: app, options: options, icon: icon, certificate: certificate, count: count)
                stage = "اكتمل توقيع النسخ. يمكنك تثبيتها من المكتبة."
            } catch is CancellationError { stage = "أُلغي التوقيع. النسخ المكتملة محفوظة في المكتبة." }
            catch { stage = stage.isEmpty ? error.localizedDescription : stage + " — " + error.localizedDescription }
        }
    }

    func sign(app: AppInfoPresentable, options: Options, icon: UIImage?, certificate: CertificatePair?, count: Int) async throws -> [String] {
        var held = Set<String>()
        var uuids: [String] = []
        defer { Self.reserved.subtract(held) }
        guard let base = options.appIdentifier ?? app.identifier, let certificate, !certificate.revoked,
              options.signingOption == .default,
              (certificate.expiration ?? .distantPast) > Date(),
              let key = Storage.shared.getFile(.certificate, from: certificate),
              let url = Storage.shared.getFile(.provision, from: certificate) else {
            throw DirectError("تكرار التطبيق يتطلب شهادة صالحة وتوقيعًا بملف تزويد.")
        }
        let profile = try DirectProfile.read(url)
        try Self.validateIdentity(key, password: certificate.password ?? "", profile: url)
        var occupied = Self.reserved
        for entity in ["Imported", "Signed"] {
            let request = NSFetchRequest<NSDictionary>(entityName: entity)
            request.resultType = .dictionaryResultType
            request.propertiesToFetch = ["identifier"]
            for row in try Storage.shared.context.fetch(request) {
                if let id = row["identifier"] as? String { occupied.insert(id) }
            }
        }
        let plan = try ClonePolicy.identifiers(base: base, count: count, occupied: occupied, profile: profile)
        guard Self.reserved.isDisjoint(with: plan) else { throw DirectError("هذه النسخ قيد التوقيع بالفعل.") }
        held = Set(plan)
        Self.reserved.formUnion(held)
        for (offset, id) in plan.enumerated() {
            try Task.checkCancellation()
            stage = "توقيع النسخة \(offset + 1) من \(count) · \(id)"
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

    private static func validateIdentity(_ p12: URL, password: String, profile: URL) throws {
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

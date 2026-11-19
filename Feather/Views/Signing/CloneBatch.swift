import SwiftUI
import CoreData
import Security

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
        let plan = try ClonePolicy.identifiers(base: base, count: count, occupied: occupied, profile: DirectProfile.read(url))
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
        var items: CFArray?
        let status = SecPKCS12Import(try Data(contentsOf: p12) as CFData,
                                     [kSecImportExportPassphrase as String: password] as CFDictionary, &items)
        guard status == errSecSuccess, let records = items as? [[String: Any]],
              let item = records.first?[kSecImportItemIdentity as String],
              CFGetTypeID(item as CFTypeRef) == SecIdentityGetTypeID() else {
            throw DirectError("تعذّر فتح هوية التوقيع المحلية. تحقق من الشهادة وكلمة مرورها.")
        }
        let identity = item as! SecIdentity
        var leaf: SecCertificate?
        guard SecIdentityCopyCertificate(identity, &leaf) == errSecSuccess, let leaf,
              let plist = try PropertyListSerialization.propertyList(from: DirectProfile.payload(profile), format: nil) as? [String: Any],
              let allowed = plist["DeveloperCertificates"] as? [Data],
              allowed.contains(SecCertificateCopyData(leaf) as Data) else {
            throw DirectError("شهادة التوقيع غير مدرجة في ملف التزويد المختار.")
        }
    }
}

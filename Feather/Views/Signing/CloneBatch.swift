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
            var held = Set<String>()
            defer {
                Self.reserved.subtract(held)
                running = false
                task = nil
            }
            do {
                guard let base = app.identifier, let certificate, !certificate.revoked,
                      options.signingOption == .default,
                      let url = Storage.shared.getFile(.provision, from: certificate) else {
                    throw DirectError("تكرار التطبيق يتطلب شهادة صالحة وتوقيعًا بملف تزويد.")
                }
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
                    } catch {
                        try? await signer.clean()
                        throw error
                    }
                }
                stage = "اكتمل توقيع النسخ. يمكنك تثبيتها من المكتبة."
            } catch is CancellationError { stage = "أُلغي التوقيع. النسخ المكتملة محفوظة في المكتبة." }
            catch { stage = stage.isEmpty ? error.localizedDescription : stage + " — " + error.localizedDescription }
        }
    }
}

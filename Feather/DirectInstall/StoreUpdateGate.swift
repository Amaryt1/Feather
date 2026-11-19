import SwiftUI
import CryptoKit
import NimbleViews

@MainActor
final class StoreUpdateGate: ObservableObject {
    struct Document: Decodable {
        let schema: Int
        let revision: Int
        let current: StoreRelease?
        enum CodingKeys: String, CodingKey { case schema, revision, current }
        init(from decoder: Decoder) throws {
            let fields = try decoder.container(keyedBy: CodingKeys.self)
            schema = try fields.decode(Int.self, forKey: .schema)
            revision = try fields.decode(Int.self, forKey: .revision)
            current = try fields.decode(StoreRelease?.self, forKey: .current)
        }
    }
    static let endpoint = URL(string: "https://raw.githubusercontent.com/Amaryt1/Mstoda/main/store-update.json")!
    @Published private(set) var required: StoreRelease?
    @Published private(set) var checked = false
    @Published private(set) var offline = false
    private let cache = "AMARYT.lastStoreUpdateDocument"
    private var generation = 0
    private var revision = -1

    init() {
        if let bytes = UserDefaults.standard.data(forKey: cache) { try? accept(bytes) }
    }

    private func accept(_ bytes: Data) throws {
        let doc = try JSONDecoder().decode(Document.self, from: bytes)
        guard doc.schema == 1, doc.revision >= 0, doc.revision >= revision else { throw DirectError("صيغة نشر غير مدعومة.") }
        if let release = doc.current {
            try release.validate()
            let bundle = Bundle.main
            required = try release.required(over: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "",
                                            build: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "") ? release : nil
        } else { required = nil }
        revision = doc.revision
    }

    func refresh() async {
        generation += 1
        let token = generation
        do {
            let request = URLRequest(url: Self.endpoint, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
            let (bytes, response) = try await URLSession.shared.data(for: request)
            guard generation == token, !Task.isCancelled else { return }
            guard response.url == Self.endpoint, (response as? HTTPURLResponse)?.statusCode == 200,
                  bytes.count <= 65536 else { throw DirectError("تعذّر جلب إعدادات التحديث.") }
            try accept(bytes)
            UserDefaults.standard.set(bytes, forKey: cache)
            offline = false
        } catch {
            guard generation == token, !Task.isCancelled else { return }
            offline = true
        }
        checked = true
    }
}

enum StoreUpdateSigning {
    static func verifyFile(_ url: URL, release: StoreRelease) async throws {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var digest = SHA256()
        while let chunk = try handle.read(upToCount: 1 << 20), !chunk.isEmpty {
            try Task.checkCancellation()
            digest.update(data: chunk)
        }
        guard digest.finalize().map({ String(format: "%02x", $0) }).joined() == release.sha256 else {
            throw DirectError("بصمة IPA مختلفة عن الملف المنشور. أعد التحقق من التحديث.")
        }
    }

    static func verifyContinuity(of directory: URL) throws {
        func claims(_ executable: URL?) throws -> [String: Any] {
            guard let executable, let bytes = LCGetMachOEntitlements(executable.path),
                  let claims = try PropertyListSerialization.propertyList(from: bytes, format: nil) as? [String: Any] else {
                throw DirectError("تعذّر التحقق من صلاحيات التحديث.")
            }
            return claims
        }
        let installed = try claims(Bundle.main.executableURL)
        let signed = try claims(Bundle(url: directory)?.executableURL)
        for key in ["application-identifier", "com.apple.developer.team-identifier"] {
            guard let identity = installed[key] as? String, signed[key] as? String == identity else {
                throw DirectError("تغيّرت هوية التوقيع؛ تعذّر تجهيز تحديث فوق النسخة الحالية.")
            }
        }
        for key in ["keychain-access-groups", "com.apple.security.application-groups"] {
            let previous = installed[key] as? [String] ?? []
            let next = signed[key] as? [String] ?? []
            guard Set(previous).isSubset(of: Set(next)) else { throw DirectError("يفقد التحديث صلاحية الوصول إلى بيانات النسخة الحالية.") }
        }
    }

    @MainActor static func certificate() throws -> CertificatePair {
        let storage = Storage.shared
        guard let cert = storage.getCertificate(for: UserDefaults.standard.integer(forKey: "feather.selectedCert")),
              !cert.revoked, (cert.expiration ?? .distantPast) > Date(),
              let key = storage.getFile(.certificate, from: cert), let url = storage.getFile(.provision, from: cert) else {
            throw DirectError("لا توجد شهادة توقيع صالحة. يجب إضافة شهادة لتحديث المتجر.")
        }
        let profile = try DirectProfile.read(url)
        try CloneBatch.validateIdentity(key, password: cert.password ?? "", profile: url)
        guard let id = Bundle.main.bundleIdentifier, profile.permits(id),
              let executable = Bundle.main.executableURL, let data = LCGetMachOEntitlements(executable.path),
              let claims = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let prefix = profile.Entitlements.applicationIdentifier.split(separator: ".").first,
              claims["application-identifier"] as? String == String(prefix) + "." + id,
              let plist = try PropertyListSerialization.propertyList(from: DirectProfile.payload(url), format: nil) as? [String: Any],
              let teams = plist["TeamIdentifier"] as? [String],
              let team = claims["com.apple.developer.team-identifier"] as? String, teams.contains(team) else {
            throw DirectError("اختر ملف تزويد متوافقًا مع هوية وفريق توقيع المتجر المثبّت.")
        }
        return cert
    }
}

struct StoreUpdateScreen: View {
    let release: StoreRelease
    @ObservedObject var gate: StoreUpdateGate
    @StateObject private var engine = DirectEngine()
    @State private var message = ""
    @State private var adding = false
    @State private var choosing = false
    @State private var settings = false

    private var working: Bool {
        [.preparing, .downloading, .signing, .submitting].contains(engine.phase)
    }

    private func checkCertificate() -> Bool {
        do { _ = try StoreUpdateSigning.certificate(); message = ""; return true }
        catch { message = error.localizedDescription; return false }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Image(systemName: "arrow.down.app.fill").font(.largeTitle).foregroundStyle(Color.accentColor)
                    Text("تحديث AMARYT STORE مطلوب").font(.title2.bold())
                    Text(release.version + (release.build.isEmpty ? "" : " (\(release.build))"))
                    Text(release.notes).multilineTextAlignment(.center)
                    if gate.offline { Text("الاتصال غير متاح. يُعرض آخر تحديث إجباري محفوظ.").font(.footnote) }
                    if !message.isEmpty { Text(message).foregroundStyle(.secondary) }
                    if engine.phase != .idle { Text(engine.statusText) }
                    if working { ProgressView(value: engine.phase == .downloading ? engine.progress : nil) }
                    if engine.phase == .sent {
                        Text("بعد موافقة iOS، افتح المتجر مرة ثانية للتحقق من الإصدار. أبقِ المتجر مفتوحًا أثناء نقل الملف.")
                    }
                    if engine.phase == .ready || engine.phase == .sent {
                        Button("تثبيت التحديث") { engine.submit() }.buttonStyle(.borderedProminent)
                    } else {
                        Button(engine.phase == .failed ? "إعادة المحاولة" : "تحديث الآن") {
                            if checkCertificate() { engine.prepareStoreUpdate(release) }
                        }.buttonStyle(.borderedProminent).disabled(working)
                    }
                    if engine.phase == .idle || engine.phase == .failed {
                        Button("إضافة شهادة") { adding = true }
                        Button("اختيار أو تغيير الشهادة") { choosing = true }
                        Button("إعدادات المحرك والثقة المحلية") { settings = true }
                    }
                    Button("فحص التحديث مجددًا") { Task { await gate.refresh() } }
                    Link("التواصل عبر Telegram", destination: URL(string: "https://t.me/llydl")!)
                }
                .frame(maxWidth: 520).padding().frame(maxWidth: .infinity)
            }
            .storeScreen()
            .sheet(isPresented: $adding, onDismiss: { _ = checkCertificate() }) {
                CertificatesAddView(onSaved: { UserDefaults.standard.set(0, forKey: "feather.selectedCert") })
            }
            .sheet(isPresented: $choosing, onDismiss: { _ = checkCertificate() }) {
                NavigationStack { CertificatesView().toolbar {
                    ToolbarItem(placement: .confirmationAction) { Button("تم") { choosing = false } }
                } }
            }
            .sheet(isPresented: $settings) {
                NavigationStack { DirectSettingsView().toolbar {
                    ToolbarItem(placement: .confirmationAction) { Button("تم") { settings = false } }
                } }
            }
        }
        .onDisappear { engine.cancel() }
    }
}

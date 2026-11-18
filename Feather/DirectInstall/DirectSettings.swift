import SwiftUI
import UniformTypeIdentifiers

enum DirectPreferences {
    static var enabled: Bool { UserDefaults.standard.object(forKey: "AMARYT.Local.enabled") as? Bool ?? true }
    static var retries: Int { min(3, max(0, UserDefaults.standard.object(forKey: "AMARYT.Local.retries") as? Int ?? 1)) }
}
private struct RootProfile: FileDocument {
    static let type = UTType(filenameExtension: "mobileconfig") ?? .data
    static var readableContentTypes: [UTType] { [type] }
    let data: Data
    init(_ data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

struct DirectSettingsView: View {
    @AppStorage("AMARYT.Local.enabled") private var enabled = true
    @AppStorage("AMARYT.Local.retries") private var retries = 1
    @State private var profile: RootProfile?
    @State private var exporting = false
    @State private var renew = false
    @State private var message = ""

    var body: some View {
        Form {
            Toggle("تفعيل التثبيت المحلي", isOn: $enabled)
            Stepper("محاولات إضافية للتنزيل: \(retries)", value: $retries, in: 0...3)
            Section("تجهيز HTTPS على هذا الجهاز") {
                Text("احفظ ملف الثقة على جهازك وافتحه، ثم ثبّت ملف التعريف من الإعدادات. افتح عام ← حول ← إعدادات الثقة بالشهادات، وفعّل الثقة لشهادة AMARYT الخاصة بهذا الجهاز.")
                Button("حفظ ملف الثقة العام") {
                    do {
                        profile = RootProfile(try DirectIdentity.load().publicProfile())
                        exporting = true
                    } catch { message = error.localizedDescription }
                }
                Button("تجديد هوية HTTPS", role: .destructive) { renew = true }
                if !message.isEmpty { Text(message).font(.footnote) }
            }
        }
        .navigationTitle("AMARYT Direct Install")
        .fileExporter(isPresented: $exporting, document: profile, contentType: RootProfile.type,
                      defaultFilename: "AMARYT-Local.mobileconfig") { result in
            if case let .failure(error) = result { message = error.localizedDescription }
        }
        .alert("تجديد هوية الجهاز؟", isPresented: $renew) {
            Button("تجديد", role: .destructive) {
                do { try DirectIdentity.reset(); message = "احذف ملف الثقة السابق من إعدادات iOS وثبّت ملفًا جديدًا." }
                catch { message = error.localizedDescription }
            }
            Button("إلغاء", role: .cancel) {}
        } message: { Text("بعد التجديد يلزم تثبيت ملف الثقة الجديد وتفعيل الثقة به.") }
    }
}

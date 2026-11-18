import SwiftUI

struct DirectInstallView: View {
    let input: DirectInput
    @Environment(\.dismiss) private var dismiss
    @StateObject private var engine = DirectEngine()
    @State private var settings = false
    @State private var confirmClose = false
    @State private var certificates = false

    private var title: String {
        switch input { case let .source(_, title, _, _): return title
        case let .signed(app): return app.name ?? "التطبيق" }
    }
    private var version: String? {
        switch input { case let .source(_, _, version, _): return version
        case let .signed(app): return app.version }
    }
    private var stateText: String {
        switch engine.phase {
        case .idle, .preparing: return "جارٍ تجهيز التثبيت…"
        case .downloading: return "جارٍ تنزيل IPA…"
        case .signing: return "جارٍ توقيع التطبيق على جهازك…"
        case .ready: return "الحزمة موقّعة وجاهزة للتثبيت"
        case .submitting: return "جارٍ إرسال طلب التثبيت…"
        case .sent: return "تم إرسال طلب التثبيت إلى iOS"
        case .failed: return engine.message
        }
    }
    @ViewBuilder private var icon: some View {
        switch input {
        case let .source(_, _, _, url):
            AsyncImage(url: url) { image in image.resizable().scaledToFit() } placeholder: {
                Image("App_Unknown").resizable().scaledToFit()
            }
        case let .signed(app): FRAppIconView(app: app)
        }
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    icon.frame(width: 76, height: 76).clipShape(RoundedRectangle(cornerRadius: 16))
                    Text(title).font(.title2.bold())
                    if let version { Text(version).foregroundStyle(.secondary) }
                    if engine.size > 0 { Text(ByteCountFormatter.string(fromByteCount: engine.size, countStyle: .file)).font(.caption) }
                    if engine.phase == .downloading {
                        ProgressView(value: engine.progress)
                        if let fraction = engine.progress {
                            Text(fraction.formatted(.percent.precision(.fractionLength(0))))
                        }
                        if engine.totalSize > 0 {
                            Text("من " + ByteCountFormatter.string(fromByteCount: engine.totalSize, countStyle: .file))
                        }
                        if engine.speed > 0 {
                            Text(ByteCountFormatter.string(fromByteCount: Int64(engine.speed), countStyle: .file) + " / ث").font(.caption)
                        }
                    }
                    else if [.preparing, .signing, .submitting].contains(engine.phase) { ProgressView() }
                    Text(stateText).multilineTextAlignment(.center)
                    if engine.phase == .ready {
                        Button("تثبيت الآن") {
                            engine.submit()
                        }.buttonStyle(.borderedProminent)
                    }
                    if engine.phase == .failed {
                        if engine.needsTrust { Button("إعدادات الثقة المحلية") { settings = true } }
                        if engine.needsCertificate { Button("فتح قسم الشهادات") { certificates = true } }
                        Button("إعادة المحاولة") { engine.prepare(input) }.buttonStyle(.borderedProminent)
                    }
                    if engine.phase == .sent {
                        Text(engine.servedPackage ? "وصل طلب قراءة IPA إلى الخادم المحلي." : "بانتظار طلب قراءة الحزمة. أبقِ المتجر مفتوحًا أثناء النقل.").font(.footnote)
                        Button("إنهاء المشاركة المحلية") { confirmClose = true }
                    } else {
                        Button("إلغاء") { engine.cancel(); dismiss() }
                    }
                }.frame(maxWidth: .infinity).padding()
            }
            .navigationTitle("AMARYT Direct Install")
            .navigationBarTitleDisplayMode(.inline)
            .alert("إنهاء إتاحة الحزمة؟", isPresented: $confirmClose) {
                Button("إنهاء", role: .destructive) { engine.cancel(); dismiss() }
                Button("متابعة المشاركة", role: .cancel) {}
            } message: { Text("إذا كان iOS ما زال يقرأ الملف، فقد يتوقف التثبيت.") }
            .sheet(isPresented: $settings) { NavigationStack { DirectSettingsView().toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("تم") { settings = false } }
            } } }
            .sheet(isPresented: $certificates) { NavigationStack { CertificatesView().toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("تم") { certificates = false } }
            } } }
        }
        .interactiveDismissDisabled(engine.phase == .sent || engine.phase == .submitting)
        .onAppear { if engine.phase == .idle { engine.prepare(input) } }
        .onDisappear { engine.cancel() }
    }
}

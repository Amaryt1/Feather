import SwiftUI
import NimbleViews

struct DirectInstallView: View {
    @Environment(\.storeAppearance) private var appearance
    @Environment(\.storeMotion) private var motion
    let input: DirectInput
    @Environment(\.dismiss) private var dismiss
    @StateObject private var engine = DirectEngine()
    @State private var settings = false
    @State private var confirmClose = false
    @State private var certificates = false

    private var title: String {
        if let prepared = engine.preparedTitle { return prepared }
        switch input { case let .source(_, title, _, _): return title
        case let .signed(app): return app.name ?? "التطبيق" }
    }
    private var version: String? {
        if let prepared = engine.preparedVersion { return prepared }
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
    private var stateIcon: String {
        switch engine.phase {
        case .idle, .preparing: "shippingbox"
        case .downloading: "arrow.down.circle"
        case .signing: "signature"
        case .ready: "checkmark.seal"
        case .submitting, .sent: "paperplane"
        case .failed: "exclamationmark.triangle"
        }
    }
    @ViewBuilder private var icon: some View {
        if let prepared = engine.preparedIcon {
            Image(uiImage: prepared).resizable().scaledToFit()
        } else { switch input {
        case let .source(_, _, _, url):
            AsyncImage(url: url) { image in image.resizable().scaledToFit() } placeholder: {
                Image("App_Unknown").resizable().scaledToFit()
            }
        case let .signed(app): FRAppIconView(app: app)
        } }
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ZStack {
                        icon.frame(width: 68, height: 68).clipShape(RoundedRectangle(cornerRadius: 16))
                        if engine.phase == .downloading, let value = engine.progress {
                            StoreProgressRing(value).frame(width: 96, height: 96)
                        }
                    }.frame(height: 100)
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
                    Label(stateText, systemImage: stateIcon)
                        .font(.body.weight(.medium)).multilineTextAlignment(.center)
                        .foregroundStyle(engine.phase == .failed ? Color.red : (appearance == .professional ? StoreTheme.ink : Color.primary))
                    if engine.phase == .ready || engine.phase == .sent {
                        Button("تثبيت الآن") {
                            engine.submit()
                        }.buttonStyle(StoreActionStyle())
                    }
                    if engine.phase == .failed {
                        if engine.needsTrust { Button("إعدادات الثقة المحلية") { settings = true } }
                        if engine.needsCertificate { Button("فتح قسم الشهادات") { certificates = true } }
                        Button("إعادة المحاولة") { engine.prepare(input) }.buttonStyle(StoreActionStyle())
                    }
                    if engine.phase == .sent {
                        Text(engine.servedPackage ? "وصل طلب قراءة IPA إلى الخادم المحلي." : "بانتظار طلب قراءة الحزمة. أبقِ المتجر مفتوحًا أثناء النقل.").font(.footnote)
                        Button("إنهاء المشاركة المحلية") { confirmClose = true }
                    } else {
                        Button("إلغاء") { engine.cancel(); dismiss() }
                    }
                }.frame(maxWidth: 520).padding(StoreTheme.inset).storeCard().padding()
                    .frame(maxWidth: .infinity)
                    .animation(motion ? StoreTheme.feedback : nil, value: engine.phase)
            }
            .storeScreen()
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
        .onDisappear { if !settings && !certificates { engine.cancel() } }
    }
}

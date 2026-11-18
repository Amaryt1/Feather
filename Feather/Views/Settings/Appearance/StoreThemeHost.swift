import SwiftUI
import NimbleViews
import AltSourceKit

/// The probe belongs to this WindowGroup's window, including multiwindow iPad scenes.
private struct StoreWindowStyle: UIViewRepresentable {
    let style: UIUserInterfaceStyle
    let tint: UIColor
    final class Probe: UIView {
        var style: UIUserInterfaceStyle = .unspecified
        var accent: UIColor?
        override func didMoveToWindow() { super.didMoveToWindow(); apply() }
        func apply() {
            if window?.overrideUserInterfaceStyle != style { window?.overrideUserInterfaceStyle = style }
            if window?.tintColor != accent { window?.tintColor = accent }
        }
    }
    func makeUIView(context: Context) -> Probe { Probe() }
    func updateUIView(_ view: Probe, context: Context) {
        view.style = style
        view.accent = tint
        view.apply()
    }
}

struct StoreThemeHost: ViewModifier {
    @AppStorage("Feather.userInterfaceStyle") private var saved = 0
    @AppStorage("Feather.userTintColor") private var tint = "#848ef9"
    @Environment(\.scenePhase) private var phase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled

    func body(content: Content) -> some View {
        let appearance = StoreAppearance(saved: saved)
        let accent = appearance == .professional ? StoreTheme.cyan : Color(hex: tint)
        let scheme: ColorScheme? = switch appearance {
        case .system: nil
        case .light: .light
        case .dark, .professional: .dark
        }
        let motion = StoreAppearance.animates(active: phase == .active, reduceMotion: reduceMotion, lowPower: lowPower)
        content
            .environment(\.storeAppearance, appearance)
            .environment(\.storeMotion, motion)
            .tint(accent)
            .accentColor(accent)
            .preferredColorScheme(scheme)
            .background {
                StoreWindowStyle(style: scheme.map { $0 == .dark ? .dark : .light } ?? .unspecified, tint: UIColor(accent))
                    .frame(width: 0, height: 0).allowsHitTesting(false).accessibilityHidden(true)
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
                lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
            }
    }
}

import SwiftUI

private struct AppearanceKey: EnvironmentKey {
    static let defaultValue = StoreAppearance.system
}
private struct MotionKey: EnvironmentKey {
    static let defaultValue = true
}
public extension EnvironmentValues {
    var storeAppearance: StoreAppearance {
        get { self[AppearanceKey.self] }
        set { self[AppearanceKey.self] = newValue }
    }
    var storeMotion: Bool {
        get { self[MotionKey.self] }
        set { self[MotionKey.self] = newValue }
    }
}

public enum StoreTheme {
    public static let cyan = Color(red: 0.43, green: 0.94, blue: 0.98)
    public static let teal = Color(red: 0.25, green: 0.78, blue: 0.77)
    public static let violet = Color(red: 0.66, green: 0.62, blue: 0.97)
    public static let midnight = Color(red: 0.038, green: 0.060, blue: 0.113)
    public static let glass = Color(red: 0.078, green: 0.118, blue: 0.183)
    public static let ink = Color(red: 0.88, green: 0.97, blue: 0.99)
    public static let muted = Color(red: 0.69, green: 0.77, blue: 0.85)
    public static let radius: CGFloat = 20
    public static let inset: CGFloat = 14
    public static let feedback = Animation.easeOut(duration: 0.18)
    public static let ring = AngularGradient(colors: [cyan, teal, violet, cyan], center: .center)
}

private struct ParticleField: View {
    @Environment(\.storeMotion) private var motion
    @State private var visible = false
    var body: some View {
        Group {
            if visible && motion {
                TimelineView(.periodic(from: .now, by: 1.0 / 12)) { tick in
                    layer(time: tick.date.timeIntervalSinceReferenceDate)
                }
            } else { layer(time: 0) }
        }
        .onAppear { visible = true }
        .onDisappear { visible = false }
        .allowsHitTesting(false).accessibilityHidden(true)
    }

    private func layer(time: TimeInterval) -> some View {
        Canvas { ctx, size in
            let rect = CGRect(origin: .zero, size: size)
            ctx.fill(Path(rect), with: .linearGradient(
                Gradient(colors: [.black, StoreTheme.midnight, Color(red: 0.045, green: 0.085, blue: 0.13)]),
                startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)))
            let glow = CGPoint(x: size.width * (0.72 + 0.08 * sin(time / 28)), y: size.height * 0.18)
            ctx.fill(Path(rect), with: .radialGradient(Gradient(colors: [StoreTheme.violet.opacity(0.13), .clear]),
                center: glow, startRadius: 0, endRadius: max(1, size.width * 0.82)))
            let halo = CGPoint(x: size.width * (0.18 + 0.07 * cos(time / 37)), y: size.height * 0.12)
            ctx.fill(Path(rect), with: .radialGradient(Gradient(colors: [StoreTheme.teal.opacity(0.14), .clear]),
                center: halo, startRadius: 0, endRadius: max(1, size.width * 0.70)))
            for index in 0..<48 {
                let depth = Double(index % 3 + 1)
                let x = Double((index * 163 + 41) % 997) / 997
                let y = (Double((index * 271 + 37) % 991) / 991 + time * depth / 900).truncatingRemainder(dividingBy: 1)
                let diameter = 0.75 + depth * 0.40
                let dot = CGRect(x: x * size.width, y: y * size.height, width: diameter, height: diameter)
                ctx.fill(Path(ellipseIn: dot), with: .color((index.isMultiple(of: 4) ? StoreTheme.violet : StoreTheme.cyan).opacity(0.25 + depth * 0.09 + 0.06 * sin(time / 5 + Double(index)))))
            }
        }
    }
}

private struct StoreScreen: ViewModifier {
    @Environment(\.storeAppearance) var appearance
    var fallback: Color?
    func body(content: Content) -> some View {
        content
            .scrollContentBackground(appearance == .professional ? .hidden : .automatic)
            .background {
                if appearance == .professional { ParticleField().ignoresSafeArea() }
                else if let fallback { fallback.ignoresSafeArea() }
            }
            .toolbarBackground(appearance == .professional ? .hidden : .automatic, for: .navigationBar, .tabBar)
    }
}

private struct StoreCard: ViewModifier {
    @Environment(\.storeAppearance) var appearance
    @Environment(\.accessibilityReduceTransparency) var solid
    var radius: CGFloat
    func body(content: Content) -> some View {
        let neon = appearance == .professional
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content.background {
            shape.fill(solid ? AnyShapeStyle(Color(uiColor: .secondarySystemGroupedBackground)) : AnyShapeStyle(.regularMaterial))
                .overlay { if neon { shape.fill(StoreTheme.glass.opacity(solid ? 1 : 0.83)) } }
                .overlay {
                    shape.strokeBorder(LinearGradient(colors: neon
                        ? [StoreTheme.cyan.opacity(0.50), StoreTheme.teal.opacity(0.13), StoreTheme.violet.opacity(0.40)]
                        : [.primary.opacity(0.10), .primary.opacity(0.04)],
                        startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                }
                .allowsHitTesting(false)
        }
    }
}

public struct StorePressStyle: ButtonStyle {
    @Environment(\.storeMotion) private var motion
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.83 : 1)
            .scaleEffect(motion && configuration.isPressed ? 0.985 : 1)
            .animation(motion ? StoreTheme.feedback : nil, value: configuration.isPressed)
    }
}

public extension View {
    func storeScreen(fallback: Color? = nil) -> some View { modifier(StoreScreen(fallback: fallback)) }
    func storeCard(radius: CGFloat = StoreTheme.radius) -> some View { modifier(StoreCard(radius: radius)) }
}

public struct StoreProgressRing: View {
    @Environment(\.storeAppearance) private var appearance
    @Environment(\.storeMotion) private var motion
    private let value: Double
    public init(_ value: Double) { self.value = min(1, max(0, value)) }
    public var body: some View {
        let neon = appearance == .professional
        ZStack {
            Circle().stroke(Color.secondary.opacity(0.23), lineWidth: 3)
            Circle().trim(from: 0, to: value)
                .stroke(neon ? AnyShapeStyle(StoreTheme.ring) : AnyShapeStyle(Color.accentColor),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: neon ? StoreTheme.cyan.opacity(0.3) : .clear, radius: 3)
        }
        .animation(motion ? StoreTheme.feedback : nil, value: value)
        .accessibilityHidden(true)
    }
}

private struct StoreArrival: ViewModifier {
    @Environment(\.storeMotion) private var motion
    @State private var visible = false
    func body(content: Content) -> some View {
        content.opacity(!motion || visible ? 1 : 0.84)
            .offset(y: !motion || visible ? 0 : 4)
            .animation(motion ? StoreTheme.feedback : nil, value: visible)
            .onAppear { visible = true }
            .onDisappear { visible = false }
    }
}

public extension View {
    func storeArrival() -> some View { modifier(StoreArrival()) }
}

public struct StoreActionStyle: ButtonStyle {
    @Environment(\.storeAppearance) private var appearance
    @Environment(\.storeMotion) private var motion
    @Environment(\.isEnabled) private var enabled
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        let neon = appearance == .professional
        configuration.label.font(.headline)
            .foregroundStyle(neon ? StoreTheme.midnight : Color.white)
            .padding(.horizontal, 16).frame(minHeight: 44)
            .background(neon ? StoreTheme.cyan : Color.accentColor, in: RoundedRectangle(cornerRadius: 14))
            .shadow(color: neon ? StoreTheme.teal.opacity(0.25) : .clear, radius: 5)
            .opacity(!enabled ? 0.5 : configuration.isPressed ? 0.82 : 1)
            .scaleEffect(motion && configuration.isPressed ? 0.98 : 1)
            .animation(motion ? StoreTheme.feedback : nil, value: configuration.isPressed)
    }
}

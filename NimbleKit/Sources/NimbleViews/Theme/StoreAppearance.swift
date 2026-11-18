// Raw values 0–2 match Feather's persisted UIKit interface styles.
public enum StoreAppearance: Int, CaseIterable, Sendable {
    case system = 0, light = 1, dark = 2, professional = 3

    public init(saved: Int) { self = Self(rawValue: saved) ?? .system }

    public static func animates(active: Bool, reduceMotion: Bool, lowPower: Bool) -> Bool {
        active && !reduceMotion && !lowPower
    }
}

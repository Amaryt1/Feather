import Foundation

@main
struct AppearanceTests {
    static func main() {
        let previous: [StoreAppearance] = [.system, .light, .dark]
        for (saved, mode) in previous.enumerated() {
            precondition(StoreAppearance(saved: saved) == mode)
        }
        precondition(StoreAppearance(saved: 3) == .professional)
        precondition(StoreAppearance(saved: -1) == .system)
        precondition(StoreAppearance.allCases.count == 4)
        for active in [false, true] {
            for reduce in [false, true] {
                for low in [false, true] {
                    let expected = active && !reduce && !low
                    precondition(StoreAppearance.animates(active: active, reduceMotion: reduce, lowPower: low) == expected)
                }
            }
        }
        print("Appearance selection and eight motion-policy combinations passed.")
    }
}

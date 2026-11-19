import Foundation

@main struct StoreUpdatePolicyTests {
    static func main() throws {
        func release(_ version: String, _ build: String = "", _ mandatory: Bool = true,
                     _ url: String = "https://github.com/Amaryt1/Mstoda/releases/download/v3/store.ipa") -> StoreRelease {
            StoreRelease(version: version, build: build, url: URL(string: url)!, notes: "", mandatory: mandatory,
                         sha256: String(repeating: "a", count: 64))
        }
        for (policy, installed, build, expected) in [
            (release("2.10"), "2.9.9", "99", true), (release("2.10"), "2.10.0", "1", false),
            (release("2.10", "12"), "2.10", "2", true), (release("2.10", "12"), "2.10", "12", false),
            (release("2"), "3", "1", false), (release("3", "", false), "1", "1", false)
        ] {
            try policy.validate()
            let required = try policy.required(over: installed, build: build)
            precondition(required == expected)
        }
        for checked in [false, true] {
            let required = release("3")
            precondition(StoreLaunchScreen(libraryReady: false, checked: checked, required: required) == .welcome)
            precondition(StoreLaunchScreen(libraryReady: false, checked: checked, required: nil) == .welcome)
            precondition(StoreLaunchScreen(libraryReady: true, checked: checked, required: required) == .mandatory(required))
            precondition(StoreLaunchScreen(libraryReady: true, checked: checked, required: nil) == (checked ? .store : .welcome))
        }
        precondition((try? StoreRelease.parts("1..2")) == nil)
        do {
            try release("3", "", true, "https://example.com/store.ipa").validate()
            fatalError("untrusted host accepted")
        } catch {}
    }
}

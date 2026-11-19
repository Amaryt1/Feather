import Foundation

@main
struct SourceOperationTests {
    static func main() {
        func key(_ source: String = "https://example.com/apps", _ app: String = "tv",
                 _ version: String = "1", _ ipa: String = "https://cdn.example/app.ipa") -> String {
            SourceOperationKey(source: SourceOperationKey.repository(URL(string: source))!, app: app,
                               version: version, url: ipa).id
        }
        let original = key()
        precondition(original == key("https://example.com/apps?utm_source=catalog"))
        precondition(original != key("https://example.com/apps?channel=beta"))
        precondition(original != key("https://other.example/apps"))
        precondition(original != key("https://example.com/apps", "tv", "2"))
        precondition(original != key("https://example.com/apps", "tv", "1", "https://cdn.example/b.ipa"))
        var history = SourceOutcomes()
        for state: SourceOutcome in [.cancelled, .failed("network"), .imported, .signing, .ready("signed"), .submitted] {
            history[original] = state
            precondition(history[key()] == state && history[key("https://other.example/apps")] == nil)
        }
        history[original] = nil
        precondition(history[key()] == nil)
        history[original] = .signing
        for index in 0..<140 { history["other-\(index)"] = .imported }
        precondition(history[key()] == .signing && history["other-0"] == nil)
        print("Source identity, reattachment, source/version isolation, retry and retained outcomes passed")
    }
}

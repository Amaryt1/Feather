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
        var outcomes = SourceOutcomes()
        func check(_ sessions: [String], _ transfers: [String], _ expected: [String]) {
            let rows = DownloadManagerEntry.visible(sessions: sessions, transfers: transfers, outcomes: outcomes)
            precondition(rows.map(\.id) == expected)
        }
        check([], [], [])
        check([], ["one"], ["one"])
        check([], ["one", "two"], ["one", "two"])
        check(["direct"], ["one", "two"], ["direct", "one", "two"])
        // Pausing/resuming or packaging changes the transfer in place. During
        // handoff its signing outcome may coexist with its last transfer row.
        outcomes["one"] = .signing
        check(["direct"], ["one", "two"], ["direct", "one", "two"])
        check(["direct"], ["two"], ["direct", "two", "one"])
        outcomes["two"] = .cancelled
        check(["direct"], [], ["direct", "one"])
        for terminal: SourceOutcome in [.ready("uuid"), .copiesReady(["1", "2"]), .submitted, .installed,
                                       .imported, .cancelled, .failed("error")] {
            outcomes["one"] = terminal
            check([], [], [])
        }
        check(["direct"], ["direct", "two", "two"], ["direct", "two"])
        precondition(DownloadManagerEntry.badge(0) == nil && DownloadManagerEntry.badge(1) == "1")
        precondition(DownloadManagerEntry.badge(99) == "99" && DownloadManagerEntry.badge(100) == "99+")
        print("Source identity, reattachment, source/version isolation, retry and retained outcomes passed")
    }
}

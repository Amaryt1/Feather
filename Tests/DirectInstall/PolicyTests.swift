import Foundation

@main
struct PolicyTests {
    static func main() async throws {
        for text in ["http://example.org/a", "file:///tmp/a", "https://name:secret@example.org/a", "https://example.org/a#private"] {
            precondition((try? DirectPolicy.https(URL(string: text))) == nil)
        }
        precondition((try? DirectPolicy.installLink(URL(string: "https://example.org/manifest.plist")!)) == nil)
        let manifest = URL(string: "https://127.0.0.1:35000/session/manifest.plist")!
        let ipa = URL(string: "https://127.0.0.1:35000/session/app.ipa")!
        let metadata = DirectMetadata(title: "A&B", bundle: "org.example.demo", version: "42")
        let data = try metadata.manifest(for: ipa)
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as! [String: [[String: Any]]]
        let item = plist["items"]!.first!
        let assets = item["assets"] as! [[String: String]]
        precondition(assets.first?["url"] == ipa.absoluteString)
        precondition((item["metadata"] as? [String: String])?["title"] == "A&B")
        let invalid = DirectMetadata(title: "", bundle: "", version: "")
        precondition((try? invalid.manifest(for: ipa)) == nil)
        do {
            try await DirectHandoff.send(manifest: manifest, enabled: false) { _ in fatalError("disabled handoff") }
            fatalError("disabled accepted")
        } catch is DirectError {}
        do {
            try await DirectHandoff.send(manifest: manifest, enabled: true) { _ in false }
            fatalError("iOS rejection swallowed")
        } catch is DirectError {}
        let cancelled = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            try await DirectHandoff.send(manifest: manifest, enabled: true) { _ in fatalError("cancelled handoff") }
        }
        do { try await cancelled.value; fatalError("cancel swallowed") } catch is CancellationError {}
        try await DirectHandoff.send(manifest: manifest, enabled: true) { url in
            let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
            return url.scheme == "itms-services" && query?.first(where: { $0.name == "url" })?.value == manifest.absoluteString
        }
        let location = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: location) }
        for expired in [false, true] {
            let fields: [String: Any] = ["ExpirationDate": Date(timeIntervalSinceNow: expired ? -100 : 100),
                                         "Entitlements": ["application-identifier": "TEAM.org.example.*"]]
            let xml = try PropertyListSerialization.data(fromPropertyList: fields, format: .xml, options: 0)
            try (Data([1, 2]) + xml + Data([3, 4])).write(to: location)
            let profile = try? DirectProfile.read(location)
            precondition((profile == nil) == expired)
            if let profile {
                precondition(profile.permits("org.example.game") && !profile.permits("org.other.game"))
            }
        }
        print("Direct install policy and handoff checks passed")
    }
}

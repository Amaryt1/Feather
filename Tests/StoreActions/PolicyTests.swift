import Foundation

@main
struct StoreActionTests {
    static func main() throws {
        let wildcard = DirectProfile(ExpirationDate: .distantFuture, Entitlements: .init(applicationIdentifier: "TEAM.com.example.*"))
        let exact = DirectProfile(ExpirationDate: .distantFuture, Entitlements: .init(applicationIdentifier: "TEAM.com.example.app"))
        let base = "com.example.app"
        let plan = try ClonePolicy.identifiers(base: base, count: 3, occupied: [], profile: wildcard)
        precondition(plan == [base, base + ".clone2", base + ".clone3"])
        let single = try ClonePolicy.identifiers(base: base, count: 1, occupied: [], profile: exact)
        precondition(single == [base])
        for (count, occupied, profile) in [(2, Set<String>(), exact), (0, [], wildcard), (11, [], wildcard),
                                          (3, [base + ".clone2"], wildcard)] {
            precondition((try? ClonePolicy.identifiers(base: base, count: count, occupied: occupied, profile: profile)) == nil)
        }
        let allowed: [String: Any] = ["keychain-access-groups": ["TEAM.*"], "get-task-allow": true]
        precondition(ClonePolicy.permits(["keychain-access-groups": ["TEAM.foo"]], by: allowed))
        precondition(!ClonePolicy.permits(["keychain-access-groups": ["OTHER.foo"]], by: allowed))
        precondition(!ClonePolicy.permits(["unknown": true], by: allowed))
        precondition(!ClonePolicy.permits(NSNumber(value: 1), by: NSNumber(value: true)))
        let key = SourceOperationKey(source: "مصدر", app: "tv:a", version: "2", url: "https://example.org/a")
        precondition(SourceOperationKey(encoded: key.id) == key)
        precondition(SourceOperationKey(encoded: "source:900:a") == nil)
        let a = CatalogRank(id: "source", name: "برنامج 2", date: nil, size: 250, hasArtwork: false)
        var b = CatalogRank(id: "api", name: "برنامج 10", date: Date(), size: nil, hasArtwork: true)
        let ar = Locale(identifier: "ar")
        precondition(a.precedes(b, sort: .name, locale: ar))
        precondition(b.precedes(a, sort: .newest))
        precondition(a.precedes(b, sort: .largest))
        b.lastDownload = Date()
        precondition(b.precedes(a, sort: .recommended))
        print("PASS: clone IDs, profile restrictions, collision and entitlement checks, source identity and four catalog sort modes")
    }
}

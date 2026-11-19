import Foundation

@main
struct StoreActionTests {
    static func main() throws {
        let suite = "StoreDefaultsTests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        FirstLaunchDefaults.apply(to: defaults, domain: suite, existingLibrary: false)
        let persisted = defaults.persistentDomain(forName: suite)!
        precondition(persisted["Feather.installationMethod"] as? Int == 0 && persisted["Feather.serverMethod"] as? Int == 1)
        precondition(persisted["Feather.ipFix"] as? Bool == true && persisted["Feather.userInterfaceStyle"] as? Int == 3)
        defaults.set(false, forKey: "Feather.ipFix")
        FirstLaunchDefaults.apply(to: defaults, domain: suite, existingLibrary: false)
        precondition(!defaults.bool(forKey: "Feather.ipFix"))
        defaults.removePersistentDomain(forName: suite)
        FirstLaunchDefaults.apply(to: defaults, domain: suite, existingLibrary: true)
        precondition(defaults.object(forKey: "Feather.serverMethod") == nil)
        defaults.removePersistentDomain(forName: suite)
        defaults.set(2, forKey: "Feather.userInterfaceStyle")
        FirstLaunchDefaults.apply(to: defaults, domain: suite, existingLibrary: false)
        precondition(defaults.integer(forKey: "Feather.userInterfaceStyle") == 2)
        precondition(defaults.object(forKey: "Feather.serverMethod") == nil)
        let wildcard = DirectProfile(ExpirationDate: .distantFuture, Entitlements: .init(applicationIdentifier: "TEAM.com.example.*"))
        let exact = DirectProfile(ExpirationDate: .distantFuture, Entitlements: .init(applicationIdentifier: "TEAM.com.example.app"))
        let base = "com.example.app"
        let plan = try ClonePolicy.identifiers(base: base, count: 3, occupied: [], profile: wildcard)
        precondition(plan == [base, base + ".1", base + ".2"])
        let occupiedPlan = try ClonePolicy.identifiers(base: base, count: 2, occupied: [base + ".1"], profile: wildcard)
        precondition(occupiedPlan == [base, base + ".2"])
        let single = try ClonePolicy.identifiers(base: base, count: 1, occupied: [], profile: exact)
        precondition(single == [base])
        for (count, occupied, profile) in [(2, Set<String>(), exact), (0, [], wildcard), (11, [], wildcard)] {
            precondition((try? ClonePolicy.identifiers(base: base, count: count, occupied: occupied, profile: profile)) == nil)
        }
        let grants: [String: Any] = ["application-identifier": "TEAM.com.example.*", "keychain-access-groups": ["TEAM.*"]]
        let source = ["application-identifier": "OLD.com.example.app", "keychain-access-groups": ["OLD.com.example.app"]] as [String: Any]
        let claims = try ClonePolicy.claims(source, id: base + ".1", profile: wildcard, grants: grants)
        precondition(claims["application-identifier"] as? String == "TEAM.com.example.app.1")
        precondition(claims["keychain-access-groups"] as? [String] == ["TEAM.com.example.app.1"])
        precondition((try? ClonePolicy.claims(["unknown": true], id: base, profile: wildcard, grants: grants)) == nil)
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

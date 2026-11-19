import Foundation

enum FirstLaunchDefaults {
    static func apply(to defaults: UserDefaults, domain: String, existingLibrary: Bool) {
        let marker = "Feather.didConfigureFirstLaunch"
        let saved = defaults.persistentDomain(forName: domain) ?? [:]
        guard saved[marker] == nil else { return }
        if !existingLibrary && !saved.keys.contains(where: { $0.lowercased().hasPrefix("feather.") }) {
            defaults.set(0, forKey: "Feather.installationMethod")
            defaults.set(1, forKey: "Feather.serverMethod")
            defaults.set(true, forKey: "Feather.ipFix")
            defaults.set(3, forKey: "Feather.userInterfaceStyle")
        }
        defaults.set(true, forKey: marker)
    }
}

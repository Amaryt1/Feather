import Foundation

/// Length-prefix each component so URL delimiters cannot alias another operation.
struct SourceOperationKey: Hashable {
    let source: String
    let app: String
    let version: String
    let url: String

    static func repository(_ url: URL?) -> String? {
        guard let url, var parts = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        if let items = parts.queryItems {
            let identity = items.filter { !$0.name.hasPrefix("utm_") }
            if identity.count != items.count { parts.queryItems = identity.isEmpty ? nil : identity }
        }
        if parts.path.isEmpty { parts.path = "/" }
        parts.fragment = nil
        return parts.string
    }

    var id: String {
        "source:" + [source, app, version, url].map { "\($0.utf8.count):\($0)" }.joined()
    }
}

enum SourceOutcome: Equatable {
    case submitted, imported, signing, ready(String), failed(String), cancelled
}

/// Active signing entries must survive navigation and history pruning.
struct SourceOutcomes {
    private var values: [String: SourceOutcome] = [:]
    private var recent: [String] = []
    subscript(_ key: String) -> SourceOutcome? {
        get { values[key] }
        set {
            recent.removeAll { $0 == key }
            values[key] = newValue
            if let newValue, newValue != .signing {
                recent.append(key)
                if recent.count > 100 { values.removeValue(forKey: recent.removeFirst()) }
            }
        }
    }
}

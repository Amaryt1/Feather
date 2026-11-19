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

extension SourceOperationKey {
    init?(encoded: String) {
        guard encoded.hasPrefix("source:") else { return nil }
        var bytes = encoded.utf8.dropFirst("source:".utf8.count)
        var parts: [String] = []
        for _ in 0..<4 {
            guard let end = bytes.firstIndex(of: 58),
                  let length = Int(String(decoding: bytes[..<end], as: UTF8.self)), length >= 0 else { return nil }
            bytes = bytes.suffix(from: bytes.index(after: end))
            guard length <= bytes.count, let part = String(bytes: bytes.prefix(length), encoding: .utf8) else { return nil }
            parts.append(part)
            bytes = bytes.dropFirst(length)
        }
        guard bytes.isEmpty else { return nil }
        self.init(source: parts[0], app: parts[1], version: parts[2], url: parts[3])
    }
}

enum SourceOutcome: Equatable {
    case installed, submitted, imported, signing, ready(String), copiesReady([String]), failed(String), cancelled
}

/// Active signing entries must survive navigation and history pruning.
struct SourceOutcomes {
    private var values: [String: SourceOutcome] = [:]
    private var recent: [String] = []
    var signingIDs: [String] {
        values.compactMap { $0.value == .signing ? $0.key : nil }.sorted()
    }

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

/// Ordered membership shared by the downloads list and its toolbar label.
struct DownloadManagerEntry: Identifiable {
    enum Kind { case session, transfer, signing }
    let id: String
    let kind: Kind

    static func visible(sessions: [String], transfers: [String], outcomes: SourceOutcomes) -> [Self] {
        var seen = Set<String>()
        var rows: [Self] = []
        func append(_ ids: [String], kind: Kind) {
            for id in ids where seen.insert(id).inserted { rows.append(Self(id: id, kind: kind)) }
        }
        append(sessions.sorted(), kind: .session)
        append(transfers, kind: .transfer)
        append(outcomes.signingIDs, kind: .signing)
        return rows
    }

    static func badge(_ count: Int) -> String? {
        guard count > 0 else { return nil }
        return count > 99 ? "99+" : String(count)
    }
}

import Foundation

// Match the signed profile's plist payload. Platform signature and entitlement checks remain with iOS.
struct DirectProfile: Decodable {
    let ExpirationDate: Date
    let Entitlements: EntitlementsFields
    struct EntitlementsFields: Decodable {
        let applicationIdentifier: String
        enum CodingKeys: String, CodingKey { case applicationIdentifier = "application-identifier" }
    }

    static func payload(_ url: URL) throws -> Data {
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        guard let start = data.range(of: Data("<?xml".utf8)),
              let end = data.range(of: Data("</plist>".utf8), in: start.upperBound..<data.endIndex) else {
            throw DirectError("تعذّرت قراءة ملف التزويد.")
        }
        return data[start.lowerBound..<end.upperBound]
    }

    static func read(_ url: URL) throws -> Self {
        let profile = try PropertyListDecoder().decode(Self.self, from: payload(url))
        guard profile.ExpirationDate > Date() else { throw DirectError("ملف التزويد منتهي الصلاحية.") }
        return profile
    }

    func permits(_ bundle: String) -> Bool {
        let identifier = Entitlements.applicationIdentifier
        guard !bundle.isEmpty, let split = identifier.firstIndex(of: ".") else { return false }
        let pattern = identifier[identifier.index(after: split)...]
        return pattern == bundle || (pattern.hasSuffix("*") && bundle.hasPrefix(pattern.dropLast()))
    }
}

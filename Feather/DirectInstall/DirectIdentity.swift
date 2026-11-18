import Foundation
import Security

struct DirectIdentity: Codable {
    let root: Data
    let certificate: Data
    let serverKey: Data
    let id: UUID

    private static let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "AMARYT.LocalInstall.TLS",
        kSecAttrAccount as String: "loopback"
    ]

    static func load() throws -> Self {
        var q = query
        q[kSecReturnData as String] = true
        var result: CFTypeRef?
        let status = SecItemCopyMatching(q as CFDictionary, &result)
        if status == errSecSuccess, let data = result as? Data {
            return try PropertyListDecoder().decode(Self.self, from: data)
        }
        guard status == errSecItemNotFound else { throw DirectError("تعذر الوصول إلى هوية HTTPS المحلية.") }
        var material = DirectTLSMaterial()
        guard DirectTLSGenerate(&material) != 0 else { throw DirectError("تعذر إنشاء هوية HTTPS للجهاز.") }
        defer { DirectTLSFree(&material) }
        let identity = Self(root: Data(bytes: material.root, count: material.rootLength),
                            certificate: Data(bytes: material.leaf, count: material.leafLength),
                            serverKey: Data(bytes: material.key, count: material.keyLength), id: UUID())
        var item = query
        item[kSecValueData as String] = try PropertyListEncoder().encode(identity)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let inserted = SecItemAdd(item as CFDictionary, nil)
        if inserted == errSecDuplicateItem { return try load() }
        guard inserted == errSecSuccess else { throw DirectError("تعذر حفظ هوية HTTPS على الجهاز.") }
        return identity
    }

    static func reset() throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw DirectError("تعذر تجديد هوية الجهاز.") }
    }

    func publicProfile() throws -> Data {
        let identifier = "org.amaryt.local." + id.uuidString
        let name = "AMARYT Local " + String(id.uuidString.prefix(8))
        let rootPayload: [String: Any] = [
            "PayloadType": "com.apple.security.root", "PayloadVersion": 1,
            "PayloadUUID": id.uuidString, "PayloadIdentifier": identifier + ".root",
            "PayloadDisplayName": name, "PayloadContent": root
        ]
        let profile: [String: Any] = [
            "PayloadType": "Configuration", "PayloadVersion": 1,
            "PayloadUUID": UUID().uuidString, "PayloadIdentifier": identifier,
            "PayloadDisplayName": name, "PayloadContent": [rootPayload]
        ]
        return try PropertyListSerialization.data(fromPropertyList: profile, format: .xml, options: 0)
    }
}

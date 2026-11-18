import Foundation

struct DirectError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

enum DirectPolicy {
    static let method = 2

    static func https(_ url: URL?) throws -> URL {
        guard let url, url.scheme?.lowercased() == "https", url.host?.isEmpty == false,
              url.user == nil, url.password == nil, url.fragment == nil else {
            throw DirectError("يلزم رابط HTTPS صالح.")
        }
        return url
    }

    static func installLink(_ manifest: URL) throws -> URL {
        guard manifest.host == "127.0.0.1", manifest.port != nil else { throw DirectError("عنوان التثبيت يجب أن يكون على هذا الجهاز.") }
        var link = URLComponents()
        link.scheme = "itms-services"
        link.host = ""
        link.queryItems = [URLQueryItem(name: "action", value: "download-manifest"),
                           URLQueryItem(name: "url", value: try https(manifest).absoluteString)]
        guard let url = link.url else { throw DirectError("تعذر تجهيز طلب التثبيت.") }
        return url
    }
}

struct DirectMetadata {
    let title: String
    let bundle: String
    let version: String

    func manifest(for ipa: URL) throws -> Data {
        guard !title.isEmpty, !version.isEmpty, !bundle.isEmpty else {
            throw DirectError("بيانات التطبيق غير مكتملة.")
        }
        let item: [String: Any] = [
            "assets": [["kind": "software-package", "url": try DirectPolicy.https(ipa).absoluteString]],
            "metadata": ["kind": "software", "title": title, "bundle-version": version, "bundle-identifier": bundle]
        ]
        return try PropertyListSerialization.data(fromPropertyList: ["items": [item]], format: .xml, options: 0)
    }
}

enum DirectHandoff {
    static func send(manifest: URL, enabled: Bool, open: (URL) async -> Bool) async throws {
        try Task.checkCancellation()
        guard enabled else { throw DirectError("المحرك معطّل في إعدادات التثبيت.") }
        let link = try DirectPolicy.installLink(manifest)
        guard await open(link) else { throw DirectError("رفض iOS فتح طلب التثبيت.") }
    }
}

import Foundation

/// Experimental, opt-in catalog transport. Existing Feather sources remain untouched.
enum AMARYTCatalogAPI {
    static let baseURL = URL(string: "https://amaryt1.github.io/AMARYT-Catalog-API/api/")!

    struct Manifest: Decodable {
        let schemaVersion: Int
        let totalApps: Int
        let pageSize: Int
        let pageCount: Int
        let homePath: String
        let pagePattern: String
        let detailPattern: String
        let searchIndexPath: String
    }

    struct AppSummary: Decodable, Identifiable {
        let id: String
        let sourceId: String
        let name: String
        let bundleIdentifier: String
        let iconURL: String?
        let developerName: String?
        let subtitle: String?
        let version: String?
        let versionDate: String?
        let category: String?
        let detailPath: String?
    }

    struct Page: Decodable {
        let schemaVersion: Int
        let items: [AppSummary]
    }

    enum CatalogError: Error {
        case invalidPath, invalidResponse(Int), unsupportedSchema(Int)
    }

    static func fetchManifest(session: URLSession = .shared) async throws -> Manifest {
        let manifest: Manifest = try await fetch("manifest.json", session: session)
        guard manifest.schemaVersion == 2 else { throw CatalogError.unsupportedSchema(manifest.schemaVersion) }
        return manifest
    }

    static func fetchPage(_ index: Int, manifest: Manifest, session: URLSession = .shared) async throws -> [AppSummary] {
        guard index >= 0 && index < manifest.pageCount else { return [] }
        let pageName = String(format: "%06d", index)
        let path = manifest.pagePattern.replacingOccurrences(of: "{page:06d}", with: pageName)
        let page: Page = try await fetch(path, session: session)
        guard page.schemaVersion == 2 else { throw CatalogError.unsupportedSchema(page.schemaVersion) }
        return page.items
    }

    static func fetchDetail(_ path: String, session: URLSession = .shared) async throws -> Data {
        try await data(at: path, session: session)
    }

    private static func fetch<T: Decodable>(_ path: String, session: URLSession) async throws -> T {
        let payload = try await data(at: path, session: session)
        return try JSONDecoder().decode(T.self, from: payload)
    }

    private static func data(at path: String, session: URLSession) async throws -> Data {
        guard !path.hasPrefix("/"), !path.contains(".."),
              let url = URL(string: path, relativeTo: baseURL)?.absoluteURL,
              url.scheme == "https", url.host == baseURL.host,
              url.path.hasPrefix(baseURL.path) else { throw CatalogError.invalidPath }
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw CatalogError.invalidResponse((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        return data
    }
}

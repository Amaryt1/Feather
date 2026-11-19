import Foundation
import Vapor
import NIOSSL

// Loopback only. The public root is installed by the user and iOS evaluates TLS trust.
final class DirectLocalServer {
    private let server: Application
    let manifest: URL
    let manifestData: Data

    init(file: URL, metadata: DirectMetadata, onPackageRequested: @escaping () -> Void) throws {
        let identity = try DirectIdentity.load()
        let host = "127.0.0.1"
        let port = Int.random(in: 30000...60000)
        let capability = UUID().uuidString
        var base = URLComponents()
        base.scheme = "https"
        base.host = host
        base.port = port
        guard let origin = base.url else { throw DirectError("عنوان السيرفر المحلي غير صالح.") }
        let root = origin.appendingPathComponent(capability)
        manifest = root.appendingPathComponent("manifest.plist")
        let xml = try metadata.manifest(for: root.appendingPathComponent("app.ipa"))
        manifestData = xml
        let tls = try TLSConfiguration.makeServerConfiguration(
            certificateChain: [.certificate(try NIOSSLCertificate(bytes: Array(identity.certificate), format: .der))],
            privateKey: .privateKey(NIOSSLPrivateKey(bytes: Array(identity.serverKey), format: .pem)))
        let app = Application(try ServerInstaller.environment.get())
        server = app
        app.http.server.configuration.hostname = "127.0.0.1"
        app.http.server.configuration.port = port
        app.http.server.configuration.tlsConfiguration = tls
        app.get(.constant(capability), "manifest.plist") { _ in
            Response(status: .ok, headers: ["Content-Type": "application/xml", "Cache-Control": "no-store"], body: .init(data: xml))
        }
        app.get(.constant(capability), "app.ipa") { req in
            onPackageRequested()
            return req.fileio.streamFile(at: file.path)
        }
        do { try app.server.start() } catch { app.shutdown(); throw error }
    }
    func checkTrust() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.connectionProxyDictionary = [:]
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel() }
        let (data, response) = try await session.data(for: URLRequest(url: manifest, timeoutInterval: 10))
        guard response.url == manifest, (response as? HTTPURLResponse)?.statusCode == 200,
              data == manifestData else { throw DirectError("تعذر التحقق من ملف Manifest المحلي.") }
    }

    deinit { server.server.shutdown(); server.shutdown() }
}

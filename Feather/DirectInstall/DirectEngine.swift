import SwiftUI
import CoreData
import IDeviceSwift

enum DirectInput {
    case source(URL?, String, String?, URL?)
    case signed(AppInfoPresentable)
}

@MainActor
final class DirectEngine: ObservableObject {
    enum Phase: Equatable {
        case idle, downloading, signing, preparing, ready, submitting, sent, failed
    }
    @Published var phase = Phase.idle
    @Published var message = ""
    @Published var progress: Double?
    @Published var size: Int64 = 0
    @Published var needsCertificate = false
    private var work: Task<Void, Never>?
    private var folder: URL?
    private var archive: URL?
    private var metadata: DirectMetadata?
    private var listener: DirectLocalServer?
    @Published var speed: Double = 0
    @Published var totalSize: Int64 = 0
    @Published var needsTrust = false
    @Published var servedPackage = false
    private var background: UIBackgroundTaskIdentifier = .invalid


    private static let clearPreviousProcessFiles: Void = {
        let fm = FileManager.default
        for url in (try? fm.contentsOfDirectory(at: fm.temporaryDirectory, includingPropertiesForKeys: nil)) ?? [] {
            let name = url.lastPathComponent
            if name.hasPrefix("AMARYTDirect-"), UUID(uuidString: String(name.dropFirst("AMARYTDirect-".count))) != nil {
                try? fm.removeItem(at: url)
            }
        }
    }()

    func prepare(_ input: DirectInput) {
        guard work == nil else { return }
        clean()
        speed = 0; totalSize = 0; needsTrust = false; servedPackage = false
        progress = nil
        size = 0
        needsCertificate = false
        phase = .preparing
        work = Task {
            defer { work = nil }
            do {
                _ = Self.clearPreviousProcessFiles
                guard DirectPreferences.enabled else { throw DirectError("المحرك متوقف في الإعدادات.") }
                let path = FileManager.default.temporaryDirectory.appendingPathComponent("AMARYTDirect-" + UUID().uuidString)
                try FileManager.default.createDirectory(at: path, withIntermediateDirectories: false)
                folder = path
                switch input {
                case let .source(url, _, _, _):
                    let cert = try certificate()
                    let ipa = path.appendingPathComponent("source.ipa")
                    phase = .downloading
                    try await download(try DirectPolicy.https(url), to: ipa)
                    try Task.checkCancellation()
                    phase = .signing
                    try await signAndPack(ipa, cert: cert, folder: path)
                case let .signed(app):
                    try await pack(app, folder: path)
                }
                try Task.checkCancellation()
                guard let archive, let metadata else { throw DirectError("تعذر تجهيز الحزمة.") }
                size = Int64(try archive.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0)
                guard size > 0 else { throw DirectError("الحزمة فارغة.") }
                let service = try DirectLocalServer(file: archive, metadata: metadata) { [weak self] in
                    Task { @MainActor in self?.servedPackage = true }
                }
                do {
                    try await service.checkTrust()
                } catch {
                    needsTrust = true
                    throw DirectError("تعذر التحقق من HTTPS المحلي. افحص ملف الثقة من إعدادات المحرك. " + error.localizedDescription)
                }
                try Task.checkCancellation()
                listener = service
                phase = .ready
            } catch { fail(error); clean() }
        }
    }

    private func certificate() throws -> CertificatePair {
        let index = UserDefaults.standard.integer(forKey: "feather.selectedCert")
        guard let cert = Storage.shared.getCertificate(for: index) else {
            needsCertificate = true
            throw DirectError("أضف شهادة وحددها قبل التثبيت.")
        }
        guard !cert.revoked, Storage.shared.getFile(.certificate, from: cert) != nil,
              let profile = Storage.shared.getProvisionFileDecoded(for: cert), profile.ExpirationDate > Date() else {
            needsCertificate = true
            throw DirectError("الشهادة أو ملف التزويد غير صالح أو منتهي الصلاحية.")
        }
        return cert
    }

    private func download(_ url: URL, to file: URL) async throws {
        let retries = DirectPreferences.retries
        var resume: Data?
        let directory = file.deletingLastPathComponent()
        for attempt in 0...retries {
            try Task.checkCancellation()
            let delegate = DirectNetworkDelegate(destination: directory) { [weak self] bytes, total, speed in
                Task { @MainActor in
                    guard self?.phase == .downloading else { return }
                    self?.progress = total > 0 ? min(1, Double(bytes) / Double(total)) : nil
                    self?.size = bytes
                    self?.totalSize = total
                    self?.speed = speed
                }
            }
            let config = URLSessionConfiguration.ephemeral
            config.timeoutIntervalForRequest = 45
            let session = URLSession(configuration: config)
            defer { session.invalidateAndCancel() }
            do {
                let tmp: URL
                let response: URLResponse
                if let resume { (tmp, response) = try await session.download(resumeFrom: resume, delegate: delegate) }
                else { (tmp, response) = try await session.download(for: URLRequest(url: url), delegate: delegate) }
                defer { try? FileManager.default.removeItem(at: tmp) }
                guard let http = response as? HTTPURLResponse else { throw DirectError("استجابة تنزيل غير صالحة.") }
                if (500...599).contains(http.statusCode) { throw URLError(.badServerResponse) }
                guard (200...299).contains(http.statusCode) else { throw DirectError("تعذر تنزيل IPA (HTTP \(http.statusCode)).") }
                let count = try tmp.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                guard count > 0 else { throw DirectError("ملف IPA فارغ.") }
                try DirectDisk.require(Int64(count), at: directory)
                try FileManager.default.moveItem(at: tmp, to: file)
                return
            } catch {
                if let issue = delegate.spaceError { throw issue }
                try Task.checkCancellation()
                let ns = error as NSError
                guard ns.domain == NSURLErrorDomain, attempt < retries,
                      [URLError.Code.timedOut, .networkConnectionLost, .notConnectedToInternet, .badServerResponse, .cannotConnectToHost]
                        .contains(URLError.Code(rawValue: ns.code) ?? .unknown) else { throw error }
                resume = ns.userInfo[NSURLSessionDownloadTaskResumeData] as? Data
                try await Task.sleep(nanoseconds: UInt64(attempt + 1) * 1_000_000_000)
            }
        }
    }

    private func signAndPack(_ ipa: URL, cert: CertificatePair, folder: URL) async throws {
        let importer = AppFileHandler(file: ipa)
        defer { try? FileManager.default.removeItem(at: ipa) }
        do {
            try await importer.copy()
            try await importer.extract()
            try Task.checkCancellation()
            try await importer.move()
            try await importer.addToDatabase()
            try await importer.clean()
        } catch {
            try? await importer.clean()
            try? FileManager.default.removeItem(at: FileManager.default.unsigned(importer.importedUUID))
            throw error
        }
        let request = NSFetchRequest<Imported>(entityName: "Imported")
        request.predicate = NSPredicate(format: "uuid == %@", importer.importedUUID)
        guard let imported = try Storage.shared.context.fetch(request).first else {
            try? FileManager.default.removeItem(at: FileManager.default.unsigned(importer.importedUUID))
            throw DirectError("لم تتضمن الحزمة تطبيقًا صالحًا.")
        }
        defer { Storage.shared.deleteApp(for: imported) }
        try Task.checkCancellation()
        guard let appDir = Storage.shared.getAppDirectory(for: imported),
              NSDictionary(contentsOf: appDir.appendingPathComponent("Info.plist")) != nil else { throw DirectError("ملف معلومات التطبيق غير صالح.") }
        try DirectDisk.require(try DirectDisk.size(of: appDir), at: folder)
        var options = OptionsManager.shared.options
        options.signingOption = .default
        options.removeProvisioning = false
        let signer = SigningHandler(app: imported, options: options)
        signer.requireSigningResult = true
        signer.appCertificate = cert
        let signedRequest = NSFetchRequest<Signed>(entityName: "Signed")
        signedRequest.predicate = NSPredicate(format: "uuid == %@", signer.signedUUID)
        defer {
            if let record = try? Storage.shared.context.fetch(signedRequest).first { Storage.shared.deleteApp(for: record) }
            else { try? FileManager.default.removeItem(at: FileManager.default.signed(signer.signedUUID)) }
        }
        do {
            try await signer.copy()
            try await signer.modify()
            try await signer.clean()
        } catch {
            try? await signer.clean()
            throw error
        }
        try Task.checkCancellation()
        guard let signed = try Storage.shared.context.fetch(signedRequest).first else { throw DirectError("تعذر قراءة نتيجة التوقيع.") }
        try await pack(signed, folder: folder)
    }

    private func pack(_ app: AppInfoPresentable, folder: URL) async throws {
        phase = .preparing
        guard app.isSigned, let dir = Storage.shared.getAppDirectory(for: app),
              let info = Bundle(url: dir)?.infoDictionary,
              let id = info["CFBundleIdentifier"] as? String, id != Bundle.main.bundleIdentifier,
              let version = info["CFBundleVersion"] as? String,
              let profile = CertificateReader(dir.appendingPathComponent("embedded.mobileprovision")).decoded,
              profile.ExpirationDate > Date(),
              let appID = profile.Entitlements?["application-identifier"]?.value as? String,
              let split = appID.firstIndex(of: ".") else { throw DirectError("تحقّق من توقيع الحزمة وملف التزويد. لا يمكن تحديث المتجر من نفسه.") }
        let pattern = String(appID[appID.index(after: split)...])
        guard pattern == id || (pattern.hasSuffix("*") && id.hasPrefix(pattern.dropLast())) else {
            throw DirectError("ملف التزويد لا يشمل معرّف التطبيق الموقّع.")
        }
        try DirectDisk.require(try DirectDisk.size(of: dir), at: folder)
        let metadata = DirectMetadata(title: app.name ?? id, bundle: id, version: version)
        let handler = ArchiveHandler(app: app, viewModel: InstallerStatusViewModel(isIdevice: false), workDirectory: folder.appendingPathComponent("archive"))
        try await handler.move()
        try DirectDisk.require(try DirectDisk.size(of: dir), at: folder)
        archive = try await handler.archive()
        self.metadata = metadata
    }

    func submit() {
        guard phase == .ready, work == nil, let listener else { return }
        phase = .submitting
        work = Task {
            defer { work = nil }
            do {
                background = UIApplication.shared.beginBackgroundTask(withName: "AMARYT Local Install") { [weak self] in
                    Task { @MainActor in
                        self?.endBackground()
                    }
                }
                try await DirectHandoff.send(manifest: listener.manifest, enabled: DirectPreferences.enabled) { url in
                    await UIApplication.shared.open(url)
                }
                // Keep the archive available until the user closes this transfer.
                phase = .sent
                if Task.isCancelled { clean() }
            } catch { fail(error); clean() }
        }
    }

    func cancel() {
        if let work { work.cancel() } else { clean() }
    }

    private func endBackground() {
        if background != .invalid {
            UIApplication.shared.endBackgroundTask(background)
            background = .invalid
        }
    }
    private func clean() {
        endBackground()
        listener = nil
        if let folder { try? FileManager.default.removeItem(at: folder) }
        folder = nil; archive = nil; metadata = nil
    }

    private func fail(_ error: Error) {
        if Task.isCancelled { return }
        message = error.localizedDescription
        phase = .failed
    }
}

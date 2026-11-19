import SwiftUI
import Combine
private struct StagedApp: AppInfoPresentable {
    let identifier: String?
    var name: String? { nil }
    var version: String? { nil }
    var date: Date? { nil }
    var icon: String? { nil }
    var uuid: String? { nil }
    var source: URL? { nil }
    var isSigned: Bool { false }
}

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
    @Published var preparedTitle: String?
    @Published var preparedVersion: String?
    @Published var preparedIcon: UIImage?
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

    private var cardHandoff: AnyCancellable?
    func prepareFromCard(_ input: DirectInput) {
        cardHandoff = $phase.filter { $0 == .ready }.prefix(1).receive(on: DispatchQueue.main).sink { [weak self] _ in self?.submit() }
        prepare(input)
    }

    func prepare(_ input: DirectInput) { begin(input, update: nil) }

    func prepareStoreUpdate(_ release: StoreRelease) {
        begin(.source(release.url, "AMARYT STORE", release.version, nil), update: release)
    }

    private func begin(_ input: DirectInput, update: StoreRelease?) {
        guard work == nil else { return }
        if update == nil, needsTrust, archive != nil, metadata != nil {
            phase = .preparing
            work = Task {
                defer { work = nil }
                do { try await checkListener() }
                catch { fail(error); if Task.isCancelled { clean() } }
            }
            return
        }
        preparedTitle = nil; preparedVersion = nil; preparedIcon = nil
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
                    let cert: CertificatePair
                    if let update {
                        try update.validate()
                        cert = try StoreUpdateSigning.certificate()
                    } else { cert = try certificate() }
                    let ipa = path.appendingPathComponent("source.ipa")
                    phase = .downloading
                    try await download(try DirectPolicy.https(url), to: ipa)
                    try Task.checkCancellation()
                    if let update { try await StoreUpdateSigning.verifyFile(ipa, release: update) }
                    phase = .signing
                    try await signAndPack(ipa, cert: cert, folder: path, update: update)
                case let .signed(app):
                    guard app.isSigned, let directory = Storage.shared.getAppDirectory(for: app) else { throw DirectError("اختر تطبيقًا موقّعًا من المكتبة.") }
                    try DirectDisk.require(try await DirectDisk.size(of: directory), at: path)
                    let payload = path.appendingPathComponent("Payload")
                    try FileManager.default.createDirectory(at: payload, withIntermediateDirectories: false)
                    let copy = payload.appendingPathComponent(directory.lastPathComponent)
                    try await Self.copyBundle(from: directory, to: copy)
                    try await pack(copy, folder: path)
                }
                try Task.checkCancellation()
                try await checkListener()
            } catch {
                fail(error)
                if !needsTrust || Task.isCancelled { clean() }
            }
        }
    }

    private func checkListener() async throws {
        guard DirectPreferences.enabled, let archive, let metadata else { throw DirectError("تعذّر تجهيز التثبيت المحلي.") }
        size = Int64(try archive.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0)
        guard size > 0 else { throw DirectError("الحزمة فارغة.") }
        let service = try DirectLocalServer(file: archive, metadata: metadata) { [weak self] in
            Task { @MainActor in self?.servedPackage = true }
        }
        do { try await service.checkTrust() } catch {
            needsTrust = true
            throw DirectError("تعذر التحقق من HTTPS المحلي. افحص ملف الثقة من إعدادات المحرك. " + error.localizedDescription)
        }
        try Task.checkCancellation()
        needsTrust = false
        listener = service
        phase = .ready
    }

    private func certificate() throws -> CertificatePair {
        let index = UserDefaults.standard.integer(forKey: "feather.selectedCert")
        guard let cert = Storage.shared.getCertificate(for: index) else {
            needsCertificate = true
            throw DirectError("أضف شهادة وحددها قبل التثبيت.")
        }
        guard !cert.revoked, Storage.shared.getFile(.certificate, from: cert) != nil,
              let file = Storage.shared.getFile(.provision, from: cert), (try? DirectProfile.read(file)) != nil else {
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

    private func signAndPack(_ ipa: URL, cert: CertificatePair, folder: URL, update: StoreRelease?) async throws {
        let directory = try await Self.unpack(ipa, folder: folder)
        try FileManager.default.removeItem(at: ipa)
        try Task.checkCancellation()
        guard let id = Bundle(url: directory)?.bundleIdentifier,
              NSDictionary(contentsOf: directory.appendingPathComponent("Info.plist")) != nil else {
            throw DirectError("ملف معلومات التطبيق غير صالح.")
        }
        if let update {
            let info = NSDictionary(contentsOf: directory.appendingPathComponent("Info.plist")) as? [String: Any] ?? [:]
            try update.verifyPackage(info)
        }
        var options = update == nil ? OptionsManager.shared.options : Options.defaultOptions
        options.signingOption = .default
        options.appIdentifier = nil
        // ZsignHandler passes the inverse of this flag to Zsign.removeProvision.
        // Keep the newly embedded provisioning profile in the signed IPA.
        options.removeProvisioning = true
        let signer = SigningHandler(app: StagedApp(identifier: id), options: options)
        signer.appCertificate = cert
        do {
            if update != nil { try await signer.signStoreUpdate(at: directory, expectedID: id) }
            else { try await signer.signStagedBundle(at: directory) }
            try await signer.clean()
        } catch {
            try? await signer.clean()
            needsCertificate = true
            throw error
        }
        try Task.checkCancellation()
        try await pack(directory, folder: folder, update: update)
    }

    private nonisolated static func unpack(_ ipa: URL, folder: URL) async throws -> URL {
        try await DirectArchive.unpack(ipa, in: folder) { try DirectDisk.require($0, at: folder) }
    }

    private nonisolated static func copyBundle(from source: URL, to destination: URL) async throws {
        try FileManager.default.copyItem(at: source, to: destination)
    }

    private func pack(_ dir: URL, folder: URL, update: StoreRelease? = nil) async throws {
        phase = .preparing
        guard let info = NSDictionary(contentsOf: dir.appendingPathComponent("Info.plist")) as? [String: Any],
              let id = info["CFBundleIdentifier"] as? String, (update != nil || id != Bundle.main.bundleIdentifier),
              let version = info["CFBundleVersion"] as? String else { throw DirectError("تحقّق من توقيع الحزمة وملف التزويد. لا يمكن تحديث المتجر من نفسه.") }
        if let update {
            try update.verifyPackage(info)
            try StoreUpdateSigning.verifyContinuity(of: dir)
        }
        let profile = try DirectProfile.read(dir.appendingPathComponent("embedded.mobileprovision"))
        guard profile.permits(id) else {
            needsCertificate = true
            throw DirectError("ملف التزويد لا يشمل معرّف التطبيق الموقّع.")
        }
        try DirectDisk.require(try await DirectDisk.size(of: dir), at: folder)
        let title = info["CFBundleDisplayName"] as? String ?? info["CFBundleName"] as? String ?? id
        let metadata = DirectMetadata(title: title, bundle: id, version: version)
        preparedTitle = title
        preparedVersion = info["CFBundleShortVersionString"] as? String ?? version
        preparedIcon = await Task.detached(priority: .utility) { iconTest(dir, true) }.value
        try Task.checkCancellation()
        let destination = folder.appendingPathComponent("signed.ipa")
        try await DirectArchive.pack(dir.deletingLastPathComponent(), to: destination)
        try FileManager.default.removeItem(at: dir.deletingLastPathComponent())
        archive = destination
        self.metadata = metadata
    }

    func submit() {
        guard (phase == .ready || phase == .sent), work == nil, let listener else { return }
        phase = .submitting
        work = Task {
            defer { work = nil }
            do {
                if background == .invalid {
                    background = UIApplication.shared.beginBackgroundTask(withName: "AMARYT Local Install") { [weak self] in
                        Task { @MainActor in self?.endBackground() }
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
        cardHandoff?.cancel()
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

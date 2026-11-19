//
//  enum.swift
//  Feather
//
//  Created by samara on 3.05.2025.
//

import Foundation
import CryptoKit
import Combine
import CoreData
import UIKit.UIImpactFeedbackGenerator
import BackgroundTasks

class Download: ObservableObject, Identifiable, @unchecked Sendable {
	@Published var progress: Double = 0.0
	@Published var bytesDownloaded: Int64 = 0
	@Published var totalBytes: Int64 = 0
	@Published var unpackageProgress: Double = 0.0
    @Published var isPaused: Bool = false
	
	var overallProgress: Double {
		onlyArchiving
		? unpackageProgress
		: (0.3 * unpackageProgress) + (0.7 * progress)
	}
	
	var task: URLSessionDownloadTask?
	var resumeData: Data?
	
	let id: String
	let url: URL
	let fileName: String
	let onlyArchiving: Bool
	var sourceProvenance: SourceAppProvenance?
    var packageTask: Task<Void, Never>?
    var reviewedCloneIDs: [String]?
    var cloneBaseOverride: String?
    var copyCount = 1
    var signingCertificate: CertificatePair?
    @Published var packaging = false
    var sampleTime = ProcessInfo.processInfo.systemUptime
    var sampleBytes: Int64 = 0
    @Published var bytesPerSecond: Int64 = 0
    var importedUUID: String?
	
	init(
		id: String,
		url: URL,
		onlyArchiving: Bool = false,
		sourceProvenance: SourceAppProvenance? = nil
	) {
		self.id = id
		self.url = url
		self.onlyArchiving = onlyArchiving
		self.sourceProvenance = sourceProvenance
		self.fileName = url.lastPathComponent
	}
}

class DownloadManager: NSObject, ObservableObject {
	static let shared = DownloadManager()
	
	@Published var outcomes = SourceOutcomes()
    private var signingTasks: [String: Task<Void, Never>] = [:]
    var localSessionIDs = Set<String>()
	@Published var downloads: [Download] = []
	
	var manualDownloads: [Download] {
		downloads.filter { isManualDownload($0.id) }
	}
	
	private var _session: URLSession!
	
	#if !targetEnvironment(macCatalyst)
	private func _updateBackgroundAudioState() {
		if #unavailable(iOS 26.0){
			if !downloads.isEmpty {
				BackgroundAudioManager.shared.start()
			} else  {
				BackgroundAudioManager.shared.stop()
			}
		}
	}
	#endif
	
	override init() {
		super.init()
		let configuration = URLSessionConfiguration.default
		_session = URLSession(configuration: configuration, delegate: self, delegateQueue: .main)
	}
	
	func startDownload(
		from url: URL,
		id: String = UUID().uuidString,
		sourceProvenance: SourceAppProvenance? = nil,
        signingCertificate: CertificatePair? = nil,
        copyCount: Int = 1, reviewedCloneIDs: [String]? = nil, cloneBaseOverride: String? = nil
    ) -> Download? {
        guard outcomes[id] != .signing, !localSessionIDs.contains(id) else { return nil }
        let sourceOperation = id.hasPrefix("source:")
        if let existing = downloads.first(where: { download in
            if sourceOperation || download.id.hasPrefix("source:") { return download.id == id }
            return download.url == url && download.sourceProvenance == sourceProvenance
        }) {
            return existing
        }
        let download = Download(id: id, url: url, sourceProvenance: sourceProvenance)
        download.reviewedCloneIDs = reviewedCloneIDs
        download.cloneBaseOverride = cloneBaseOverride
        download.copyCount = copyCount
        download.signingCertificate = signingCertificate
        if sourceOperation { outcomes[id] = nil }
        let task = _session.downloadTask(with: url)
		download.task = task
        download.isPaused = false
		task.resume()
		
		downloads.append(download)
		
		#if !targetEnvironment(macCatalyst)
		if #available(iOS 26.0, *) {
			BackgroundTaskManager.shared.startTask(for: id, filename: url.lastPathComponent)
		} else {
			_updateBackgroundAudioState()
		}
		#endif
		
		return download
	}
	
	func startArchive(
		from url: URL,
		id: String = UUID().uuidString
	) -> Download {
		let download = Download(id: id, url: url, onlyArchiving: true)
		downloads.append(download)
		
		#if !targetEnvironment(macCatalyst)
		_updateBackgroundAudioState()
		#endif
		
		return download
	}
	
	func pauseDownload(_ download: Download) {
        guard let task = download.task, !download.isPaused, !download.packaging else { return }
        download.isPaused = true
        task.cancel(byProducingResumeData: { resumeData in
            DispatchQueue.main.async {
                guard download.task === task else { return }
                download.resumeData = resumeData
                download.task = nil
                download.isPaused = true
            }
        })
    }

	func resumeDownload(_ download: Download) {
		guard download.isPaused, download.task == nil else { return }
        download.sampleTime = ProcessInfo.processInfo.systemUptime
        download.sampleBytes = download.bytesDownloaded
        download.bytesPerSecond = 0
		if let resumeData = download.resumeData {
			let task = _session.downloadTask(withResumeData: resumeData)
			download.task = task
            download.resumeData = nil
            download.isPaused = false
			task.resume()
			
			#if !targetEnvironment(macCatalyst)
			_updateBackgroundAudioState()
			#endif
		} else {
			let task = _session.downloadTask(with: download.url)
			download.task = task
            download.isPaused = false
			task.resume()
			
			#if !targetEnvironment(macCatalyst)
			_updateBackgroundAudioState()
			#endif
		}
	}
	
	func cancelDownload(_ download: Download) {
		guard downloads.contains(where: { $0 === download }) else { return }
        if download.id.hasPrefix("source:") { outcomes[download.id] = .cancelled }
		download.packageTask?.cancel()
        download.task?.cancel()
		
		if let index = downloads.firstIndex(where: { $0.id == download.id }) {
			downloads.remove(at: index)
			
			#if !targetEnvironment(macCatalyst)
			_updateBackgroundAudioState()

			if #available(iOS 26.0, *) {
				BackgroundTaskManager.shared.stopTask(for: download.id, success: false)
			}
			#endif
		}
	}
	
	func isManualDownload(_ string: String) -> Bool {
		return string.contains("FeatherManualDownload")
	}
	
	func getDownload(by id: String) -> Download? {
		return downloads.first(where: { $0.id == id })
	}
	
	func getDownloadIndex(by id: String) -> Int? {
		return downloads.firstIndex(where: { $0.id == id })
	}
	
	func getDownloadTask(by task: URLSessionDownloadTask) -> Download? {
		return downloads.first(where: { $0.task == task })
	}
}

extension DownloadManager: URLSessionDownloadDelegate {
	
	func cancelSigning(_ id: String) {
        signingTasks[id]?.cancel()
    }

    private func signImported(_ download: Download, certificate: CertificatePair) {
        let request = NSFetchRequest<Imported>(entityName: "Imported")
        request.fetchLimit = 1
        guard let uuid = download.importedUUID else {
            outcomes[download.id] = .failed("تعذر تحديد التطبيق المستورد.")
            return
        }
        request.predicate = NSPredicate(format: "uuid == %@", uuid)
        guard let imported = try? Storage.shared.context.fetch(request).first else {
            outcomes[download.id] = .failed("تعذر العثور على التطبيق المستورد.")
            return
        }
        let id = download.id
        outcomes[id] = .signing
        var options = OptionsManager.shared.options
        options.signingOption = .default
        options.appIdentifier = nil
        // ZsignHandler passes the inverse flag; store installs require the embedded profile.
        options.removeProvisioning = true
        if download.copyCount > 1 {
            options.appIdentifier = download.cloneBaseOverride ?? imported.identifier.flatMap { options.identifiers[$0] }
            signingTasks[id] = Task { @MainActor in
                defer { self.signingTasks.removeValue(forKey: id) }
                do {
                    let signed = try await CloneBatch().sign(app: imported, options: options, icon: nil,
                                                             certificate: certificate, count: download.copyCount, expected: download.reviewedCloneIDs)
                    guard signed.count == 1, let uuid = signed.first else {
                        throw DirectError("تعذّر تجهيز النسخة الإضافية المطلوبة.")
                    }
                    self.outcomes[id] = .ready(uuid)
                } catch is CancellationError { self.outcomes[id] = .cancelled }
                catch { self.outcomes[id] = .failed(error.localizedDescription) }
            }
            return
        }
        signingTasks[id] = FR.signPackageFile(imported, using: options, icon: nil,
                           certificate: certificate, onSigned: { self.outcomes[id] = .ready($0) }) { error in
            self.signingTasks.removeValue(forKey: id)
            if let error { self.outcomes[id] = error is CancellationError ? .cancelled : .failed(error.localizedDescription) }
        }
    }

    func handlePachageFile(url: URL, dl: Download) throws {
		dl.packageTask = FR.handlePackageFile(url, download: dl) { err in
            dl.packageTask = nil
            guard self.downloads.contains(where: { $0 === dl }) else { return }
            if dl.id.hasPrefix("source:") {
                if let err { self.outcomes[dl.id] = .failed(err.localizedDescription) }
                else if let certificate = dl.signingCertificate {
                    self.signImported(dl, certificate: certificate)
                } else { self.outcomes[dl.id] = .imported }
            }
            if err != nil {
				let generator = UINotificationFeedbackGenerator()
				generator.notificationOccurred(.error)
			}
			
			DispatchQueue.main.async {
				if let index = self.downloads.firstIndex(where: { $0 === dl }) {
					self.downloads.remove(at: index)
					
					#if !targetEnvironment(macCatalyst)
					if #available(iOS 26.0, *) {
						BackgroundTaskManager.shared.updateProgress(for: dl.id, progress: 1.0)
					}
					
					self._updateBackgroundAudioState()
					#endif
				}
			}
		}
	}
	
	func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
		guard let download = getDownloadTask(by: downloadTask) else { return }
		
		let tempDirectory = FileManager.default.temporaryDirectory
		let customTempDir = tempDirectory.appendingPathComponent("FeatherDownloads", isDirectory: true)
		
		do {
			if let response = downloadTask.response as? HTTPURLResponse, !(200..<300).contains(response.statusCode) {
                throw NSError(domain: "Feather.Download.HTTP", code: response.statusCode,
                              userInfo: [NSLocalizedDescriptionKey: "فشل التنزيل (HTTP \(response.statusCode))."])
            }
            try FileManager.default.createDirectoryIfNeeded(at: customTempDir)
			
			// Use the server-suggested filename if available, otherwise fallback
			let suggestedFileName = URL(fileURLWithPath: downloadTask.response?.suggestedFilename ?? download.fileName).lastPathComponent
			// Repeated downloads of a source version replace their own history file;
            // concurrent versions with identical filenames get separate directories.
            let identity = download.id.hasPrefix("source:") ? download.id : download.url.absoluteString
            let digest = SHA256.hash(data: Data(identity.utf8)).map { String(format: "%02x", $0) }.joined()
            let directory = customTempDir.appendingPathComponent(digest, isDirectory: true)
            try FileManager.default.createDirectoryIfNeeded(at: directory)
            let safeName = ["", ".", "..", "/"].contains(suggestedFileName) ? "download.ipa" : suggestedFileName
            let destinationURL = directory.appendingPathComponent(safeName)
			
			try FileManager.default.removeFileIfNeeded(at: destinationURL)
			try FileManager.default.moveItem(at: location, to: destinationURL)

            Task { @MainActor in
                AppsCatalogPersonalization.shared.recordDownload(
                    id: download.id,
                    fileName: suggestedFileName,
                    sourceURL: download.url,
                    localURL: destinationURL
                )
            }

			download.packaging = true
            try handlePachageFile(url: destinationURL, dl: download)
		} catch {
			finishFailure(download, error: error)
		}
	}
	
	func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
		guard let download = getDownloadTask(by: downloadTask) else { return }
		
		DispatchQueue.main.async {
			let now = ProcessInfo.processInfo.systemUptime
            let elapsed = now - download.sampleTime
            if elapsed >= 1 {
                download.bytesPerSecond = max(0, Int64(Double(totalBytesWritten - download.sampleBytes) / elapsed))
                download.sampleTime = now
                download.sampleBytes = totalBytesWritten
            }
            download.progress = totalBytesExpectedToWrite > 0
			? Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
			: 0
			download.bytesDownloaded = totalBytesWritten
			download.totalBytes = totalBytesExpectedToWrite
			
			#if !targetEnvironment(macCatalyst)
			if #available(iOS 26.0, *) {
				BackgroundTaskManager.shared.updateProgress(for: download.id, progress: download.overallProgress)
			}
			#endif
		}
	}
	
	func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
		guard
			let error = error,
			let downloadTask = task as? URLSessionDownloadTask,
			let download = getDownloadTask(by: downloadTask)
		else {
			return
		}
		
		if download.isPaused && (error as NSError).code == NSURLErrorCancelled { return }
        finishFailure(download, error: error)
    }

    private func finishFailure(_ download: Download, error: Error) {
        if download.id.hasPrefix("source:") { outcomes[download.id] = .failed(error.localizedDescription) }
        downloads.removeAll { $0 === download }
        #if !targetEnvironment(macCatalyst)
        if #available(iOS 26.0, *) { BackgroundTaskManager.shared.stopTask(for: download.id, success: false) }
        else { _updateBackgroundAudioState() }
        #endif
    }
}

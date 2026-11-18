import Foundation

final class DirectNetworkDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    let destination: URL
    let update: @Sendable (Int64, Int64, Double) -> Void
    private var lastTime = ProcessInfo.processInfo.systemUptime
    private var lastBytes: Int64 = 0
    private(set) var spaceError: Error?

    init(destination: URL, update: @escaping @Sendable (Int64, Int64, Double) -> Void) {
        self.destination = destination
        self.update = update
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler((try? DirectPolicy.https(request.url)) == nil ? nil : request)
    }
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {}
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData delta: Int64,
                    totalBytesWritten bytes: Int64, totalBytesExpectedToWrite total: Int64) {
        let now = ProcessInfo.processInfo.systemUptime
        let elapsed = now - lastTime
        guard lastBytes == 0 || elapsed >= 0.5 || bytes == total else { return }
        do { try DirectDisk.require(max(0, total - bytes), at: destination) }
        catch { spaceError = error; downloadTask.cancel(); return }
        update(bytes, total, elapsed > 0 && lastBytes > 0 ? Double(max(0, bytes-lastBytes))/elapsed : 0)
        lastBytes = bytes
        lastTime = now
    }
}

enum DirectDisk {
    static func require(_ bytes: Int64, at directory: URL) throws {
        let values = try directory.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        if let available = values.volumeAvailableCapacityForImportantUsage, available < bytes {
            throw DirectError("المساحة المتاحة لا تكفي لإكمال العملية.")
        }
    }
    static func size(of url: URL) throws -> Int64 {
        var result: Int64 = 0
        let fm = FileManager.default
        var enumerationError: Error?
        let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey]
        guard let entries = fm.enumerator(at: url, includingPropertiesForKeys: keys, errorHandler: { _, error in
            enumerationError = error
            return false
        }) else { throw DirectError("تعذر قراءة ملفات الحزمة.") }
        for case let entry as URL in entries {
            let values = try entry.resourceValues(forKeys: Set(keys))
            if values.isRegularFile == true { result += Int64(values.fileSize ?? 0) }
        }
        if let enumerationError { throw enumerationError }
        return result
    }
}

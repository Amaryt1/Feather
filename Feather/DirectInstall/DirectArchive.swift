import Foundation
import ZIPFoundation

enum DirectArchive {
    static func unpack(_ ipa: URL, in directory: URL, available: (Int64) throws -> Void) async throws -> URL {
        let progress = Progress(totalUnitCount: 0)
        return try await withTaskCancellationHandler {
            try extract(ipa, in: directory, progress: progress, available: available)
        } onCancel: { progress.cancel() }
    }

    private static func extract(_ ipa: URL, in directory: URL, progress: Progress, available: (Int64) throws -> Void) throws -> URL {
        let archive = try Archive(url: ipa, accessMode: .read)
        var mainApp: String?
        var expanded: Int64 = 0
        let fm = FileManager.default

        for entry in archive {
            try Task.checkCancellation()
            guard entry.path.hasPrefix("Payload/") else { continue }
            let components = entry.path.split(separator: "/", omittingEmptySubsequences: false)
            guard components.count >= 2, components[1].hasSuffix(".app") else { continue }
            let name = String(components[1])
            guard !entry.path.contains("\\"), !components.contains(".."), !components.contains("."),
                  !components.dropLast().contains(""), entry.type != .symlink,
                  mainApp == nil || mainApp == name,
                  let length = Int64(exactly: entry.uncompressedSize) else {
                throw DirectError("بنية Payload غير مدعومة أو تحتوي على مسارات غير آمنة.")
            }
            let (sum, overflow) = expanded.addingReportingOverflow(length)
            guard !overflow else { throw DirectError("حجم الحزمة يتجاوز سعة نظام الملفات.") }
            expanded = sum
            mainApp = name
        }
        guard let mainApp else { throw DirectError("لم تتضمن الحزمة تطبيقًا داخل Payload.") }
        try available(expanded)
        let prefix = "Payload/" + mainApp + "/"
        for entry in archive where entry.path.hasPrefix(prefix) {
            try Task.checkCancellation()
            let target = directory.appendingPathComponent(entry.path)
            if entry.type == .directory {
                try fm.createDirectory(at: target, withIntermediateDirectories: true)
            } else {
                try fm.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
                let checksum = try archive.extract(entry, to: target, progress: progress)
                guard checksum == entry.checksum else { throw DirectError("ملف IPA تالف.") }
            }
        }
        return directory.appendingPathComponent("Payload").appendingPathComponent(mainApp)
    }

    static func pack(_ payload: URL, to ipa: URL) async throws {
        let progress = Progress(totalUnitCount: 0)
        try await withTaskCancellationHandler {
            try Task.checkCancellation()
            try FileManager.default.zipItem(at: payload, to: ipa, compressionMethod: .deflate, progress: progress)
            try Task.checkCancellation()
        } onCancel: { progress.cancel() }
    }
}

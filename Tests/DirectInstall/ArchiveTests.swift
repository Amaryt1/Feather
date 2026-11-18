import Foundation
import ZIPFoundation

@main struct ArchiveTests {
    static func main() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? fm.removeItem(at: root) }
        let input = root.appendingPathComponent("input")
        let payload = input.appendingPathComponent("Payload")
        let app = payload.appendingPathComponent("Demo.app")
        try fm.createDirectory(at: app, withIntermediateDirectories: true)
        let info = Data("test bundle metadata".utf8)
        try info.write(to: app.appendingPathComponent("Info.plist"))
        let large = ProcessInfo.processInfo.arguments.contains("--large")
        if large {
            let resource = app.appendingPathComponent("resource.bin")
            guard fm.createFile(atPath: resource.path, contents: nil) else { throw CocoaError(.fileWriteUnknown) }
            let handle = try FileHandle(forWritingTo: resource)
            try handle.truncate(atOffset: 513 * 1024 * 1024)
            try handle.close()
        }
        let ipa = root.appendingPathComponent("input.ipa")
        try fm.zipItem(at: payload, to: ipa, compressionMethod: .none)
        if large {
            let bytes = try ipa.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            precondition(bytes > 512 * 1024 * 1024)
            print("Testing file-backed IPA with \(bytes) bytes")
        }
        let stage = root.appendingPathComponent("stage")
        do {
            _ = try await DirectArchive.unpack(ipa, in: stage) { _ in throw DirectError("disk full") }
            fatalError("Missing space preflight")
        } catch is DirectError {}
        let extracted = try await DirectArchive.unpack(ipa, in: stage) { size in precondition(size >= info.count) }
        let readBack = try Data(contentsOf: extracted.appendingPathComponent("Info.plist"))
        precondition(readBack == info)
        let output = root.appendingPathComponent("output.ipa")
        try await DirectArchive.pack(extracted.deletingLastPathComponent(), to: output)
        let reopened = try Archive(url: output, accessMode: .read)
        precondition(reopened["Payload/Demo.app/Info.plist"] != nil)
        if large { precondition(reopened["Payload/Demo.app/resource.bin"]?.uncompressedSize == 513 * 1024 * 1024) }
        let cancelled = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            try await DirectArchive.pack(payload, to: root.appendingPathComponent("cancel.ipa"))
        }
        do { try await cancelled.value; fatalError("Cancellation ignored") } catch is CancellationError {}
        print("Local archive round trip, space preflight and cancellation passed")
    }
}

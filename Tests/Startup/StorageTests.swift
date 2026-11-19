import Foundation
import CoreData

@main
struct StartupTests {
    @MainActor static func settle(_ storage: Storage) async throws {
        storage.load()
        for _ in 0..<200 {
            if storage.state != .loading { return }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        fatalError("Persistent store load timed out")
    }

    @MainActor static func main() async throws {
        let model = URL(fileURLWithPath: CommandLine.arguments[1])
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }
        let missing = Storage(modelOverride: temp.appendingPathComponent("absent.mom"))
        try await settle(missing)
        guard case .failed = missing.state else { fatalError("Expected missing model recovery") }
        let obstruction = temp.appendingPathComponent("folder")
        try Data("sentinel".utf8).write(to: obstruction)
        let disk = Storage(modelOverride: model, storeURL: obstruction.appendingPathComponent("test.sqlite"))
        try await settle(disk)
        guard case .failed = disk.state else { fatalError("Expected failed SQLite open") }
        let preserved = try Data(contentsOf: obstruction)
        precondition(preserved == Data("sentinel".utf8))
        try FileManager.default.removeItem(at: obstruction)
        try FileManager.default.createDirectory(at: obstruction, withIntermediateDirectories: true)
        try await settle(disk)
        precondition(disk.state == .ready)
        print("Missing model, nondestructive failed open and retry passed")
    }
}

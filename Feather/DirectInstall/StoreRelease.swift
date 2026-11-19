import Foundation

struct StoreRelease: Codable, Hashable {
    let version: String
    let build: String
    let url: URL
    let notes: String
    let mandatory: Bool
    let sha256: String

    static func parts(_ text: String) throws -> [Int] {
        let split = text.split(separator: ".", omittingEmptySubsequences: false)
        guard (1...3).contains(split.count) else { throw DirectError("رقم إصدار غير صالح.") }
        var parts = try split.map { component -> Int in
            guard (1...9).contains(component.count), component.utf8.allSatisfy({ (48...57).contains($0) }),
                  let n = Int(component) else { throw DirectError("رقم إصدار غير صالح.") }
            return n
        }
        while parts.count < 3 { parts.append(0) }
        return parts
    }

    func required(over installed: String, build installedBuild: String) throws -> Bool {
        let target = try Self.parts(version)
        // The Debug scheme appends this suffix to MARKETING_VERSION.
        let local = try Self.parts(installed.hasSuffix("-debug") ? String(installed.dropLast(6)) : installed)
        if !build.isEmpty { _ = try Self.parts(build) }
        guard mandatory else { return false }
        if target != local { return local.lexicographicallyPrecedes(target) }
        guard !build.isEmpty else { return false }
        return try Self.parts(installedBuild).lexicographicallyPrecedes(Self.parts(build))
    }

    func validate() throws {
        let pattern = #"^https://github\.com/Amaryt1/[A-Za-z0-9_.-]+/releases/download/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+\.ipa$"#
        guard url.absoluteString.range(of: pattern, options: .regularExpression) != nil,
              !url.pathComponents.contains(".."), !url.pathComponents.contains("."),
              sha256.utf8.count == 64, sha256.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }),
              notes.count <= 4000 else { throw DirectError("بيانات نشر التحديث غير صالحة.") }
    }

    func verifyPackage(_ info: [String: Any], installed: Bundle = .main) throws {
        guard let id = installed.bundleIdentifier, info["CFBundleIdentifier"] as? String == id,
              info["CFBundleShortVersionString"] as? String == version, let actual = info["CFBundleVersion"] as? String,
              (build.isEmpty || actual == build),
              try required(over: installed.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "",
                           build: installed.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "") else {
            throw DirectError("هوية الحزمة أو إصدارها لا يطابق تحديث المتجر المنشور.")
        }
    }
}

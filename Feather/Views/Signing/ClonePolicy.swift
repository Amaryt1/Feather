import Foundation
import CoreFoundation

enum ClonePolicy {
    static let limit = 10
    static func identifiers(base: String, count: Int, occupied: Set<String>, profile: DirectProfile) throws -> [String] {
        guard (1...limit).contains(count), !base.isEmpty,
              base.split(separator: ".", omittingEmptySubsequences: false).allSatisfy({
                  !$0.isEmpty && $0.utf8.allSatisfy { (65...90).contains($0) || (97...122).contains($0) || (48...57).contains($0) || $0 == 45 }
              }) else { throw DirectError("عدد النسخ أو معرّف التطبيق غير صالح.") }
        return try (1...count).map { index in
            let id = index == 1 ? base : "\(base).clone\(index)"
            guard profile.permits(id) else { throw DirectError("ملف التزويد لا يسمح بالمعرّف " + id) }
            guard index == 1 || !occupied.contains(id) else { throw DirectError("المعرّف مستخدم بالفعل: " + id) }
            return id
        }
    }

    /// Match only an exact scalar or a trailing provisioning wildcard.
    static func permits(_ claim: Any, by allowed: Any) -> Bool {
        if let text = claim as? String, let pattern = allowed as? String {
            return !text.contains("*") && (text == pattern || (pattern.hasSuffix("*") && text.hasPrefix(pattern.dropLast())))
        }
        if let array = claim as? [Any], let choices = allowed as? [Any] {
            return array.allSatisfy { item in choices.contains { permits(item, by: $0) } }
        }
        if let dict = claim as? [String: Any], let grants = allowed as? [String: Any] {
            return dict.allSatisfy { key, value in grants[key].map { permits(value, by: $0) } ?? false }
        }
        if let n = claim as? NSNumber, let grant = allowed as? NSNumber {
            return CFGetTypeID(n) == CFGetTypeID(grant) && n == grant
        }
        if let data = claim as? Data { return data == allowed as? Data }
        return false
    }
}

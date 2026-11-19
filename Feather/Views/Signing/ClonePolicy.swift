import Foundation
import CoreFoundation

enum ClonePolicy {
    static let limit = 10
    static func identifiers(base: String, count: Int, occupied: Set<String>, profile: DirectProfile) throws -> [String] {
        let ids = try identifiers(base: base, count: count, occupied: occupied)
        try validate(ids, profile: profile)
        return ids
    }

    static func validate(_ ids: [String], profile: DirectProfile) throws {
        let pattern = profile.Entitlements.applicationIdentifier
        if ids.count > 1 && !pattern.hasSuffix("*") {
            throw DirectError("ملف التزويد الحالي مخصّص لمعرّف واحد (" + pattern + "). لا يمكنه توقيع نسختين بمعرّفين مختلفين. اختر ملف تزويد wildcard يغطي معرّفات النسخ وامتداداتها، أو استخدم نسخة واحدة بمعرّف مصرح به.")
        }
        if let denied = ids.first(where: { !profile.permits($0) }) {
            throw DirectError("معرّف النسخة " + denied + " خارج نطاق " + pattern + ". عدّل المعرّف الأساسي أو اختر ملف تزويد متوافقًا.")
        }
    }

    static func rebased(_ value: String, from old: String, to new: String) -> String {
        guard value == old || value.hasPrefix(old + ".") else { return value }
        return new + String(value.dropFirst(old.count))
    }

    static func identifiers(base: String, count: Int, occupied: Set<String>) throws -> [String] {
        guard (1...limit).contains(count), !base.isEmpty,
              base.split(separator: ".", omittingEmptySubsequences: false).allSatisfy({
                  !$0.isEmpty && $0.utf8.allSatisfy { (65...90).contains($0) || (97...122).contains($0) || (48...57).contains($0) || $0 == 45 }
              }) else { throw DirectError("عدد النسخ أو معرّف التطبيق غير صالح.") }
        var suffix = 0
        let used = Set(occupied.map { $0.lowercased() })
        return (1...count).map { index in
            var id = base
            if index > 1 {
                repeat {
                    suffix += 1
                    id = "\(base).\(suffix)"
                } while used.contains(id.lowercased())
            }
            return id
        }
    }

    static func claims(_ original: [String: Any], id: String, profile: DirectProfile, grants: [String: Any]) throws -> [String: Any] {
        guard profile.permits(id), let prefix = profile.Entitlements.applicationIdentifier.split(separator: ".").first else {
            throw DirectError("ملف التزويد لا يغطي " + id)
        }
        let identity = String(prefix) + "." + id
        var result = original
        result["application-identifier"] = identity
        let teamKey = "com.apple.developer.team-identifier"
        result[teamKey] = grants[teamKey]
        // Development and distribution profiles control debugger access.
        result["get-task-allow"] = grants["get-task-allow"]
        if let groups = original["keychain-access-groups"] as? [String] {
            let oldID = original["application-identifier"] as? String
            result["keychain-access-groups"] = groups.map { $0 == oldID ? identity : $0 }
        }
        for (key, value) in result {
            guard let grant = grants[key], permits(value, by: grant) else {
                throw DirectError("ملف التزويد لا يسمح بالصلاحية " + key + " للتطبيق " + id)
            }
        }
        return result
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

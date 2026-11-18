//
//  ExpandableText.swift
//  Feather
//
//  Created by samsam on 7/26/25.
//


import SwiftUI


// Only sanitize presentation text. Never rewrite repository data, metadata or IPA links.
enum AppDescriptionSanitizer {
    private static let urlPattern = try! NSRegularExpression(
        pattern: #"(?i)(?:\[[^\]]+\]\(\s*)?(?:https?://|ftp://|tg://|www\.)[^\s<>]+|(?<![\w@])(?:[a-z0-9-]+\.)+(?:com|net|org|me|io|gg|app|dev|co|tv|xyz|site|store|info|link|ru|us|uk|ps|ir|cn|de|fr)(?::\d+)?(?:/[^\s<>]*)?"#
    )
    private static let emailPattern = try! NSRegularExpression(
        pattern: #"(?i)\b[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}\b"#
    )
    private static let promotionPattern = try! NSRegularExpression(
        pattern: #"(?i)\b(?:giveaway|telegram\s+channel|discord\s+server|whatsapp\s+group|join\s+(?:our|the)\b|follow\s+us\b|subscribe\s+to\s+our\b|visit\s+our\s+(?:channel|website)|check\s+out\s+our\s+(?:channel|website)|promo\s+code|sponsored\s+by|support\s+us)\b|(?:تابعونا|اشتركوا|قناتنا|روابطنا|قناة\s*(?:تيليجرام|التليجرام|تلغرام|التلغرام)|انضموا\s+(?:إلى|الى)|سحب\s+على\s+شهاد|حقوق\s+النشر)"#
    )
    private static let creditLinePattern = try! NSRegularExpression(
        pattern: #"(?i)^\s*(?:©|℗|\(c\)|copyright\b|all\s+rights\s+reserved\b|rights\s+reserved\b|credits?\s*[:：]|author\s*[:：]|made\s+by\b|developed\s+by\b|created\s+by\b|designed\s+by\b|powered\s+by\b|special\s+thanks\b|thanks\s+to\b|جميع\s+الحقوق|حقوق\s+النشر|الحقوق\s+محفوظة|تطوير\s+بواسطة|تم\s+التطوير\s+بواسطة|برمجة\s+بواسطة|تصميم\s+بواسطة|المطور\s*[:：])"#
    )
    private static let trailingRightsPattern = try! NSRegularExpression(
        pattern: #"(?i)(?:©|℗|\bcopyright\b|\ball\s+rights\s+reserved\b|جميع\s+الحقوق\s+محفوظة|حقوق\s+النشر\s+محفوظة).*$"#
    )

    private static func remove(_ regex: NSRegularExpression, from text: String) -> String {
        regex.stringByReplacingMatches(
            in: text, range: NSRange(text.startIndex..<text.endIndex, in: text), withTemplate: ""
        )
    }

    private static func contains(_ regex: NSRegularExpression, in text: String) -> Bool {
        regex.firstMatch(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text)) != nil
    }

    static func clean(_ original: String) -> String {
        var output: [String] = []
        for sourceLine in original.components(separatedBy: .newlines) {
            if contains(promotionPattern, in: sourceLine) ||
               contains(creditLinePattern, in: sourceLine) {
                continue
            }
            var line = remove(urlPattern, from: sourceLine)
            line = remove(emailPattern, from: line)
            line = remove(trailingRightsPattern, from: line)
            line = line.trimmingCharacters(in: .whitespacesAndNewlines)

            // Omit orphaned bullets, Markdown link labels and standalone handles.
            if line.hasPrefix("[") && line.hasSuffix("]") { continue }
            if line.hasPrefix("@") && !line.contains(" ") { continue }
            if !line.isEmpty &&
               !line.unicodeScalars.contains(where: { CharacterSet.alphanumerics.contains($0) }) {
                continue
            }
            if line.isEmpty {
                if !output.isEmpty && output.last != "" { output.append("") }
            } else {
                output.append(line)
            }
        }
        while output.last == "" { output.removeLast() }
        return output.joined(separator: "\n")
    }
}


struct ExpandableText: View {
	let text: String
	let lineLimit: Int

	@State private var expanded: Bool = false
	@State private var truncated: Bool = false

	var body: some View {
		VStack(alignment: .leading, spacing: 4) {
			Text(AppDescriptionSanitizer.clean(text))
				.lineLimit(expanded ? nil : lineLimit)
				.background(
					Text(AppDescriptionSanitizer.clean(text))
						.lineLimit(lineLimit)
						.background(GeometryReader { proxy in
							Color.clear
								.onAppear {
									let totalHeight = proxy.size.height
									let lineHeight = UIFont.preferredFont(forTextStyle: .body).lineHeight
									truncated = totalHeight > lineHeight * CGFloat(lineLimit)
								}
						})
						.hidden()
				)
				.onTapGesture {pGesture in
					withAnimation {
						expanded.toggle()
					}
				}

			if truncated {
				Button(action: {
					withAnimation {
						expanded.toggle()
					}
				}) {
					Text(expanded ? .localized("Less") : .localized("More"))
						.font(.caption)
						.foregroundColor(.accentColor)
				}
			}
		}
	}
}


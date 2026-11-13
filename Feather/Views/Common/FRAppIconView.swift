//
//  FRAppIconView.swift
//  Feather
//
//  Created by samara on 18.04.2025.
//

import SwiftUI

enum FRIconAppearance: Int {
	case light = 0
	case dark = 1
}

final class FRIconCache {
	static let shared = FRIconCache()
	private init() {}

	private let cache = NSCache<NSString, UIImage>()

	private func key(url: URL, appearance: FRIconAppearance, tint: String, isTinted: Bool, dynamic: Bool, preservesOriginalColors: Bool) -> NSString {
		"\(url.path)#\(appearance.rawValue)#\(tint)#\(isTinted)#\(dynamic)#\(preservesOriginalColors)" as NSString
	}

	func image(for url: URL, appearance: FRIconAppearance, tint: String, isTinted: Bool, dynamic: Bool, preservesOriginalColors: Bool) -> UIImage? {
		cache.object(forKey: key(url: url, appearance: appearance, tint: tint, isTinted: isTinted, dynamic: dynamic, preservesOriginalColors: preservesOriginalColors))
	}

	func insert(_ image: UIImage, for url: URL, appearance: FRIconAppearance, tint: String, isTinted: Bool, dynamic: Bool, preservesOriginalColors: Bool) {
		cache.setObject(image, forKey: key(url: url, appearance: appearance, tint: tint, isTinted: isTinted, dynamic: dynamic, preservesOriginalColors: preservesOriginalColors))
	}

	func invalidateAll() {
		cache.removeAllObjects()
	}
}

@MainActor
final class FRAppIconLoader: ObservableObject {
	@Published var image: UIImage?
	private var task: Task<Void, Never>?

	func load(bundleURL: URL, appearance: FRIconAppearance, tint: String, isTinted: Bool, dynamic: Bool, preservesOriginalColors: Bool) {
		if let cached = FRIconCache.shared.image(for: bundleURL, appearance: appearance, tint: tint, isTinted: isTinted, dynamic: dynamic, preservesOriginalColors: preservesOriginalColors) {
			self.image = cached
			return
		}

		task?.cancel()
		task = Task {
			let generated = await Task.detached(priority: .userInitiated) {
				return iconTest(bundleURL, preservesOriginalColors)
			}.value

			guard !Task.isCancelled else { return }

			if let generated {
				FRIconCache.shared.insert(generated, for: bundleURL, appearance: appearance, tint: tint, isTinted: isTinted, dynamic: dynamic, preservesOriginalColors: preservesOriginalColors)
				self.image = generated
			}
		}
	}

	func cancel() {
		task?.cancel()
	}
}

struct FRAppIconView: View {
	private let app: AppInfoPresentable?
	private let size: CGFloat
	private let preservesOriginalColors: Bool

	@Environment(\.colorScheme) private var colorScheme
	@StateObject private var loader = FRAppIconLoader()
	
	@AppStorage("Feather.userTintColor") private var selectedColorHex: String = "#848ef9"
	@AppStorage("Feather.shouldTintIcons") private var shouldTintIcons: Bool = false
	@AppStorage("Feather.shouldChangeIconsBasedOffStyle") private var shouldChangeIconsBasedOffStyle: Bool = false
	
	init(app: AppInfoPresentable? = nil, size: CGFloat = 87, preservesOriginalColors: Bool = false) {
		self.app = app
		self.size = size
		self.preservesOriginalColors = preservesOriginalColors
	}

	private var appearance: FRIconAppearance {
		colorScheme == .dark ? .dark : .light
	}

	var body: some View {
		Group {
			if let image = loader.image {
				if preservesOriginalColors {
					Image(uiImage: image)
						.renderingMode(.original)
						.appIconStyle(size: size)
				} else {
					Image(uiImage: image)
						.appIconStyle(size: size)
				}
			} else {
				if preservesOriginalColors {
					Image("App_Unknown")
						.renderingMode(.original)
						.appIconStyle(size: size)
				} else {
					Image("App_Unknown")
						.appIconStyle(size: size)
				}
			}
		}
		.task(id: "\(appearance.rawValue)\(selectedColorHex)\(shouldTintIcons)\(shouldChangeIconsBasedOffStyle)") {
			_load()
		}
		.onDisappear {
			loader.cancel()
		}
	}
	
	private func _load() {
		let bundleURL: URL

		if let app {
			guard let url = Storage.shared.getAppDirectory(for: app) else { return }
			bundleURL = url
		} else {
			bundleURL = Bundle.main.bundleURL
		}

		loader.load(
			bundleURL: bundleURL,
			appearance: appearance,
			tint: selectedColorHex,
			isTinted: shouldTintIcons,
			dynamic: shouldChangeIconsBasedOffStyle,
			preservesOriginalColors: preservesOriginalColors
		)
	}

}

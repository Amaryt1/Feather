//
//  DownloadButtonView.swift
//  Feather
//
//  Created by samsam on 7/25/25.
//

import SwiftUI
import Combine
import AltSourceKit
import NimbleViews

struct DownloadButtonView: View {
	let sourceURL: URL?
	let source: ASRepository?
	let app: ASRepository.App?
    private let fallbackDownloadURL: URL?
    private let fallbackDownloadID: String?

    init(sourceURL: URL?, source: ASRepository?, app: ASRepository.App) {
        self.sourceURL = sourceURL
        self.source = source
        self.app = app
        self.fallbackDownloadURL = nil
        self.fallbackDownloadID = nil
    }

    init(downloadURL: URL, downloadID: String) {
        self.sourceURL = nil
        self.source = nil
        self.app = nil
        self.fallbackDownloadURL = downloadURL
        self.fallbackDownloadID = downloadID
    }

    private var effectiveDownloadURL: URL? { app?.currentDownloadUrl ?? fallbackDownloadURL }
    private var effectiveDownloadID: String { app?.currentUniqueId ?? fallbackDownloadID ?? UUID().uuidString }
	@ObservedObject private var downloadManager = DownloadManager.shared

	@State private var downloadProgress: Double = 0
	@State private var cancellable: AnyCancellable?

	var body: some View {
		ZStack {
			if let currentDownload = downloadManager.getDownload(by: effectiveDownloadID) {
				ZStack {
					Circle()
						.trim(from: 0, to: downloadProgress)
						.stroke(AngularGradient(colors: [.cyan, Color.accentColor, .purple, .cyan], center: .center), style: StrokeStyle(lineWidth: 2.8, lineCap: .round))
						.rotationEffect(.degrees(-90))
						.frame(width: 31, height: 31)
						.animation(.smooth, value: downloadProgress)

					Image(systemName: downloadProgress >= 0.75 ? "archivebox" : "square.fill")
						.foregroundStyle(.tint)
						.font(.footnote).bold()
				}
				.onTapGesture {
					if downloadProgress <= 0.75 {
						downloadManager.cancelDownload(currentDownload)
					}
				}
				.compatTransition()
			} else {
				Button {
					if let url = effectiveDownloadURL {
						_ = downloadManager.startDownload(
							from: url,
							id: effectiveDownloadID,
							sourceProvenance: _sourceProvenance()
						)
					}
				} label: {
					Text(.localized("Get"))
						.lineLimit(0)
						.font(.headline.bold())
						.foregroundStyle(Color.accentColor)
						.padding(.horizontal, 24)
						.padding(.vertical, 6)
						.modifier(DownloadActionSurface())
				}
				.buttonStyle(.borderless)
				.compatTransition()
			}
		}
		.onAppear(perform: setupObserver)
		.onDisappear { cancellable?.cancel() }
		.onChange(of: downloadManager.downloads.description) { _ in
			setupObserver()
		}
		.animation(.easeInOut(duration: 0.3), value: downloadManager.getDownload(by: effectiveDownloadID) != nil)
	}

	private func setupObserver() {
		cancellable?.cancel()
		guard let download = downloadManager.getDownload(by: effectiveDownloadID) else {
			downloadProgress = 0
			return
		}
		downloadProgress = download.overallProgress

		let publisher = Publishers.CombineLatest(
			download.$progress,
			download.$unpackageProgress
		)

		cancellable = publisher.sink { _, _ in
			downloadProgress = download.overallProgress
		}
	}
	
	private func _sourceProvenance() -> SourceAppProvenance? {
		guard let source, let app else { return nil }
		return SourceAppProvenance(sourceURL: sourceURL, repository: source, app: app)
	}
}


private struct DownloadActionSurface: ViewModifier {
	func body(content: Content) -> some View {
		if #available(iOS 26.0, *) {
			content.glassEffect(.regular, in: Capsule())
		} else {
			content
				.background(.ultraThinMaterial, in: Capsule())
				.overlay(Capsule().strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
		}
	}
}

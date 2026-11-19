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
	let app: ASRepository.App
    var opensDetails = false
	@ObservedObject private var downloadManager = DownloadManager.shared

    private var operationID: String {
        SourceOperationKey.make(sourceURL: sourceURL, repository: source, app: app).id
    }

    var body: some View {
        ZStack {
            if let download = downloadManager.getDownload(by: operationID) {
                if opensDetails, let source {
                    NavigationLink {
                        SourceAppsDetailView(sourceURL: sourceURL, source: source, app: app)
                    } label: { SourceDownloadRing(download: download) }
                } else {
                    Button { downloadManager.cancelDownload(download) } label: { SourceDownloadRing(download: download) }
                        .disabled(download.packaging)
                }
            } else if opensDetails, let source {
                NavigationLink {
                    SourceAppsDetailView(sourceURL: sourceURL, source: source, app: app)
                } label: {
                    getLabel
                }
                .buttonStyle(.borderless)
            } else {
				Button {
					if let url = app.currentDownloadUrl {
						_ = downloadManager.startDownload(
							from: url,
							id: operationID,
							sourceProvenance: _sourceProvenance()
						)
					}
				} label: {
                    getLabel
                }
				.buttonStyle(.borderless)
				.compatTransition()
			}
		}

	}

    private var getLabel: some View {
        SourceActivityLabel(id: operationID, idle: .localized("Get"))
            .lineLimit(1)
            .font(.headline.bold())
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, 24)
            .padding(.vertical, 6)
            .modifier(DownloadActionSurface())
    }

	private func _sourceProvenance() -> SourceAppProvenance? {
		guard let source else { return nil }
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


struct SourceDownloadRing: View {
    @ObservedObject var download: Download
    var body: some View {
        ZStack {
            StoreProgressRing(download.packaging ? download.unpackageProgress : download.progress)
            Image(systemName: download.packaging ? "archivebox" : "arrow.down").font(.caption)
        }.frame(width: 32, height: 32)
        .accessibilityLabel(download.packaging ? "تجهيز الحزمة" : "جارٍ التنزيل")
    }
}

struct SourceActivityLabel: View {
    let id: String
    let idle: String
    @ObservedObject private var manager = DownloadManager.shared
    @ObservedObject private var local = SourceDirectSessions.shared

    init(id: String, idle: String) {
        self.id = id
        self.idle = idle
    }

    var body: some View {
        if let download = manager.getDownload(by: id) {
            SourceDownloadRing(download: download)
        } else if let session = local.sessions[id] {
            DirectSessionStatus(engine: session.engine)
        } else {
            switch manager.outcomes[id] {
            case .signing: Text("جارٍ التوقيع")
            case .ready: Text("جاهز للتثبيت")
            case .imported: Text("تمت الإضافة")
            default: Text(idle)
            }
        }
    }
}

//
//  DownloadHeaderView.swift
//  Feather
//
//  Created by samara on 16.05.2025.
//

import SwiftUI
import NimbleViews
import Combine
import NimbleExtensions

struct DownloadHeaderView: View {
	@ObservedObject var downloadManager: DownloadManager
	
	var body: some View {
		ZStack {
			if !downloadManager.manualDownloads.isEmpty {
				VStack {
					VStack(spacing: 12) {
						if let firstDownload = downloadManager.manualDownloads.first {
							DownloadItemView(download: firstDownload)
							
							if downloadManager.manualDownloads.count > 1 {
								HStack {
									Spacer()
									Text(verbatim: "+\(downloadManager.manualDownloads.count - 1)")
										.font(.caption)
										.foregroundColor(.secondary)
										.padding(.vertical, 4)
								}
							}
						}
					}
					.padding(.horizontal)
				}
				.transition(.move(edge: .top).combined(with: .opacity))
			}
		}
		.animation(.spring(), value: downloadManager.manualDownloads.count)
	}
}

struct DownloadItemView: View {
    @ObservedObject var download: Download

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(download.fileName).font(.subheadline.weight(.semibold)).lineLimit(2)
            DownloadMetricsView(download: download)
        }
        .padding(StoreTheme.inset)
        .storeCard()
    }
}

struct DownloadMetricsView: View {
    @ObservedObject var download: Download
    @Environment(\.storeAppearance) private var appearance
    @State private var sampleTime = Date()
    @State private var sampleBytes: Int64?
    @State private var rate: Int64?

    private var packaging: Bool { download.onlyArchiving || download.progress >= 1 }
    private var fraction: Double? {
        if packaging { return min(1, max(0, download.unpackageProgress)) }
        guard download.totalBytes > 0 else { return nil }
        return min(1, max(0, Double(download.bytesDownloaded) / Double(download.totalBytes)))
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(download.isPaused ? "متوقف مؤقتًا" : packaging ? "تجهيز الحزمة" : "تنزيل IPA")
                Spacer()
                if let fraction { Text(fraction.formatted(.percent.precision(.fractionLength(0)))).monospacedDigit() }
            }
            ProgressView(value: fraction).progressViewStyle(.linear)
                .tint(appearance == .professional ? StoreTheme.cyan : .accentColor)
            if !packaging {
                ViewThatFits(in: .horizontal) {
                    HStack { byteCount; Spacer(); transferRate }
                    VStack(alignment: .leading) { byteCount; transferRate }
                }
                .foregroundStyle(.secondary)
            }
        }
        .font(.caption)
        .accessibilityElement(children: .combine)
        .onAppear { resetSample() }
        .onChange(of: download.isPaused) { _ in resetSample() }
        .onChange(of: download.bytesDownloaded) { bytes in
            let now = Date()
            let seconds = now.timeIntervalSince(sampleTime)
            guard !download.isPaused, let previous = sampleBytes, bytes >= previous else { resetSample(); return }
            guard seconds >= 1 else { return }
            rate = Int64(Double(bytes - previous) / seconds)
            sampleBytes = bytes
            sampleTime = now
        }
    }
    private var byteCount: Text {
        let received = download.bytesDownloaded.formattedByteCount
        return Text(verbatim: download.totalBytes > 0 ? "\(received) / \(download.totalBytes.formattedByteCount)" : received)
    }
    @ViewBuilder private var transferRate: some View {
        if !download.isPaused, let rate, rate > 0 { Text(verbatim: "\(rate.formattedByteCount) / ث") }
    }
    private func resetSample() { sampleBytes = download.bytesDownloaded; sampleTime = Date(); rate = nil }
}

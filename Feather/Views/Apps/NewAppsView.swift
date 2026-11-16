import SwiftUI
import AltSourceKit
import NimbleJSON
import NukeUI
import CoreImage
import UIKit

private enum AMARYTStoreFeed {
    static let url = URL(string: "https://raw.githubusercontent.com/Amaryt1/Mstoda/main/apps.json")!
}

struct NewAppsView: View {
    @State private var repository: ASRepository?
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var selectedRoute: SourceAppsView.SourceAppRoute?

    private let fetchService = NBFetchService()

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && repository == nil {
                    ProgressView("جارٍ تحميل التطبيقات...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let repository, !repository.apps.isEmpty {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(repository.apps, id: \.currentUniqueId) { app in
                                NewAppFeatureCard(app: app) {
                                    selectedRoute = SourceAppsView.SourceAppRoute(
                                        sourceURL: AMARYTStoreFeed.url,
                                        source: repository,
                                        app: app
                                    )
                                }
                            }
                        }
                        .padding(16)
                    }
                    .refreshable { await loadRepository() }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 36))
                            .foregroundStyle(.secondary)
                        Text("لا توجد تطبيقات جديدة")
                            .font(.headline)
                        Text(loadError ?? "ستظهر التطبيقات هنا عند إضافتها إلى مستودع AMARYT STORE.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button("إعادة المحاولة") {
                            Task { await loadRepository() }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("جديد")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestinationIfAvailable(item: $selectedRoute) { route in
                SourceAppsDetailView(sourceURL: route.sourceURL, source: route.source, app: route.app)
            }
        }
        .task { await loadRepository() }
    }

    @MainActor
    private func loadRepository() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }

        do {
            let decoded: ASRepository = try await withCheckedThrowingContinuation { continuation in
                fetchService.fetch(from: AMARYTStoreFeed.url) { (result: Result<ASRepository, Error>) in
                    continuation.resume(with: result)
                }
            }
            repository = decoded
        } catch {
            loadError = "تعذر تحميل المستودع. تحقق من الاتصال ومن ملف apps.json."
        }
    }
}

private struct NewAppFeatureCard: View {
    let app: ASRepository.App
    let open: () -> Void

    @State private var sampledColor: Color?
    private var accent: Color { sampledColor ?? app.tintColor ?? Color.accentColor }

    var body: some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .bottomLeading) {
                    RoundedRectangle(cornerRadius: 23, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [accent.opacity(0.38), accent.opacity(0.12), Color(uiColor: .secondarySystemBackground)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    if let bannerURL = app.bannerURL {
                        LazyImage(url: bannerURL) { state in
                            if let image = state.image {
                                image.resizable().aspectRatio(contentMode: .fill)
                            } else {
                                bannerFallback
                            }
                        }
                    } else {
                        bannerFallback
                    }

                    LinearGradient(
                        colors: [.clear, accent.opacity(0.18), Color.black.opacity(0.58)],
                        startPoint: .center,
                        endPoint: .bottom
                    )

                    HStack(spacing: 10) {
                        if let iconURL = app.iconURL {
                            LazyImage(url: iconURL) { state in
                                if let image = state.image {
                                    image.resizable().aspectRatio(contentMode: .fill)
                                } else {
                                    Image(systemName: "app.fill").resizable().scaledToFit().padding(13)
                                }
                            }
                            .frame(width: 58, height: 58)
                            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 15).stroke(.white.opacity(0.25), lineWidth: 1))
                        } else {
                            Image(systemName: "app.fill")
                                .font(.system(size: 28))
                                .frame(width: 58, height: 58)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 15))
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text(app.currentName)
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.white)
                            Text(app.currentDescription ?? "تطبيق جديد")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.88))
                                .lineLimit(2)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.up.right")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .padding(15)
                }
                .frame(height: 205)
                .clipShape(RoundedRectangle(cornerRadius: 23, style: .continuous))

                HStack(spacing: 8) {
                    Label(app.currentVersion.map { "v\($0)" } ?? "الإصدار غير محدد", systemImage: "tag")
                    if let category = app.category {
                        Text("•")
                        Text(category)
                    }
                    Spacer()
                    Text("التفاصيل")
                        .fontWeight(.semibold)
                    Image(systemName: "chevron.left")
                }
                .font(.caption)
                .foregroundStyle(accent)
                .padding(.horizontal, 5)
                .padding(.top, 10)
            }
            .padding(11)
            .background {
                RoundedRectangle(cornerRadius: 27, style: .continuous)
                    .fill(accent.opacity(0.075))
                    .overlay(RoundedRectangle(cornerRadius: 27).strokeBorder(accent.opacity(0.16), lineWidth: 1))
            }
        }
        .buttonStyle(.plain)
        .task(id: (app.bannerURL ?? app.iconURL)?.absoluteString) {
            await sampleArtworkColor()
        }
    }

    @MainActor
    private func sampleArtworkColor() async {
        guard let url = app.bannerURL ?? app.iconURL else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let image = UIImage(data: data), let input = CIImage(image: image) else { return }
            let filter = CIFilter(name: "CIAreaAverage")
            filter?.setValue(input, forKey: kCIInputImageKey)
            filter?.setValue(CIVector(cgRect: input.extent), forKey: "inputExtent")
            guard
                let output = filter?.outputImage,
                let pixel = CIContext().createCGImage(output, from: CGRect(x: 0, y: 0, width: 1, height: 1))
            else { return }
            sampledColor = Color(uiColor: UIColor(cgImage: pixel))
        } catch {
            // Keep the configured tint color or system accent when artwork is unavailable.
        }
    }

    private var bannerFallback: some View {
        ZStack {
            LinearGradient(
                colors: [accent.opacity(0.5), accent.opacity(0.16), Color(uiColor: .secondarySystemBackground)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "sparkles")
                .font(.system(size: 38, weight: .light))
                .foregroundStyle(accent.opacity(0.75))
        }
    }
}

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
    @State private var isRefreshing = false
    @State private var selectedRoute: SourceAppsView.SourceAppRoute?

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
                        // Fill the content area offered by the parent layout.
                        // Any iPad category/sidebar column remains managed by the parent view.
                        .frame(maxWidth: .infinity, alignment: .center)
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
        .task {
            await loadRepository()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 120_000_000_000)
                guard !Task.isCancelled else { break }
                await loadRepository()
            }
        }
    }

    private var cacheURL: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("amaryt-store-apps.json")
    }

    @MainActor
    private func loadRepository() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        isLoading = repository == nil
        loadError = nil
        defer {
            isLoading = false
            isRefreshing = false
        }

        // اعرض آخر نسخة محفوظة فوراً، ثم حدّثها من GitHub.
        if repository == nil,
           let cachedData = try? Data(contentsOf: cacheURL),
           let cachedRepository = try? JSONDecoder().decode(ASRepository.self, from: cachedData) {
            repository = cachedRepository
        }

        // نقرأ apps.json مباشرةً من raw.githubusercontent.com لتجنب استهلاك
        // حد GitHub REST API عند وجود عدد كبير من المستخدمين.
        // معامل متغير مع تعليمات no-cache يقللان احتمال وصول نسخة CDN قديمة.
        var lastError: Error?
        for attempt in 0..<2 {
            do {
                var components = URLComponents(url: AMARYTStoreFeed.url, resolvingAgainstBaseURL: false)!
                components.queryItems = [
                    URLQueryItem(
                        name: "_refresh",
                        value: "\(Int(Date().timeIntervalSince1970 * 1000))-\(attempt)"
                    )
                ]

                var request = URLRequest(url: components.url!, timeoutInterval: 25)
                request.cachePolicy = .reloadIgnoringLocalCacheData
                request.setValue("no-cache, no-store, max-age=0", forHTTPHeaderField: "Cache-Control")
                request.setValue("no-cache", forHTTPHeaderField: "Pragma")

                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode),
                      !data.isEmpty else {
                    throw URLError(.badServerResponse)
                }

                // لا نستبدل النسخة المعروضة أو المحفوظة إلا بعد نجاح تحليل الملف كاملاً.
                let decoded = try JSONDecoder().decode(ASRepository.self, from: data)
                try data.write(to: cacheURL, options: .atomic)
                repository = decoded
                loadError = nil
                return
            } catch {
                lastError = error
                if attempt == 0 {
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                }
            }
        }

        if repository == nil {
            loadError = "تعذر تحميل المستودع. تحقق من الاتصال ومن ملف apps.json."
        }
        _ = lastError
    }
}

private struct NewAppFeatureCard: View {
    let app: ASRepository.App
    let open: () -> Void

    @State private var sampledColor: Color?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var accent: Color { sampledColor ?? app.tintColor ?? Color.accentColor }

    private var bannerMaskGradient: LinearGradient {
        let stops: [Gradient.Stop] = [
            Gradient.Stop(color: Color.clear, location: 0.0),
            Gradient.Stop(color: Color.black, location: 0.32),
            Gradient.Stop(color: Color.black, location: 1.0)
        ]
        let gradient = Gradient(stops: stops)
        return LinearGradient(
            gradient: gradient,
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var bannerInfoBackground: some View {
        let material = Rectangle()
            .fill(.ultraThinMaterial.opacity(0.50))
            .environment(\.colorScheme, .dark)

        let overlay = material.overlay(
            Rectangle().fill(Color.black.opacity(0.035))
        )

        return overlay.mask(bannerMaskGradient)
    }

    var body: some View {
        Button(action: open) {
            cardContent
        }
        .buttonStyle(.plain)
        .task(id: (app.bannerURL ?? app.iconURL)?.absoluteString) {
            await sampleArtworkColor()
        }
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            bannerSection

            if horizontalSizeClass == .regular {
                tabletAppInfo
            }

            metadataRow
        }
        .padding(11)
        .background(cardBackground)
    }

    private var bannerSection: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 23, style: .continuous)
                .fill(bannerPlaceholderGradient)

            bannerArtwork

            LinearGradient(
                colors: [.clear, accent.opacity(0.08), Color.black.opacity(0.12)],
                startPoint: .center,
                endPoint: .bottom
            )

            if horizontalSizeClass != .regular {
                compactAppInfo
            }
        }
        .frame(height: horizontalSizeClass == .regular ? 260 : 205)
        .frame(maxWidth: .infinity)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 23, style: .continuous))
    }

    private var bannerPlaceholderGradient: LinearGradient {
        LinearGradient(
            colors: [
                accent.opacity(0.38),
                accent.opacity(0.12),
                Color(uiColor: .secondarySystemBackground)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    @ViewBuilder
    private var bannerArtwork: some View {
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
    }

    private var compactAppInfo: some View {
        HStack(spacing: 10) {
            appIcon(size: 58, cornerRadius: 15)

            VStack(alignment: .leading, spacing: 3) {
                Text(app.currentName)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)

                Text(appDescription)
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 15)
        .padding(.vertical, 12)
        .background(bannerInfoBackground)
    }

    private var tabletAppInfo: some View {
        HStack(spacing: 12) {
            appIcon(size: 64, cornerRadius: 16)

            VStack(alignment: .leading, spacing: 5) {
                Text(app.currentName)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)

                Text(appDescription)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.88))
                    .lineLimit(3)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(tabletInfoBackground)
    }

    private var tabletInfoBackground: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        let material = shape
            .fill(.ultraThinMaterial.opacity(0.50))
            .environment(\\.colorScheme, .dark)

        return material.overlay(
            shape.fill(Color.black.opacity(0.035))
        )
    }

    private var appDescription: String {
        app.currentDescription ?? "تطبيق جديد"
    }

    @ViewBuilder
    private func appIcon(size: CGFloat, cornerRadius: CGFloat) -> some View {
        if let iconURL = app.iconURL {
            LazyImage(url: iconURL) { state in
                if let image = state.image {
                    image.resizable().aspectRatio(contentMode: .fill)
                } else {
                    Image(systemName: "app.fill")
                        .resizable()
                        .scaledToFit()
                        .padding(13)
                }
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(.white.opacity(0.25), lineWidth: 1)
            )
        } else {
            Image(systemName: "app.fill")
                .font(.system(size: size * 0.48))
                .frame(width: size, height: size)
                .background(
                    .ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                )
        }
    }

    private var metadataRow: some View {
        HStack(spacing: 8) {
            Label(
                app.currentVersion.map { "v\($0)" } ?? "الإصدار غير محدد",
                systemImage: "tag"
            )

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

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 27, style: .continuous)
            .fill(accent.opacity(0.075))
            .overlay(
                RoundedRectangle(cornerRadius: 27, style: .continuous)
                    .strokeBorder(accent.opacity(0.16), lineWidth: 1)
            )
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
            let bytes = UnsafeMutablePointer<UInt8>.allocate(capacity: 4)
            defer { bytes.deallocate() }
            let bitmap = CGContext(
                data: bytes,
                width: 1,
                height: 1,
                bitsPerComponent: 8,
                bytesPerRow: 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
            bitmap?.draw(pixel, in: CGRect(x: 0, y: 0, width: 1, height: 1))
            sampledColor = Color(
                red: Double(bytes[0]) / 255,
                green: Double(bytes[1]) / 255,
                blue: Double(bytes[2]) / 255
            )
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

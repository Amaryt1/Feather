import SwiftUI
import AltSourceKit
import NimbleViews
import NimbleJSON
import NukeUI
import SWCompression

private enum AppsCatalogCategory: String, CaseIterable, Identifiable, Sendable {
    case all, games, emulators, media, design, social, productivity
    case developer, signing, jailbreak, customization, ai, education, utilities, other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "الكل"
        case .games: "الألعاب"
        case .emulators: "المحاكيات"
        case .media: "الأفلام والوسائط"
        case .design: "التصميم وتحرير الصور"
        case .social: "التواصل الاجتماعي"
        case .productivity: "الإنتاجية والعمل"
        case .developer: "البرمجة والمطورين"
        case .signing: "التوقيع وتثبيت IPA"
        case .jailbreak: "الجيلبريك والأدوات"
        case .customization: "التخصيص والثيمات"
        case .ai: "الذكاء الاصطناعي"
        case .education: "التعليم"
        case .utilities: "الأدوات والخدمات"
        case .other: "تطبيقات أخرى"
        }
    }

    var icon: String {
        switch self {
        case .all: "square.grid.2x2"
        case .games: "gamecontroller"
        case .emulators: "arcade.stick"
        case .media: "play.rectangle"
        case .design: "paintpalette"
        case .social: "bubble.left.and.bubble.right"
        case .productivity: "checklist"
        case .developer: "chevron.left.forwardslash.chevron.right"
        case .signing: "signature"
        case .jailbreak: "wrench.and.screwdriver"
        case .customization: "slider.horizontal.3"
        case .ai: "sparkles"
        case .education: "graduationcap"
        case .utilities: "wrench.and.screwdriver"
        case .other: "app"
        }
    }

    static func classify(_ app: ASRepository.App) -> AppsCatalogCategory {
        let raw = (app.category ?? "")
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
        let text = [app.category, app.name, app.subtitle, app.description,
                    app.localizedDescription, app.developer]
            .compactMap { $0 }
            .joined(separator: " ")
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()

        func has(_ terms: [String]) -> Bool { terms.contains { text.contains($0) } }

        if has(["emulator", "emulation", "retroarch", "ppsspp", "delta emulator", "محاكي", "محاكاة"]) { return .emulators }
        if has(["game", "games", "gaming", "arcade", "rpg", "minecraft", "terraria", "fortnite", "لعبة", "ألعاب", "العاب"]) { return .games }
        if has(["photo editor", "photo editing", "graphic design", "drawing", "illustration", "canva", "procreate", "vector editor", "video editor", "تصميم", "تعديل الصور", "رسم"]) { return .design }
        if has(["movie", "movies", "tv series", "streaming", "iptv", "anime", "video player", "music player", "podcast", "cinema", "film", "أفلام", "مسلسلات", "انمي", "أنمي", "مشاهدة", "بث"]) { return .media }
        if has(["artificial intelligence", "ai assistant", "chatgpt", "openai", "claude", "gemini", "copilot", "stable diffusion", "machine learning", "ذكاء اصطناعي"]) { return .ai }
        if has(["jailbreak", "trollstore", "sileo", "cydia", "zebra", "dopamine", "ellekit", "roothide", "bootstrap", "misaka", "serotonin", "filza", "tweak", "جيلبريك", "تويك"]) { return .jailbreak }
        if has(["signing", "signer", "ksign", "esign", "scarlet", "sideload", "ipa installer", "certificate manager", "توقيع", "تثبيت ipa", "شهادات"]) { return .signing }
        if has(["ide", "code editor", "developer tool", "terminal", "git client", "ssh client", "debugger", "programming", "xcode", "برمجة", "مطور"]) { return .developer }
        if has(["language learning", "dictionary", "flashcards", "education", "school", "university", "تعليم", "قاموس", "تعلم", "دراسة"]) { return .education }
        if has(["productivity", "task manager", "todo", "notes", "calendar", "office suite", "document editor", "إنتاجية", "مهام", "ملاحظات"]) { return .productivity }
        if has(["social network", "messenger", "chat app", "telegram", "discord", "reddit", "social media", "مراسلة", "تواصل اجتماعي"]) { return .social }
        if has(["theme", "icon pack", "customization", "widgets", "wallpaper", "lock screen", "تخصيص", "ثيمات", "خلفيات"]) { return .customization }

        switch raw {
        case "games", "game", "gaming": return .games
        case "graphics", "photo-video", "design", "photography": return .design
        case "ai", "artificial-intelligence", "machine-learning": return .ai
        case "emulator", "emulators": return .emulators
        case "developer", "development": return .developer
        case "entertainment", "music", "video", "media": return .media
        case "productivity", "business": return .productivity
        case "customization", "themes", "personalization": return .customization
        case "jailbreak", "tweaks": return .jailbreak
        case "signing", "sideloading": return .signing
        case "education": return .education
        case "social": return .social
        case "utilities", "utility", "lifestyle", "health", "navigation", "weather", "finance", "news": return .utilities
        default: return .other
        }
    }
}

private struct AppsCatalogEntry: Identifiable, Sendable {
    let sourceURL: URL?
    let source: ASRepository
    let app: ASRepository.App
    let category: AppsCatalogCategory
    var id: String { "\(sourceURL?.absoluteString ?? "")|\(app.currentUniqueId)" }
}

private struct AppsCatalogIndex: Sendable {
    let repositories: [SourceAppsView.SourceRepositoryContext]
    let entries: [AppsCatalogEntry]
    let entriesByCategory: [AppsCatalogCategory: [AppsCatalogEntry]]
    let categoryCounts: [AppsCatalogCategory: Int]

    static func build(from repositories: [SourceAppsView.SourceRepositoryContext]) -> AppsCatalogIndex {
        var seen = Set<String>()
        var entries: [AppsCatalogEntry] = []
        entries.reserveCapacity(repositories.reduce(0) { $0 + $1.repository.apps.count })
        for context in repositories {
            for app in context.repository.apps {
                let name = app.currentName
                    .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let bundle = (app.id ?? "").lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                guard seen.insert("\(bundle)|\(name)").inserted else { continue }
                entries.append(.init(sourceURL: context.sourceURL, source: context.repository,
                                     app: app, category: AppsCatalogCategory.classify(app)))
            }
        }
        entries.sort { $0.app.currentName.localizedCaseInsensitiveCompare($1.app.currentName) == .orderedAscending }
        var buckets: [AppsCatalogCategory: [AppsCatalogEntry]] = [:]
        var counts: [AppsCatalogCategory: Int] = [:]
        for entry in entries {
            buckets[entry.category, default: []].append(entry)
            counts[entry.category, default: 0] += 1
        }
        return .init(repositories: repositories, entries: entries,
                     entriesByCategory: buckets, categoryCounts: counts)
    }
}

private enum AppsCatalogCache {
    private static func fileURL(for url: URL) -> URL? {
        guard let cachesDirectory = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else { return nil }

        let hash = url.absoluteString.utf8.reduce(UInt64(14695981039346656037)) {
            ($0 ^ UInt64($1)) &* 1099511628211
        }
        return cachesDirectory
            .appendingPathComponent("AppsCatalog", isDirectory: true)
            .appendingPathComponent(String(format: "%016llx.json", hash))
    }

    static func load(for url: URL) -> ASRepository? {
        guard let fileURL = fileURL(for: url),
              let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(ASRepository.self, from: data)
    }

    static func save(_ data: Data, for url: URL) {
        guard let fileURL = fileURL(for: url),
              (try? JSONDecoder().decode(ASRepository.self, from: data)) != nil else { return }

        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // Caching is an optimization; a cache write failure must not stop loading.
        }
    }
}

private enum AppsCatalogBundledSeed {
    private struct Payload: Decodable {
        struct Source: Decodable {
            let sourceURL: String
            let repository: ASRepository
        }
        let sources: [Source]
    }

    static func load() async -> AppsCatalogIndex {
        await Task.detached(priority: .userInitiated) {
            let repositories = decode()
            return AppsCatalogIndex.build(from: repositories)
        }.value
    }

    private static func decode() -> [SourceAppsView.SourceRepositoryContext] {
        guard
            let fileURL = Bundle.main.url(forResource: "AppsCatalogSeed.json", withExtension: "gz"),
            let compressedData = try? Data(contentsOf: fileURL),
            let data = try? GzipArchive.unarchive(archive: compressedData)
        else { return [] }

        // Decode the bundled JSON directly. Avoid constructing and serializing
        // a huge [String: Any] graph before decoding each repository again.
        if let payload = try? JSONDecoder().decode(Payload.self, from: data) {
            return payload.sources.compactMap { item in
                guard let url = URL(string: item.sourceURL) else { return nil }
                return .init(sourceURL: url, repository: item.repository)
            }
        }

        // Keep a tolerant fallback for repositories containing an unusual app.
        guard
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let items = root["sources"] as? [[String: Any]]
        else { return [] }

        var contexts: [SourceAppsView.SourceRepositoryContext] = []
        for item in items {
            guard
                let sourceString = item["sourceURL"] as? String,
                let sourceURL = URL(string: sourceString),
                let object = item["repository"] as? [String: Any],
                let repositoryData = try? JSONSerialization.data(withJSONObject: object)
            else { continue }
            if let repository = try? JSONDecoder().decode(ASRepository.self, from: repositoryData) {
                contexts.append(.init(sourceURL: sourceURL, repository: repository))
                continue
            }
            guard let apps = object["apps"] as? [[String: Any]] else { continue }
            var metadata = object
            metadata.removeValue(forKey: "apps")
            for app in apps {
                var single = metadata
                single["apps"] = [app]
                guard let data = try? JSONSerialization.data(withJSONObject: single),
                      let repository = try? JSONDecoder().decode(ASRepository.self, from: data) else { continue }
                contexts.append(.init(sourceURL: sourceURL, repository: repository))
            }
        }
        return contexts
    }
}
struct AppsCatalogView: View {
    @State private var repositories: [SourceAppsView.SourceRepositoryContext] = []
    @State private var selectedCategory: AppsCatalogCategory = .all
    @State private var searchText = ""
    @State private var selectedRoute: SourceAppsView.SourceAppRoute?
    @State private var isLoading = true
    @State private var hasLoaded = false
    @State private var hadFailures = false

    // These feed URLs are intentionally private to the app and are never displayed as source entries.
    private let feedURLs: [URL] = [
        URL(string: "https://fastsign.dev/repo.json")!,
        URL(string: "https://repository.apptesters.org")!,
        URL(string: "https://ipa.cypwn.xyz/cypwn.json")!
    ]

    // Build the catalog index once when repositories change. Rebuilding this
    // 27k-app index from body-computed properties made every category redraw
    // repeatedly scan the entire catalog.
    @State private var catalogEntries: [AppsCatalogEntry] = []
    @State private var entriesByCategory: [AppsCatalogCategory: [AppsCatalogEntry]] = [:]
    @State private var categoryCounts: [AppsCatalogCategory: Int] = [:]

    private var entries: [AppsCatalogEntry] { catalogEntries }

    private func apply(_ index: AppsCatalogIndex) {
        repositories = index.repositories
        catalogEntries = index.entries
        entriesByCategory = index.entriesByCategory
        categoryCounts = index.categoryCounts
    }

    @MainActor
    private func rebuildEntries() async {
        let snapshot = repositories
        let index = await Task.detached(priority: .userInitiated) {
            AppsCatalogIndex.build(from: snapshot)
        }.value
        catalogEntries = index.entries
        entriesByCategory = index.entriesByCategory
        categoryCounts = index.categoryCounts
    }

    private var visibleCategories: [AppsCatalogCategory] {
        AppsCatalogCategory.allCases.filter { $0 == .all || categoryCount($0) > 0 }
    }

    private var filteredEntries: [AppsCatalogEntry] {
        let selectedEntries = selectedCategory == .all ? entries : entriesByCategory[selectedCategory, default: []]
        guard !searchText.isEmpty else { return selectedEntries }
        return selectedEntries.filter { entry in
            entry.app.currentName.localizedCaseInsensitiveContains(searchText)
                || (entry.app.currentDescription?.localizedCaseInsensitiveContains(searchText) ?? false)
                || (entry.app.developer?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    var body: some View {
        NBNavigationView("التطبيقات") {
            VStack(spacing: 0) {
                categoryPicker

                if hadFailures && !repositories.isEmpty {
                    Label("تم تحميل بعض التطبيقات، وتعذر الوصول إلى مصدر أو أكثر",
                          systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.bottom, 6)
                }

                if isLoading && repositories.isEmpty {
                    Spacer()
                    ProgressView("جارٍ تحميل التطبيقات…")
                    Spacer()
                } else if filteredEntries.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "square.grid.3x3")
                            .font(.system(size: 34))
                            .foregroundStyle(.secondary)
                        Text(searchText.isEmpty ? "لا توجد تطبيقات في هذا القسم" : "لا توجد نتائج")
                            .font(.headline)
                        Text("اسحب للأسفل لتحديث قائمة التطبيقات.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        Section {
                            ForEach(filteredEntries) { entry in appRow(entry) }
                        } header: {
                            Text("\(filteredEntries.count) تطبيق")
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .searchable(text: $searchText, placement: .platform(), prompt: "ابحث عن تطبيق أو لعبة")
            .refreshable { await loadRepositories(forceRefresh: true) }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if isLoading {
                        ProgressView()
                    } else {
                        Button { Task { await loadRepositories(forceRefresh: true) } } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .accessibilityLabel("تحديث التطبيقات")
                    }
                }
            }
            .navigationDestinationIfAvailable(item: $selectedRoute) { route in
                SourceAppsDetailView(sourceURL: route.sourceURL, source: route.source, app: route.app)
            }
        }
        .task {
            guard !hasLoaded else { return }

            // Keep the loading state visible while the bundled snapshot is decoded.
            // The complete bundled catalog is the first screen; do not immediately
            // replace it with a slow, incremental network stream on every entry.
            let bundledIndex = await AppsCatalogBundledSeed.load()
            if !bundledIndex.entries.isEmpty {
                apply(bundledIndex)
                hasLoaded = true
                isLoading = false
                return
            }

            // Older installs without a bundled snapshot fall back to disk cache
            // and then to the network.
            hasLoaded = true
            isLoading = false
            await loadRepositories()
        }
    }

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(visibleCategories) { category in
                    let selected = selectedCategory == category
                    Button {
                        selectedCategory = category
                    } label: {
                        Label("\(category.title) · \(categoryCount(category))", systemImage: category.icon)
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 13)
                            .padding(.vertical, 9)
                            .background(Capsule().fill(selected ? Color.accentColor : Color(.secondarySystemBackground)))
                            .foregroundStyle(selected ? Color.white : Color.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
    }

    private func categoryCount(_ category: AppsCatalogCategory) -> Int {
        category == .all ? entries.count : categoryCounts[category, default: 0]
    }

    @ViewBuilder
    private func appRow(_ entry: AppsCatalogEntry) -> some View {
        HStack(spacing: 12) {
            Button {
                selectedRoute = SourceAppsView.SourceAppRoute(
                    sourceURL: entry.sourceURL, source: entry.source, app: entry.app
                )
            } label: {
                HStack(spacing: 12) {
                    LazyImage(url: entry.app.iconURL) { state in
                        if let image = state.image {
                            image.resizable().aspectRatio(contentMode: .fill)
                        } else {
                            Image("App_Unknown").resizable().aspectRatio(contentMode: .fit).padding(10)
                        }
                    }
                    .frame(width: 58, height: 58)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.app.currentName)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text(entry.app.currentDescription ?? "تطبيق")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                        Text(entry.category.title)
                            .font(.caption)
                            .foregroundStyle(Color.accentColor)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            DownloadButtonView(sourceURL: entry.sourceURL, source: entry.source, app: entry.app)
        }
        .padding(.vertical, 5)
    }

    @MainActor
    private func loadRepositories(forceRefresh: Bool = false) async {
        guard !isLoading else { return }
        isLoading = true
        hadFailures = false
        defer { isLoading = false }

        // On normal entry, restore complete repositories from disk first.
        // Only sources without a valid local copy need a network request.
        let urlsToLoad: [URL]
        if forceRefresh {
            urlsToLoad = feedURLs
        } else {
            var missingURLs: [URL] = []
            for url in feedURLs {
                if let cachedRepository = AppsCatalogCache.load(for: url) {
                    repositories.removeAll { $0.sourceURL == url }
                    repositories.append(
                        SourceAppsView.SourceRepositoryContext(
                            sourceURL: url,
                            repository: cachedRepository
                        )
                    )
                } else {
                    missingURLs.append(url)
                }
            }

            // Publish one prebuilt index after restoring all cached feeds.
            await rebuildEntries()

            // All feeds are already cached: show the full catalog immediately.
            if missingURLs.isEmpty { return }
            urlsToLoad = missingURLs
        }

        // Refresh feeds concurrently. Keep the last complete cached catalog visible
        // until each refreshed feed has finished successfully.
        await withTaskGroup(of: Bool.self) { group in
            for url in urlsToLoad {
                group.addTask {
                    do {
                        var fetchedContexts: [SourceAppsView.SourceRepositoryContext] = []

                        for try await partialRepository in AppsCatalogStreamingLoader.stream(from: url) {
                            let context = SourceAppsView.SourceRepositoryContext(
                                sourceURL: url,
                                repository: partialRepository
                            )
                            fetchedContexts.append(context)
                        }

                        await MainActor.run {
                            repositories.removeAll { $0.sourceURL == url }
                            repositories.append(contentsOf: fetchedContexts)
                        }
                        await rebuildEntries()
                        return true
                    } catch {
                        return false
                    }
                }
            }

            for await succeeded in group {
                if !succeeded {
                    hadFailures = true
                }
            }
        }
    }
}

// MARK: - Incremental repository JSON reader

/// Reads the top-level "apps" array as the response arrives and decodes one app
/// object at a time. The small repository wrapper preserves compatibility with
/// the existing SourceAppsDetailView and DownloadButtonView APIs.
private final class AppsCatalogStreamingLoader: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private var continuation: AsyncThrowingStream<ASRepository, Error>.Continuation?
    private var session: URLSession?
    private var task: URLSessionDataTask?
    private var buffer: [UInt8] = []
    private var searchIndex = 0
    private var readIndex = 0
    private var appsArrayStarted = false
    private var appsArrayFinished = false
    private var repositoryPrefix = Data()
    private var downloadedData = Data()
    private var sourceURL: URL?

    // Persist the JSON scanner state across network callbacks. Large app objects
    // are therefore scanned only once, rather than from their first byte per chunk.
    private var objectStartIndex: Int?
    private var objectScanIndex = 0
    private var objectDepth = 0
    private var objectInString = false
    private var objectEscaped = false

    // URLSession invokes this loader on one serial delegate queue.
    private let decoder = JSONDecoder()

    private static let appsKey = Array("\"apps\"".utf8)
    private static let whitespace: Set<UInt8> = [32, 9, 10, 13]

    static func stream(from url: URL) -> AsyncThrowingStream<ASRepository, Error> {
        AsyncThrowingStream { continuation in
            let loader = AppsCatalogStreamingLoader()
            loader.continuation = continuation
            loader.sourceURL = url

            let delegateQueue = OperationQueue()
            delegateQueue.maxConcurrentOperationCount = 1
            let session = URLSession(
                configuration: .default,
                delegate: loader,
                delegateQueue: delegateQueue
            )
            loader.session = session
            let task = session.dataTask(with: url)
            loader.task = task

            continuation.onTermination = { @Sendable _ in
                session.invalidateAndCancel()
            }
            task.resume()
        }
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        if let response = response as? HTTPURLResponse,
           !(200...299).contains(response.statusCode) {
            completionHandler(.cancel)
            continuation?.finish(throwing: URLError(.badServerResponse))
            return
        }
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        downloadedData.append(data)
        buffer.append(contentsOf: data)
        consumeAvailableApps()
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        if let error {
            continuation?.finish(throwing: error)
        } else if !appsArrayStarted || !appsArrayFinished {
            continuation?.finish(throwing: URLError(.cannotParseResponse))
        } else {
            if let sourceURL {
                AppsCatalogCache.save(downloadedData, for: sourceURL)
            }
            continuation?.finish()
        }
        session.finishTasksAndInvalidate()
    }

    private func consumeAvailableApps() {
        guard !appsArrayFinished else { return }

        if !appsArrayStarted {
            while searchIndex + Self.appsKey.count <= buffer.count {
                let keyStart = searchIndex
                let candidate = buffer[keyStart..<(keyStart + Self.appsKey.count)]
                if candidate.elementsEqual(Self.appsKey) {
                    var lookahead = keyStart + Self.appsKey.count
                    while lookahead < buffer.count,
                          Self.whitespace.contains(buffer[lookahead]) {
                        lookahead += 1
                    }
                    // The key may be split from its colon or opening bracket
                    // across network chunks. Keep the key position for the next chunk.
                    guard lookahead < buffer.count else {
                        searchIndex = keyStart
                        return
                    }
                    guard buffer[lookahead] == 58 else {
                        searchIndex = keyStart + 1
                        continue
                    }
                    lookahead += 1
                    while lookahead < buffer.count,
                          Self.whitespace.contains(buffer[lookahead]) {
                        lookahead += 1
                    }
                    guard lookahead < buffer.count else {
                        searchIndex = keyStart
                        return
                    }
                    if buffer[lookahead] == 91 {
                        let candidatePrefix = Data(buffer[..<keyStart])
                        var validationData = candidatePrefix
                        validationData.append(Data("\"apps\":[]}".utf8))
                        guard (try? JSONSerialization.jsonObject(with: validationData)) != nil else {
                            searchIndex = keyStart + 1
                            continue
                        }
                        repositoryPrefix = candidatePrefix
                        readIndex = lookahead + 1
                        searchIndex = 0
                        appsArrayStarted = true
                        break
                    }
                    searchIndex = keyStart + 1
                } else {
                    searchIndex += 1
                }
            }
            guard appsArrayStarted else {
                // Retain enough trailing bytes to recognize a key split at a chunk boundary.
                if searchIndex > Self.appsKey.count {
                    let discardCount = searchIndex - Self.appsKey.count
                    buffer.removeFirst(discardCount)
                    searchIndex = Self.appsKey.count
                }
                return
            }
        }

        while readIndex < buffer.count {
            while readIndex < buffer.count,
                  Self.whitespace.contains(buffer[readIndex]) || buffer[readIndex] == 44 {
                readIndex += 1
            }
            guard readIndex < buffer.count else { return }

            if buffer[readIndex] == 93 {
                appsArrayFinished = true
                readIndex += 1
                return
            }

            guard buffer[readIndex] == 123 else {
                // Ignore unexpected separators while remaining inside the apps array.
                readIndex += 1
                continue
            }

            if objectStartIndex == nil {
                objectStartIndex = readIndex
                objectScanIndex = readIndex
                objectDepth = 0
                objectInString = false
                objectEscaped = false
            }

            guard let objectStart = objectStartIndex else { return }
            var completedEnd: Int?

            while objectScanIndex < buffer.count {
                let byte = buffer[objectScanIndex]
                if objectInString {
                    if objectEscaped {
                        objectEscaped = false
                    } else if byte == 92 {
                        objectEscaped = true
                    } else if byte == 34 {
                        objectInString = false
                    }
                } else {
                    if byte == 34 {
                        objectInString = true
                    } else if byte == 123 {
                        objectDepth += 1
                    } else if byte == 125 {
                        objectDepth -= 1
                        if objectDepth == 0 {
                            completedEnd = objectScanIndex
                            objectScanIndex += 1
                            break
                        }
                    }
                }
                objectScanIndex += 1
            }

            guard let endIndex = completedEnd else {
                // Resume at the first unseen byte when the next network chunk arrives.
                return
            }

            let appData = Data(buffer[objectStart...endIndex])
            readIndex = endIndex + 1
            objectStartIndex = nil
            objectScanIndex = 0
            objectDepth = 0
            objectInString = false
            objectEscaped = false

            // A one-app repository keeps the existing app detail and download
            // components working while the rest of the feed is still arriving.
            var repositoryData = repositoryPrefix
            repositoryData.append(Data("\"apps\":[".utf8))
            repositoryData.append(appData)
            repositoryData.append(Data("]}".utf8))

            if let repository = try? decoder.decode(ASRepository.self, from: repositoryData) {
                continuation?.yield(repository)
            }

            compactBufferIfNeeded()
        }
    }

    /// Avoid repeated Array.removeFirst calls while consuming individual apps.
    /// Compact occasionally, and only between complete JSON objects.
    private func compactBufferIfNeeded() {
        guard objectStartIndex == nil,
              readIndex >= 65_536,
              readIndex * 2 >= buffer.count else { return }

        let discarded = readIndex
        buffer.removeFirst(discarded)
        readIndex = 0
        searchIndex = max(0, searchIndex - discarded)
    }
}

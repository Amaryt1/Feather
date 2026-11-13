import SwiftUI
import AltSourceKit
import NimbleViews
import NimbleJSON
import NukeUI
import SWCompression

private enum AppsCatalogCategory: String, CaseIterable, Identifiable, Sendable {
    case all, games, emulators, media, design, photography, social, productivity
    case developer, signing, jailbreak, customization, ai, education
    case utilities, finance, shopping, travel, health, navigation, news, lifestyle, sports, food, other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "الكل"
        case .games: "الألعاب"
        case .emulators: "المحاكيات"
        case .media: "الأفلام والوسائط"
        case .design: "التصميم وتحرير الصور"
        case .photography: "التصوير الفوتوغرافي"
        case .social: "التواصل الاجتماعي"
        case .productivity: "الإنتاجية والعمل"
        case .developer: "البرمجة والمطورين"
        case .signing: "التوقيع وتثبيت IPA"
        case .jailbreak: "الجيلبريك والأدوات"
        case .customization: "التخصيص والثيمات"
        case .ai: "الذكاء الاصطناعي"
        case .education: "التعليم"
        case .utilities: "الأدوات والخدمات"
        case .finance: "المال والأعمال المصرفية"
        case .shopping: "التسوق"
        case .travel: "السفر والحجوزات"
        case .health: "الصحة واللياقة"
        case .navigation: "الخرائط والملاحة"
        case .news: "الأخبار والمجلات"
        case .lifestyle: "نمط الحياة"
        case .sports: "الرياضة"
        case .food: "الطعام والطبخ"
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
        case .photography: "camera"
        case .social: "bubble.left.and.bubble.right"
        case .productivity: "checklist"
        case .developer: "chevron.left.forwardslash.chevron.right"
        case .signing: "signature"
        case .jailbreak: "wrench.and.screwdriver"
        case .customization: "slider.horizontal.3"
        case .ai: "sparkles"
        case .education: "graduationcap"
        case .utilities: "wrench.and.screwdriver"
        case .finance: "creditcard"
        case .shopping: "bag"
        case .travel: "airplane"
        case .health: "heart"
        case .navigation: "map"
        case .news: "newspaper"
        case .lifestyle: "leaf"
        case .sports: "figure.run"
        case .food: "fork.knife"
        case .other: "app"
        }
    }

    static func classify(_ app: ASRepository.App) -> AppsCatalogCategory {
        let raw = (app.category ?? "")
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let text = [app.category, app.name, app.subtitle, app.description,
                    app.localizedDescription, app.developer, app.id]
            .compactMap { $0 }
            .joined(separator: " ")
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()

        func has(_ terms: [String]) -> Bool { terms.contains { text.contains($0) } }

        // Prefer explicit, specific categories supplied by the repository.
        switch raw {
        case "games", "game", "gaming": return .games
        case "emulator", "emulators": return .emulators
        case "graphics", "photo-video", "design", "graphic design": return .design
        case "photography", "photo": return .photography
        case "entertainment", "music", "video", "media": return .media
        case "social", "social networking": return .social
        case "productivity", "business": return .productivity
        case "developer", "development": return .developer
        case "signing", "sideloading": return .signing
        case "jailbreak", "tweaks": return .jailbreak
        case "customization", "themes", "personalization": return .customization
        case "ai", "artificial intelligence", "machine learning": return .ai
        case "education": return .education
        case "finance": return .finance
        case "shopping": return .shopping
        case "travel": return .travel
        case "health", "fitness", "medical": return .health
        case "navigation": return .navigation
        case "news": return .news
        case "lifestyle": return .lifestyle
        case "sports": return .sports
        case "food", "food & drink": return .food
        default: break
        }

        // Use the app's descriptive metadata when the source has no specific category.
        if has(["emulator", "emulation", "retroarch", "ppsspp", "delta emulator", "محاكي", "محاكاة"]) { return .emulators }
        if has(["video game", "mobile game", "gameplay", "gaming", "arcade", "rpg", "minecraft", "terraria", "fortnite", "pubg", "roblox", "clash of clans", "clash royale", "subway surfers", "gta:", "grand theft auto", "bully", "8 ball pool", "agar.io", "car parking", "brawl stars", "call of duty", "free fire", "among us", "stardew valley", "pokemon", "لعبة", "ألعاب", "العاب"]) { return .games }
        if has(["artificial intelligence", "ai assistant", "chatgpt", "openai", "claude", "gemini", "copilot", "stable diffusion", "machine learning", "ذكاء اصطناعي"]) { return .ai }
        if has(["jailbreak", "trollstore", "sileo", "cydia", "zebra", "dopamine", "ellekit", "roothide", "bootstrap", "misaka", "serotonin", "filza", "tweak", "جيلبريك", "تويك"]) { return .jailbreak }
        if has(["signing", "signer", "ksign", "esign", "scarlet", "sideload", "ipa installer", "certificate manager", "توقيع", "تثبيت ipa", "شهادات"]) { return .signing }
        if has(["ide", "code editor", "developer tool", "terminal", "git client", "ssh client", "debugger", "programming", "xcode", "برمجة", "مطور"]) { return .developer }
        if has(["photo editor", "photo editing", "graphic design", "drawing", "illustration", "canva", "procreate", "vector editor", "video editor", "تصميم", "تعديل الصور", "رسم"]) { return .design }
        if has(["camera", "photography", "raw photo", "photo filter", "تصوير", "كاميرا"]) { return .photography }
        if has(["movie", "movies", "tv series", "streaming", "iptv", "anime", "video player", "music player", "podcast", "cinema", "film", "أفلام", "مسلسلات", "انمي", "أنمي", "مشاهدة", "بث"]) { return .media }
        if has(["language learning", "dictionary", "flashcards", "education", "school", "university", "تعليم", "قاموس", "تعلم", "دراسة"]) { return .education }
        if has(["task manager", "todo", "notes", "calendar", "office suite", "document editor", "إنتاجية", "مهام", "ملاحظات"]) { return .productivity }
        if has(["social network", "messenger", "chat app", "telegram", "discord", "reddit", "social media", "instagram", "facebook", "tiktok", "whatsapp", "snapchat", "twitter", "تواصل اجتماعي", "مراسلة"]) { return .social }
        if has(["youtube", "netflix", "spotify", "twitch", "vlc", "soundcloud", "music streaming", "video streaming"]) { return .media }
        if has(["capcut", "picsart", "canva", "alight motion", "video star", "kinemaster", "lightroom", "photoshop", "procreate", "rem editing"]) { return .design }
        if has(["notion", "todoist", "ticktick", "goodnotes", "notability", "noteshelf", "microsoft office", "google drive", "dropbox", "pdf editor"]) { return .productivity }
        if has(["theme", "icon pack", "customization", "widgets", "wallpaper", "lock screen", "تخصيص", "ثيمات", "خلفيات"]) { return .customization }
        if has(["banking", "bank account", "investment", "stock market", "crypto wallet", "payment", "wallet", "bank", "مصرف", "محفظة", "دفع"]) { return .finance }
        if has(["shopping", "marketplace", "online store", "e-commerce", "retail", "تسوق", "متجر", "شراء"]) { return .shopping }
        if has(["flight", "hotel booking", "travel guide", "airline", "trip planner", "حجز فندق", "سفر", "رحلات"]) { return .travel }
        if has(["fitness", "workout", "health", "medical", "doctor", "meditation", "sleep tracker", "لياقة", "صحة", "طبي"]) { return .health }
        if has(["navigation", "maps", "gps", "directions", "خرائط", "ملاحة"]) { return .navigation }
        if has(["news", "newspaper", "magazine", "breaking news", "أخبار", "مجلة"]) { return .news }
        if has(["recipe", "cooking", "food delivery", "restaurant", "وصفات", "طبخ", "طعام", "مطعم"]) { return .food }
        if has(["football", "soccer", "basketball", "tennis", "sports", "workout training", "كرة القدم", "رياضة"]) { return .sports }
        if has(["lifestyle", "home design", "parenting", "pets", "نمط الحياة", "منزل"]) { return .lifestyle }
        if has(["utility", "utilities", "file manager", "scanner", "calculator", "speed test", "weather", "أدوات", "حاسبة", "طقس"]) { return .utilities }

        switch raw {
        case "utilities", "utility": return .utilities
        default: return .other
        }
    }
}

private enum AppsCatalogSort: String, CaseIterable {
    case recommended, name, newest, largest

    var title: String {
        switch self {
        case .recommended: "مقترح"
        case .name: "الاسم"
        case .newest: "الأحدث"
        case .largest: "الأكبر حجماً"
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
                let displayName = app.currentName.trimmingCharacters(in: .whitespacesAndNewlines)
                let normalizedName = displayName.lowercased()
                guard !displayName.isEmpty,
                      !["name", "unknown", "app"].contains(normalizedName),
                      let downloadURL = app.currentDownloadUrl,
                      let scheme = downloadURL.scheme?.lowercased(),
                      ["http", "https"].contains(scheme),
                      downloadURL.host != nil else { continue }

                let bundle = (app.id ?? "").lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                let developer = (app.developer ?? "").lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                let identity = bundle.isEmpty ? "name|\(normalizedName)|\(developer)" : "bundle|\(bundle)"
                guard seen.insert(identity).inserted else { continue }

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


struct AppsCatalogView: View {
    // These repositories are intentionally fetched internally and never added to the visible Sources list.
    private static let privateFeedURLs: [URL] = [
        URL(string: "https://ipaomtk-source.shrubhub.workers.dev/ipaomtk.json")!,
        URL(string: "https://iosvizor-source.shrubhub.workers.dev/iosvizor.json")!,
        URL(string: "https://raw.githubusercontent.com/RipeStore/altmaker/main/AltMaker.json")!,
        URL(string: "https://ittza7aa.com/repo.json")!
    ]

    @State private var repositories: [SourceAppsView.SourceRepositoryContext] = []
    @State private var selectedCategory: AppsCatalogCategory = .all
    @State private var searchText = ""
    @State private var selectedRoute: SourceAppsView.SourceAppRoute?
    @State private var isLoading = true
    @State private var hasLoaded = false
    @StateObject private var personalization = AppsCatalogPersonalization.shared
    @State private var favoritesOnly = false
    @State private var recentOnly = false
    @State private var sortOption: AppsCatalogSort = .recommended
    @State private var isHistoryPresented = false
    @State private var isDownloadsPresented = false

    // Build the catalog index once when repositories change. Rebuilding this
    // 27k-app index from body-computed properties made every category redraw
    // repeatedly scan the entire catalog.
    @State private var catalogEntries: [AppsCatalogEntry] = []
    @State private var entriesByCategory: [AppsCatalogCategory: [AppsCatalogEntry]] = [:]
    @State private var categoryCounts: [AppsCatalogCategory: Int] = [:]

    private var entries: [AppsCatalogEntry] { catalogEntries }

    private static func fetchPrivateRepository(from url: URL) async -> SourceAppsView.SourceRepositoryContext? {
        await withCheckedContinuation { continuation in
            let service = NBFetchService()
            service.fetch(from: url) { (result: Result<ASRepository, Error>) in
                switch result {
                case .success(let repository):
                    continuation.resume(returning: SourceAppsView.SourceRepositoryContext(
                        sourceURL: url, repository: repository
                    ))
                case .failure:
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    @MainActor
    private func loadPrivateFeeds(force: Bool = false) async {
        guard !hasLoaded || force else { return }
        isLoading = true

        let feeds = Self.privateFeedURLs
        let loadedContexts = await withTaskGroup(
            of: (Int, SourceAppsView.SourceRepositoryContext?).self,
            returning: [SourceAppsView.SourceRepositoryContext].self
        ) { group in
            for (index, url) in feeds.enumerated() {
                group.addTask {
                    (index, await Self.fetchPrivateRepository(from: url))
                }
            }

            var results: [(Int, SourceAppsView.SourceRepositoryContext?)] = []
            for await result in group {
                results.append(result)
            }
            return results
                .sorted { $0.0 < $1.0 }
                .compactMap { $0.1 }
        }

        let index = await Task.detached(priority: .userInitiated) {
            AppsCatalogIndex.build(from: loadedContexts)
        }.value
        apply(index)
        hasLoaded = true
        isLoading = false
    }

    private func apply(_ index: AppsCatalogIndex) {
        repositories = index.repositories
        catalogEntries = index.entries
        entriesByCategory = index.entriesByCategory
        categoryCounts = index.categoryCounts
        personalization.checkForUpdates(in: index.entries.map {
            AppsCatalogEntrySnapshot(id: $0.id, name: $0.app.currentName, version: $0.app.currentVersion)
        })
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
        personalization.checkForUpdates(in: index.entries.map {
            AppsCatalogEntrySnapshot(id: $0.id, name: $0.app.currentName, version: $0.app.currentVersion)
        })
    }

    private var visibleCategories: [AppsCatalogCategory] {
        AppsCatalogCategory.allCases.filter { $0 == .all || categoryCount($0) > 0 }
    }

    private var filteredEntries: [AppsCatalogEntry] {
        let selectedEntries = selectedCategory == .all ? entries : entriesByCategory[selectedCategory, default: []]
        var result = selectedEntries

        if favoritesOnly {
            result = result.filter { personalization.isFavorite($0.id) }
        }
        if recentOnly {
            let recentOrder = Dictionary(uniqueKeysWithValues: personalization.recentIDs.enumerated().map { ($1, $0) })
            result = result.filter { recentOrder[$0.id] != nil }
            result.sort { (recentOrder[$0.id] ?? .max) < (recentOrder[$1.id] ?? .max) }
        }
        if !searchText.isEmpty {
            result = result.filter { entry in
                entry.app.currentName.localizedCaseInsensitiveContains(searchText)
                    || (entry.app.currentDescription?.localizedCaseInsensitiveContains(searchText) ?? false)
                    || (entry.app.developer?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        switch sortOption {
        case .recommended:
            if let recentID = personalization.recentIDs.first,
               let recentCategory = entries.first(where: { $0.id == recentID })?.category {
                result.sort {
                    ($0.category == recentCategory ? 0 : 1) < ($1.category == recentCategory ? 0 : 1)
                }
            }
        case .name:
            result.sort { $0.app.currentName.localizedCaseInsensitiveCompare($1.app.currentName) == .orderedAscending }
        case .newest:
            result.sort { ($0.app.currentDate?.date ?? .distantPast) > ($1.app.currentDate?.date ?? .distantPast) }
        case .largest:
            result.sort { ($0.app.size ?? 0) > ($1.app.size ?? 0) }
        }
        return result
    }

    var body: some View {
        NBNavigationView("التطبيقات") {
            VStack(spacing: 0) {
                categoryPicker
                catalogControls

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
                        Text("تحقق من اتصال الإنترنت أو جرّب تحميل القائمة من جديد.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        if catalogEntries.isEmpty {
                            Button {
                                Task { await loadPrivateFeeds(force: true) }
                            } label: {
                                Label("إعادة تحميل التطبيقات", systemImage: "arrow.clockwise")
                            }
                            .buttonStyle(.bordered)
                            .disabled(isLoading)
                        }
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
                    .refreshable {
                        await loadPrivateFeeds(force: true)
                    }
                }
            }
            .searchable(text: $searchText, placement: .platform(), prompt: "ابحث عن تطبيق أو لعبة")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { isDownloadsPresented = true } label: {
                        Image(systemName: "arrow.down.circle")
                    }
                    .accessibilityLabel("مدير التحميلات")

                    Button { isHistoryPresented = true } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                    .accessibilityLabel("سجل التحميلات")

                    Button {
                        personalization.setUpdateNotificationsEnabled(!personalization.updateNotificationsEnabled)
                    } label: {
                        Image(systemName: personalization.updateNotificationsEnabled ? "bell.badge.fill" : "bell")
                    }
                    .accessibilityLabel("تنبيهات تحديث التطبيقات المفضلة")

                }
            }
            .sheet(isPresented: $isHistoryPresented) {
                AppsCatalogHistoryView()
            }
            .sheet(isPresented: $isDownloadsPresented) {
                AppsCatalogDownloadsView()
            }
            .navigationDestinationIfAvailable(item: $selectedRoute) { route in
                SourceAppsDetailView(sourceURL: route.sourceURL, source: route.source, app: route.app)
            }
        }
        .task {
            await loadPrivateFeeds()
        }
    }

    private var catalogControls: some View {
        HStack(spacing: 8) {
            Button {
                favoritesOnly.toggle()
                if favoritesOnly { recentOnly = false }
            } label: {
                Label("المفضلة", systemImage: favoritesOnly ? "heart.fill" : "heart")
            }
            .tint(favoritesOnly ? .pink : .accentColor)
            .buttonStyle(.bordered)

            Button {
                recentOnly.toggle()
                if recentOnly { favoritesOnly = false }
            } label: {
                Label("الأخيرة", systemImage: "clock")
            }
            .tint(recentOnly ? .accentColor : .secondary)
            .buttonStyle(.bordered)

            Spacer(minLength: 0)

            Menu {
                ForEach(AppsCatalogSort.allCases, id: \.rawValue) { option in
                    Button {
                        sortOption = option
                    } label: {
                        if sortOption == option {
                            Label(option.title, systemImage: "checkmark")
                        } else {
                            Text(option.title)
                        }
                    }
                }
            } label: {
                Label("ترتيب", systemImage: "arrow.up.arrow.down")
                    .font(.subheadline)
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
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
                personalization.recordViewed(entry.id)
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

            VStack(spacing: 8) {
                DownloadButtonView(sourceURL: entry.sourceURL, source: entry.source, app: entry.app)
                Button {
                    personalization.toggleFavorite(entry.id)
                } label: {
                    Image(systemName: personalization.isFavorite(entry.id) ? "heart.fill" : "heart")
                        .foregroundStyle(personalization.isFavorite(entry.id) ? Color.pink : Color.secondary)
                        .font(.system(size: 17, weight: .medium))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(personalization.isFavorite(entry.id) ? "إزالة من المفضلة" : "إضافة إلى المفضلة")
            }
        }
        .padding(.vertical, 5)
    }


}


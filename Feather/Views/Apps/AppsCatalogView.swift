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

    private static func normalized(_ value: String) -> String {
        let folded = value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: "أ", with: "ا")
            .replacingOccurrences(of: "إ", with: "ا")
            .replacingOccurrences(of: "آ", with: "ا")
            .replacingOccurrences(of: "ى", with: "ي")
            .replacingOccurrences(of: "ة", with: "ه")
        let words = folded
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        return " " + words.joined(separator: " ") + " "
    }

    private static func containsAny(_ phrases: [String], in text: String) -> Bool {
        phrases.contains { text.contains(normalized($0)) }
    }

    static func classify(_ app: ASRepository.App) -> AppsCatalogCategory {
        let name = normalized(app.name ?? "")
        let subtitle = normalized(app.subtitle ?? "")
        let category = normalized(app.category ?? "")
        let details = normalized([
            app.description,
            app.localizedDescription
        ].compactMap { $0 }.joined(separator: " "))

        func named(_ phrases: [String]) -> Bool {
            containsAny(phrases, in: name)
        }
        func titled(_ phrases: [String]) -> Bool {
            containsAny(phrases, in: name) || containsAny(phrases, in: subtitle)
        }
        func categorized(_ phrases: [String]) -> Bool {
            containsAny(phrases, in: category)
        }
        func described(_ phrases: [String]) -> Bool {
            containsAny(phrases, in: details)
        }

        // Resolve clear app identities first. This prevents sports-themed games,
        // fitness games, or news about games from being placed in non-game sections.
        if named([
            "emulator", "emulators", "retroarch", "ppsspp", "delta emulator",
            "provenance", "dolphin emulator", "folium", "mame", "game boy emulator"
        ]) {
            return .emulators
        }

        if named([
            "gta", "grand theft auto", "bully", "minecraft", "roblox", "fortnite",
            "pubg", "playerunknown", "call of duty", "free fire", "among us",
            "8 ball pool", "8ball pool", "agar io", "car parking", "clash of clans",
            "clash royale", "subway surfers", "brawl stars", "stardew valley",
            "pokemon", "genshin impact", "honkai", "mobile legends",
            "league of legends", "wild rift", "asphalt", "need for speed",
            "efootball", "fifa", "ea sports fc", "dream league soccer",
            "real racing", "monopoly", "angry birds", "fruit ninja", "temple run",
            "hill climb", "shadow fight", "geometry dash", "plants vs zombies",
            "mortal kombat", "tekken", "street fighter", "terraria", "dead cells",
            "the sims", "simcity", "hay day", "stumble guys", "fall guys",
            "ludo", "chess", "candy crush", "homescapes", "royal match",
            "arena of valor", "brawlhalla", "لعبة", "العاب"
        ]) || named(["game", "games", "gaming"]) || categorized([
            "games", "game", "gaming", "arcade games", "puzzle games",
            "action games", "adventure games", "racing games", "strategy games"
        ]) {
            return .games
        }

        if named([
            "esign", "e sign", "scarlet", "altstore", "sidestore", "trollstore",
            "troll installer", "trollinstallerx", "feather signer", "ksign"
        ]) {
            return .signing
        }
        if named([
            "sileo", "cydia", "dopamine", "misaka", "serotonin", "ellekit",
            "roothide", "bootstrap", "filza", "snowboard", "jailbreak", "tweak"
        ]) {
            return .jailbreak
        }
        if named([
            "chatgpt", "openai", "claude", "gemini", "copilot", "perplexity",
            "midjourney", "stable diffusion", "ai assistant"
        ]) {
            return .ai
        }

        // Well-known apps are classified by their actual purpose, not incidental
        // words in their marketing descriptions or developer names.
        if named([
            "netflix", "youtube", "spotify", "twitch", "vlc", "soundcloud",
            "iptv", "crunchyroll", "disney plus", "prime video", "apple music",
            "apple tv", "plex", "kodi", "podcast", "video player", "movie player",
            "djay", "moviespirit"
        ]) {
            return .media
        }
        if named([
            "capcut", "picsart", "canva", "alight motion", "video star",
            "kinemaster", "lightroom", "photoshop", "procreate", "ibis paint",
            "remini", "cute cut", "videoleap", "inshot", "affinity", "pixelmator"
        ]) {
            return .design
        }
        if named([
            "halide", "camera plus", "procamera", "blackmagic camera",
            "dslr camera", "spectre camera", "camera app"
        ]) {
            return .photography
        }
        if named([
            "telegram", "discord", "reddit", "instagram", "facebook", "tiktok",
            "whatsapp", "snapchat", "twitter", "threads", "signal", "messenger",
            "wechat", "imo", "viber"
        ]) {
            return .social
        }
        if named([
            "duolingo", "khan academy", "coursera", "udemy", "quizlet", "moodle",
            "kahoot", "babbel", "busuu", "linkedin learning", "goodreads"
        ]) {
            return .education
        }
        if named([
            "notion", "todoist", "ticktick", "goodnotes", "notability", "noteshelf",
            "microsoft office", "google drive", "dropbox", "pdf expert",
            "microsoft word", "microsoft excel", "microsoft powerpoint"
        ]) {
            return .productivity
        }
        if named([
            "working copy", "textastic", "code editor", "github", "git client",
            "xcode", "terminal", "terminus", "ssh client", "ide"
        ]) {
            return .developer
        }
        if named([
            "paypal", "revolut", "wise", "cash app", "payoneer", "wallet",
            "banking", "bank app", "venmo"
        ]) {
            return .finance
        }
        if named([
            "amazon", "aliexpress", "ebay", "etsy", "temu", "shein",
            "shopping", "shop app"
        ]) {
            return .shopping
        }
        if named([
            "booking com", "airbnb", "expedia", "tripadvisor", "skyscanner",
            "airline", "flight booking", "travel guide"
        ]) {
            return .travel
        }
        if named([
            "health", "fitness", "workout", "gym", "medical", "doctor",
            "myfitnesspal", "fitbit", "nike training club", "apple fitness",
            "headspace", "sleep cycle", "calm", "medisafe", "ada health"
        ]) {
            return .health
        }
        if named([
            "google maps", "apple maps", "waze", "maps", "navigation",
            "here wego", "sygic", "tomtom"
        ]) {
            return .navigation
        }
        if named([
            "bbc news", "cnn", "reuters", "ap news", "al jazeera", "sky news",
            "new york times", "the guardian", "npr", "news", "newspaper",
            "magazine", "flipboard"
        ]) {
            return .news
        }
        if named([
            "onefootball", "fotmob", "sofascore", "flashscore", "livescore",
            "365scores", "espn", "bein sports", "f1 tv", "formula 1",
            "nba", "nfl", "ufc", "cricbuzz", "wimbledon", "strava",
            "sports", "sport", "football scores", "soccer", "basketball",
            "tennis", "cricket", "rugby"
        ]) {
            return .sports
        }
        if named([
            "uber eats", "doordash", "deliveroo", "talabat", "food delivery",
            "recipe", "cooking", "kitchen stories"
        ]) {
            return .food
        }
        if named([
            "widgy", "widgetsmith", "themify", "color widgets", "wallpaper",
            "icon pack", "lock launcher", "themes"
        ]) {
            return .customization
        }
        if named([
            "calculator", "file manager", "scanner", "qr scanner", "speed test",
            "weather", "auto clicker", "password manager", "compressor"
        ]) {
            return .utilities
        }
        if named([
            "home design", "home decor", "pet care", "parenting", "personal journal",
            "habit tracker", "lifestyle", "daily journal"
        ]) {
            return .lifestyle
        }

        // Use explicit source categories next. The values are normalized first,
        // so variants such as "Health & Fitness" and "Food & Drink" are handled.
        if categorized(["health", "health fitness", "fitness", "medical", "medicine"]) {
            return .health
        }
        if categorized(["sports", "sport", "sports recreation"]) {
            return .sports
        }
        if categorized(["news", "news magazines", "magazines newspapers"]) {
            return .news
        }
        if categorized(["lifestyle", "life style"]) {
            return .lifestyle
        }
        if categorized(["graphics design", "graphic design", "design", "photo video"]) {
            return .design
        }
        if categorized(["photography", "camera"]) {
            return .photography
        }
        if categorized(["entertainment", "music", "video", "media", "streaming"]) {
            return .media
        }
        if categorized(["social", "social networking", "communication", "messaging"]) {
            return .social
        }
        if categorized(["productivity", "business", "office"]) {
            return .productivity
        }
        if categorized(["developer", "developer tools", "development", "programming"]) {
            return .developer
        }
        if categorized(["signing", "sideloading"]) {
            return .signing
        }
        if categorized(["jailbreak", "tweaks"]) {
            return .jailbreak
        }
        if categorized(["customization", "themes", "personalization"]) {
            return .customization
        }
        if categorized(["ai", "artificial intelligence", "machine learning"]) {
            return .ai
        }
        if categorized(["education", "reference", "books"]) {
            return .education
        }
        if categorized(["finance", "banking", "financial"]) {
            return .finance
        }
        if categorized(["shopping", "retail", "e commerce"]) {
            return .shopping
        }
        if categorized(["travel", "travel navigation"]) {
            return .travel
        }
        if categorized(["navigation", "maps"]) {
            return .navigation
        }
        if categorized(["food", "food drink", "food dining"]) {
            return .food
        }
        if categorized(["utilities", "utility", "tools"]) {
            return .utilities
        }

        // Descriptions are only used for specific functions, never broad words
        // such as "sports", "health", or "news" that can appear incidentally.
        if described([
            "workout plan", "fitness tracker", "step counter", "calorie counter",
            "sleep tracker", "health records", "medical appointment", "gym training",
            "تمارين رياضية", "تتبع اللياقة", "عداد الخطوات", "السعرات الحرارية",
            "تتبع النوم", "السجل الطبي"
        ]) {
            return .health
        }
        if described([
            "live sports scores", "football scores", "match schedule", "match results",
            "league table", "sports news", "مباريات مباشرة", "نتائج المباريات",
            "جدول المباريات", "اخبار الرياضة", "أخبار الرياضة"
        ]) {
            return .sports
        }
        if described([
            "breaking news", "news reader", "world news", "daily news",
            "أخبار عاجلة", "نشرة الأخبار", "صحيفة", "مجلة"
        ]) {
            return .news
        }
        if described([
            "flight booking", "hotel booking", "travel guide", "trip planner",
            "حجز الطيران", "حجز الفنادق", "دليل السفر"
        ]) {
            return .travel
        }
        if described([
            "food delivery", "recipe book", "cooking recipes", "توصيل الطعام",
            "وصفات الطعام", "وصفات الطبخ"
        ]) {
            return .food
        }
        if described([
            "online shopping", "shopping cart", "marketplace", "التسوق عبر الانترنت"
        ]) {
            return .shopping
        }
        if described([
            "mobile banking", "bank account", "payment wallet", "التحويلات البنكية"
        ]) {
            return .finance
        }
        if described([
            "home automation", "interior design", "pet care", "parenting",
            "منزل ذكي", "رعاية الحيوانات", "العناية بالحيوانات"
        ]) {
            return .lifestyle
        }
        if described([
            "file manager", "document scanner", "qr code scanner", "speed test",
            "weather forecast", "calculator app", "password manager"
        ]) {
            return .utilities
        }

        return .other
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
        var result = selectedEntries

        if !searchText.isEmpty {
            result = result.filter { entry in
                entry.app.currentName.localizedCaseInsensitiveContains(searchText)
                    || (entry.app.currentDescription?.localizedCaseInsensitiveContains(searchText) ?? false)
                    || (entry.app.developer?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        switch sortOption {
        case .recommended:
            break
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
        HStack {
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


}


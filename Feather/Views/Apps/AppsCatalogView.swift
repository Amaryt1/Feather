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
            // In Arabic text the conjunction "و" is attached to the next word.
            // Separate it when preceded by a space so category labels still match.
            .replacingOccurrences(of: " و", with: " ")
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
            "clash royale", "clash royal", "subway surfers", "sabway surfers", "brawl stars", "stardew valley",
            "pokemon", "genshin impact", "honkai", "mobile legends",
            "league of legends", "wild rift", "asphalt", "need for speed",
            "efootball", "fifa mobile", "fifa 23", "fifa 24", "fifa 25", "fifa 26",
            "fc mobile", "fc 24", "fc 25", "fc 26", "ea sports fc", "dream league soccer",
            "football manager", "nba 2k", "madden nfl", "mlb the show", "f1 mobile racing",
            "real racing", "monopoly", "angry birds", "fruit ninja", "temple run",
            "hill climb", "shadow fight", "geometry dash", "plants vs zombies",
            "mortal kombat", "tekken", "street fighter", "terraria", "dead cells",
            "the sims", "simcity", "hay day", "stumble guys", "fall guys",
            "ludo", "chess", "candy crush", "homescapes", "royal match",
            "arena of valor", "brawlhalla", "لعبة", "العاب"
        ]) || named(["game", "games", "gaming"]) || categorized([
            "games", "game", "gaming", "arcade", "arcade games", "puzzle games", "العاب", "لعبه",
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
            "netflix", "youtube", "spotify", "twitch", "vlc", "soundcloud", "org 24", "org 2024",
            "iptv", "crunchyroll", "disney plus", "prime video", "apple music",
            "apple tv", "plex", "kodi", "podcast", "video player", "movie player",
            "djay", "moviespirit"
        ]) {
            return .media
        }
        if named([
            "capcut", "picsart", "canva", "alight motion", "video star",
            "kinemaster", "imovie", "lightroom", "photoshop", "procreate", "ibis paint",
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
            "google fit", "apple health", "samsung health", "fitbod", "strong workout",
            "nike run club", "myfitnesspal", "fitbit", "nike training club",
            "apple fitness", "strava", "headspace", "sleep cycle", "calm", "medisafe", "ada health"
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
            "nba", "nfl", "ufc", "cricbuzz", "wimbledon",
            "sports", "sport", "fifa", "motogp", "premier league", "football scores", "soccer", "basketball",
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
            "calculator", "file manager", "scanner", "qr scanner", "speed test", "ispoofer", "ipogo",
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
        if categorized(["health", "health fitness", "health and fitness", "fitness", "medical", "medicine", "الصحة", "الصحه", "الصحة واللياقة", "الصحه واللياقه", "لياقة", "لياقه"]) {
            return .health
        }
        if categorized(["sports", "sport", "sports recreation", "sports and recreation", "الرياضة", "الرياضه", "رياضة", "رياضه"]) {
            return .sports
        }
        if categorized(["news", "news magazines", "news and magazines", "magazines newspapers", "magazines and newspapers", "الأخبار", "الاخبار", "أخبار", "اخبار", "مجلات", "صحف"]) {
            return .news
        }
        if categorized(["lifestyle", "life style", "نمط الحياة", "نمط الحياه", "اسلوب الحياة", "اسلوب الحياه"]) {
            return .lifestyle
        }
        if categorized(["graphics design", "graphics and design", "graphic design", "design", "photo video", "photo and video", "التصميم", "تصميم"]) {
            return .design
        }
        if categorized(["photography", "camera", "التصوير", "تصوير", "كاميرا"]) {
            return .photography
        }
        if categorized(["entertainment", "music", "video", "media", "streaming"]) {
            return .media
        }
        if categorized(["social", "social networking", "communication", "messaging", "التواصل الاجتماعي", "تواصل اجتماعي", "مراسلة"]) {
            return .social
        }
        if categorized(["finance", "banking", "financial", "المال", "التمويل", "مصارف", "مصرف"]) {
            return .finance
        }
        if categorized(["productivity", "business", "office", "الإنتاجية", "الانتاجية", "الأعمال", "الاعمال"]) {
            return .productivity
        }
        if categorized(["developer", "developer tools", "development", "programming", "البرمجة", "برمجة", "مطورين"]) {
            return .developer
        }
        if categorized(["signing", "sideloading", "التوقيع", "تثبيت ipa", "شهادات"]) {
            return .signing
        }
        if categorized(["jailbreak", "tweaks", "جيلبريك", "تويكات", "تويك"]) {
            return .jailbreak
        }
        if categorized(["customization", "themes", "personalization", "التخصيص", "ثيمات", "خلفيات"]) {
            return .customization
        }
        if categorized(["ai", "artificial intelligence", "machine learning", "الذكاء الاصطناعي", "ذكاء اصطناعي"]) {
            return .ai
        }
        if categorized(["education", "reference", "books", "التعليم", "تعليم", "دراسة"]) {
            return .education
        }
        if categorized(["shopping", "retail", "e commerce", "التسوق", "تسوق"]) {
            return .shopping
        }
        if categorized(["travel", "travel navigation", "السفر", "رحلات"]) {
            return .travel
        }
        if categorized(["navigation", "maps", "الملاحة", "خرائط"]) {
            return .navigation
        }
        if categorized(["food", "food drink", "food and drink", "food dining", "الطعام", "الطبخ", "وصفات", "مطاعم"]) {
            return .food
        }
        if categorized(["utilities", "utility", "tools", "أدوات", "ادوات", "خدمات"]) {
            return .utilities
        }

        // A short title or subtitle can supply a clear purpose when a feed omits
        // its category. These are specific phrases, not loose keyword fragments.
        if titled([
            "health and fitness", "fitness tracker", "workout tracker", "workout app",
            "gym training", "medical app", "mental health", "health app"
        ]) {
            return .health
        }
        if titled([
            "live sports scores", "sports scores", "football scores", "match schedule",
            "match results", "league table", "sports news", "soccer", "basketball",
            "tennis", "cricket", "rugby"
        ]) {
            return .sports
        }
        if titled([
            "breaking news", "news reader", "news app", "world news", "daily news",
            "newspaper", "magazine", "أخبار عاجلة", "نشرة الأخبار"
        ]) {
            return .news
        }
        if titled([
            "streaming app", "video player", "movie player", "music player",
            "music streaming", "video streaming", "podcast player", "iptv player"
        ]) {
            return .media
        }
        if titled([
            "photo editor", "video editor", "graphic design", "drawing app",
            "image editor", "animation editor"
        ]) {
            return .design
        }
        if titled([
            "camera app", "camera controls", "photography app", "raw camera"
        ]) {
            return .photography
        }
        if titled([
            "social network", "messaging app", "chat messenger", "social media"
        ]) {
            return .social
        }
        if titled([
            "language learning", "online courses", "learning app", "education app"
        ]) {
            return .education
        }
        if titled([
            "task manager", "to do list", "note taking", "calendar app",
            "office suite", "pdf editor"
        ]) {
            return .productivity
        }
        if titled([
            "code editor", "developer tools", "programming", "terminal emulator"
        ]) {
            return .developer
        }
        if titled([
            "banking app", "personal finance", "payment wallet", "budget tracker"
        ]) {
            return .finance
        }
        if titled([
            "online shopping", "shopping app", "e commerce", "marketplace"
        ]) {
            return .shopping
        }
        if titled([
            "flight booking", "hotel booking", "travel guide", "trip planner"
        ]) {
            return .travel
        }
        if titled([
            "maps and navigation", "gps navigation", "navigation app", "map app"
        ]) {
            return .navigation
        }
        if titled([
            "home design", "home decor", "pet care", "parenting", "lifestyle app",
            "personal journal", "habit tracker"
        ]) {
            return .lifestyle
        }
        if titled([
            "food delivery", "recipe app", "cooking recipes", "food and drink"
        ]) {
            return .food
        }
        if titled([
            "file manager", "document scanner", "qr code scanner", "speed test",
            "weather forecast", "calculator app", "password manager", "vpn"
        ]) {
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
    @State private var isDownloadsPresented = false
    @State private var isRecentUpdatesPresented = false

    // Build the catalog index once when repositories change. Rebuilding this
    // 27k-app index from body-computed properties made every category redraw
    // repeatedly scan the entire catalog.
    @State private var catalogEntries: [AppsCatalogEntry] = []
    @State private var entriesByCategory: [AppsCatalogCategory: [AppsCatalogEntry]] = [:]
    @State private var categoryCounts: [AppsCatalogCategory: Int] = [:]
    @State private var recentlyUpdatedEntries: [AppsCatalogEntry] = []

    private var entries: [AppsCatalogEntry] { catalogEntries }

    /// Build the seven-day shelf only when the catalog index changes, not on every
    /// SwiftUI body refresh, so large catalogs remain responsive.
    private static func recentUpdates(in entries: [AppsCatalogEntry], now: Date = Date()) -> [AppsCatalogEntry] {
        let cutoff = now.addingTimeInterval(-7 * 24 * 60 * 60)
        return entries
            .filter { entry in
                guard let updatedAt = entry.app.currentDate?.date else { return false }
                return updatedAt >= cutoff && updatedAt <= now
            }
            .sorted {
                ($0.app.currentDate?.date ?? .distantPast) > ($1.app.currentDate?.date ?? .distantPast)
            }
    }

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
        recentlyUpdatedEntries = Self.recentUpdates(in: index.entries)
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
        recentlyUpdatedEntries = Self.recentUpdates(in: index.entries)
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
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 158), spacing: 12)], spacing: 14) {
                            ForEach(filteredEntries) { entry in
                                AppsCatalogPremiumCard(entry: entry) {
                                    selectedRoute = SourceAppsView.SourceAppRoute(
                                        sourceURL: entry.sourceURL, source: entry.source, app: entry.app
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.top, 8)
                        .padding(.bottom, 24)
                    }
                    .refreshable {
                        await loadPrivateFeeds(force: true)
                    }
                    .overlay(alignment: .top) {
                        Text("\(filteredEntries.count) تطبيق")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial, in: Capsule())
                            .padding(.top, 4)
                            .allowsHitTesting(false)
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

                    Button { isRecentUpdatesPresented = true } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .overlay(alignment: .topTrailing) {
                                if !recentlyUpdatedEntries.isEmpty {
                                    Text(recentlyUpdatedEntries.count > 99 ? "99+" : "\(recentlyUpdatedEntries.count)")
                                        .font(.system(size: 9, weight: .bold, design: .rounded))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 4)
                                        .frame(minWidth: 16, minHeight: 16)
                                        .background(Color.red.gradient, in: Capsule())
                                        .offset(x: 9, y: -8)
                                        .accessibilityHidden(true)
                                }
                            }
                    }
                    .accessibilityLabel("التحديثات الأخيرة، \(recentlyUpdatedEntries.count) تطبيق")

                }
            }
            .sheet(isPresented: $isDownloadsPresented) {
                AppsCatalogDownloadsView()
            }
            .sheet(isPresented: $isRecentUpdatesPresented) {
                AppsCatalogRecentUpdatesView(entries: recentlyUpdatedEntries) { entry in
                    selectedRoute = SourceAppsView.SourceAppRoute(
                        sourceURL: entry.sourceURL, source: entry.source, app: entry.app
                    )
                    isRecentUpdatesPresented = false
                }
            }
            .navigationDestinationIfAvailable(item: $selectedRoute) { route in
                SourceAppsDetailView(sourceURL: route.sourceURL, source: route.source, app: route.app)
            }
        }
        .task {
            _ = AppsCatalogPersonalization.shared
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

}

private struct AppsCatalogRecentUpdatesView: View {
    let entries: [AppsCatalogEntry]
    let open: (AppsCatalogEntry) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "checkmark.seal")
                            .font(.system(size: 36))
                            .foregroundStyle(.secondary)
                        Text("لا توجد تحديثات حديثة")
                            .font(.headline)
                        Text("ستظهر هنا التطبيقات التي نُشرت تحديثاتها خلال آخر 7 أيام.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            ForEach(entries) { entry in
                                VStack(alignment: .leading, spacing: 7) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "clock")
                                            .font(.caption2)
                                        if let date = entry.app.currentDate?.date {
                                            Text("تم التحديث \(date.formatted(date: .abbreviated, time: .omitted))")
                                                .font(.caption.weight(.medium))
                                        } else {
                                            Text("تحديث حديث")
                                                .font(.caption.weight(.medium))
                                        }
                                        Spacer()
                                        Text(entry.app.currentVersion.map { "v\($0)" } ?? "")
                                            .font(.caption2.monospaced())
                                            .foregroundStyle(.secondary)
                                    }
                                    .foregroundStyle(.secondary)
                                    AppsCatalogPremiumCard(entry: entry) {
                                        open(entry)
                                    }
                                }
                            }
                        }
                        .padding(14)
                    }
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("التحديثات الأخيرة")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("تم") { dismiss() }
                }
            }
        }
    }
}

private struct AppsCatalogPremiumCard: View {
    let entry: AppsCatalogEntry
    let open: () -> Void

    @GestureState private var dragOffset: CGSize = .zero
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var tiltX: Double { reduceMotion ? 0 : Double(-dragOffset.height / 18) }
    private var tiltY: Double { reduceMotion ? 0 : Double(dragOffset.width / 18) }

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            Button(action: open) {
                VStack(alignment: .leading, spacing: 10) {
                    ZStack(alignment: .topTrailing) {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.accentColor.opacity(0.22), Color(uiColor: .secondarySystemBackground)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        LazyImage(url: entry.app.iconURL) { state in
                            if let image = state.image {
                                image.resizable().aspectRatio(contentMode: .fill)
                            } else {
                                Image("App_Unknown").resizable().aspectRatio(contentMode: .fit).padding(18)
                            }
                        }
                        .frame(width: 76, height: 76)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(14)

                        Image(systemName: "arrow.up.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                            .padding(9)
                            .background(.thinMaterial, in: Circle())
                            .padding(9)
                    }
                    .frame(height: 126)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.app.currentName)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text(entry.app.currentDescription ?? "تطبيق")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .frame(height: 34, alignment: .topLeading)
                        Text(entry.category.title)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
            .buttonStyle(.plain)

            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(entry.app.currentVersion.map { "v\($0)" } ?? "Feather Store")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 2)
                DownloadButtonView(sourceURL: entry.sourceURL, source: entry.source, app: entry.app)
                    .scaleEffect(0.92)
            }
        }
        .padding(11)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.regularMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
                }
        }
        .shadow(color: Color.black.opacity(0.07), radius: 14, y: 7)
        .rotation3DEffect(.degrees(tiltY), axis: (x: 0, y: 1, z: 0), perspective: 0.72)
        .rotation3DEffect(.degrees(tiltX), axis: (x: 1, y: 0, z: 0), perspective: 0.72)
        .scaleEffect(dragOffset == .zero ? 1 : 1.025)
        .animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.72), value: dragOffset)
        .simultaneousGesture(
            DragGesture(minimumDistance: 8)
                .updating($dragOffset) { value, state, _ in
                    state = CGSize(
                        width: max(-18, min(18, value.translation.width / 3)),
                        height: max(-18, min(18, value.translation.height / 3))
                    )
                }
        )
        .accessibilityElement(children: .contain)
    }
}


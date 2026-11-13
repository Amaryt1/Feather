import SwiftUI
import CryptoKit
import AltSourceKit
import NimbleViews
import NimbleJSON
import NukeUI
import SWCompression

private enum AppsCatalogCategory: String, CaseIterable, Identifiable, Codable, Sendable {
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
    var id: String {
        "\(sourceURL?.absoluteString ?? "")|\(app.currentUniqueId)|\(app.currentName)|\(app.currentVersion ?? "")|\(app.currentDownloadUrl?.absoluteString ?? "")"
    }
}

private struct AppsCatalogIndex: Codable, Sendable {
    let repositories: [SourceAppsView.SourceRepositoryContext]
    let entries: [AppsCatalogEntry]
    let entriesByCategory: [AppsCatalogCategory: [AppsCatalogEntry]]
    let categoryCounts: [AppsCatalogCategory: Int]

    private struct EntryReference: Codable {
        let sourceIndex: Int
        let appIndex: Int
        let category: AppsCatalogCategory
    }

    private enum CodingKeys: String, CodingKey {
        case repositories, entryReferences
    }

    init(
        repositories: [SourceAppsView.SourceRepositoryContext],
        entries: [AppsCatalogEntry],
        entriesByCategory: [AppsCatalogCategory: [AppsCatalogEntry]],
        categoryCounts: [AppsCatalogCategory: Int]
    ) {
        self.repositories = repositories
        self.entries = entries
        self.entriesByCategory = entriesByCategory
        self.categoryCounts = categoryCounts
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        repositories = try container.decode([SourceAppsView.SourceRepositoryContext].self, forKey: .repositories)
        let references = try container.decode([EntryReference].self, forKey: .entryReferences)
        var restored: [AppsCatalogEntry] = []
        restored.reserveCapacity(references.count)
        var buckets: [AppsCatalogCategory: [AppsCatalogEntry]] = [:]
        var counts: [AppsCatalogCategory: Int] = [:]
        for reference in references {
            guard repositories.indices.contains(reference.sourceIndex) else { continue }
            let context = repositories[reference.sourceIndex]
            guard context.repository.apps.indices.contains(reference.appIndex) else { continue }
            let entry = AppsCatalogEntry(
                sourceURL: context.sourceURL,
                source: context.repository,
                app: context.repository.apps[reference.appIndex],
                category: reference.category
            )
            restored.append(entry)
            buckets[reference.category, default: []].append(entry)
            counts[reference.category, default: 0] += 1
        }
        entries = restored
        entriesByCategory = buckets
        categoryCounts = counts
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(repositories, forKey: .repositories)

        var sourceIndices: [String: Int] = [:]
        var appIndices: [[String: Int]] = []
        for (sourceIndex, context) in repositories.enumerated() {
            if let url = context.sourceURL {
                sourceIndices[url.absoluteString] = sourceIndex
            }
            var indices: [String: Int] = [:]
            for (appIndex, app) in context.repository.apps.enumerated() {
                indices[app.currentUniqueId] = appIndex
            }
            appIndices.append(indices)
        }

        var references: [EntryReference] = []
        references.reserveCapacity(entries.count)
        for entry in entries {
            guard let sourceURL = entry.sourceURL?.absoluteString,
                  let sourceIndex = sourceIndices[sourceURL],
                  let appIndex = appIndices[sourceIndex][entry.app.currentUniqueId] else { continue }
            references.append(EntryReference(
                sourceIndex: sourceIndex,
                appIndex: appIndex,
                category: entry.category
            ))
        }
        try container.encode(references, forKey: .entryReferences)
    }

    private static func cacheIdentity(sourceURL: URL?, app: ASRepository.App) -> String {
        "\(sourceURL?.absoluteString ?? "")|\(app.currentUniqueId)|\(app.currentName)|\(app.currentVersion ?? "")|\(app.currentDownloadUrl?.absoluteString ?? "")"
    }

    static func build(
        from repositories: [SourceAppsView.SourceRepositoryContext],
        cachedCategories: [String: String] = [:]
    ) -> AppsCatalogIndex {
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
                let version = (app.currentVersion ?? "").lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                let downloadIdentity = downloadURL.absoluteString
                let identity = bundle.isEmpty
                    ? "name|\(normalizedName)|developer|\(developer)|version|\(version)|url|\(downloadIdentity)"
                    : "bundle|\(bundle)|name|\(normalizedName)|version|\(version)|url|\(downloadIdentity)"
                guard seen.insert(identity).inserted else { continue }

                let category = cachedCategories[cacheIdentity(sourceURL: context.sourceURL, app: app)]
                    .flatMap(AppsCatalogCategory.init(rawValue:)) ?? AppsCatalogCategory.classify(app)
                entries.append(.init(sourceURL: context.sourceURL, source: context.repository,
                                     app: app, category: category))
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

private struct PrivateAppsCatalogManifest: Codable, Sendable {
    let schemaVersion: Int
    let generatedAt: String
    let catalogURL: URL
    let sha256: String
    let compressedBytes: Int
    let uncompressedBytes: Int
    let sourceCount: Int
    let appCount: Int
}

private struct PrivateAppsCatalogSource: Decodable {
    let sourceURL: URL
    let repository: ASRepository
}

private struct PrivateAppsCatalogPayload: Decodable {
    let schemaVersion: Int
    let sources: [PrivateAppsCatalogSource]
}

private struct PrivateAppsCatalogIndexCache: Codable {
    let schemaVersion: Int
    let sha256: String
    let categories: [String: String]
    let index: AppsCatalogIndex?
}

@MainActor
private final class AppsCatalogMemoryCache {
    static let shared = AppsCatalogMemoryCache()

    private(set) var sha256: String?
    private(set) var index: AppsCatalogIndex?

    func snapshot() -> (sha256: String?, index: AppsCatalogIndex)? {
        guard let index else { return nil }
        return (sha256, index)
    }

    func store(_ index: AppsCatalogIndex, sha256: String?) {
        self.index = index
        self.sha256 = sha256
    }
}


@MainActor
struct AppsCatalogView: View {
    // These repositories are intentionally fetched internally and never added to the visible Sources list.
    nonisolated private static let privateFeedURLs: [URL] = [
        URL(string: "https://ipaomtk-source.shrubhub.workers.dev/ipaomtk.json")!,
        URL(string: "https://iosvizor-source.shrubhub.workers.dev/iosvizor.json")!,
        URL(string: "https://raw.githubusercontent.com/RipeStore/altmaker/main/AltMaker.json")!,
        URL(string: "https://ittza7aa.com/repo.json")!
    ]
    nonisolated private static let privateCatalogManifestURL = URL(
        string: "https://raw.githubusercontent.com/Amaryt1/Feather/main/catalogs/private-apps/manifest.json"
    )!

    nonisolated private static var privateCatalogCacheDirectory: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("FeatherPrivateAppsCatalog", isDirectory: true)
    }

    nonisolated private static var cachedCatalogURL: URL? {
        privateCatalogCacheDirectory?.appendingPathComponent("catalog.json.gz")
    }

    nonisolated private static var cachedManifestURL: URL? {
        privateCatalogCacheDirectory?.appendingPathComponent("manifest.json")
    }

    nonisolated private static var cachedIndexURL: URL? {
        privateCatalogCacheDirectory?.appendingPathComponent("catalog-index.json")
    }

    private static func readCachedIndex(sha256: String?) async -> AppsCatalogIndex? {
        guard let sha256, let url = cachedIndexURL else { return nil }
        return await Task.detached(priority: .userInitiated) {
            guard let data = try? Data(contentsOf: url),
                  let cache = try? JSONDecoder().decode(PrivateAppsCatalogIndexCache.self, from: data),
                  cache.schemaVersion == 2, cache.sha256 == sha256,
                  let index = cache.index, !index.entries.isEmpty else { return nil }
            return index
        }.value
    }

    private static func saveCatalogIndex(_ index: AppsCatalogIndex, sha256: String?) async {
        guard let sha256, let url = cachedIndexURL else { return }
        await Task.detached(priority: .utility) {
            var categories: [String: String] = [:]
            categories.reserveCapacity(index.entries.count)
            for entry in index.entries { categories[entry.id] = entry.category.rawValue }
            let cache = PrivateAppsCatalogIndexCache(schemaVersion: 2, sha256: sha256, categories: categories, index: index)
            guard let data = try? JSONEncoder().encode(cache) else { return }
            try? data.write(to: url, options: .atomic)
        }.value
    }

    nonisolated private static func readBundledPrivateCatalogManifest() -> PrivateAppsCatalogManifest? {
        guard let url = Bundle.main.url(forResource: "PrivateAppsCatalogSeedManifest", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let manifest = try? JSONDecoder().decode(PrivateAppsCatalogManifest.self, from: data),
              manifest.schemaVersion == 1, manifest.sourceCount == privateFeedURLs.count,
              manifest.appCount > 0, manifest.sha256.count == 64 else { return nil }
        return manifest
    }

    nonisolated private static func readCachedManifest() -> PrivateAppsCatalogManifest? {
        guard let url = cachedManifestURL,
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(PrivateAppsCatalogManifest.self, from: data)
    }

    nonisolated private static func readCachedCatalogData() -> Data? {
        guard let url = cachedCatalogURL else { return nil }
        return try? Data(contentsOf: url)
    }

    private static func readCachedCatalogFiles() async -> (PrivateAppsCatalogManifest, Data)? {
        await Task.detached(priority: .utility) { () -> (PrivateAppsCatalogManifest, Data)? in
            guard let manifest = AppsCatalogView.readCachedManifest(),
                  manifest.schemaVersion == 1,
                  manifest.sourceCount == AppsCatalogView.privateFeedURLs.count,
                  let data = AppsCatalogView.readCachedCatalogData() else { return nil }
            return (manifest, data)
        }.value
    }

    private static func saveCatalog(_ data: Data, manifest: PrivateAppsCatalogManifest) async {
        await Task.detached(priority: .utility) {
            guard let directory = AppsCatalogView.privateCatalogCacheDirectory,
                  let catalogURL = AppsCatalogView.cachedCatalogURL,
                  let manifestURL = AppsCatalogView.cachedManifestURL else { return }

            do {
                try FileManager.default.createDirectory(
                    at: directory,
                    withIntermediateDirectories: true
                )
                try data.write(to: catalogURL, options: .atomic)
                let manifestData = try JSONEncoder().encode(manifest)
                try manifestData.write(to: manifestURL, options: .atomic)
            } catch {
                // The in-memory catalog remains usable if the optional disk cache fails.
            }
        }.value
    }

    private static func catalogContexts(
        from compressedData: Data,
        expectedSHA256: String
    ) async -> [SourceAppsView.SourceRepositoryContext]? {
        await Task.detached(priority: .userInitiated) { () -> [SourceAppsView.SourceRepositoryContext]? in
            let actualSHA256 = SHA256.hash(data: compressedData)
                .map { String(format: "%02x", $0) }
                .joined()
            guard actualSHA256.caseInsensitiveCompare(expectedSHA256) == .orderedSame,
                  let jsonData = try? GzipArchive.unarchive(archive: compressedData),
                  let payload = try? JSONDecoder().decode(PrivateAppsCatalogPayload.self, from: jsonData),
                  payload.schemaVersion == 1,
                  payload.sources.count == AppsCatalogView.privateFeedURLs.count,
                  !payload.sources.isEmpty,
                  payload.sources.allSatisfy({ !$0.repository.apps.isEmpty }) else {
                return nil
            }

            let expectedURLs = Set(AppsCatalogView.privateFeedURLs.map(\.absoluteString))
            let receivedURLs = Set(payload.sources.map { $0.sourceURL.absoluteString })
            guard expectedURLs == receivedURLs else { return nil }

            return payload.sources.map {
                SourceAppsView.SourceRepositoryContext(
                    sourceURL: $0.sourceURL,
                    repository: $0.repository
                )
            }
        }.value
    }

    nonisolated private static func readBundledPrivateCatalogFiles() async -> (PrivateAppsCatalogManifest, Data)? {
        await Task.detached(priority: .utility) {
            guard
                let manifestURL = Bundle.main.url(
                    forResource: "PrivateAppsCatalogSeedManifest",
                    withExtension: "json"
                ),
                let manifestData = try? Data(contentsOf: manifestURL),
                let manifest = try? JSONDecoder().decode(
                    PrivateAppsCatalogManifest.self,
                    from: manifestData
                ),
                manifest.schemaVersion == 1,
                manifest.sourceCount == AppsCatalogView.privateFeedURLs.count,
                manifest.appCount > 0,
                manifest.compressedBytes > 0,
                manifest.uncompressedBytes > 0,
                manifest.sha256.count == 64,
                manifest.catalogURL.scheme?.lowercased() == "https",
                manifest.catalogURL.host == "raw.githubusercontent.com",
                manifest.catalogURL.path == "/Amaryt1/Feather/main/catalogs/private-apps/catalog.json.gz",
                let catalogURL = Bundle.main.url(
                    forResource: "PrivateAppsCatalogSeed",
                    withExtension: "json.gz"
                ),
                let compressedData = try? Data(contentsOf: catalogURL),
                compressedData.count == manifest.compressedBytes
            else {
                return nil
            }

            let digest = SHA256.hash(data: compressedData)
                .map { String(format: "%02x", $0) }
                .joined()
            guard digest.caseInsensitiveCompare(manifest.sha256) == .orderedSame else {
                return nil
            }

            return (manifest, compressedData)
        }.value
    }

    private static func loadBundledPrivateCatalog() async -> (
        sha256: String,
        contexts: [SourceAppsView.SourceRepositoryContext]
    )? {
        guard
            let (manifest, data) = await readBundledPrivateCatalogFiles(),
            let contexts = await catalogContexts(
                from: data,
                expectedSHA256: manifest.sha256
            )
        else {
            return nil
        }

        return (manifest.sha256, contexts)
    }

    private static func loadCachedPrivateCatalog() async -> (sha256: String, contexts: [SourceAppsView.SourceRepositoryContext])? {
        guard let (manifest, data) = await readCachedCatalogFiles(),
              let contexts = await catalogContexts(from: data, expectedSHA256: manifest.sha256) else {
            return nil
        }
        return (manifest.sha256, contexts)
    }

    private static func fetchPrivateCatalogManifest() async -> PrivateAppsCatalogManifest? {
        var request = URLRequest(
            url: privateCatalogManifestURL,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: 30
        )
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode) else { return nil }

            let manifest = try JSONDecoder().decode(PrivateAppsCatalogManifest.self, from: data)
            guard manifest.schemaVersion == 1,
                  manifest.sourceCount == AppsCatalogView.privateFeedURLs.count,
                  manifest.appCount > 0,
                  manifest.sha256.count == 64,
                  manifest.catalogURL.scheme?.lowercased() == "https",
                  manifest.catalogURL.host == "raw.githubusercontent.com",
                  manifest.catalogURL.path == "/Amaryt1/Feather/main/catalogs/private-apps/catalog.json.gz" else {
                return nil
            }
            return manifest
        } catch {
            return nil
        }
    }

    private static func fetchPrebuiltPrivateCatalog(
        manifest suppliedManifest: PrivateAppsCatalogManifest? = nil
    ) async -> (sha256: String, contexts: [SourceAppsView.SourceRepositoryContext])? {
        let manifest: PrivateAppsCatalogManifest
        if let suppliedManifest {
            manifest = suppliedManifest
        } else {
            guard let fetchedManifest = await fetchPrivateCatalogManifest() else { return nil }
            manifest = fetchedManifest
        }

        if let (cachedManifest, cachedData) = await readCachedCatalogFiles(),
           cachedManifest.sha256 == manifest.sha256,
           let cachedContexts = await catalogContexts(
                from: cachedData,
                expectedSHA256: manifest.sha256
           ) {
            return (manifest.sha256, cachedContexts)
        }

        do {
            var catalogComponents = URLComponents(url: manifest.catalogURL, resolvingAgainstBaseURL: false)
            var catalogQueryItems = catalogComponents?.queryItems ?? []
            catalogQueryItems.append(URLQueryItem(name: "v", value: manifest.sha256))
            catalogComponents?.queryItems = catalogQueryItems
            let downloadURL = catalogComponents?.url ?? manifest.catalogURL
            var request = URLRequest(url: downloadURL, timeoutInterval: 180)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.setValue("Feather-PrivateAppsCatalog/1.0", forHTTPHeaderField: "User-Agent")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode),
                  let contexts = await catalogContexts(
                    from: data,
                    expectedSHA256: manifest.sha256
                  ) else {
                return nil
            }
            await saveCatalog(data, manifest: manifest)
            return (manifest.sha256, contexts)
        } catch {
            return nil
        }
    }

    @State private var repositories: [SourceAppsView.SourceRepositoryContext] = AppsCatalogMemoryCache.shared.index?.repositories ?? []
    @State private var selectedCategory: AppsCatalogCategory = .all
    @State private var searchText = ""
    @State private var selectedRoute: SourceAppsView.SourceAppRoute?
    @State private var isLoading = AppsCatalogMemoryCache.shared.index == nil
    @State private var hasLoaded = AppsCatalogMemoryCache.shared.index != nil
    @State private var sortOption: AppsCatalogSort = .recommended
    @State private var isDownloadsPresented = false
    @State private var isRecentUpdatesPresented = false

    // Build the catalog index once when repositories change. Rebuilding this
    // 27k-app index from body-computed properties made every category redraw
    // repeatedly scan the entire catalog.
    @State private var catalogEntries: [AppsCatalogEntry] = AppsCatalogMemoryCache.shared.index?.entries ?? []
    @State private var entriesByCategory: [AppsCatalogCategory: [AppsCatalogEntry]] = AppsCatalogMemoryCache.shared.index?.entriesByCategory ?? [:]
    @State private var categoryCounts: [AppsCatalogCategory: Int] = AppsCatalogMemoryCache.shared.index?.categoryCounts ?? [:]
    @State private var recentlyUpdatedEntries: [AppsCatalogEntry] = AppsCatalogMemoryCache.shared.index.map { Self.recentUpdates(in: $0.entries) } ?? []

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

        // Reuse the already-decoded and indexed catalog when this view is recreated.
        // This is the fast path for every subsequent visit during the app session.
        if let cached = AppsCatalogMemoryCache.shared.snapshot() {
            apply(cached.index)
            hasLoaded = true
            isLoading = false
            if force {
                await refreshPrivateCatalogInBackground()
            } else {
                Task { await refreshPrivateCatalogInBackground() }
            }
            return
        }

        // Restore the ready index before reading, hashing or decompressing the feed.
        if let manifest = await Self.readCachedManifest() ?? Self.readBundledPrivateCatalogManifest(),
           let cachedIndex = await Self.readCachedIndex(sha256: manifest.sha256) {
            AppsCatalogMemoryCache.shared.store(cachedIndex, sha256: manifest.sha256)
            apply(cachedIndex)
            hasLoaded = true
            isLoading = false
            Task { await refreshPrivateCatalogInBackground() }
            return
        }

        // First launch or invalid cache: parse the verified catalog and build its index.
        if let cached = await Self.loadCachedPrivateCatalog() {
            await applyRepositories(cached.contexts, sha256: cached.sha256)
            hasLoaded = true
            isLoading = false
            if force {
                await refreshPrivateCatalogInBackground()
            } else {
                Task { await refreshPrivateCatalogInBackground() }
            }
            return
        }

        // A fresh installation already contains a verified four-feed snapshot
        // inside the IPA. Use it before any network request so the store can work
        // on first launch and while offline; only the lightweight freshness check
        // and any changed snapshot are fetched in the background.
        if let bundled = await Self.loadBundledPrivateCatalog() {
            await applyRepositories(bundled.contexts, sha256: bundled.sha256)
            hasLoaded = true
            isLoading = false
            if force {
                await refreshPrivateCatalogInBackground()
            } else {
                Task { await refreshPrivateCatalogInBackground() }
            }
            return
        }

        isLoading = repositories.isEmpty

        // First install or an explicit refresh: prefer the generated snapshot.
        if let prebuilt = await Self.fetchPrebuiltPrivateCatalog() {
            await applyRepositories(prebuilt.contexts, sha256: prebuilt.sha256)
            hasLoaded = true
            isLoading = false
            return
        }

        // Compatibility fallback: if the generated catalog is not published or
        // temporarily unreachable, retain the existing four-feed loading path.
        guard !hasLoaded else {
            isLoading = false
            return
        }

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

        await applyRepositories(loadedContexts, sha256: nil)
        hasLoaded = true
        isLoading = false
    }

    @MainActor
    private func applyRepositories(
        _ contexts: [SourceAppsView.SourceRepositoryContext],
        sha256: String?
    ) async {
        let index = await Task.detached(priority: .userInitiated) {
            AppsCatalogIndex.build(from: contexts)
        }.value

        // Publish the ready catalog before doing any optional cache maintenance.
        // Rewriting the full category map (thousands of entries) on every cold
        // launch was delaying the first visible apps even when the map was valid.
        AppsCatalogMemoryCache.shared.store(index, sha256: sha256)
        apply(index)

        // Persist the complete ready index after publishing it. Atomic replacement
        // preserves the last valid snapshot if a write is interrupted.
        if let sha256 {
            Task { await Self.saveCatalogIndex(index, sha256: sha256) }
        }
    }

    @MainActor
    private func refreshPrivateCatalogInBackground() async {
        guard let manifest = await Self.fetchPrivateCatalogManifest() else { return }

        // An unchanged manifest means the current in-memory index is already valid.
        // Do not decompress, decode, classify, sort, or rebuild the same catalog.
        if let cached = AppsCatalogMemoryCache.shared.snapshot(),
           cached.sha256 == manifest.sha256 {
            return
        }

        guard let refreshed = await Self.fetchPrebuiltPrivateCatalog(manifest: manifest) else { return }
        await applyRepositories(refreshed.contexts, sha256: refreshed.sha256)
        hasLoaded = true
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


import SwiftUI
import AltSourceKit
import NimbleViews
import NimbleJSON
import NukeUI

private enum AppsCatalogCategory: String, CaseIterable, Identifiable {
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

private struct AppsCatalogEntry: Identifiable {
    let sourceURL: URL
    let source: ASRepository
    let app: ASRepository.App

    var id: String { "\(sourceURL.absoluteString)|\(app.currentUniqueId)" }
    var category: AppsCatalogCategory { AppsCatalogCategory.classify(app) }
}

struct AppsCatalogView: View {
    @State private var repositories: [SourceAppsView.SourceRepositoryContext] = []
    @State private var selectedCategory: AppsCatalogCategory = .all
    @State private var searchText = ""
    @State private var selectedRoute: SourceAppsView.SourceAppRoute?
    @State private var isLoading = false
    @State private var hasLoaded = false
    @State private var hadFailures = false
    private let dataService = NBFetchService()

    // These feed URLs are intentionally private to the app and are never displayed as source entries.
    private let feedURLs: [URL] = [
        URL(string: "https://fastsign.dev/repo.json")!,
        URL(string: "https://repository.apptesters.org")!,
        URL(string: "https://ipa.cypwn.xyz/cypwn.json")!
    ]

    private var entries: [AppsCatalogEntry] {
        var seen = Set<String>()
        return repositories.flatMap { context in
            context.repository.apps.compactMap { app in
                let name = app.currentName
                    .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let bundle = (app.id ?? "").lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                // Keep separately named variants even when they share a bundle identifier.
                let key = "\(bundle)|\(name)"
                guard seen.insert(key).inserted else { return nil }
                return AppsCatalogEntry(sourceURL: context.sourceURL, source: context.repository, app: app)
            }
        }
    }

    private var visibleCategories: [AppsCatalogCategory] {
        AppsCatalogCategory.allCases.filter { $0 == .all || categoryCount($0) > 0 }
    }

    private var filteredEntries: [AppsCatalogEntry] {
        entries.filter { entry in
            let categoryMatches = selectedCategory == .all || entry.category == selectedCategory
            let searchable = [entry.app.currentName, entry.app.currentDescription ?? "",
                              entry.app.developer ?? ""].joined(separator: " ")
            return categoryMatches && (searchText.isEmpty || searchable.localizedCaseInsensitiveContains(searchText))
        }
        .sorted { $0.app.currentName.localizedCaseInsensitiveCompare($1.app.currentName) == .orderedAscending }
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
            .refreshable { await loadRepositories() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if isLoading {
                        ProgressView()
                    } else {
                        Button { Task { await loadRepositories() } } label: {
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
            hasLoaded = true
            await loadRepositories()
        }
    }

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(visibleCategories) { category in
                    let selected = selectedCategory == category
                    Button {
                        withAnimation(.snappy(duration: 0.2)) { selectedCategory = category }
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
        category == .all ? entries.count : entries.filter { $0.category == category }.count
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
    private func loadRepositories() async {
        guard !isLoading else { return }
        isLoading = true
        hadFailures = false
        defer { isLoading = false }

        var loaded: [SourceAppsView.SourceRepositoryContext] = []
        for url in feedURLs {
            let repository: ASRepository? = await withCheckedContinuation { continuation in
                dataService.fetch(from: url) { (result: Result<ASRepository, Error>) in
                    switch result {
                    case .success(let value): continuation.resume(returning: value)
                    case .failure: continuation.resume(returning: nil)
                    }
                }
            }
            if let repository {
                loaded.append(SourceAppsView.SourceRepositoryContext(sourceURL: url, repository: repository))
            } else {
                hadFailures = true
            }
        }
        repositories = loaded
    }
}

//
//  AppsCatalogView.swift
//  Feather
//
//  Curated app catalogue backed by bundled AltStore-compatible sources.
//

import SwiftUI
import AltSourceKit
import NimbleViews
import NimbleJSON
import NukeUI

private struct AppsCatalogSource {
    let name: String
    let url: URL
}

private struct AppsCatalogEntry: Identifiable {
    let sourceURL: URL?
    let source: ASRepository
    let app: ASRepository.App

    var id: String {
        "\(sourceURL?.absoluteString ?? source.name ?? "catalog").\(app.currentUniqueId)"
    }

    var isFeatured: Bool {
        app.category?.lowercased() == "featured"
    }

    var category: AppsCatalogCategory {
        AppsCatalogCategory.classify(app)
    }
}

private enum AppsCatalogCategory: String, CaseIterable, Identifiable {
    case all
    case featured
    case games
    case emulators
    case jailbreak
    case signing
    case design
    case media
    case artificialIntelligence
    case productivity
    case developer
    case education
    case social
    case utilities
    case programs

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "الكل"
        case .featured: "المميز"
        case .games: "الألعاب"
        case .emulators: "المحاكيات"
        case .jailbreak: "الجيلبريك"
        case .signing: "التوقيع والتثبيت"
        case .design: "التصميم"
        case .media: "الأفلام والموسيقى"
        case .artificialIntelligence: "الذكاء الاصطناعي"
        case .productivity: "الإنتاجية"
        case .developer: "أدوات المطورين"
        case .education: "التعليم"
        case .social: "التواصل الاجتماعي"
        case .utilities: "الأدوات"
        case .programs: "برامج عامة"
        }
    }

    var icon: String {
        switch self {
        case .all: "square.grid.2x2"
        case .featured: "star.fill"
        case .games: "gamecontroller"
        case .emulators: "arcade.stick"
        case .jailbreak: "wrench.and.screwdriver"
        case .signing: "signature"
        case .design: "paintpalette"
        case .media: "play.rectangle"
        case .artificialIntelligence: "sparkles"
        case .productivity: "checklist"
        case .developer: "chevron.left.forwardslash.chevron.right"
        case .education: "graduationcap"
        case .social: "bubble.left.and.bubble.right"
        case .utilities: "wrench.and.screwdriver"
        case .programs: "app"
        }
    }

    static func classify(_ app: ASRepository.App) -> AppsCatalogCategory {
        let rawCategory = (app.category ?? "")
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: "_", with: "-")
            .replacingOccurrences(of: " ", with: "-")

        let text = [
            app.category,
            app.name,
            app.subtitle,
            app.description,
            app.localizedDescription,
            app.developer
        ]
        .compactMap { $0 }
        .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        .lowercased()

        func containsAny(_ words: [String]) -> Bool {
            words.contains { text.contains($0) }
        }

        // Emulators are checked before games because emulator listings often mention games.
        if containsAny([
            "emulator", "emulation", "retroarch", "ppsspp", "delta emulator",
            "nes emulator", "game boy", "playstation portable", "psp emulator",
            "stiknes", "محاكي", "محاكاة"
        ]) {
            return .emulators
        }
        if containsAny([
            "artificial intelligence", "ai assistant", "chatgpt", "openai",
            "claude", "gemini", "copilot", "stable diffusion", "large language model",
            "machine learning", "ذكاء اصطناعي"
        ]) {
            return .artificialIntelligence
        }
        if containsAny([
            "jailbreak", "trollstore", "sileo", "cydia", "zebra", "dopamine",
            "ellekit", "roothide", "bootstrap", "misaka", "serotonin", "filza",
            "tweak", "package manager", "جيلبريك", "تويك"
        ]) {
            return .jailbreak
        }
        if containsAny([
            "codesigning", "code signing", "signing app", "signer", "signing",
            "ksign", "esign", "scarlet", "feather", "sideload", "side-loading",
            "ipa installer", "ipa installer", "certificate manager",
            "توقيع", "تثبيت ipa", "شهادات"
        ]) {
            return .signing
        }
        if containsAny([
            "photo editor", "photo editing", "graphic design", "design tool",
            "drawing", "illustration", "bazaart", "procreate", "canva",
            "vector editor", "video editor", "تصميم", "تعديل الصور", "رسم"
        ]) {
            return .design
        }
        if containsAny([
            "movie", "movies", "tv series", "streaming", "iptv", "anime",
            "video player", "music player", "podcast", "cinema", "film",
            "أفلام", "مسلسلات", "انمي", "أنمي", "مشاهدة", "بث"
        ]) {
            return .media
        }
        if containsAny([
            "game", "games", "arcade", "rpg", "minecraft", "terraria",
            "fortnite", "flappy bird", "gameplay", "لعبة", "ألعاب", "العاب"
        ]) {
            return .games
        }
        if containsAny([
            "ide", "code editor", "developer tool", "development tool",
            "terminal", "git client", "ssh client", "debugger", "programming",
            "xcode", "مطور", "برمجة"
        ]) {
            return .developer
        }
        if containsAny([
            "language learning", "dictionary", "flashcards", "course",
            "learning app", "education", "school", "university", "تعليم",
            "قاموس", "تعلم", "دراسة"
        ]) {
            return .education
        }
        if containsAny([
            "productivity", "task manager", "to-do", "todo list", "notes",
            "calendar", "office suite", "document editor", "workflow",
            "إنتاجية", "مهام", "ملاحظات"
        ]) {
            return .productivity
        }
        if containsAny([
            "social network", "messenger", "chat app", "telegram", "discord",
            "reddit", "mastodon", "social media", "شبكة اجتماعية", "مراسلة"
        ]) {
            return .social
        }

        switch rawCategory {
        case "games", "game", "gaming":
            return .games
        case "graphics", "photo-video", "design", "photography":
            return .design
        case "ai", "artificial-intelligence", "machine-learning":
            return .artificialIntelligence
        case "emulator", "emulators":
            return .emulators
        case "jailbreak", "tweaks":
            return .jailbreak
        case "signing", "sideloading", "utilities-signing":
            return .signing
        case "developer", "development":
            return .developer
        case "education":
            return .education
        case "productivity":
            return .productivity
        case "entertainment", "music", "video", "photo-video":
            return .media
        case "social":
            return .social
        case "utilities", "utility", "lifestyle", "health", "business",
             "navigation", "weather", "finance", "news":
            return .utilities
        default:
            return .programs
        }
    }
}

struct AppsCatalogView: View {
    @State private var repositories: [SourceAppsView.SourceRepositoryContext] = []
    @State private var selectedCategory: AppsCatalogCategory = .all
    @State private var searchText = ""
    @State private var selectedRoute: SourceAppsView.SourceAppRoute?
    @State private var isLoading = false
    @State private var hasLoaded = false
    @State private var loadError = false
    private let dataService = NBFetchService()

    // Source endpoints are intentionally kept in app configuration and are never shown in the interface.
    // AppIraq's PHP/JSON endpoints are not added until their response schemas can be verified as AltStore-compatible.
    // browse_categories.json is category metadata, not an IPA feed. Backloop's pack.json is a discontinued certificate pack.
    private let sources: [AppsCatalogSource] = [
        AppsCatalogSource(
            name: "التطبيقات المميزة",
            url: URL(string: "https://raw.githubusercontent.com/Amaryt1/Feather/feature/apps-catalog/Feather/Resources/FeaturedApps.json")!
        ),
        AppsCatalogSource(
            name: "Ksign",
            url: URL(string: "https://raw.githubusercontent.com/Nyasami/Ksign/refs/heads/main/repo.json")!
        ),
        AppsCatalogSource(
            name: "CyPwn",
            url: URL(string: "https://ipa.cypwn.xyz/cypwn.json")!
        ),
        AppsCatalogSource(
            name: "SideStore Community",
            url: URL(string: "https://community-apps.sidestore.io/sidecommunity.json")!
        ),
        AppsCatalogSource(
            name: "LiveContainer",
            url: URL(string: "https://raw.githubusercontent.com/LiveContainer/LiveContainer/main/.github/apps.json")!
        )
    ]

    private var entries: [AppsCatalogEntry] {
        repositories.flatMap { context in
            context.repository.apps.map {
                AppsCatalogEntry(sourceURL: context.sourceURL, source: context.repository, app: $0)
            }
        }
    }

    private var filteredEntries: [AppsCatalogEntry] {
        entries.filter { entry in
            let matchesCategory: Bool
            switch selectedCategory {
            case .all:
                matchesCategory = true
            case .featured:
                matchesCategory = entry.isFeatured
            default:
                matchesCategory = entry.category == selectedCategory
            }
            let searchableText = [
                entry.app.currentName,
                entry.app.currentDescription ?? "",
                entry.app.developer ?? "",
                entry.source.name ?? ""
            ].joined(separator: " ")
            let matchesSearch = searchText.isEmpty || searchableText.localizedCaseInsensitiveContains(searchText)
            return matchesCategory && matchesSearch
        }
        .sorted { $0.app.currentName.localizedCaseInsensitiveCompare($1.app.currentName) == .orderedAscending }
    }

    var body: some View {
        NBNavigationView("التطبيقات") {
            VStack(spacing: 0) {
                categoryPicker

                if isLoading && repositories.isEmpty {
                    Spacer()
                    ProgressView("جارٍ تحميل التطبيقات…")
                    Spacer()
                } else if filteredEntries.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "square.grid.3x3")
                            .font(.system(size: 34))
                            .foregroundStyle(.secondary)
                        Text(searchText.isEmpty ? "لا توجد تطبيقات في هذا التصنيف" : "لا توجد نتائج")
                            .font(.headline)
                        Text(loadError ? "تعذر تحميل بعض المصادر. اسحب للأسفل لإعادة المحاولة." : "جرّب اختيار تصنيف آخر أو تغيير عبارة البحث.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        Section {
                            ForEach(filteredEntries) { entry in
                                appRow(entry)
                                    .listRowSeparator(.visible)
                            }
                        } header: {
                            Text("\(filteredEntries.count) تطبيق")
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .searchable(text: $searchText, placement: .platform(), prompt: "ابحث عن تطبيق أو لعبة")
            .refreshable {
                await loadRepositories()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if isLoading {
                        ProgressView()
                    } else {
                        Button {
                            Task { await loadRepositories() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .accessibilityLabel("تحديث التطبيقات")
                    }
                }
            }
            .navigationDestinationIfAvailable(item: $selectedRoute) { route in
                SourceAppsDetailView(
                    sourceURL: route.sourceURL,
                    source: route.source,
                    app: route.app
                )
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
                ForEach(AppsCatalogCategory.allCases) { category in
                    let isSelected = selectedCategory == category
                    Button {
                        withAnimation(.snappy(duration: 0.2)) {
                            selectedCategory = category
                        }
                    } label: {
                        Label("\(category.title) · \(categoryCount(category))", systemImage: category.icon)
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 13)
                            .padding(.vertical, 9)
                            .background(
                                Capsule()
                                    .fill(isSelected ? Color.accentColor : Color(.secondarySystemBackground))
                            )
                            .foregroundStyle(isSelected ? Color.white : Color.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
    }


    private func categoryCount(_ category: AppsCatalogCategory) -> Int {
        switch category {
        case .all:
            return entries.count
        case .featured:
            return entries.filter(\.isFeatured).count
        default:
            return entries.filter { $0.category == category }.count
        }
    }

    @ViewBuilder
    private func appRow(_ entry: AppsCatalogEntry) -> some View {
        HStack(spacing: 12) {
            Button {
                selectedRoute = SourceAppsView.SourceAppRoute(
                    sourceURL: entry.sourceURL,
                    source: entry.source,
                    app: entry.app
                )
            } label: {
                HStack(spacing: 12) {
                    LazyImage(url: entry.app.iconURL) { state in
                        if let image = state.image {
                            image.resizable().aspectRatio(contentMode: .fill)
                        } else {
                            Image("App_Unknown").resizable().aspectRatio(contentMode: .fit)
                                .padding(10)
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
                        Text(entry.isFeatured ? "مميز · \(entry.category.title)" : entry.category.title)
                            .font(.caption)
                            .foregroundStyle(Color.accentColor)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            DownloadButtonView(
                sourceURL: entry.sourceURL,
                source: entry.source,
                app: entry.app
            )
        }
        .padding(.vertical, 5)
    }

    @MainActor
    private func loadRepositories() async {
        guard !isLoading else { return }
        isLoading = true
        loadError = false
        defer { isLoading = false }

        var loaded: [SourceAppsView.SourceRepositoryContext] = []
        for source in sources {
            let result: ASRepository? = await withCheckedContinuation { continuation in
                dataService.fetch(from: source.url) { (result: Result<ASRepository, Error>) in
                    switch result {
                    case .success(let repository):
                        continuation.resume(returning: repository)
                    case .failure:
                        continuation.resume(returning: nil)
                    }
                }
            }

            if let result {
                loaded.append(
                    SourceAppsView.SourceRepositoryContext(
                        sourceURL: source.url,
                        repository: result
                    )
                )
            } else {
                loadError = true
            }
        }

        repositories = loaded
    }
}

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

    var category: AppsCatalogCategory {
        AppsCatalogCategory.classify(app)
    }
}

private enum AppsCatalogCategory: String, CaseIterable, Identifiable {
    case all
    case games
    case programs
    case jailbreak
    case design
    case artificialIntelligence
    case emulators

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "الكل"
        case .games: "الألعاب"
        case .programs: "البرامج"
        case .jailbreak: "برامج الجيلبريك"
        case .design: "التصميم"
        case .artificialIntelligence: "الذكاء الاصطناعي"
        case .emulators: "المحاكيات"
        }
    }

    var icon: String {
        switch self {
        case .all: "square.grid.2x2"
        case .games: "gamecontroller"
        case .programs: "app"
        case .jailbreak: "wrench.and.screwdriver"
        case .design: "paintpalette"
        case .artificialIntelligence: "sparkles"
        case .emulators: "arcade.stick"
        }
    }

    static func classify(_ app: ASRepository.App) -> AppsCatalogCategory {
        let text = [
            app.category,
            app.name,
            app.subtitle,
            app.description,
            app.localizedDescription,
            app.developer
        ]
        .compactMap { $0 }
        .joined(separator: " ")
        .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        .lowercased()

        func containsAny(_ words: [String]) -> Bool {
            words.contains { text.contains($0) }
        }

        if containsAny(["emulator", "emulation", "retroarch", "ppsspp", "delta emulator", "nes emulator", "game boy"]) {
            return .emulators
        }
        if containsAny(["game", "games", "arcade", "rpg", "minecraft", "terraria", "fortnite", "flappy bird"]) {
            return .games
        }
        if containsAny(["artificial intelligence", "ai assistant", "chatgpt", "openai", "claude", "gemini", "copilot", "stable diffusion"]) {
            return .artificialIntelligence
        }
        if containsAny(["photo editor", "photo editing", "graphic design", "design tool", "drawing", "illustration", "bazaart", "procreate"]) {
            return .design
        }
        if containsAny(["jailbreak", "trollstore", "sileo", "cydia", "zebra", "dopamine", "ellekit", "roothide", "bootstrap", "misaka", "serotonin", "filza", "tweak", "signing", "signer", "ksign", "esign", "side-loading", "sideloading"]) {
            return .jailbreak
        }

        switch (app.category ?? "").lowercased() {
        case "games", "game": return .games
        case "graphics", "photo-video", "design": return .design
        case "developer", "utilities", "productivity", "education", "entertainment", "music", "social":
            return .programs
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

    // Source endpoints are intentionally kept in app configuration and are never shown in the interface.
    private let sources: [AppsCatalogSource] = [
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
            url: URL(string: "https://github.com/LiveContainer/LiveContainer/releases/download/1.0/apps.json")!
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
            let matchesCategory = selectedCategory == .all || entry.category == selectedCategory
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
                    ContentUnavailableView {
                        Label(
                            searchText.isEmpty ? "لا توجد تطبيقات في هذا التصنيف" : "لا توجد نتائج",
                            systemImage: "square.grid.3x3"
                        )
                    } description: {
                        Text(loadError ? "تعذر تحميل بعض المصادر. اسحب للأسفل لإعادة المحاولة." : "جرّب اختيار تصنيف آخر أو تغيير عبارة البحث.")
                    }
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
                        Label(category.title, systemImage: category.icon)
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
                        Text(entry.category.title)
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
                NBFetchService().fetch(from: source.url) { (result: Result<ASRepository, Error>) in
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

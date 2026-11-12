import SwiftUI
import AltSourceKit
import NimbleViews
import NukeUI
import SWCompression

private enum AppsCatalogCategory: String, CaseIterable, Hashable, Identifiable, Sendable {
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
}

// MARK: - Lightweight bundled index

/// This is deliberately a small display-only model. The complete AltSourceKit
/// repository is not decoded until the user opens or downloads an app.
private struct AppsCatalogEntry: Decodable, Identifiable, Sendable {
    let id: String
    let sourceIndex: Int
    let appIndex: Int
    let bundleIdentifier: String
    let appDownloadURL: String?
    let name: String
    let subtitle: String?
    let developer: String?
    let iconURL: URL?
    let category: String

    var catalogCategory: AppsCatalogCategory {
        AppsCatalogCategory(rawValue: category) ?? .other
    }
}

private struct AppsCatalogSourceReference: Decodable, Identifiable, Sendable {
    let id: Int
    let sourceURL: URL
    let resourceName: String
}

private struct AppsCatalogIndex: Decodable, Sendable {
    let schemaVersion: Int
    let sources: [AppsCatalogSourceReference]
    let apps: [AppsCatalogEntry]
}

private struct AppsCatalogPreparedSnapshot: Sendable {
    let sources: [AppsCatalogSourceReference]
    let entriesByCategory: [AppsCatalogCategory: [AppsCatalogEntry]]
    let categoryCounts: [AppsCatalogCategory: Int]
    let visibleCategories: [AppsCatalogCategory]
}

private struct AppsCatalogResolvedApp: Sendable {
    let sourceURL: URL
    let repository: ASRepository
    let app: ASRepository.App
}

private enum AppsCatalogBundleLoader {
    /// Reads and groups only the prebuilt index. All decompression, decoding,
    /// and grouping happen away from the main actor.
    static func loadIndex() async -> AppsCatalogPreparedSnapshot? {
        await Task.detached(priority: .userInitiated) {
            guard
                let indexURL = Bundle.main.url(
                    forResource: "AppsCatalogIndex",
                    withExtension: "json.gz"
                ),
                let compressedData = try? Data(contentsOf: indexURL),
                let indexData = try? GzipArchive.unarchive(archive: compressedData),
                let index = try? JSONDecoder().decode(AppsCatalogIndex.self, from: indexData),
                index.schemaVersion == 1,
                !index.sources.isEmpty,
                !index.apps.isEmpty
            else {
                return nil
            }

            var grouped = Dictionary(grouping: index.apps, by: \.catalogCategory)
            grouped[.all] = index.apps

            var counts: [AppsCatalogCategory: Int] = [.all: index.apps.count]
            for (category, entries) in grouped where category != .all {
                counts[category] = entries.count
            }

            let visible = AppsCatalogCategory.allCases.filter {
                $0 == .all || counts[$0, default: 0] > 0
            }

            return AppsCatalogPreparedSnapshot(
                sources: index.sources,
                entriesByCategory: grouped,
                categoryCounts: counts,
                visibleCategories: visible
            )
        }.value
    }

    /// The full repository is loaded lazily, once per source, only when the
    /// user opens an item or presses Get.
    static func loadRepository(for source: AppsCatalogSourceReference) -> ASRepository? {
        guard
            let fileURL = Bundle.main.url(
                forResource: source.resourceName,
                withExtension: "json.gz"
            ),
            let compressedData = try? Data(contentsOf: fileURL),
            let repositoryData = try? GzipArchive.unarchive(archive: compressedData)
        else {
            return nil
        }

        let decoder = JSONDecoder()
        if let repository = try? decoder.decode(ASRepository.self, from: repositoryData) {
            return repository
        }

        // A single malformed app in a third-party feed must not make every
        // other app in that source impossible to open.
        guard
            var root = try? JSONSerialization.jsonObject(with: repositoryData) as? [String: Any],
            let rawApps = root["apps"] as? [[String: Any]]
        else {
            return nil
        }

        let validApps = rawApps.filter { appObject in
            guard let appData = try? JSONSerialization.data(withJSONObject: appObject) else {
                return false
            }
            return (try? decoder.decode(ASRepository.App.self, from: appData)) != nil
        }

        guard !validApps.isEmpty else { return nil }
        root["apps"] = validApps

        if
            let filteredData = try? JSONSerialization.data(withJSONObject: root),
            let repository = try? decoder.decode(ASRepository.self, from: filteredData)
        {
            return repository
        }

        // Last-resort metadata sanitization: preserve the useful source identity
        // and display fields while dropping optional malformed repository fields.
        var safeRoot: [String: Any] = ["apps": validApps]
        for key in [
            "identifier", "name", "subtitle", "description",
            "website", "iconURL", "headerURL", "patreonURL"
        ] {
            if let value = root[key] as? String {
                safeRoot[key] = value
            }
        }

        guard let safeData = try? JSONSerialization.data(withJSONObject: safeRoot) else {
            return nil
        }
        return try? decoder.decode(ASRepository.self, from: safeData)
    }
}

// MARK: - Shared catalog store

/// A shared store prevents the index from being decoded again when SwiftUI
/// recreates the tab's view hierarchy or the user switches tabs.
@MainActor
private final class AppsCatalogStore: ObservableObject {
    static let shared = AppsCatalogStore()

    @Published private(set) var entriesByCategory: [AppsCatalogCategory: [AppsCatalogEntry]] = [:]
    @Published private(set) var categoryCounts: [AppsCatalogCategory: Int] = [:]
    @Published private(set) var visibleCategories: [AppsCatalogCategory] = [.all]
    @Published private(set) var isLoading = true
    @Published private(set) var isReady = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var detailErrorMessage: String?

    private var sourcesByIndex: [Int: AppsCatalogSourceReference] = [:]
    private var repositoriesBySource: [Int: ASRepository] = [:]
    private var repositoryTasks: [Int: Task<ASRepository?, Never>] = [:]
    private var indexTask: Task<Void, Never>?

    func loadIfNeeded() {
        guard !isReady, indexTask == nil else { return }

        isLoading = true
        errorMessage = nil
        indexTask = Task {
            let prepared = await AppsCatalogBundleLoader.loadIndex()
            guard !Task.isCancelled else { return }

            if let prepared {
                sourcesByIndex = Dictionary(
                    uniqueKeysWithValues: prepared.sources.map { ($0.id, $0) }
                )
                entriesByCategory = prepared.entriesByCategory
                categoryCounts = prepared.categoryCounts
                visibleCategories = prepared.visibleCategories
                isReady = true
            } else {
                errorMessage = "ملف فهرس التطبيقات غير موجود أو غير صالح. شغّل مهمة تحديث المكتبة في GitHub ثم أعد بناء التطبيق."
            }

            isLoading = false
            indexTask = nil
        }
    }

    func retryLoadingIndex() {
        guard !isLoading else { return }
        isReady = false
        errorMessage = nil
        loadIfNeeded()
    }

    func resolve(_ entry: AppsCatalogEntry) async -> AppsCatalogResolvedApp? {
        detailErrorMessage = nil

        guard let source = sourcesByIndex[entry.sourceIndex] else {
            detailErrorMessage = "تعذر العثور على مصدر هذا التطبيق."
            return nil
        }

        let repository: ASRepository
        if let cached = repositoriesBySource[source.id] {
            repository = cached
        } else {
            let task: Task<ASRepository?, Never>
            if let existingTask = repositoryTasks[source.id] {
                task = existingTask
            } else {
                let newTask = Task.detached(priority: .userInitiated) {
                    AppsCatalogBundleLoader.loadRepository(for: source)
                }
                repositoryTasks[source.id] = newTask
                task = newTask
            }

            guard let loaded = await task.value else {
                repositoryTasks[source.id] = nil
                detailErrorMessage = "تعذر قراءة بيانات المستودع لهذا التطبيق."
                return nil
            }

            repositoriesBySource[source.id] = loaded
            repositoryTasks[source.id] = nil
            repository = loaded
        }

        let matchingApp = repository.apps.first { app in
            let identifierMatches = entry.bundleIdentifier.isEmpty || app.id == entry.bundleIdentifier
            let downloadMatches = entry.appDownloadURL == nil
                || app.downloadURL?.absoluteString == entry.appDownloadURL
            return identifierMatches && downloadMatches
        } ?? repository.apps.first(where: { $0.currentName == entry.name })

        let app: ASRepository.App
        if let matchingApp {
            app = matchingApp
        } else if repository.apps.indices.contains(entry.appIndex) {
            app = repository.apps[entry.appIndex]
        } else {
            detailErrorMessage = "لم أتمكن من مطابقة التطبيق مع بيانات المستودع."
            return nil
        }

        return AppsCatalogResolvedApp(
            sourceURL: source.sourceURL,
            repository: repository,
            app: app
        )
    }
}

// MARK: - Catalog view

struct AppsCatalogView: View {
    @StateObject private var catalog = AppsCatalogStore.shared
    @State private var selectedCategory: AppsCatalogCategory = .all
    @State private var searchText = ""
    @State private var selectedRoute: SourceAppsView.SourceAppRoute?
    @State private var openingEntryID: String?

    private var filteredEntries: [AppsCatalogEntry] {
        let categoryEntries = catalog.entriesByCategory[selectedCategory] ?? []
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return categoryEntries }

        return categoryEntries.filter { entry in
            entry.name.localizedCaseInsensitiveContains(query)
                || (entry.subtitle ?? "").localizedCaseInsensitiveContains(query)
                || (entry.developer ?? "").localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NBNavigationView("التطبيقات") {
            VStack(spacing: 0) {
                categoryPicker

                if let detailErrorMessage = catalog.detailErrorMessage {
                    Label(detailErrorMessage, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.bottom, 6)
                }

                if catalog.isLoading {
                    Spacer()
                    ProgressView("جارٍ تجهيز مكتبة التطبيقات…")
                    Spacer()
                } else if !catalog.isReady {
                    ContentUnavailableView {
                        Label("تعذر تجهيز التطبيقات", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(catalog.errorMessage ?? "ملف المكتبة غير متاح.")
                    } actions: {
                        Button("إعادة المحاولة") {
                            catalog.retryLoadingIndex()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredEntries.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "square.grid.3x3")
                            .font(.system(size: 34))
                            .foregroundStyle(.secondary)
                        Text(searchText.isEmpty ? "لا توجد تطبيقات في هذا القسم" : "لا توجد نتائج")
                            .font(.headline)
                        Text("جرّب فئة أخرى أو غيّر عبارة البحث.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        Section {
                            ForEach(filteredEntries) { entry in
                                appRow(entry)
                            }
                        } header: {
                            Text("\(filteredEntries.count) تطبيق")
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .searchable(text: $searchText, placement: .platform(), prompt: "ابحث عن تطبيق أو لعبة")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if catalog.isLoading {
                        ProgressView()
                    } else if !catalog.isReady {
                        Button {
                            catalog.retryLoadingIndex()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .accessibilityLabel("إعادة تحميل فهرس التطبيقات")
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
            catalog.loadIfNeeded()
        }
    }

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(catalog.visibleCategories) { category in
                    let selected = selectedCategory == category
                    Button {
                        // The target category is already indexed. Switching only
                        // swaps the visible array; it does not classify or rescan
                        // the full catalog.
                        selectedCategory = category
                    } label: {
                        Label(
                            "\(category.title) · \(categoryCount(category))",
                            systemImage: category.icon
                        )
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 13)
                        .padding(.vertical, 9)
                        .background(
                            Capsule().fill(
                                selected ? Color.accentColor : Color(.secondarySystemBackground)
                            )
                        )
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
        catalog.categoryCounts[category, default: 0]
    }

    @ViewBuilder
    private func appRow(_ entry: AppsCatalogEntry) -> some View {
        HStack(spacing: 12) {
            Button {
                open(entry)
            } label: {
                HStack(spacing: 12) {
                    LazyImage(url: entry.iconURL) { state in
                        if let image = state.image {
                            image.resizable().aspectRatio(contentMode: .fill)
                        } else {
                            Image("App_Unknown")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .padding(10)
                        }
                    }
                    .frame(width: 58, height: 58)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text(entry.subtitle ?? "تطبيق")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                        Text(entry.catalogCategory.title)
                            .font(.caption)
                            .foregroundStyle(Color.accentColor)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(openingEntryID == entry.id)

            if openingEntryID == entry.id {
                ProgressView()
                    .frame(width: 64)
            } else {
                AppsCatalogDownloadButton(store: catalog, entry: entry)
            }
        }
        .padding(.vertical, 5)
    }

    private func open(_ entry: AppsCatalogEntry) {
        guard openingEntryID == nil else { return }
        openingEntryID = entry.id

        Task {
            let resolved = await catalog.resolve(entry)
            if let resolved {
                selectedRoute = SourceAppsView.SourceAppRoute(
                    sourceURL: resolved.sourceURL,
                    source: resolved.repository,
                    app: resolved.app
                )
            }
            openingEntryID = nil
        }
    }
}

// MARK: - Lazy download action

/// Keeps the existing DownloadButtonView behavior, but resolves its full
/// AltSourceKit models only after the user actually presses Get.
private struct AppsCatalogDownloadButton: View {
    @ObservedObject var store: AppsCatalogStore
    let entry: AppsCatalogEntry

    @State private var resolvedApp: AppsCatalogResolvedApp?
    @State private var isResolving = false

    var body: some View {
        Group {
            if let resolvedApp {
                DownloadButtonView(
                    sourceURL: resolvedApp.sourceURL,
                    source: resolvedApp.repository,
                    app: resolvedApp.app
                )
            } else {
                Button {
                    Task { await resolveAndStartDownload() }
                } label: {
                    Group {
                        if isResolving {
                            ProgressView()
                                .frame(width: 38, height: 30)
                        } else {
                            Text("Get")
                                .lineLimit(0)
                                .font(.headline.bold())
                                .foregroundStyle(Color.accentColor)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 6)
                                .background(Color(uiColor: .quaternarySystemFill))
                                .clipShape(Capsule())
                        }
                    }
                }
                .buttonStyle(.borderless)
                .disabled(isResolving)
            }
        }
    }

    @MainActor
    private func resolveAndStartDownload() async {
        guard !isResolving else { return }
        isResolving = true
        defer { isResolving = false }

        guard let resolved = await store.resolve(entry) else { return }
        resolvedApp = resolved

        guard let downloadURL = resolved.app.currentDownloadUrl else { return }
        let provenance = SourceAppProvenance(
            sourceURL: resolved.sourceURL,
            repository: resolved.repository,
            app: resolved.app
        )
        _ = DownloadManager.shared.startDownload(
            from: downloadURL,
            id: resolved.app.currentUniqueId,
            sourceProvenance: provenance
        )
    }
}

import SwiftUI

/// Launch Feather from the Xcode scheme with -AMARYTCatalogPreview to test the API.
/// This screen does not alter the normal store, source database, or installer.
struct AMARYTCatalogPreviewView: View {
    @State private var manifest: AMARYTCatalogAPI.Manifest?
    @State private var apps: [AMARYTCatalogAPI.AppSummary] = []
    @State private var nextPage = 0
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedApp: AMARYTCatalogAPI.AppSummary?
    @State private var searchText = ""

    private var filteredApps: [AMARYTCatalogAPI.AppSummary] {
        guard !searchText.isEmpty else { return apps }
        return apps.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.bundleIdentifier.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if let manifest {
                    Section {
                        Text("Loaded \(apps.count) of \(manifest.totalApps) apps")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                ForEach(filteredApps) { app in
                    Button {
                        selectedApp = app
                    } label: {
                        HStack(spacing: 12) {
                            if let raw = app.iconURL, let url = URL(string: raw), url.scheme == "https" {
                                AsyncImage(url: url) { image in
                                    image.resizable().scaledToFit()
                                } placeholder: {
                                    Image(systemName: "app").foregroundStyle(.secondary)
                                }
                                .frame(width: 44, height: 44)
                                .clipShape(RoundedRectangle(cornerRadius: 9))
                            } else {
                                Image(systemName: "app").frame(width: 44, height: 44)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text(app.name).font(.headline)
                                Text([app.version, app.sourceId].compactMap { $0 }.joined(separator: " · "))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                if let manifest, nextPage < manifest.pageCount {
                    Button(isLoading ? "Loading…" : "Load next 50") {
                        Task { await loadNextPage() }
                    }
                    .disabled(isLoading)
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                    Button("Retry") { Task { await loadNextPage() } }
                }
            }
            .navigationTitle("API Catalog Preview")
            .searchable(text: $searchText)
            .task { await loadNextPage() }
            .sheet(item: $selectedApp) { app in
                AMARYTDetailPreview(app: app)
            }
        }
    }

    private func loadNextPage() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let current: AMARYTCatalogAPI.Manifest
            if let cached = manifest { current = cached }
            else { current = try await AMARYTCatalogAPI.fetchManifest() }
            manifest = current
            guard nextPage < current.pageCount else { return }
            let page = try await AMARYTCatalogAPI.fetchPage(nextPage, manifest: current)
            apps.append(contentsOf: page)
            nextPage += 1
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

}

private struct AMARYTDetailPreview: View {
    let app: AMARYTCatalogAPI.AppSummary
    @State private var detail: DetailRecord?
    @State private var errorMessage: String?

    private struct DetailRecord: Decodable {
        let id: String
        let name: String
        let localizedDescription: String?
        let downloadURL: String?
        let developerName: String?
        let version: String?
        let screenshotURLs: [String]?
    }
    private struct DetailPage: Decodable {
        let items: [DetailRecord]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(app.name).font(.title2).bold()
                    Text([app.version, app.sourceId].compactMap { $0 }.joined(separator: " · "))
                        .foregroundStyle(.secondary)
                    if let detail {
                        Text(detail.localizedDescription ?? "No description provided")
                        if let url = detail.downloadURL, let download = URL(string: url),
                           ["https", "http"].contains(download.scheme?.lowercased() ?? "") {
                            Link("Open IPA download URL", destination: download)
                        }
                        Text("Installation is not enabled in this API preview.")
                            .font(.caption).foregroundStyle(.secondary)
                    } else if let errorMessage {
                        Text(errorMessage).foregroundStyle(.red)
                    } else {
                        ProgressView()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .navigationTitle("App Details")
            .task {
                guard let path = app.detailPath else {
                    errorMessage = "No detail path for this app"
                    return
                }
                do {
                    let data = try await AMARYTCatalogAPI.fetchDetail(path)
                    let page = try JSONDecoder().decode(DetailPage.self, from: data)
                    guard let record = page.items.first(where: { $0.id == app.id }) else {
                        errorMessage = "App not found in detail page"
                        return
                    }
                    detail = record
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

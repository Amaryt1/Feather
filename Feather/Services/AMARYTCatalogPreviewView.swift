import SwiftUI

/// Launch Feather from the Xcode scheme with -AMARYTCatalogPreview to test the API.
/// This screen does not alter the normal store, source database, or installer.
struct AMARYTCatalogPreviewView: View {
    @State private var manifest: AMARYTCatalogAPI.Manifest?
    @State private var apps: [AMARYTCatalogAPI.AppSummary] = []
    @State private var nextPage = 0
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedDetail: String?
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
                        selectedDetail = app.detailPath
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
            .sheet(item: Binding(
                get: { selectedDetail.map { DetailSelection(path: $0) } },
                set: { selectedDetail = $0?.path }
            )) { selection in
                AMARYTDetailPreview(path: selection.path)
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

    private struct DetailSelection: Identifiable {
        let path: String
        var id: String { path }
    }
}

private struct AMARYTDetailPreview: View {
    let path: String
    @State private var text = "Loading…"

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(text).font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled).padding()
            }
            .navigationTitle("API Details (read-only)")
            .task {
                do {
                    let data = try await AMARYTCatalogAPI.fetchDetail(path)
                    let object = try JSONSerialization.jsonObject(with: data)
                    let formatted = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
                    text = String(data: formatted, encoding: .utf8) ?? "Invalid UTF-8"
                } catch {
                    text = error.localizedDescription
                }
            }
        }
    }
}

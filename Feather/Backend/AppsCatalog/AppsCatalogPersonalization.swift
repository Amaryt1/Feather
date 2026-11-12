//
//  AppsCatalogPersonalization.swift
//  Feather
//
//  Persistent user features for the apps catalog.
//

import Foundation
import Combine
import UserNotifications
import SwiftUI

struct AppsCatalogDownloadRecord: Codable, Identifiable {
    let id: String
    let fileName: String
    let sourceURL: String
    let localPath: String
    let date: Date

    var localURL: URL { URL(fileURLWithPath: localPath) }
}

@MainActor
final class AppsCatalogPersonalization: ObservableObject {
    static let shared = AppsCatalogPersonalization()

    @Published private(set) var favoriteIDs: Set<String>
    @Published private(set) var recentIDs: [String]
    @Published private(set) var downloadHistory: [AppsCatalogDownloadRecord]
    @Published private(set) var updateNotificationsEnabled: Bool

    private let defaults = UserDefaults.standard
    private let favoritesKey = "Feather.AppsCatalog.Favorites.v1"
    private let recentKey = "Feather.AppsCatalog.Recent.v1"
    private let historyKey = "Feather.AppsCatalog.DownloadHistory.v1"
    private let notificationsKey = "Feather.AppsCatalog.UpdateNotifications.v1"
    private let versionsKey = "Feather.AppsCatalog.KnownVersions.v1"

    private init() {
        favoriteIDs = Set(defaults.stringArray(forKey: "Feather.AppsCatalog.Favorites.v1") ?? [])
        recentIDs = defaults.stringArray(forKey: "Feather.AppsCatalog.Recent.v1") ?? []
        if let data = defaults.data(forKey: "Feather.AppsCatalog.DownloadHistory.v1"),
           let records = try? JSONDecoder().decode([AppsCatalogDownloadRecord].self, from: data) {
            downloadHistory = records
        } else {
            downloadHistory = []
        }
        updateNotificationsEnabled = defaults.bool(forKey: "Feather.AppsCatalog.UpdateNotifications.v1")
    }

    func isFavorite(_ id: String) -> Bool {
        favoriteIDs.contains(id)
    }

    func toggleFavorite(_ id: String) {
        if favoriteIDs.contains(id) {
            favoriteIDs.remove(id)
        } else {
            favoriteIDs.insert(id)
        }
        defaults.set(Array(favoriteIDs), forKey: favoritesKey)
    }

    func recordViewed(_ id: String) {
        recentIDs.removeAll { $0 == id }
        recentIDs.insert(id, at: 0)
        if recentIDs.count > 100 { recentIDs = Array(recentIDs.prefix(100)) }
        defaults.set(recentIDs, forKey: recentKey)
    }

    func recordDownload(id: String, fileName: String, sourceURL: URL, localURL: URL) {
        let record = AppsCatalogDownloadRecord(
            id: id,
            fileName: fileName,
            sourceURL: sourceURL.absoluteString,
            localPath: localURL.path,
            date: Date()
        )
        downloadHistory.removeAll { $0.id == id && $0.localPath == localURL.path }
        downloadHistory.insert(record, at: 0)
        if downloadHistory.count > 200 { downloadHistory = Array(downloadHistory.prefix(200)) }
        persistHistory()
    }

    func removeDownloadRecord(_ record: AppsCatalogDownloadRecord) {
        downloadHistory.removeAll { $0.id == record.id && $0.localPath == record.localPath }
        persistHistory()
    }

    func clearDownloadHistory() {
        downloadHistory.removeAll()
        persistHistory()
    }

    func setUpdateNotificationsEnabled(_ enabled: Bool) {
        guard enabled else {
            updateNotificationsEnabled = false
            defaults.set(false, forKey: notificationsKey)
            UNUserNotificationCenter.current().removePendingNotificationRequests(
                withIdentifiers: favoriteIDs.map { "Feather.AppsCatalog.Update.\($0)" }
            )
            return
        }

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { [weak self] granted, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                self.updateNotificationsEnabled = granted
                self.defaults.set(granted, forKey: self.notificationsKey)
            }
        }
    }

    func checkForUpdates(in entries: [AppsCatalogEntrySnapshot]) {
        guard updateNotificationsEnabled else { return }
        var known = defaults.dictionary(forKey: versionsKey) as? [String: String] ?? [:]
        var changed: [(String, String, String)] = []

        for entry in entries where favoriteIDs.contains(entry.id) {
            guard let version = entry.version, !version.isEmpty else { continue }
            if let previous = known[entry.id], previous != version {
                changed.append((entry.id, entry.name, version))
            }
            known[entry.id] = version
        }
        defaults.set(known, forKey: versionsKey)

        for update in changed {
            let content = UNMutableNotificationContent()
            content.title = "تحديث جديد متاح"
            content.body = "\(update.1) أصبح متاحاً بالإصدار \(update.2)"
            content.sound = .default
            let request = UNNotificationRequest(
                identifier: "Feather.AppsCatalog.Update.\(update.0)",
                content: content,
                trigger: nil
            )
            UNUserNotificationCenter.current().add(request)
        }
    }

    private func persistHistory() {
        guard let data = try? JSONEncoder().encode(downloadHistory) else { return }
        defaults.set(data, forKey: historyKey)
    }
}

struct AppsCatalogEntrySnapshot {
    let id: String
    let name: String
    let version: String?
}

struct AppsCatalogHistoryView: View {
    @ObservedObject private var personalization = AppsCatalogPersonalization.shared

    var body: some View {
        NavigationView {
            Group {
                if personalization.downloadHistory.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 34))
                            .foregroundStyle(.secondary)
                        Text("لا يوجد سجل تحميلات").font(.headline)
                        Text("ستظهر هنا الملفات التي تم تنزيلها من قسم التطبيقات.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else {
                    List {
                        ForEach(personalization.downloadHistory) { record in
                            VStack(alignment: .leading, spacing: 5) {
                                Text(record.fileName).font(.headline)
                                Text(record.date.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption).foregroundStyle(.secondary)
                                Text(FileManager.default.fileExists(atPath: record.localPath)
                                     ? "الملف موجود على الجهاز"
                                     : "تم نقل الملف أو حذفه")
                                    .font(.caption2).foregroundStyle(.secondary)
                                if FileManager.default.fileExists(atPath: record.localPath) {
                                    ShareLink(item: record.localURL) {
                                        Label("مشاركة الملف", systemImage: "square.and.arrow.up")
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                            .swipeActions {
                                Button(role: .destructive) {
                                    personalization.removeDownloadRecord(record)
                                } label: {
                                    Label("حذف من السجل", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("سجل التحميلات")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !personalization.downloadHistory.isEmpty {
                        Button("مسح السجل", role: .destructive) {
                            personalization.clearDownloadHistory()
                        }
                    }
                }
            }
        }
    }
}


struct AppsCatalogDownloadsView: View {
    @ObservedObject private var manager = DownloadManager.shared

    var body: some View {
        NavigationView {
            Group {
                if manager.downloads.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 34))
                            .foregroundStyle(.secondary)
                        Text("لا توجد تنزيلات نشطة").font(.headline)
                        Text("ستظهر هنا التنزيلات الجارية والمتوقفة.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else {
                    List {
                        ForEach(manager.downloads) { download in
                            AppsCatalogDownloadRow(download: download)
                        }
                    }
                }
            }
            .navigationTitle("مدير التحميلات")
        }
    }
}

private struct AppsCatalogDownloadRow: View {
    @ObservedObject var download: Download
    @ObservedObject private var manager = DownloadManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(download.fileName)
                .font(.headline)
                .lineLimit(1)
            ProgressView(value: download.overallProgress)
            HStack {
                Text(download.isPaused ? "متوقف مؤقتاً" : "\(Int(download.overallProgress * 100))٪")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if download.totalBytes > 0 {
                    Text("\(download.bytesDownloaded.formattedByteCount) / \(download.totalBytes.formattedByteCount)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            HStack {
                Button {
                    if download.isPaused {
                        manager.resumeDownload(download)
                    } else {
                        manager.pauseDownload(download)
                    }
                } label: {
                    Label(download.isPaused ? "استئناف" : "إيقاف مؤقت",
                          systemImage: download.isPaused ? "play.fill" : "pause.fill")
                }
                .buttonStyle(.bordered)

                Button(role: .destructive) {
                    manager.cancelDownload(download)
                } label: {
                    Label("إلغاء", systemImage: "xmark")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 5)
    }
}


struct AppsCatalogSourcesStatusView: View {
    let onRefresh: @MainActor (URL) async -> Void
    @State private var refreshingSource: String?

    private let feeds: [(name: String, url: URL)] = [
        ("FastSign", URL(string: "https://fastsign.dev/repo.json")!),
        ("AppTesters", URL(string: "https://repository.apptesters.org")!),
        ("CyPwn", URL(string: "https://ipa.cypwn.xyz/cypwn.json")!),
        ("Ksign", URL(string: "https://raw.githubusercontent.com/Nyasami/Ksign/refs/heads/main/repo.json")!),
        ("SideStore Community", URL(string: "https://community-apps.sidestore.io/sidecommunity.json")!),
        ("LiveContainer", URL(string: "https://raw.githubusercontent.com/LiveContainer/LiveContainer/refs/heads/main/apps.json")!)
    ]

    @State private var statuses: [String: String] = [:]
    @State private var checking = false
    @State private var lastChecked: Date?

    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(feeds, id: \.name) { feed in
                        HStack(spacing: 12) {
                            Image(systemName: statusIcon(for: feed.name))
                                .foregroundStyle(statusColor(for: feed.name))
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(feed.name).font(.headline)
                                Text(statuses[feed.name] ?? "لم يتم الفحص بعد")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(feed.url.host ?? "")
                                .font(.caption2).foregroundStyle(.tertiary)
                                .lineLimit(1)
                            Button {
                                Task {
                                    refreshingSource = feed.name
                                    await onRefresh(feed.url)
                                    await checkSources()
                                    refreshingSource = nil
                                }
                            } label: {
                                if refreshingSource == feed.name {
                                    ProgressView()
                                } else {
                                    Image(systemName: "arrow.clockwise")
                                }
                            }
                            .disabled(refreshingSource != nil || checking)
                            .accessibilityLabel("تحديث مصدر \(feed.name)")
                        }
                        .padding(.vertical, 3)
                    }
                } header: {
                    Text("حالة المصادر الخاصة")
                } footer: {
                    Text("يفحص هذا القسم اتصال المصدر واستجابة JSON. نجاح الاتصال لا يعني أن كل ملف IPA داخله صالح أو قابل للتثبيت.")
                }

                if let lastChecked {
                    Section {
                        LabeledContent("آخر فحص", value: lastChecked.formatted(date: .abbreviated, time: .shortened))
                        LabeledContent("عدد المصادر", value: "\(feeds.count)")
                        LabeledContent("المصادر المكررة", value: "\(feeds.count - Set(feeds.map { $0.url.absoluteString }).count)")
                    }
                }
            }
            .navigationTitle("صحة المصادر")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await checkSources() }
                    } label: {
                        if checking {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .disabled(checking)
                    .accessibilityLabel("فحص المصادر")
                }
            }
            .task {
                if statuses.isEmpty { await checkSources() }
            }
        }
    }

    private func statusIcon(for name: String) -> String {
        let value = statuses[name] ?? ""
        if value.hasPrefix("متصل") { return "checkmark.circle.fill" }
        if value.isEmpty { return "circle.dashed" }
        return "exclamationmark.triangle.fill"
    }

    private func statusColor(for name: String) -> Color {
        let value = statuses[name] ?? ""
        if value.hasPrefix("متصل") { return .green }
        if value.isEmpty { return .secondary }
        return .orange
    }

    @MainActor
    private func checkSources() async {
        guard !checking else { return }
        checking = true
        defer { checking = false }

        let results = await withTaskGroup(of: (String, String).self, returning: [String: String].self) { group in
            for feed in feeds {
                group.addTask {
                    do {
                        var request = URLRequest(url: feed.url)
                        request.timeoutInterval = 20
                        request.setValue("Feather/AppsCatalog", forHTTPHeaderField: "User-Agent")
                        let (data, response) = try await URLSession.shared.data(for: request)
                        guard let http = response as? HTTPURLResponse,
                              (200..<300).contains(http.statusCode) else {
                            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                            return (feed.name, "خطأ HTTP: \(code)")
                        }
                        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                            return (feed.name, "استجابة JSON غير متوقعة")
                        }
                        let count = (object["apps"] as? [Any])?.count
                            ?? (object["sources"] as? [Any])?.count
                        if let count {
                            return (feed.name, "متصل · \(count) عنصر")
                        }
                        return (feed.name, "متصل · JSON صالح")
                    } catch {
                        return (feed.name, "تعذر الاتصال: \(error.localizedDescription)")
                    }
                }
            }
            var values: [String: String] = [:]
            for await (name, status) in group { values[name] = status }
            return values
        }
        statuses = results
        lastChecked = Date()
    }
}

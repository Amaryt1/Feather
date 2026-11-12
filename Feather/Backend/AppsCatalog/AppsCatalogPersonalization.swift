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
                withIdentifiers: ["Feather.AppsCatalog.Update"]
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

        guard let latest = changed.first else { return }
        let content = UNMutableNotificationContent()
        content.title = "تحديث جديد متاح"
        content.body = "\(latest.1) أصبح متاحاً بالإصدار \(latest.2)"
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "Feather.AppsCatalog.Update",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
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
                    ContentUnavailableView(
                        "لا يوجد سجل تحميلات",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("ستظهر هنا الملفات التي تم تنزيلها من قسم التطبيقات.")
                    )
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

import Foundation

enum AppsCatalogSort: String, CaseIterable {
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

struct CatalogRank {
    let id: String
    let name: String
    let date: Date?
    let size: Int64?
    let hasArtwork: Bool
    var lastDownload: Date? = nil

    func precedes(_ rhs: Self, sort: AppsCatalogSort, locale: Locale = .current) -> Bool {
        if sort == .recommended, lastDownload != rhs.lastDownload {
            guard let lastDownload else { return false }
            return rhs.lastDownload.map { lastDownload > $0 } ?? true
        }
        if sort == .newest || sort == .recommended, date != rhs.date {
            guard let date else { return false }
            return rhs.date.map { date > $0 } ?? true
        }
        if sort == .recommended, hasArtwork != rhs.hasArtwork { return hasArtwork }
        if sort == .largest, size != rhs.size {
            guard let size else { return false }
            return rhs.size.map { size > $0 } ?? true
        }
        let order = name.compare(rhs.name, options: [.caseInsensitive, .diacriticInsensitive, .numeric],
                                 range: nil, locale: locale)
        return order == .orderedSame ? id < rhs.id : order == .orderedAscending
    }
}

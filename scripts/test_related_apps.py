#!/usr/bin/env python3
"""Run the real Swift recommendation rules with small Foundation-only fixtures."""
from pathlib import Path
import subprocess
import tempfile

source = Path("Feather/Views/Apps/AppsCatalogView.swift").read_text()
category = source.split("enum AppsCatalogCategory:", 1)[1].split("struct AppsCatalogEntry:", 1)[0]
category = "enum AppsCatalogCategory:" + category
engine = source.split("enum RelatedApps {", 1)[1].split("    @MainActor\n    static func load", 1)[0]
engine = "enum RelatedApps {" + engine + "}\n"
stub = r"""
import Foundation
struct ASRepository {
    struct App {
        var name: String?
        var id: String?
        var category: String?
        var subtitle: String? = nil
        var description: String? = nil
        var localizedDescription: String? = nil
        var currentDownloadUrl: URL?
        var currentDate: Stamp? = nil
        var currentName: String { name ?? "" }
    }
    struct Stamp { let date: Date }
}
struct AppsCatalogEntry {
    let app: ASRepository.App
    var id: String { app.currentDownloadUrl!.absoluteString }
}
func app(_ name: String, _ category: String, bundle: String? = nil, description: String? = nil, suffix: String = "") -> ASRepository.App {
    ASRepository.App(name: name, id: bundle ?? name, category: category,
                     localizedDescription: description,
                     currentDownloadUrl: URL(string: "https://example.com/" + (name + suffix).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!))
}
func related(_ target: ASRepository.App, _ candidates: [ASRepository.App], limit: Int = 8) -> [String] {
    RelatedApps.rank(app: target, candidates: candidates.map { AppsCatalogEntry(app: $0) }, limit: limit).map { $0.app.currentName }
}
"""
tests = r"""
let tv = app("HiTV", "أفلام")
let otherTV = app("iQTv", "أفلام", description: "مشاهدة الأفلام والمسلسلات")
let music = app("Spotify", "Music")
let video = app("YouTube", "Video")
assert(related(tv, [tv, otherTV, music, video]).first == "iQTv")
assert(Set(related(tv, [tv, otherTV, music, video])) == Set(["iQTv", "Spotify", "YouTube"]))
assert(related(music, [tv, app("Deezer", "Music"), video]).first == "Deezer")
let pubg = app("PUBG", "Games")
let freeFire = app("Free Fire", "Games")
assert(related(pubg, [app("Asphalt", "Games"), freeFire, tv]) == ["Free Fire", "Asphalt"])
let cards = app("كملنا VIP", "العاب معدّلة")
assert(related(cards, [app("Solitaire", "Games"), freeFire, tv]) == ["Solitaire", "Free Fire"])
let unrelated = app("Unidentified Tool", "Other")
assert(related(unrelated, [tv, pubg, music]).count == 3)
assert(related(tv, [music]) == ["Spotify"])
assert(related(pubg, [app("Asphalt", "Games"), tv]) == ["Asphalt"])
assert(related(pubg, [tv, music]).count == 2)
let design = app("Canva", "Design")
assert(related(design, [app("Picsart", "Design"), pubg, tv]) == ["Picsart"])
assert(related(tv, []).isEmpty)
assert(related(tv, [otherTV], limit: 0).isEmpty)
assert(related(tv, [app("HiTV Pro", "أفلام", bundle: "HiTV"), tv]).isEmpty)
assert(related(tv, [otherTV, app("iQTv", "أفلام", suffix: "-older")]).count == 1)
assert(related(tv, [otherTV, app("Netflix", "Entertainment")], limit: 1).count == 1)
let misleadingGame = app("PUBG", "Games", description: "watch movies and listen to music")
assert(related(misleadingGame, [tv, music, freeFire]) == ["Free Fire"])
print("PASS: purpose ranking, category-only fallback, general fallback, Arabic, self-exclusion, deduplication and limits")
"""
with tempfile.TemporaryDirectory() as directory:
    path = Path(directory) / "RelatedAppsTests.swift"
    path.write_text(stub + category + engine + tests)
    subprocess.run(["swift", str(path)], check=True)

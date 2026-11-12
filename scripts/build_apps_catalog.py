#!/usr/bin/env python3
"""Build Feather's pre-indexed, offline Apps Catalog bundle."""

from __future__ import annotations

import gzip
import json
import sys
import time
import unicodedata
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import urlparse

FEEDS = (
    "https://fastsign.dev/repo.json",
    "https://repository.apptesters.org",
    "https://ipa.cypwn.xyz/cypwn.json",
)
RESOURCES = Path("Feather/Resources")
INDEX_OUTPUT = RESOURCES / "AppsCatalogIndex.json.gz"
REPOSITORY_PREFIX = "AppsCatalogRepository-"
LEGACY_OUTPUTS = (
    RESOURCES / "AppsCatalogSeed.json",
    RESOURCES / "AppsCatalogSeed.json.gz",
)


def normalize(value: str) -> str:
    """Case/diacritic-insensitive normalization close to Swift's folding()."""
    return "".join(
        char
        for char in unicodedata.normalize("NFKD", value).casefold()
        if not unicodedata.combining(char)
    )


def classify_app(app: dict) -> str:
    raw_category = normalize(str(app.get("category") or ""))
    searchable = " ".join(
        str(app.get(key) or "")
        for key in (
            "category",
            "name",
            "subtitle",
            "description",
            "localizedDescription",
            "developerName",
        )
    )
    searchable = normalize(searchable)

    def has(*terms: str) -> bool:
        return any(term in searchable for term in terms)

    if has("emulator", "emulation", "retroarch", "ppsspp", "delta emulator", "محاكي", "محاكاة"):
        return "emulators"
    if has("game", "games", "gaming", "arcade", "rpg", "minecraft", "terraria", "fortnite",
           "لعبة", "ألعاب", "العاب"):
        return "games"
    if has("photo editor", "photo editing", "graphic design", "drawing", "illustration",
           "canva", "procreate", "vector editor", "video editor", "تصميم", "تعديل الصور", "رسم"):
        return "design"
    if has("movie", "movies", "tv series", "streaming", "iptv", "anime", "video player",
           "music player", "podcast", "cinema", "film", "أفلام", "مسلسلات", "انمي", "أنمي",
           "مشاهدة", "بث"):
        return "media"
    if has("artificial intelligence", "ai assistant", "chatgpt", "openai", "claude",
           "gemini", "copilot", "stable diffusion", "machine learning", "ذكاء اصطناعي"):
        return "ai"
    if has("jailbreak", "trollstore", "sileo", "cydia", "zebra", "dopamine", "ellekit",
           "roothide", "bootstrap", "misaka", "serotonin", "filza", "tweak", "جيلبريك", "تويك"):
        return "jailbreak"
    if has("signing", "signer", "ksign", "esign", "scarlet", "sideload", "ipa installer",
           "certificate manager", "توقيع", "تثبيت ipa", "شهادات"):
        return "signing"
    if has("ide", "code editor", "developer tool", "terminal", "git client", "ssh client",
           "debugger", "programming", "xcode", "برمجة", "مطور"):
        return "developer"
    if has("language learning", "dictionary", "flashcards", "education", "school",
           "university", "تعليم", "قاموس", "تعلم", "دراسة"):
        return "education"
    if has("productivity", "task manager", "todo", "notes", "calendar", "office suite",
           "document editor", "إنتاجية", "مهام", "ملاحظات"):
        return "productivity"
    if has("social network", "messenger", "chat app", "telegram", "discord", "reddit",
           "social media", "مراسلة", "تواصل اجتماعي"):
        return "social"
    if has("theme", "icon pack", "customization", "widgets", "wallpaper", "lock screen",
           "تخصيص", "ثيمات", "خلفيات"):
        return "customization"

    aliases = {
        "games": "games", "game": "games", "gaming": "games",
        "graphics": "design", "photo-video": "design", "design": "design",
        "photography": "design",
        "ai": "ai", "artificial-intelligence": "ai", "machine-learning": "ai",
        "emulator": "emulators", "emulators": "emulators",
        "developer": "developer", "development": "developer",
        "entertainment": "media", "music": "media", "video": "media", "media": "media",
        "productivity": "productivity", "business": "productivity",
        "customization": "customization", "themes": "customization",
        "personalization": "customization", "jailbreak": "jailbreak", "tweaks": "jailbreak",
        "signing": "signing", "sideloading": "signing", "education": "education",
        "social": "social", "utilities": "utilities", "utility": "utilities",
        "lifestyle": "utilities", "health": "utilities", "navigation": "utilities",
        "weather": "utilities", "finance": "utilities", "news": "utilities",
    }
    return aliases.get(raw_category, "other")


def fetch_repository(url: str) -> dict:
    request = urllib.request.Request(
        url,
        headers={
            "User-Agent": "Feather-AppsCatalog/2.0",
            "Accept": "application/json",
            "Accept-Encoding": "identity",
            "Connection": "close",
        },
    )

    last_error: Exception | None = None
    for attempt in range(1, 6):
        try:
            chunks: list[bytes] = []
            with urllib.request.urlopen(request, timeout=180) as response:
                while True:
                    chunk = response.read(256 * 1024)
                    if not chunk:
                        break
                    chunks.append(chunk)
            raw = b"".join(chunks)
            value = json.loads(raw.decode("utf-8-sig"))
            if not isinstance(value, dict) or not isinstance(value.get("apps"), list):
                raise ValueError("response is not an AltStore-compatible repository")
            print(f"Fetched {url}: {len(raw):,} bytes", flush=True)
            return value
        except (OSError, TimeoutError, urllib.error.URLError, json.JSONDecodeError, ValueError) as error:
            last_error = error
            print(f"Attempt {attempt}/5 failed for {url}: {error}", file=sys.stderr, flush=True)
            if attempt < 5:
                time.sleep(min(4 * attempt, 20))

    raise RuntimeError(f"could not fetch {url}: {last_error}")


def write_gzip(path: Path, payload: bytes) -> None:
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_bytes(gzip.compress(payload, compresslevel=9, mtime=0))
    temporary.replace(path)


def app_display_name(app: dict) -> str:
    name = str(app.get("name") or "").strip() or "Unknown"
    bundle_id = str(app.get("bundleIdentifier") or "")
    if bundle_id.endswith("Beta"):
        name += " (BETA)"
    return name


def main() -> None:
    RESOURCES.mkdir(parents=True, exist_ok=True)
    bundled_sources: list[dict] = []
    indexed_apps: list[dict] = []
    seen_apps: set[str] = set()
    source_counts: dict[str, int] = {}
    generated_repository_files: set[str] = set()

    for source_index, feed_url in enumerate(FEEDS):
        repository = fetch_repository(feed_url)
        original_apps = repository.get("apps", [])
        usable_apps: list[dict] = []

        for original_app in original_apps:
            if not isinstance(original_app, dict):
                continue
            app = dict(original_app)

            # AltSourceKit requires iconURL. Use the repository icon as a fallback.
            if not app.get("iconURL") and repository.get("iconURL"):
                app["iconURL"] = repository["iconURL"]
            if not isinstance(app.get("iconURL"), str) or not urlparse(app["iconURL"]).scheme:
                continue

            # Feather does not support App Store PAL marketplace entries.
            if app.get("marketplaceID"):
                continue

            usable_apps.append(app)

        if not usable_apps:
            raise ValueError(f"feed contains no usable apps: {feed_url}")

        repository_for_bundle = dict(repository)
        repository_for_bundle["apps"] = usable_apps
        repository_bytes = json.dumps(
            repository_for_bundle, ensure_ascii=False, separators=(",", ":")
        ).encode("utf-8")

        resource_name = f"{REPOSITORY_PREFIX}{source_index}"
        repository_path = RESOURCES / f"{resource_name}.json.gz"
        write_gzip(repository_path, repository_bytes)
        generated_repository_files.add(repository_path.name)

        source_url = repository.get("sourceURL")
        if not isinstance(source_url, str) or not urlparse(source_url).scheme:
            source_url = feed_url

        bundled_sources.append({
            "id": source_index,
            "sourceURL": source_url,
            "resourceName": resource_name,
        })

        for app_index, app in enumerate(usable_apps):
            display_name = app_display_name(app)
            bundle_id = str(app.get("bundleIdentifier") or "").strip()
            dedupe_key = f"{bundle_id}|{normalize(display_name)}"
            if dedupe_key in seen_apps:
                continue
            seen_apps.add(dedupe_key)

            indexed_apps.append({
                "id": f"{source_index}:{app_index}:{bundle_id}:{app.get('downloadURL') or ''}",
                "sourceIndex": source_index,
                "appIndex": app_index,
                "bundleIdentifier": bundle_id,
                "appDownloadURL": app.get("downloadURL"),
                "name": display_name,
                "subtitle": app.get("subtitle") or app.get("localizedDescription"),
                "developer": app.get("developerName"),
                "iconURL": app["iconURL"],
                "category": classify_app(app),
            })

        source_counts[feed_url] = len(usable_apps)

    if len(bundled_sources) != len(FEEDS) or len(source_counts) != len(FEEDS):
        raise RuntimeError("not all configured feeds were included")
    if not indexed_apps:
        raise RuntimeError("the generated catalog index is empty")

    # Sort once during generation. The app never has to classify or sort thousands
    # of records on the UI thread when a user opens the catalog or switches tabs.
    indexed_apps.sort(key=lambda item: normalize(item["name"]))

    index_payload = {
        "schemaVersion": 1,
        "sources": bundled_sources,
        "apps": indexed_apps,
    }
    serialized_index = json.dumps(
        index_payload, ensure_ascii=False, separators=(",", ":")
    ).encode("utf-8")
    write_gzip(INDEX_OUTPUT, serialized_index)

    # Validate the exact compressed files consumed by the app before replacing
    # stale outputs or allowing the workflow to commit this snapshot.
    decoded_index = json.loads(gzip.decompress(INDEX_OUTPUT.read_bytes()).decode("utf-8"))
    if len(decoded_index.get("sources", [])) != len(FEEDS):
        raise RuntimeError("generated index has an invalid source count")
    if len(decoded_index.get("apps", [])) != len(indexed_apps):
        raise RuntimeError("generated index app count does not match")

    for source in bundled_sources:
        file_path = RESOURCES / f"{source['resourceName']}.json.gz"
        decoded_repository = json.loads(gzip.decompress(file_path.read_bytes()).decode("utf-8"))
        if not isinstance(decoded_repository.get("apps"), list) or not decoded_repository["apps"]:
            raise RuntimeError(f"invalid repository snapshot: {file_path}")

    # Remove the old combined seed and any obsolete per-source files. Keeping only
    # the compact index plus split repositories avoids bundling duplicate datasets.
    for legacy_path in LEGACY_OUTPUTS:
        legacy_path.unlink(missing_ok=True)
    for old_file in RESOURCES.glob(f"{REPOSITORY_PREFIX}*.json.gz"):
        if old_file.name not in generated_repository_files:
            old_file.unlink(missing_ok=True)

    print("Bundled app counts:")
    for feed, count in source_counts.items():
        print(f"- {feed}: {count:,}")
    print(f"Total source apps: {sum(source_counts.values()):,}")
    print(f"Unique catalog entries: {len(indexed_apps):,}")
    print(f"Uncompressed index size: {len(serialized_index):,} bytes")
    print(f"Compressed index size: {INDEX_OUTPUT.stat().st_size:,} bytes")
    print(f"Total compressed bundle size: {sum((RESOURCES / f).stat().st_size for f in generated_repository_files) + INDEX_OUTPUT.stat().st_size:,} bytes")
    print(f"Index output: {INDEX_OUTPUT}")


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(f"Catalog generation failed: {error}", file=sys.stderr)
        raise

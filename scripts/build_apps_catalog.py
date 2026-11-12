#!/usr/bin/env python3
"""Build the offline Apps Catalog snapshot consumed by Feather."""
from __future__ import annotations

import json
import sys
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

FEEDS = (
    "https://fastsign.dev/repo.json",
    "https://repository.apptesters.org",
    "https://ipa.cypwn.xyz/cypwn.json",
)
OUTPUT = Path("Feather/Resources/AppsCatalogSeed.json")


def fetch_repository(url: str) -> dict:
    request = urllib.request.Request(
        url,
        headers={
            "User-Agent": "Feather-AppsCatalog/1.0",
            "Accept": "application/json",
        },
    )
    with urllib.request.urlopen(request, timeout=120) as response:
        raw = response.read()
    value = json.loads(raw.decode("utf-8-sig"))
    if not isinstance(value, dict) or not isinstance(value.get("apps"), list):
        raise ValueError("response is not an AltStore-compatible repository")
    return value


def main() -> None:
    bundled_items: list[dict] = []
    source_counts: dict[str, int] = {}

    for feed_url in FEEDS:
        repository = fetch_repository(feed_url)
        apps = repository.get("apps", [])
        metadata = {key: value for key, value in repository.items() if key != "apps"}
        source_url = repository.get("sourceURL") or feed_url
        count = 0

        for original_app in apps:
            if not isinstance(original_app, dict):
                continue
            app = dict(original_app)

            # AltSourceKit requires an icon URL for each app. Repositories that
            # define only a repository icon can safely use it as a fallback.
            if not app.get("iconURL") and repository.get("iconURL"):
                app["iconURL"] = repository["iconURL"]
            if not app.get("iconURL"):
                continue

            # Feather does not support App Store PAL marketplace entries.
            if app.get("marketplaceID"):
                continue

            one_app_repository = dict(metadata)
            one_app_repository["apps"] = [app]
            bundled_items.append({
                "sourceURL": source_url,
                "repository": one_app_repository,
            })
            count += 1

        if count == 0:
            raise ValueError(f"feed contains no usable apps: {feed_url}")
        source_counts[feed_url] = count

    if len(source_counts) != len(FEEDS):
        raise RuntimeError("not all configured feeds were included")

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "generatedAt": datetime.now(timezone.utc).isoformat(),
        "sources": bundled_items,
    }
    temporary = OUTPUT.with_suffix(".json.tmp")
    temporary.write_text(
        json.dumps(payload, ensure_ascii=False, separators=(",", ":")) + "\n",
        encoding="utf-8",
    )
    temporary.replace(OUTPUT)

    print("Bundled app counts:")
    for feed, count in source_counts.items():
        print(f"- {feed}: {count}")
    print(f"Total bundled apps: {len(bundled_items)}")
    print(f"Output: {OUTPUT}")


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(f"Catalog generation failed: {error}", file=sys.stderr)
        raise

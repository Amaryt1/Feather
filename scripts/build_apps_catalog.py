#!/usr/bin/env python3
"""Build the offline Apps Catalog snapshot consumed by Feather."""
from __future__ import annotations

import gzip
import json
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

FEEDS = (
    "https://fastsign.dev/repo.json",
    "https://repository.apptesters.org",
    "https://ipa.cypwn.xyz/cypwn.json",
    "https://raw.githubusercontent.com/Nyasami/Ksign/refs/heads/main/repo.json",
    "https://community-apps.sidestore.io/sidecommunity.json",
    "https://github.com/LiveContainer/LiveContainer/releases/download/1.0/apps.json",
)
OUTPUT = Path("Feather/Resources/AppsCatalogSeed.json")
OUTPUT_GZIP = Path("Feather/Resources/AppsCatalogSeed.json.gz")


def fetch_repository(url: str) -> dict:
    request = urllib.request.Request(
        url,
        headers={
            "User-Agent": "Feather-AppsCatalog/1.0",
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
            print(
                f"Attempt {attempt}/5 failed for {url}: {error}",
                file=sys.stderr,
                flush=True,
            )
            if attempt < 5:
                time.sleep(min(4 * attempt, 20))

    raise RuntimeError(f"could not fetch {url}: {last_error}")


def main() -> None:
    bundled_sources: list[dict] = []
    source_counts: dict[str, int] = {}

    for feed_url in FEEDS:
        repository = fetch_repository(feed_url)
        apps = repository.get("apps", [])
        metadata = {key: value for key, value in repository.items() if key != "apps"}
        source_url = repository.get("sourceURL") or feed_url
        usable_apps: list[dict] = []

        for original_app in apps:
            if not isinstance(original_app, dict):
                continue
            app = dict(original_app)

            # Use the repository icon when an individual app has no icon.
            # Keep entries without either icon; Feather renders its placeholder.
            if not app.get("iconURL") and repository.get("iconURL"):
                app["iconURL"] = repository["iconURL"]

            # Feather does not support App Store PAL marketplace entries.
            if app.get("marketplaceID"):
                continue

            usable_apps.append(app)

        if not usable_apps:
            raise ValueError(f"feed contains no usable apps: {feed_url}")

        # Store repository metadata once rather than duplicating it for every app.
        bundled_repository = dict(metadata)
        bundled_repository["apps"] = usable_apps
        bundled_sources.append({
            "sourceURL": source_url,
            "repository": bundled_repository,
        })
        source_counts[feed_url] = len(usable_apps)

    if len(source_counts) != len(FEEDS):
        raise RuntimeError("not all configured feeds were included")

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "generatedAt": datetime.now(timezone.utc).isoformat(),
        "sources": bundled_sources,
    }
    serialized = json.dumps(
        payload, ensure_ascii=False, separators=(",", ":")
    ).encode("utf-8")

    temporary = OUTPUT_GZIP.with_suffix(".gz.tmp")
    temporary.write_bytes(gzip.compress(serialized, compresslevel=9, mtime=0))
    temporary.replace(OUTPUT_GZIP)
    OUTPUT.unlink(missing_ok=True)

    print("Bundled app counts:")
    for feed, count in source_counts.items():
        print(f"- {feed}: {count}")
    print(f"Total bundled apps: {sum(source_counts.values())}")
    print(f"Uncompressed catalog size: {len(serialized):,} bytes")
    print(f"Compressed catalog size: {OUTPUT_GZIP.stat().st_size:,} bytes")
    print(f"Output: {OUTPUT_GZIP}")


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(f"Catalog generation failed: {error}", file=sys.stderr)
        raise

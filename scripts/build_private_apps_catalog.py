#!/usr/bin/env python3
"""Build Feather's independent prebuilt catalog for its four private app feeds."""

from __future__ import annotations

import concurrent.futures
import gzip
import hashlib
import json
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

FEEDS = (
    ("IPAOMTK", "https://ipaomtk-source.shrubhub.workers.dev/ipaomtk.json"),
    ("iOSVizor", "https://iosvizor-source.shrubhub.workers.dev/iosvizor.json"),
    ("AltMaker", "https://raw.githubusercontent.com/RipeStore/altmaker/main/AltMaker.json"),
    ("Ittza7aa", "https://ittza7aa.com/repo.json"),
)

OUTPUT_DIR = Path("catalogs/private-apps")
CATALOG_OUTPUT = OUTPUT_DIR / "catalog.json.gz"
MANIFEST_OUTPUT = OUTPUT_DIR / "manifest.json"
CATALOG_URL = (
    "https://raw.githubusercontent.com/Amaryt1/Feather/main/"
    "catalogs/private-apps/catalog.json.gz"
)


def fetch_repository(feed: tuple[str, str]) -> tuple[str, str, dict]:
    name, url = feed
    request = urllib.request.Request(
        url,
        headers={
            "User-Agent": "Feather-PrivateAppsCatalog/1.0",
            "Accept": "application/json",
            "Accept-Encoding": "identity",
            "Connection": "close",
        },
    )

    last_error: Exception | None = None
    for attempt in range(1, 4):
        try:
            with urllib.request.urlopen(request, timeout=120) as response:
                raw = response.read()
            repository = json.loads(raw.decode("utf-8-sig"))
            if not isinstance(repository, dict):
                raise ValueError("repository response is not a JSON object")
            apps = repository.get("apps")
            if not isinstance(apps, list) or not apps:
                raise ValueError("repository has no non-empty apps array")
            valid_apps = [app for app in apps if isinstance(app, dict)]
            if not valid_apps:
                raise ValueError("repository contains no valid app objects")
            # Drop only malformed non-object list members. Preserve every app
            # object, including alternate builds and modified app variants.
            repository = dict(repository)
            repository["apps"] = valid_apps
            print(
                f"Fetched {name}: {len(valid_apps):,} valid app records "
                f"({len(raw):,} bytes)",
                flush=True,
            )
            return name, url, repository
        except (
            OSError,
            TimeoutError,
            urllib.error.URLError,
            json.JSONDecodeError,
            UnicodeDecodeError,
            ValueError,
        ) as error:
            last_error = error
            print(
                f"Attempt {attempt}/3 failed for {name} ({url}): {error}",
                file=sys.stderr,
                flush=True,
            )
            if attempt < 3:
                time.sleep(attempt * 4)

    raise RuntimeError(f"could not build catalog: {name} failed: {last_error}")


def atomic_write(path: Path, content: bytes) -> None:
    temporary = path.with_name(path.name + ".tmp")
    temporary.write_bytes(content)
    temporary.replace(path)


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    # Fetch every feed concurrently, but preserve the configured source order.
    with concurrent.futures.ThreadPoolExecutor(max_workers=len(FEEDS)) as executor:
        fetched = list(executor.map(fetch_repository, FEEDS))

    if len(fetched) != 4:
        raise RuntimeError("the private catalog must contain exactly four feeds")

    generated_at = datetime.now(timezone.utc).isoformat()
    sources = []
    app_count = 0
    source_summary = []

    for name, url, repository in fetched:
        apps = repository["apps"]
        # Keep the original repository and every app record intact. In particular,
        # do not deduplicate by display name or bundle identifier in this builder.
        sources.append({
            "sourceURL": url,
            "repository": repository,
        })
        app_count += sum(isinstance(app, dict) for app in apps)
        source_summary.append({
            "name": name,
            "sourceURL": url,
            "appCount": len(apps),
        })

    # Keep the catalog bytes deterministic. The generation timestamp belongs
    # in the manifest, not in the large payload, so unchanged feeds do not force
    # every client to download the full snapshot again.
    payload = {
        "schemaVersion": 1,
        "sources": sources,
    }
    serialized = json.dumps(
        payload,
        ensure_ascii=False,
        separators=(",", ":"),
    ).encode("utf-8")
    compressed = gzip.compress(serialized, compresslevel=9, mtime=0)
    if len(compressed) >= 90 * 1024 * 1024:
        raise RuntimeError(
            "compressed catalog exceeds the safe GitHub repository file limit; "
            "publish per-source shards instead of committing an oversized file"
        )

    # Validate the exact gzip artifact before publishing either output.
    decoded = json.loads(gzip.decompress(compressed).decode("utf-8"))
    if decoded.get("schemaVersion") != 1 or len(decoded.get("sources", [])) != 4:
        raise RuntimeError("generated catalog failed its schema/source validation")
    for source in decoded["sources"]:
        repository = source.get("repository")
        if not isinstance(repository, dict) or not isinstance(repository.get("apps"), list):
            raise RuntimeError("generated catalog contains an invalid repository")

    digest = hashlib.sha256(compressed).hexdigest()
    if MANIFEST_OUTPUT.exists():
        try:
            previous_manifest = json.loads(MANIFEST_OUTPUT.read_text(encoding="utf-8"))
            if previous_manifest.get("sha256") == digest:
                generated_at = previous_manifest.get("generatedAt") or generated_at
        except (OSError, json.JSONDecodeError):
            pass

    manifest = {
        "schemaVersion": 1,
        "generatedAt": generated_at,
        "catalogURL": CATALOG_URL,
        "sha256": digest,
        "compressedBytes": len(compressed),
        "uncompressedBytes": len(serialized),
        "sourceCount": 4,
        "appCount": app_count,
        "sources": source_summary,
    }
    manifest_bytes = json.dumps(
        manifest,
        ensure_ascii=False,
        indent=2,
    ).encode("utf-8") + b"\n"

    # Write the catalog first and the manifest last. The manifest hash prevents
    # clients from accepting a partially written or mismatched snapshot.
    atomic_write(CATALOG_OUTPUT, compressed)
    atomic_write(MANIFEST_OUTPUT, manifest_bytes)

    print("Private four-feed catalog generated successfully.")
    print(f"Sources: {len(sources)}")
    print(f"App records (before conservative UI deduplication): {app_count:,}")
    print(f"Uncompressed size: {len(serialized):,} bytes")
    print(f"Compressed size: {len(compressed):,} bytes")
    print(f"SHA-256: {digest}")
    print(f"Catalog: {CATALOG_OUTPUT}")
    print(f"Manifest: {MANIFEST_OUTPUT}")


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(f"Private catalog generation failed: {error}", file=sys.stderr)
        raise

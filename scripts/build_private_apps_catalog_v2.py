#!/usr/bin/env python3
"""Build a versioned, per-source lightweight catalog for AMARYT STORE.

This is an opt-in v2 artifact and never overwrites the production v1 manifest.
Each source is a separately cached gzip shard. Only changed shards are rewritten.
"""
from __future__ import annotations
import gzip
import hashlib
import json
import os
from pathlib import Path

from build_private_apps_catalog import FEEDS, fetch_repository, atomic_write

OUT = Path("catalogs/private-apps/v2")
BASE = "https://raw.githubusercontent.com/Amaryt1/Feather/main/catalogs/private-apps/v2/"
APPS_PER_SHARD = 250

def encode(value):
    return json.dumps(value, ensure_ascii=False, separators=(",", ":"), sort_keys=True).encode("utf-8")

def build():
    OUT.mkdir(parents=True, exist_ok=True)
    previous_path = OUT / "manifest.json"
    previous = json.loads(previous_path.read_text()) if previous_path.exists() else {}
    old_shards = {x["sourceURL"]: x for x in previous.get("sources", [])}
    result = []
    for name, url in FEEDS:
        _, _, repo = fetch_repository((name, url))
        # Each page preserves repository metadata but contains at most 250 apps.
        # A changed page gets a new content-addressed URL; unchanged pages stay cached.
        apps = repo["apps"]
        metadata = {key: value for key, value in repo.items() if key != "apps"}
        pages = []
        for offset in range(0, len(apps), APPS_PER_SHARD):
            page = {"sourceURL": url, "repository": {**metadata, "apps": apps[offset:offset + APPS_PER_SHARD]}}
            compressed = gzip.compress(encode(page), compresslevel=6, mtime=0)
            sha = hashlib.sha256(compressed).hexdigest()
            filename = f"{sha}.json.gz"
            target = OUT / filename
            if not target.exists():
                atomic_write(target, compressed)
            pages.append({"sha256": sha, "url": BASE + filename,
                          "compressedBytes": len(compressed),
                          "appCount": len(page["repository"]["apps"])})
        result.append({"name": name, "sourceURL": url, "appCount": len(apps),
                       "pages": pages})
        previous_pages = old_shards.get(url, {}).get("pages", [])
        old_hashes = {p["sha256"] for p in previous_pages}
        changed = sum(p["sha256"] not in old_hashes for p in pages)
        print(f"{name}: {len(apps)} apps; {len(pages)} pages; {changed} changed pages")
    manifest = {"schemaVersion": 2, "sources": result,
                "revision": hashlib.sha256(encode(result)).hexdigest()}
    new = encode(manifest) + b"\n"
    if not previous_path.exists() or previous_path.read_bytes() != new:
        atomic_write(previous_path, new)
    print(f"v2 revision: {manifest['revision']}")

if __name__ == "__main__":
    build()

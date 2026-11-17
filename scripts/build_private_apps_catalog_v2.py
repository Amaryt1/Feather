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
MAX_SHARD = 8 * 1024 * 1024

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
        # Preserve the full AltStore repository structure for client compatibility.
        # Chunking into individual app pages is the next protocol revision.
        raw = encode({"sourceURL": url, "repository": repo})
        compressed = gzip.compress(raw, compresslevel=6, mtime=0)
        if len(compressed) > MAX_SHARD:
            raise ValueError(f"{name}: shard too large ({len(compressed)} bytes); requires app-level pagination")
        sha = hashlib.sha256(compressed).hexdigest()
        filename = f"{sha}.json.gz"
        target = OUT / filename
        if not target.exists():
            atomic_write(target, compressed)
        result.append({"name": name, "sourceURL": url, "sha256": sha,
                       "url": BASE + filename, "compressedBytes": len(compressed),
                       "appCount": len(repo["apps"])})
        print(f"{name}: {len(repo['apps'])} apps; changed={old_shards.get(url, {}).get('sha256') != sha}")
    manifest = {"schemaVersion": 2, "sources": result,
                "revision": hashlib.sha256(encode(result)).hexdigest()}
    new = encode(manifest) + b"\n"
    if not previous_path.exists() or previous_path.read_bytes() != new:
        atomic_write(previous_path, new)
    print(f"v2 revision: {manifest['revision']}")

if __name__ == "__main__":
    build()

# AppTesters large-source pilot (disabled by default)

The original feed is `https://repository.apptesters.org/`.

The catalog builder now accepts `AMARYT_ENABLE_APPTESTERS=1` to include AppTesters in the **same main Apps catalog**, alongside existing feeds. The default is `0` so production behavior is unchanged. No IPA binaries are mirrored.

## Safe test

1. On a test branch, run `AMARYT_ENABLE_APPTESTERS=1 python scripts/build_private_apps_catalog.py`.
2. Verify that the remote feed returns compatible AltStore JSON and the generated gzip size stays below the builder's safety limit.
3. Benchmark download, JSON decode, index construction, memory, and first visible results on a real iPhone.
4. **Do not publish the resulting manifest to main before changing the iOS client's expected feed URLs/source count**. The current client requires the exact source set and will reject a 3-source snapshot.
5. To revert, unset `AMARYT_ENABLE_APPTESTERS` and rebuild; or revert commit `67f311e`. Existing two-source behavior is preserved.

## Important limitation

This is an opt-in ingestion pilot, **not** the promised delta-sync/sharded catalog architecture. It does not yet solve large-catalog cold-start cost. Production rollout requires versioned shards or lightweight index, detail-on-demand, incremental updates, and a fallback to the existing two-source catalog. Do not enable it in production until those changes and device benchmarks are complete.

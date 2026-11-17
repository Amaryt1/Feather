# AMARYT Catalog API — isolated Xcode pilot

This branch is experimental. It does not replace the existing Feather store or modify signing, certificates, installation, library, or persisted sources.

## Run

1. Check out `experiment/catalog-api-integration` in Xcode.
2. Edit Scheme → Run → Arguments Passed On Launch → add `-AMARYTCatalogPreview`.
3. Build and run on a real iPhone. The app opens the read-only API preview instead of the regular store for this launch.
4. Confirm the first page loads, tap **Load next 50**, search the loaded pages, and tap a card to inspect its detail JSON.
5. Remove the launch argument to restore normal Feather behavior.

## Known limitations

- Search filters **already loaded** pages only, not the complete remote index.
- Details are raw read-only JSON; no IPA installation is connected.
- The API must serve `api/manifest.json`, `api/pages/000000.json`, and detail paths from the manifest.
- No Xcode build or real-device timing has been executed by this change. Do not merge until compile, network, and performance tests pass.
- If the API is unavailable, the preview shows an error and Retry; the normal store is unaffected.
- GitHub Pages is static; updates depend on the separate API repository's publishing workflow.

## Acceptance tests

- Cold and warm launch; offline and failed network; next-page pagination and page boundaries.
- Inspect distinct IPA variants and verify no unique application was lost by server-side deduplication.
- Verify icon rendering, large-source memory usage, and scrolling on an iPhone.
- Verify normal Feather without the launch argument remains unchanged.
- Keep this PR draft until Xcode compile and real-device checks are complete.

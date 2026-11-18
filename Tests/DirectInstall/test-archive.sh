#!/usr/bin/env bash
set -euo pipefail
dependency="${1:?Supply the pinned ZIPFoundation checkout}"
workspace="$(mktemp -d)"
trap 'rm -rf "$workspace"' EXIT
swiftc -O -swift-version 5 -emit-library -emit-module -module-name ZIPFoundation \
    -emit-module-path "$workspace/ZIPFoundation.swiftmodule" -I "$dependency/Sources/CZLib" \
    -Xcc -D_GNU_SOURCE "$dependency"/Sources/ZIPFoundation/*.swift -o "$workspace/libZIPFoundation.so" -lz
swiftc -O -I "$workspace" -I "$dependency/Sources/CZLib" -L "$workspace" -lZIPFoundation \
    Feather/DirectInstall/Direct{Policy,Archive}.swift Tests/DirectInstall/ArchiveTests.swift -o "$workspace/check"
LD_LIBRARY_PATH="$workspace:${LD_LIBRARY_PATH:-}" "$workspace/check" --large

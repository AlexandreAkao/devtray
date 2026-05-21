#!/usr/bin/env bash
# Runs swift test for every Swift Package in the workspace.
set -euo pipefail

PACKAGES=(
    "Packages/DevTrayCore"
    "Packages/DevTrayUI"
    "Packages/Tools/JWTTool"
    "Packages/Tools/JSONTool"
    "Packages/Tools/Base64Tool"
    "Packages/Tools/URLTool"
    "Packages/Tools/HashTool"
    "Packages/Tools/UUIDTool"
    "Packages/Tools/TimestampTool"
)

failed=()
for pkg in "${PACKAGES[@]}"; do
    if [[ ! -d "$pkg" ]]; then
        echo "=== Skipping $pkg (not yet created) ==="
        continue
    fi
    if ! grep -q "testTarget" "$pkg/Package.swift" 2>/dev/null; then
        echo "=== Skipping $pkg (no test target) ==="
        continue
    fi
    echo "=== Testing $pkg ==="
    if ! (cd "$pkg" && swift test); then
        failed+=("$pkg")
    fi
done

if (( ${#failed[@]} > 0 )); then
    echo "FAILED packages: ${failed[*]}"
    exit 1
fi
echo "All package tests passed."

#!/usr/bin/env bash
# Runs swift test for every Swift Package in the workspace.
#
# NOTE: xcodebuild caches local SPM package state. If a Packages/* edit
# does not reflect in the next test run, prepend `clean` to the xcodebuild
# command (`xcodebuild clean build ...`). We do NOT clean by default because
# it is slow. See devtray-state memory for context.
set -euo pipefail

PACKAGES=(
    "Packages/DevTrayCore"
    "Packages/DevTrayUI"
    "Packages/DevTrayStorage"
    "Packages/Tools/JWTTool"
    "Packages/Tools/JSONTool"
    "Packages/Tools/Base64Tool"
    "Packages/Tools/URLTool"
    "Packages/Tools/HashTool"
    "Packages/Tools/UUIDTool"
    "Packages/Tools/TimestampTool"
    "Packages/Tools/SnippetsTool"
    "Packages/Tools/RegexTool"
    "Packages/Tools/DiffTool"
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

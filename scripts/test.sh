#!/usr/bin/env bash
# Runs swift test for every Swift Package in the workspace.
set -euo pipefail

PACKAGES=(
    "Packages/DevTrayCore"
    "Packages/DevTrayUI"
    "Packages/Tools/JWTTool"
    "Packages/Tools/JSONTool"
    "Packages/Tools/Base64Tool"
)

failed=()
for pkg in "${PACKAGES[@]}"; do
    if [[ -d "$pkg" ]]; then
        echo "=== Testing $pkg ==="
        if ! (cd "$pkg" && swift test); then
            failed+=("$pkg")
        fi
    else
        echo "=== Skipping $pkg (not yet created) ==="
    fi
done

if (( ${#failed[@]} > 0 )); then
    echo "FAILED packages: ${failed[*]}"
    exit 1
fi
echo "All package tests passed."

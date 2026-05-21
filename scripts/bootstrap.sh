#!/usr/bin/env bash
set -euo pipefail

if ! command -v xcodegen >/dev/null 2>&1; then
    echo "Installing XcodeGen via Homebrew..."
    brew install xcodegen
fi

echo "Generating Xcode project..."
xcodegen generate

echo "Resolving Swift packages..."
xcodebuild -resolvePackageDependencies -project DevTray.xcodeproj > /dev/null

echo "Done. Open DevTray.xcodeproj to start."

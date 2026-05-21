# DevTray

A native macOS menu bar app with developer utilities: JWT, JSON, snippets, hashing, and more.

## Requirements

- macOS 14 (Sonoma) or later
- Xcode 15.4 or later
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (installed automatically by bootstrap script)

## Getting started

```bash
./scripts/bootstrap.sh
open DevTray.xcodeproj
```

## Running tests

```bash
./scripts/test.sh                # all package tests
xcodebuild test \                # app + UI smoke tests
  -project DevTray.xcodeproj \
  -scheme DevTrayApp \
  -destination 'platform=macOS'
```

## Design and plans

- Spec: [docs/superpowers/specs/2026-05-20-devtray-design.md](docs/superpowers/specs/2026-05-20-devtray-design.md)
- Plans: [docs/superpowers/plans/](docs/superpowers/plans/)

## License

MIT

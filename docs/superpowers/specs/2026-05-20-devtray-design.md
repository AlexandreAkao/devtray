# DevTray — Design Document

**Date:** 2026-05-20
**Status:** Design (awaiting plan)
**Author:** Brainstorming session with user

## Summary

DevTray is a native macOS menu bar app that bundles 13 developer utilities (JWT, JSON, snippets, base64, URL, hash, UUID/ULID, timestamp, regex, diff, color, cron, YAML) behind a popover and a Spotlight-style command palette invoked by a global hotkey. The app is distributed publicly via Developer ID + Sparkle (not the Mac App Store), is open source under MIT, and is built in Swift + SwiftUI as a modular Swift Package workspace where each tool is its own package.

## Goals

- Fast, native feel for high-frequency dev utilities — popover opens instantly, tools respond on keystroke.
- Privacy by default — no telemetry, no remote crash reporting, no persistence of tool inputs (only explicit snippets).
- Modular architecture so adding a tool is a self-contained change.
- Distributable publicly with code signing, notarization, and auto-update.

## Non-goals

- Mac App Store distribution (sandboxing constraints harm core flows).
- Sync across machines in v1 (snippets are local; manual export/import provided).
- iOS/iPadOS/Linux/Windows ports.
- Third-party plugin runtime in v1 (modules are first-party, compiled in).
- Custom theming (follows system light/dark only).

## Decisions (from brainstorming)

| # | Decision | Choice | Rationale |
|---|---|---|---|
| 1 | Audience | Public distribution | User intends to ship for any developer to install |
| 2 | Feature set v1 | 13 tools (see below) | Explicit user selection |
| 3 | Stack | Swift + SwiftUI (native) | Best fit for always-running tray app; small bundle; native shortcuts/clipboard |
| 4 | UX | Hybrid: popover (primary) + Spotlight (secondary via global hotkey) | Familiar popover for browse; spotlight for power use |
| 5 | Distribution | Developer ID + Sparkle | No sandbox limits on hotkey/clipboard; standard for dev tools |
| 6 | Persistence | Local SQLite via GRDB | Simple, fast; sync deferred |
| 7 | Code structure | Modular Swift Package Manager workspace | Per-tool packages enable fast tests and clear boundaries |
| 8 | Min macOS | 14 (Sonoma) | `MenuBarExtra(.window)` stable; ~85% market share |
| 9 | Open source | Yes, MIT | Public dev tool; encourages contributions and trust |
| 10 | Telemetry | None in v1 | Privacy-first |

## Feature set (v1)

| ID | Name | Notes |
|---|---|---|
| `jwt` | JWT encode/decode | Decode header+payload; verify HS256/RS256; encode with claims |
| `json` | JSON formatter/validator | Pretty-print, minify, validate, jq-like query (later iteration) |
| `snippets` | Snippets | Persistent; tags; FTS search; favorites |
| `base64` | Base64 encode/decode | Text and file |
| `url` | URL encode/decode | Component-level (query, path, full) |
| `hash` | Hash | MD5, SHA-1, SHA-256, SHA-512 of string or file |
| `uuid` | UUID/ULID generator | v4, v7, ULID; batch copy |
| `timestamp` | Timestamp converter | Unix epoch ↔ ISO 8601; timezones |
| `regex` | Regex tester | Live match, groups, replace |
| `diff` | Text diff | Side-by-side or unified |
| `color` | Color converter | HEX ↔ RGB ↔ HSL; picker |
| `cron` | Cron expression | Parse + human description + next executions |
| `yaml` | YAML ↔ JSON | Bidirectional |

Each tool ships as a Swift package with two products: `XxxToolKit` (pure engine) and `XxxTool` (SwiftUI view).

## Architecture

### Workspace layout

```
devtray/
├── App/
│   └── DevTrayApp/                # Xcode project (main app target)
│       ├── DevTrayApp.swift       # @main, bootstrap, DI
│       ├── Info.plist
│       └── DevTrayApp.entitlements
├── Packages/
│   ├── DevTrayCore/               # Tool protocol, Registry, models, hotkey wrapper
│   ├── DevTrayUI/                 # Shared SwiftUI components (CodeEditor, ResultPane, SearchField, ToastHost)
│   ├── DevTrayStorage/            # GRDB-backed SnippetStore, migrations, FTS5 setup
│   ├── DevTraySpotlight/          # Centered NSWindow + fuzzy search + smart paste
│   └── Tools/
│       ├── JWTTool/   (+ JWTToolKit)
│       ├── JSONTool/  (+ JSONToolKit)
│       ├── SnippetsTool/
│       ├── Base64Tool/   (+ Base64ToolKit)
│       ├── URLTool/      (+ URLToolKit)
│       ├── HashTool/     (+ HashToolKit)
│       ├── UUIDTool/     (+ UUIDToolKit)
│       ├── TimestampTool/ (+ TimestampToolKit)
│       ├── RegexTool/    (+ RegexToolKit)
│       ├── DiffTool/     (+ DiffToolKit)
│       ├── ColorTool/    (+ ColorToolKit)
│       ├── CronTool/     (+ CronToolKit)
│       └── YAMLTool/     (+ YAMLToolKit)
├── Tests/                          # Cross-package integration & smoke
├── scripts/                        # build.sh, sign.sh, notarize.sh, release.sh
├── .github/workflows/              # CI: test, build, sign, notarize, release
└── docs/
```

### Tool protocol

```swift
public protocol Tool: Identifiable, Sendable {
    static var id: ToolID { get }
    static var displayName: String { get }
    static var icon: Image { get }                  // SF Symbol
    static var keywords: [String] { get }           // for spotlight fuzzy match
    static var category: ToolCategory { get }

    @MainActor associatedtype Content: View
    @MainActor static func makeView() -> Content
}

public struct ToolID: Hashable, RawRepresentable, Sendable { public let rawValue: String }
public enum ToolCategory: String, CaseIterable, Sendable {
    case encoding, formatting, crypto, storage, time, text
}
```

### Registry

A single `ToolRegistry` (observed object) holds the registered tools. Tools register at app bootstrap. The Registry is injected via SwiftUI environment.

```swift
public final class ToolRegistry: ObservableObject {
    public private(set) var tools: [AnyTool] = []
    public func register<T: Tool>(_ tool: T.Type)
    public func find(byID id: ToolID) -> AnyTool?
    public func search(_ query: String) -> [AnyTool]   // fuzzy on displayName + keywords
}
```

### Engine/View separation

Each `XxxToolKit` is a pure-Swift target with no UI dependencies. Engines expose `Result<T, ToolError>` returning functions. Engine tests run via `swift test` without spinning up SwiftUI.

```swift
// JWTToolKit
public enum JWTEngine {
    public static func decode(_ raw: String) -> Result<DecodedJWT, ToolError>
    public static func encode(header: [String: Any], payload: [String: Any], key: SigningKey) -> Result<String, ToolError>
}
```

## UI surfaces

### Tray (MenuBarExtra)

```swift
MenuBarExtra("DevTray", systemImage: "wrench.adjustable") {
    PopoverRoot().frame(width: 420, height: 540)
}
.menuBarExtraStyle(.window)
```

- Template icon (light/dark adaptive).
- Left-click opens the popover.

### Popover layout

Fixed 420×540, two-pane:

- **Header (top, 40pt):** local search (`⌘F`) filtering the sidebar + ⚙ gear opening Preferences.
- **Sidebar (left, 120pt):** vertical list grouped by category; favorites pinned on top; per-tool icon + name; `Cmd+1…9` jumps to the first nine.
- **Workspace (right, fills):** the currently selected tool's view, owned by the tool package.
- **Footer (bottom, 32pt):** three "frequent tools" chips (computed from `tool_usage` table) + version label.

### Spotlight panel

Triggered by a configurable global hotkey (default ⌥⌘Space). Implemented as a borderless `NSPanel` at level `.popUpMenu` with vibrancy, animated from the top center.

- Single search field reads the current clipboard on invoke.
- **Smart paste:** simple heuristic detection of clipboard contents promotes the right tool to the top result (e.g. starts with `eyJ` and contains two dots → JWT decode preloaded). Heuristics live in `DevTrayCore/SmartPaste.swift`.
- ⏎ on a result opens that tool with the clipboard preloaded; ⌘⏎ opens the popover instead.

### Preferences

Standard SwiftUI `Settings` scene, tabs: **General**, **Shortcuts**, **Tools** (enable/disable individual tools), **About / Updates**.

## Data and persistence

### Location

`~/Library/Application Support/DevTray/`:
- `devtray.sqlite` — main database
- `Logs/` — rotating, 7 days, `os.Logger` mirror
- Preferences via `UserDefaults`

### Schema

```sql
CREATE TABLE snippets (
    id            TEXT PRIMARY KEY,
    title         TEXT NOT NULL,
    content       TEXT NOT NULL,
    language      TEXT,
    tags          TEXT NOT NULL DEFAULT '[]',
    is_favorite   INTEGER NOT NULL DEFAULT 0,
    created_at    REAL NOT NULL,
    updated_at    REAL NOT NULL,
    use_count     INTEGER NOT NULL DEFAULT 0,
    last_used_at  REAL
);
CREATE INDEX idx_snippets_updated  ON snippets(updated_at DESC);
CREATE INDEX idx_snippets_favorite ON snippets(is_favorite, updated_at DESC);

CREATE VIRTUAL TABLE snippets_fts USING fts5(
    title, content, tags,
    content='snippets', content_rowid='rowid'
);
-- triggers maintain FTS in sync

CREATE TABLE tool_usage (
    tool_id  TEXT NOT NULL,
    used_at  REAL NOT NULL,
    PRIMARY KEY (tool_id, used_at)
);

CREATE TABLE migrations (
    version    INTEGER PRIMARY KEY,
    applied_at REAL NOT NULL
);
```

### Access layer

```swift
public protocol SnippetStore: Sendable {
    func save(_ snippet: Snippet) async throws
    func delete(id: Snippet.ID) async throws
    func all() async throws -> [Snippet]
    func search(_ query: String) async throws -> [Snippet]
    func incrementUseCount(id: Snippet.ID) async throws
}
public final class SQLiteSnippetStore: SnippetStore { /* GRDB implementation */ }
```

Tools depend on the `SnippetStore` protocol, not on GRDB.

### Privacy of tool inputs

**Nothing the user types into any tool is persisted**, with the explicit exception of snippets the user saves. `tool_usage` records only that a tool was used and when — never its contents.

### Backup / migration between machines

Settings → **Export snippets** writes a JSON file. Settings → **Import snippets** reads it back. This is the v1 path between Macs; CloudKit sync is a future option.

### Migrations

`GRDB.DatabaseMigrator` with forward-only versioned migrations. Each schema change adds one. On corruption at open: rename the file to `devtray.sqlite.corrupted-<date>` and create a fresh database, surfacing a one-time notice in the UI.

## Dependencies

| Package | Purpose | Justification |
|---|---|---|
| GRDB.swift | SQLite + FTS5 | De facto standard; safe API; native FTS support |
| Sparkle 2 | Auto-update | Standard for Developer ID apps; EdDSA-signed updates |
| KeyboardShortcuts (Sindre Sorhus) | Global hotkey + capture UI | Small, well-maintained, pre-built capture UI |
| Highlightr | Syntax highlight in CodeEditor | ~200KB; covers JSON/Swift/etc via highlight.js |
| swift-collections | OrderedDictionary, Deque | Apple-maintained |
| Yams | YAML parsing | Only viable Swift option |

**Intentionally not used:**
- External JWT library — decoding is base64url+JSON; signing via CryptoKit. Avoids a security-sensitive transitive dep.
- Logging framework — `os.Logger` is sufficient.
- Crash reporting SDK — privacy-first; can be added opt-in later.

## System integration

| Concern | Mechanism |
|---|---|
| Tray icon | `MenuBarExtra` (SwiftUI, macOS 14+) |
| Spotlight window | `NSPanel`, level `.popUpMenu`, animated |
| Global hotkey | KeyboardShortcuts; uses NSEvent global monitor (no Accessibility permission needed) |
| Clipboard read | `NSPasteboard.general` on spotlight invoke |
| Notarization | `xcrun notarytool` in CI |
| DMG | `create-dmg` |
| Update feed | Sparkle pulls `appcast.xml` from GitHub Releases |

## Entitlements and signing

- **Not sandboxed.** Developer ID distribution permits this; required because hotkey + clipboard flows would be hampered by sandbox.
- Hardened runtime enabled (notarization requirement).
- `com.apple.security.network.client` — for Sparkle update checks.
- No other special entitlements.

## Error handling

### Categories

```swift
public enum ToolError: LocalizedError, Equatable {
    case parseFailure(reason: String, hint: String?)
    case invalidInput(reason: String)
    case unsupportedOperation(String)
    case dependencyMissing(String)
    case storageFailure(underlying: Error)
}
```

`parseFailure` and `invalidInput` are expected on every keystroke and surface as inline non-modal feedback (subtle banner near the field). `storageFailure` is rare and surfaces as an alert. Errors never crash the app.

### Inline pattern

Each tool view holds a `Result<T, ToolError>` and renders a `ResultPane` that handles success and error rendering uniformly.

### Logging

`os.Logger` per subsystem; user inputs marked `privacy: .private`. Logs mirror to `Logs/` for the last 7 days.

### Tool view crashes

A `ToolErrorBoundary` wraps each tool view in the workspace. If a tool view throws, the app shows "This tool ran into a problem" with a button to file an issue, leaving the rest of the app intact.

### No crash reporting in v1

Users can attach Console.app logs to bug reports manually. Sentry-style telemetry may be added later as opt-in.

## Testing

### Targets

- **Engine unit tests (XxxToolKit):** ≥ 90% coverage. Run via `swift test` per package, parallelized in CI.
- **Storage tests:** `SQLiteSnippetStore` against an in-memory `DatabaseQueue`; migration fixtures for each prior schema version.
- **Snapshot tests:** swift-snapshot-testing for the main tool views (1–2 representative states each). Catches obvious visual regressions; no pixel-perfect targets.
- **Smoke E2E:** three XCUITest scenarios — (1) launch shows tray icon, (2) clicking icon opens popover, (3) global hotkey opens spotlight.
- **Manual checklist:** ~30-minute pre-release pass (popover open, every tool exercised, hotkey, simulated Sparkle update).

### CI

GitHub Actions:
- **On PR:** matrix of `swift test` per package + SwiftFormat lint.
- **On `v*` tag:** build release → sign with Developer ID → notarize → produce DMG → upload to GitHub Releases → update `appcast.xml`.

Target end-to-end CI < 5 min on PRs.

## Defaults

| Setting | Default |
|---|---|
| Minimum macOS | 14 (Sonoma) |
| Global hotkey | ⌥⌘Space (user-configurable) |
| Theme | Follow system (no custom themes in v1) |
| Localization | English + pt-BR |
| Telemetry | Off (none collected) |
| Crash reporting | Local logs only |
| Update channel | Stable only (beta channel deferred) |
| Versioning | SemVer; pre-1.0 during development |
| License | MIT |

## Release phasing (proposed for the implementation plan)

The spec assumes the full v1 surface, but the plan should phase delivery:

- **v0.1 (foundation):** App + tray + popover (without "frequent tools" footer initially) + 3 tools (JWT, JSON, Base64) — validates architecture end-to-end.
- **v0.2:** + URL, Hash, UUID/ULID, Timestamp.
- **v0.3:** `DevTrayStorage` (minimum: `tool_usage` table) → enables "frequent tools" footer and usage-based ranking.
- **v0.4:** Spotlight + global hotkey + smart paste (uses `tool_usage` for ranking).
- **v0.5:** Snippets + remaining storage (snippets table + FTS) + SnippetsTool.
- **v0.6:** + Regex, Diff, Color, Cron, YAML.
- **v0.7:** Sparkle + auto-update + release CI.
- **v1.0:** Polish, docs, landing page, public announcement.

## Open questions

None blocking. The implementation plan will decide:
- Specific UI choice for the code editor (TextKit 2 vs. a webview-backed Monaco-style editor).
- Final snippet export JSON shape (needs to be stable across versions before public release).
- Spotlight ranking weights (recency vs. frequency vs. fuzzy-match score).

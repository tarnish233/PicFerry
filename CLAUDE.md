# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

PicFerry is a native macOS **menu-bar image/file uploader** for GitHub and Gitee image hosting. It is a single AppKit executable (`com.tarnish233.PicFerry`) that behaves as **both a GUI app and a CLI**, plus a `picferry://` URL scheme and AppleScript support. Requires Xcode 26, deploys only to **macOS 26+, arm64**. Derived from the [uPic project](https://github.com/gee1k/uPic) (Apache 2.0 — preserve `NOTICE`).

## Build & run

```bash
# Command-line debug build (no signing identity needed)
xcodebuild build -project PicFerry.xcodeproj -scheme 'PicFerry(Release)' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO

# Resolve SPM dependencies pinned in Package.resolved
xcodebuild -resolvePackageDependencies -project PicFerry.xcodeproj
```

- There is **no XCTest target**. Verification = it compiles, plus manual exercise of the affected path (upload, clipboard output, preferences persistence, CLI, URL scheme, localized UI). Run from Xcode for menu-bar/permissions debugging.
- Localized UI schemes: `PicFerry(简体中文)` and `PicFerry(繁体中文)`.
- Package a release: `./Scripts/create-dmg.sh` (reads `build/release/PicFerry.app`).
- Install the CLI shim: `./Scripts/install-cli.sh` → `~/.local/bin/picferry` (a thin wrapper that execs the app's embedded executable).

## Architecture

### Dual entry point (GUI vs CLI)
`AppDelegate.applicationWillFinishLaunching` calls `Cli.shared.parseInvocation()`, which inspects `CommandLine.arguments` and returns `.gui`, `.upload([paths])`, or `.exit(status)`. When invoked as CLI the app runs `Cli.shared.startUpload` and returns *before* setting up the status bar. The `picferry` shell shim sets `PICFERRY_CLI_NAME` so usage output shows the right program name. So the same code path serves the menu bar, the CLI, and (via `handleGetURLEvent`) the `picferry://` URL scheme.

### Upload flow (the spine)
`BaseUploader.upload(url:)` / `BaseUploader.upload(data:)` are the **single unified entry points** for every upload trigger (menu, drag, clipboard, screenshot, CLI, URL scheme). They resolve the default `Host`, enforce size limits, then dispatch on `host.type` via a `switch` to the provider singleton (`GithubUploader.shared` / `GiteeUploader.shared`). Providers subclass `BaseUploader` and report back through its `start()` / `completed(...)` / `faild(...)` methods, which hop to `@MainActor` and call `AppDelegate.uploadStart/uploadCompleted/uploadFaild`. `completed` also writes a thumbnailed `HistoryThumbnailModel` to history.

`BaseUploaderUtil` holds the provider-agnostic helpers: PNG/JPEG compression (via bundled `libminipng`), filename/`saveKey` templating with variable substitution, and output-URL formatting (URL / Markdown / HTML).

### Adding a provider
Each provider lives entirely under `Models/<Provider>/` with three files: `<Provider>Uploader.swift`, `<Provider>HostConfig.swift`, `<Provider>Util.swift`. To add one, wire it in at these seams (grep `/* 有新的图床在这里进行判断调用 */`):
1. Add a case to `HostType` (`Models/HostType.swift`), including `legacyIntValue` mapping if migrating.
2. Add the `switch` case in both `BaseUploader.upload(url:)` and `upload(data:)`.
3. Add the config factory case in `HostConfig.create(type:)`.
4. Declare which config fields are secrets via the config's `secretKeys` (see credential storage below).

### Config, credentials, persistence
- **`ConfigManager.shared`** (`@MainActor`): app-wide config, host list, and history caching. Simple preferences use `Defaults[...]` keys defined in `Utils/PreferenceKey.swift` (UserDefaults wrapper).
- **`HostCredentialStore`**: provider secrets are kept in the **Keychain, never UserDefaults**. `hydrate(_:)` loads secrets into a `HostConfig`; `save(_:)` persists them. Serialization of hosts uses `includeSecrets:` to keep tokens out of exported/plain data.
- **`DBManager`** (WCDB / SQLCipher): SQLite storage for upload history (`HistoryThumbnailModel`) and custom output formats (`OutputFormatModel`).
- **`DiskPermissionManager`**: security-scoped bookmarks for sandboxed file access. Note the **macOS 26.0 root-bookmark bug workaround** (`shouldUseRootSubdirectoryWorkaround`) — 26.0 falls back to per-subdirectory bookmarks; 26.1+ uses a single root bookmark, with an upgrade path (`tryUpgradeToRootDirectoryPermission`).

### Dependencies (SPM)
Alamofire (networking), SwiftyJSON, WCDB (encrypted SQLite), KeyboardShortcuts (global hotkeys), LaunchAtLogin-Modern, CocoaLumberjack + swift-log (logging via `Logger.shared`), Zip. `libs/libminipng` is a **bundled prebuilt** framework/static lib — do not edit its generated contents.

## Conventions

- Swift: 4-space indent, braces on the declaration line, `// MARK: -` section separators. `UpperCamelCase` types/filenames, `lowerCamelCase` members. No formatter/linter is configured.
- Keep provider-specific behavior inside `Models/<Provider>/`.
- Bilingual comments (Chinese + English) are common and expected; mirror the local style.
- Localization lives in `.xcstrings` catalogs (`Localizable.xcstrings`, `mul.lproj/Main.xcstrings`) and `Base.lproj`. Strings are accessed via `.localized` / `NSLocalizedString`; `PicFerry/Script/AutoGenStrings.py` assists generation.
- `AGENTS.md` has additional contributor/process guidance; `CONTRIBUTING.md` asks that substantial changes be discussed via issue first.

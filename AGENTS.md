# Repository Guidelines

## Project Structure & Module Organization

PicFerry is a Swift 5 macOS menu-bar application managed by `PicFerry.xcodeproj`. Application code lives in `PicFerry/`: uploader integrations are grouped by provider under `Models/`, window and storyboard code under `Views/`, shared services under `Managers/`, and reusable helpers under `Basic/`, `Extensions/`, and `Utils/`. Images belong in `PicFerry/Assets.xcassets`; localized strings and storyboards live in `Base.lproj`, `mul.lproj`, and `.xcstrings` catalogs. `libs/` contains the bundled `libminipng` library; do not edit generated library contents.

## Build, Test, and Development Commands

Requires Xcode 26; the application target deploys only to macOS 26.

- `open PicFerry.xcodeproj` opens the project in Xcode and resolves Swift Package dependencies.
- `xcodebuild -resolvePackageDependencies -project PicFerry.xcodeproj` resolves the versions pinned in `Package.resolved`.
- `xcodebuild build -project PicFerry.xcodeproj -scheme 'PicFerry(Release)' -configuration Debug CODE_SIGNING_ALLOWED=NO` performs a command-line debug build without requiring a signing identity.

Use the localized schemes `PicFerry(简体中文)` and `PicFerry(繁体中文)` when checking language-specific UI. Run the app from Xcode for menu-bar and permissions debugging.

## Coding Style & Naming Conventions

Follow the existing Swift style: four-space indentation, opening braces on the declaration line, and `// MARK: -` separators for substantial sections. Use `UpperCamelCase` for types and filenames, `lowerCamelCase` for properties and methods, and descriptive suffixes such as `Uploader`, `HostConfig`, and `ViewController`. Keep provider-specific behavior inside its `Models/<Provider>/` directory. No formatter or linter is configured, so use Xcode's indentation and remove trailing whitespace before submitting.

## Testing Guidelines

This checkout has no XCTest target or stated coverage threshold. Every change must at least compile with the command above. Manually exercise affected upload paths, clipboard output, progress/error handling, preferences persistence, CLI behavior, URL scheme handling, and relevant localized UI. Never use production credentials in reproducible test notes.

## Commit & Pull Request Guidelines

The available history is shallow and uses concise release-style subjects (for example, `released 1.4.9.`); write short, imperative subjects that identify the change. Keep commits focused. Before substantial work, discuss the proposal through an issue or with maintainers as requested in `CONTRIBUTING.md`. Pull requests should complete the repository template: summarize the change, link an issue when applicable, list exact test steps, include screenshots for UI changes, and note additional compatibility or configuration concerns.

## Security & Configuration

Do not commit API tokens, cloud credentials, signing certificates, provisioning profiles, or personal entitlements. Preserve `Package.resolved` updates only when dependency changes are intentional.

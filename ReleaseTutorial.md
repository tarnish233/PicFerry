# PicFerry release checklist

1. Build and manually verify the `PicFerry(Release)` scheme on macOS 26.
2. Verify file, clipboard, screenshot, drag-and-drop, URL scheme, AppleScript, CLI, upload history, and launch-at-login flows.
3. Archive with the PicFerry Developer ID application identity.
4. Export `PicFerry.app`, sign nested code, and verify with `codesign --verify --deep --strict`.
5. Run `Scripts/create-dmg.sh` to package `PicFerry-<version>-macos26-arm64.dmg` with an Applications shortcut.
6. Sign the DMG, submit it for Apple notarization, staple the ticket, and validate it with Gatekeeper.
7. Record the DMG SHA-256 checksum and publish it from the standalone PicFerry repository.
8. Never include provider tokens, certificates, provisioning profiles, or local entitlements.

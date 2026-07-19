# GitPic release checklist

1. Build and manually verify the `GitPic(Release)` scheme on macOS 26.
2. Verify file, clipboard, screenshot, drag-and-drop, URL scheme, AppleScript, CLI, upload history, and launch-at-login flows.
3. Archive with the GitPic Developer ID application identity.
4. Export `GitPic.app`, sign nested code, and verify with `codesign --verify --deep --strict`.
5. Run `Scripts/create-dmg.sh` to package `GitPic-<version>-macos26-arm64.dmg` with an Applications shortcut.
6. Sign the DMG, submit it for Apple notarization, staple the ticket, and validate it with Gatekeeper.
7. Record the DMG SHA-256 checksum and publish it from the standalone GitPic repository.
8. Never include provider tokens, certificates, provisioning profiles, or local entitlements.

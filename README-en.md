# PicFerry

[简体中文](README.md) | **English**

PicFerry is a native macOS menu-bar uploader for GitHub and Gitee. It can upload selected files, clipboard contents, screenshots, URLs, and dragged items, then copy the resulting link as URL, Markdown, or HTML.

## Features

- Upload selected files, clipboard contents, or screenshots from the menu bar
- Drag local files or browser images onto the menu-bar icon to upload them
- Switch quickly between configured GitHub and Gitee hosts
- Customize URL, Markdown, and HTML output, encoding, and image compression
- Receive clear success or failure notifications and review results in upload history
- Trigger uploads with global keyboard shortcuts or the `picferry` CLI

## Requirements

- macOS 26 or later
- Apple Silicon (`arm64`)
- Xcode 26 for development

## Install

Download `PicFerry-2.0.1-macos26-arm64.dmg` from Releases, open it, and drag `PicFerry.app` into the Applications folder.

Current test builds are locally signed. If macOS blocks the first launch, Control-click the app in Finder and choose **Open**.

## Build

```bash
xcodebuild build \
  -project PicFerry.xcodeproj \
  -scheme 'PicFerry(Release)' \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO
```

Language-specific schemes are also available as `PicFerry(简体中文)` and `PicFerry(繁体中文)`.

## Create a DMG

After building and signing the Release app, run:

```bash
./Scripts/create-dmg.sh
```

By default, the script reads `build/release/PicFerry.app` and creates a DMG with an Applications shortcut in the same directory. Custom app and output paths are also supported:

```bash
./Scripts/create-dmg.sh /path/to/PicFerry.app /path/to/PicFerry.dmg
```

## Command line

The application executable also provides the CLI:

```bash
/Applications/PicFerry.app/Contents/MacOS/PicFerry \
  --upload ~/Desktop/example.png \
  --output markdown
```

Install the shorter `picferry` command for the current user:

```bash
./Scripts/install-cli.sh
picferry --help
```

The installer writes only a small launcher under `~/.local/bin`. Ensure that directory is included in `PATH`.

Common options:

```text
-u, --upload    One or more file paths or URLs to upload
-o, --output    Output format: url, markdown, md, or html
-s, --silent    Suppress error messages
-h, --help      Show help
-v, --version   Show the version
```

## Application information

- Product and executable: `PicFerry`
- Bundle identifier: `com.tarnish233.PicFerry`
- URL scheme: `picferry://`
- Version: `2.0.1 (41)`

## License and attribution

Licensed under the [Apache License 2.0](LICENSE). PicFerry is derived from the original [uPic project](https://github.com/gee1k/uPic); the original copyright and license notices are retained as required by the license. See [NOTICE](NOTICE).

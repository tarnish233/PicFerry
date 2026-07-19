#!/bin/sh

set -eu

app_path=${1:-build/release/GitPic.app}

if [ ! -d "$app_path" ]; then
    echo "GitPic app not found at: $app_path" >&2
    exit 1
fi

info_plist="$app_path/Contents/Info.plist"
if [ ! -f "$info_plist" ]; then
    echo "Info.plist not found in: $app_path" >&2
    exit 1
fi

version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$info_plist")
output_path=${2:-"build/release/GitPic-$version-macos26-arm64.dmg"}
staging_directory=$(mktemp -d "${TMPDIR:-/tmp}/GitPicDMG.XXXXXX")

cleanup() {
    rm -rf "$staging_directory"
}
trap cleanup EXIT INT TERM

mkdir -p "$(dirname "$output_path")"
ditto "$app_path" "$staging_directory/GitPic.app"
ln -s /Applications "$staging_directory/Applications"
rm -f "$output_path"

hdiutil create \
    -volname GitPic \
    -srcfolder "$staging_directory" \
    -ov \
    -format UDZO \
    "$output_path"

echo "Created: $output_path"

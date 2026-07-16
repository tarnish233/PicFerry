#!/bin/sh

set -eu

app_path=${PICFERRY_APP_PATH:-/Applications/PicFerry.app}
prefix=${PREFIX:-"$HOME/.local"}
executable="$app_path/Contents/MacOS/PicFerry"
destination="$prefix/bin/picferry"
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

if [ ! -x "$executable" ]; then
    echo "PicFerry executable not found at: $executable" >&2
    exit 1
fi

mkdir -p "$prefix/bin"
if [ -L "$destination" ]; then
    rm "$destination"
fi
install -m 755 "$script_dir/picferry" "$destination"
echo "Installed: $destination"

#!/bin/sh

set -eu

app_path=${GITPIC_APP_PATH:-/Applications/GitPic.app}
prefix=${PREFIX:-"$HOME/.local"}
executable="$app_path/Contents/MacOS/GitPic"
destination="$prefix/bin/gitpic"
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

if [ ! -x "$executable" ]; then
    echo "GitPic executable not found at: $executable" >&2
    exit 1
fi

mkdir -p "$prefix/bin"
if [ -L "$destination" ]; then
    rm "$destination"
fi
install -m 755 "$script_dir/gitpic" "$destination"
echo "Installed: $destination"

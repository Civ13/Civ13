#!/usr/bin/env bash
set -euo pipefail
test "$(id -u)" = 0 || { echo 'Setup requires root'; exit 1; }
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
apt-get update
apt-get install -y git python3 curl unzip make libc6-i386 lib32stdc++6
destination="$(python3 "$script_dir/byond_toolchain.py" field linux-bin)"
destination="${destination%/byond/bin}"
if [ ! -x "$destination/byond/bin/DreamMaker" ]; then
    temporary=$(mktemp -d)
    trap 'rm -rf -- "$temporary"' EXIT
    # Official by default. BYOND_ARCHIVE_SOURCE may name another reviewed source
    # (community-mirror or repository-release) when the official host refuses the
    # download; every source is held to the same pinned size and SHA-256.
    timeout -k 5 65 python3 "$script_dir/byond_toolchain.py" download --platform linux --source "${BYOND_ARCHIVE_SOURCE:-official}" --output "$temporary/byond.zip"
    unzip -q "$temporary/byond.zip" -d "$temporary"
    test -x "$temporary/byond/bin/DreamMaker"
    mkdir -p "$destination"
    cp -a "$temporary/byond" "$destination/"
    make -C "$destination/byond" here
fi
echo 'Dependencies installed. From Windows run local-wsl.ps1 -Action Build for each server.'

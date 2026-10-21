#!/usr/bin/env bash
set -euo pipefail
test "$(id -u)" = 0 || { echo 'Setup requires root'; exit 1; }
apt-get update
apt-get install -y git python3 curl unzip make libc6-i386 lib32stdc++6
destination=/opt/civ13-byond-516.1681
if [ ! -x "$destination/byond/bin/DreamMaker" ]; then
    temporary=$(mktemp -d)
    trap 'rm -rf -- "$temporary"' EXIT
    curl --fail --location --proto '=https' --tlsv1.2 https://www.byond.com/download/build/516/516.1681_byond_linux.zip -o "$temporary/byond.zip"
    unzip -q "$temporary/byond.zip" -d "$temporary"
    test -x "$temporary/byond/bin/DreamMaker"
    mkdir -p "$destination"
    cp -a "$temporary/byond" "$destination/"
    make -C "$destination/byond" here
fi
echo 'Dependencies installed. From Windows run local-wsl.ps1 -Action Build for each server.'

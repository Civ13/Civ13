#!/bin/bash
# Install the pinned BYOND compiler for a local or cloud agent session (Linux).
# Uses the canonical pin in tools/byond/version.json and the repository-release
# mirror (reachable through the cloud agent proxy). Installs outside the repo.
#
#   bash scripts/cloud_byond_setup.sh            # install once, then compile
#   source "$HOME/byond-<version>/byond/bin/byondsetup" && DreamMaker -max_errors 0 civ13.dme
#
# This is a developer convenience. It is not the CI bootstrap
# (scripts/travis_pre_byond.sh) and its result is not CI evidence.
set -eo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
version="$(python3 "$repo_root/scripts/byond_toolchain.py" field version)"
target="${BYOND_HOME:-$HOME/byond-$version}"
bin="$target/byond/bin"

if [ ! -x "$bin/DreamMaker" ]; then
    as_root=()
    [ "$(id -u)" -ne 0 ] && as_root=(sudo)
    if ! dpkg --print-foreign-architectures | grep -qx i386; then
        "${as_root[@]}" dpkg --add-architecture i386
    fi
    "${as_root[@]}" env DEBIAN_FRONTEND=noninteractive apt-get update -qq
    "${as_root[@]}" env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends \
        unzip make libc6-i386 libstdc++6:i386 libgcc-s1:i386 libcurl4:i386 lib32z1 >/dev/null \
        || "${as_root[@]}" env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends \
        unzip make libc6-i386 libstdc++6:i386 libgcc-s1:i386 libcurl4t64:i386 lib32z1 >/dev/null
    mkdir -p "$target"
    python3 "$repo_root/scripts/byond_toolchain.py" download --platform linux \
        --source "${BYOND_ARCHIVE_SOURCE:-repository-release}" --output "$target/pinned.zip" >/dev/null
    (cd "$target" && unzip -q -o pinned.zip && cd byond && make here >/dev/null)
fi

# shellcheck disable=SC1091
source "$bin/byondsetup"
banner="$(DreamMaker 2>&1 | head -n 1 || true)"
echo "$banner"
echo "Ready. In each new shell: source \"$bin/byondsetup\""
echo "Compile: DreamMaker -max_errors 0 civ13.dme   (expect '- 0 errors, 0 warnings')"

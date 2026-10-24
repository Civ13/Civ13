#!/bin/bash
set -eo pipefail

# BEGIN compiler status contract
compile_game() {
    timeout -k 5 300 DreamMaker -max_errors 0 civ13.dme 2>&1 | tee result.log
    # pipefail rejects a failing compiler even if it prints a zero-warning line.
    grep -q -- '- 0 errors, 0 warnings' result.log
}
# END compiler status contract

echo "Setting up the system for BYOND compilation."
sudo timeout -k 5 30 dpkg --add-architecture i386
# Install dependencies only; never upgrade the hosted image.
sudo env DEBIAN_FRONTEND=noninteractive timeout -k 5 120 apt-get update
sudo env DEBIAN_FRONTEND=noninteractive timeout -k 5 180 apt-get install -y python3 wget git unzip make sudo libstdc++6:i386 libgcc-s1:i386 libc6-i386 libcurl4:i386 lib32z1 libncurses6 libncurses6:i386

echo "Setting up BYOND."
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$script_dir/.."
repo_root="$PWD"
mkdir -p .ci/compile
git rev-parse HEAD 'HEAD^{tree}' > .ci/compile/checkout-commit-tree.txt
git ls-tree -r HEAD > .ci/compile/source-tree.txt
git diff --binary HEAD > .ci/compile/source-before.patch
trap 'status=$?; cd "$repo_root"; cp result.log .ci/compile/compiler.log 2>/dev/null || true; git diff --binary HEAD > .ci/compile/source-after.patch; exit "$status"' EXIT
# Fresh hosted checkout only. Refuse an existing install rather than deleting it.
mkdir BYOND
cd BYOND
timeout -k 5 65 wget --timeout=30 --tries=1 --no-verbose -O 516.1681_byond_linux.zip "https://civ13.com/downloads/516.1681_byond_linux.zip"
# This records bytes observed from the mirror, not independent authenticity.
sha256sum 516.1681_byond_linux.zip > "$repo_root/.ci/compile/byond-archive.sha256"
timeout -k 5 30 unzip -q 516.1681_byond_linux.zip
cd byond
timeout -k 5 60 make here
source "$repo_root/BYOND/byond/bin/byondsetup"
cd "$repo_root"
echo "Compiling the dme..."
timeout -k 5 60 python3 scripts/build-crafting-atlas.py --catalog-only --game-catalog UI/crafting-atlas.json
compile_game

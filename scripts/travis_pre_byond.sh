#!/bin/bash
set -eo pipefail

# Only the two reviewed manual fixture workflows use this historical toolchain.
case "${1:-}" in
    '') legacy_fixture=false ;;
    --legacy-fixture-5161681) legacy_fixture=true ;;
    *) echo 'Unsupported BYOND bootstrap option' >&2; exit 2 ;;
esac
test "$#" -le 1 || exit 2

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$script_dir/.."
repo_root="$PWD"
if "$legacy_fixture"; then
    byond_version=516.1681
else
    byond_version="$(python3 "$script_dir/byond_toolchain.py" field version)"
fi
if [ -n "${BYOND_MAJOR:-}" ] && [ "$BYOND_MAJOR" != "${byond_version%.*}" ]; then
    echo 'BYOND major differs from selected toolchain' >&2; exit 2
fi
if [ -n "${BYOND_MINOR:-}" ] && [ "$BYOND_MINOR" != "${byond_version#*.}" ]; then
    echo 'BYOND build differs from selected toolchain' >&2; exit 2
fi

# BEGIN compiler status contract
compile_game() {
    timeout -k 5 300 DreamMaker -max_errors 0 civ13.dme 2>&1 | tee result.log
    # pipefail rejects a failing compiler even if it prints a zero-warning line.
    grep -q -- '- 0 errors, 0 warnings' result.log
    test "$(grep -c '^DM compiler version' result.log)" = 1
    grep -Fx -- "DM compiler version $byond_version" result.log
}
# END compiler status contract

# BEGIN package setup
echo "Setting up the system for BYOND compilation."
sudo timeout -k 5 30 dpkg --add-architecture i386
# Install dependencies only; never upgrade the hosted image.
sudo env DEBIAN_FRONTEND=noninteractive timeout -k 5 120 apt-get update
sudo env DEBIAN_FRONTEND=noninteractive timeout -k 5 180 apt-get install -y python3 wget git unzip make sudo libstdc++6:i386 libgcc-s1:i386 libc6-i386 libcurl4:i386 lib32z1 libncurses6 libncurses6:i386

# END package setup

echo "Setting up BYOND."
mkdir -p .ci/compile
git rev-parse HEAD 'HEAD^{tree}' > .ci/compile/checkout-commit-tree.txt
git ls-tree -r HEAD > .ci/compile/source-tree.txt
git diff --binary HEAD > .ci/compile/source-before.patch
trap 'status=$?; cd "$repo_root"; cp result.log .ci/compile/compiler.log 2>/dev/null || true; git diff --binary HEAD > .ci/compile/source-after.patch; exit "$status"' EXIT
# Fresh hosted checkout only. Refuse an existing install rather than deleting it.
mkdir BYOND
cd BYOND
if "$legacy_fixture"; then
    # Preserve the historical fixture download; no independent checksum is claimed.
    timeout -k 5 65 wget --timeout=30 --tries=1 --no-verbose -O pinned.zip "https://civ13.com/downloads/516.1681_byond_linux.zip"
else
    timeout -k 5 65 python3 "$script_dir/byond_toolchain.py" download --platform linux --output pinned.zip > "$repo_root/.ci/compile/byond-download.json"
fi
sha256sum pinned.zip > "$repo_root/.ci/compile/byond-archive.sha256"
printf '%s\n' "$byond_version" > "$repo_root/.ci/compile/byond-version.txt"
timeout -k 5 30 unzip -q pinned.zip
cd byond
timeout -k 5 60 make here
source "$repo_root/BYOND/byond/bin/byondsetup"
cd "$repo_root"
echo "Compiling the dme..."
timeout -k 5 60 python3 scripts/build-crafting-atlas.py --catalog-only --game-catalog UI/crafting-atlas.json
compile_game

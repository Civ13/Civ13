#!/bin/bash
set -eo pipefail

# Toolchain selection is exclusively the canonical repository manifest.
if [ "$#" -ne 0 ]; then
    echo 'Unsupported BYOND bootstrap option; only the canonical pin is supported' >&2
    exit 2
fi

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$script_dir/.."
repo_root="$PWD"
byond_version="$(python3 "$script_dir/byond_toolchain.py" field version)"
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
# Retry stalled transfers inside the existing phase deadlines. These command-local
# options keep APT's authentication; no host config is written.
apt_acquire=(-o Acquire::Retries=2 -o Acquire::http::Timeout=15 -o Acquire::https::Timeout=15)
apt_sources=()
apt_packages=(python3 wget git unzip make sudo libstdc++6:i386 libgcc-s1:i386 libc6-i386 libcurl4:i386 lib32z1 libncurses6 libncurses6:i386)
# The runner image's Azure mirror can go dark for hours: its update then hangs
# or "succeeds" with every index ignored. Canonical's own hosts failed DNS from
# runners in the same outage (2026-11-11), so retry once with the kernel.org
# mirror, given to APT as command options only. The list lives in the runner
# temp dir and a missing parts directory makes APT read only that list.
use_fallback_mirrors() {
    echo 'Ubuntu mirror failed; retrying with public non-Azure mirrors.' >&2
    local codename mirror suite list="${RUNNER_TEMP:-$PWD}/civ13-apt-fallback.list"
    codename="$(. /etc/os-release && printf '%s' "$VERSION_CODENAME")"
    : > "$list"
    for mirror in http://mirrors.edge.kernel.org/ubuntu; do
        for suite in "$codename" "$codename-updates" "$codename-security"; do
            printf 'deb [arch=amd64,i386] %s %s main universe\n' "$mirror" "$suite" >> "$list"
        done
    done
    apt_sources=(-o "Dir::Etc::SourceList=$list" -o "Dir::Etc::SourceParts=$list.d")
    sudo env DEBIAN_FRONTEND=noninteractive timeout -k 5 180 apt-get "${apt_acquire[@]}" "${apt_sources[@]}" update
}
install_packages() {
    sudo env DEBIAN_FRONTEND=noninteractive timeout -k 5 180 apt-get "${apt_acquire[@]}" "${apt_sources[@]}" install -y --no-install-recommends "${apt_packages[@]}"
}
if ! sudo env DEBIAN_FRONTEND=noninteractive timeout -k 5 120 apt-get "${apt_acquire[@]}" update; then
    use_fallback_mirrors
fi
if install_packages; then :; else
    apt_status=$?
    [ "${#apt_sources[@]}" -eq 0 ] || exit "$apt_status"
    use_fallback_mirrors
    install_packages
fi

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
archive_args=(--platform linux --output pinned.zip --source "${BYOND_ARCHIVE_SOURCE:-official}")
if [ -n "${BYOND_ARCHIVE_CACHE:-}" ]; then
    archive_args+=(--cache-dir "$BYOND_ARCHIVE_CACHE")
fi
timeout -k 5 65 python3 "$script_dir/byond_toolchain.py" download "${archive_args[@]}" > "$repo_root/.ci/compile/byond-download.json"
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

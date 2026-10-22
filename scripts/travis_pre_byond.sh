#!/bin/bash
set -e

# No user URL/hash arguments: only the dedicated, fixed mall opt-in is accepted.
case "$#:$1" in
  0:) official_pinned_mall=false ;;
  1:--official-pinned-mall) official_pinned_mall=true ;;
  *) echo 'Expected no argument or --official-pinned-mall' >&2; exit 64 ;;
esac
if [[ "$official_pinned_mall" == true ]]; then
  # Check before package installation or any source/toolchain filesystem effect.
  command -v curl >/dev/null || { echo 'Official mall bootstrap requires existing curl' >&2; exit 69; }
fi

# BEGIN FIXED OFFICIAL MALL DOWNLOAD
download_official_pinned_mall() {
  local archive='516.1681_byond_linux.zip'
  local expected_bytes=4884042
  local expected_sha256='614c126b9d0073c67558172c2c2fcb92c31298cf36092208ed55a416326bede3'
  local url='https://www.byond.com/download/build/516/516.1681_byond_linux.zip'
  local status bytes
  # Observed official-origin HTTPS identity captured 2026-10-21: HTTP200,
  # 4884042 bytes, independently read-back SHA256 above. This is a reviewed
  # byte pin, not a publisher-signed checksum or a permanent release guarantee.
  if [[ -e "$archive" || -L "$archive" ]]; then
    echo 'Refusing pre-existing official archive output' >&2
    return 1
  fi
  # --disable is first: ignore curlrc. No proxy, redirects, retries or fallback;
  # retain normal certificate/hostname verification and permit HTTPS only.
  if ! status=$(curl --disable --proxy '' --noproxy '*' --proto '=https' \
      --tlsv1.2 --fail --silent --show-error --request GET \
      --connect-timeout 10 --max-time 60 --max-filesize 8388608 \
      --retry 0 --max-redirs 0 --output "$archive" --write-out '%{http_code}' "$url"); then
    echo 'Official archive transport/TLS/size/time failure; no fallback' >&2
    return 1
  fi
  if [[ "$status" != 200 ]]; then
    echo 'Official archive requires exact HTTP200; no redirect/fallback' >&2
    return 1
  fi
  bytes=$(wc -c < "$archive")
  bytes=${bytes//[[:space:]]/}
  if [[ ! "$bytes" =~ ^[0-9]+$ || "$bytes" -ne "$expected_bytes" || "$bytes" -gt 8388608 ]]; then
    echo 'Official archive byte count mismatch' >&2
    return 1
  fi
  if ! printf '%s  %s\n' "$expected_sha256" "$archive" | sha256sum --check --status; then
    echo 'Official archive SHA256 mismatch' >&2
    return 1
  fi
  printf 'Verified observed official-origin BYOND archive: bytes=%s sha256=%s url=%s\n' "$bytes" "$expected_sha256" "$url"
}
# END FIXED OFFICIAL MALL DOWNLOAD

echo "Setting up the system for BYOND compilation."
sudo dpkg --add-architecture i386
# Install the build dependencies only. Upgrading the entire hosted image can
# trigger unrelated Firefox/snap provisioning and fail before BYOND is installed.
sudo env DEBIAN_FRONTEND=noninteractive apt-get update
sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y python3 wget git unzip make sudo
sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y libstdc++6:i386 libgcc1:i386 libc6-i386 libcurl4:i386 lib32z1 libncurses6 libncurses6:i386

echo "Setting up BYOND."
rm -rf "BYOND"
mkdir -p "BYOND"
cd "BYOND"
if [[ "$official_pinned_mall" == true ]]; then
  download_official_pinned_mall
else
# Bound transient download failures without weakening TLS or changing source/version.
wget --timeout=60 --tries=3 --waitretry=5 -O 516.1681_byond_linux.zip "https://civ13.com/downloads/516.1681_byond_linux.zip"
fi
ls
unzip -o 516.1681_byond_linux.zip
cd byond
make here
echo "Compiling the dme..."
retval=1
source /home/runner/work/Civ13/Civ13/BYOND/byond/bin/byondsetup
cd /home/runner/work/Civ13/Civ13/
python3 scripts/build-crafting-atlas.py --catalog-only --game-catalog UI/crafting-atlas.json
DreamMaker -max_errors 0 civ13.dme | tee result.log
retval=$?
if ! grep '\- 0 errors, 0 warnings' result.log
then
	retval=1 #hard fail, due to warnings or errors
	echo "Failed to compile!"
	exit 1
	fi

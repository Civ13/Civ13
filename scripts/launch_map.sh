#!/bin/bash
# launch_map.sh - Swap the map in civ13.dme, compile, and run on DreamSeeker.
# Usage: ./scripts/launch_map.sh <map>
#
# Resolution order:
#   1. If MAP_<UPPER> is defined in code/__defines/maps.dm, use that map ID.
#   2. Otherwise find <arg>.dmm (case-insensitive) under maps/.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DME="$REPO_DIR/civ13.dme"
MAPS_DM="$REPO_DIR/code/__defines/maps.dm"

# --- arg check ---
if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <map>"
    echo "  e.g. $0 nomads"
    echo "       $0 SUBCOM13"
    exit 1
fi

ARG="$1"
UPPER="$(echo "$ARG" | tr '[:lower:]' '[:upper:]')"

# --- resolve map .dmm path ---
find_dmm() {
    local name="$1"
    # Recursive case-insensitive search under maps/
    find "$REPO_DIR/maps" -iname "${name}.dmm" -type f 2>/dev/null | head -1
}

MAP_PATH=""

# Step 1: check for MAP_<UPPER> define (exact match - space/tab after name)
if [[ -f "$MAPS_DM" ]] && grep -qP "#define\s+MAP_${UPPER}\s" "$MAPS_DM"; then
    # The define value is the string ID used in map metadata - find the .dmm by that ID
    # e.g. #define MAP_NOMADS "nomads"  →  look for nomads.dmm
    MAP_ID=$(grep -P "#define\s+MAP_${UPPER}\s" "$MAPS_DM" | sed 's/.*"\(.*\)".*/\1/')
    echo "Found #define MAP_${UPPER} \"${MAP_ID}\""
    MAP_PATH="$(find_dmm "$MAP_ID")"
fi

# Step 2: direct filename match
if [[ -z "$MAP_PATH" ]]; then
    MAP_PATH="$(find_dmm "$ARG")"
fi

# Step 3: try capitalized
if [[ -z "$MAP_PATH" ]]; then
    MAP_PATH="$(find_dmm "$UPPER")"
fi

if [[ -z "$MAP_PATH" ]]; then
    echo "ERROR: Could not find a .dmm for '${ARG}'."
    echo "Searched: MAP_${UPPER} define, ${ARG}.dmm, ${UPPER}.dmm under maps/"
    exit 1
fi

# Convert to relative path from repo root
MAP_REL="${MAP_PATH#$REPO_DIR/}"
echo "Map file: $MAP_REL"

# --- rewrite civ13.dme: replace any existing .dmm include ---
# DME uses backslash paths - we store the include with forward slashes
# (BYOND on Linux handles both, and this avoids sed escaping issues).
MAP_INCLUDE="#include \"${MAP_REL}\""

# Build new DME: keep everything except .dmm lines, then insert map before END_INCLUDE
TMPDME=$(mktemp)
awk '!/\.dmm"/' "$DME" > "$TMPDME"
# Insert map include before the // END_INCLUDE line
sed -i "s|^// END_INCLUDE|${MAP_INCLUDE}\n// END_INCLUDE|" "$TMPDME"
mv "$TMPDME" "$DME"

echo "DME updated: $MAP_INCLUDE"

# --- compile ---
echo "Compiling..."
if command -v DreamMaker &>/dev/null; then
    DreamMaker "$DME"
elif command -v dm &>/dev/null; then
    dm "$DME"
else
    echo "ERROR: Neither 'DreamMaker' nor 'dm' found in PATH."
    echo "Install BYOND or add DreamMaker to PATH."
    exit 1
fi

if [[ ! -f "${DME%.dme}.dmb" ]]; then
    echo "ERROR: Compilation failed - .dmb not found."
    exit 1
fi

echo "Compilation successful."

# --- run on DreamSeeker ---
echo "Launching DreamSeeker..."
if command -v DreamSeeker &>/dev/null; then
    DreamSeeker "${DME%.dme}.dmb" &
elif command -v byond &>/dev/null; then
    byond "${DME%.dme}.dmb" &
else
    echo "WARNING: DreamSeeker not found in PATH."
    echo "Open ${DME%.dme}.dmb manually in BYOND."
fi

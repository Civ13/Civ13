#!/bin/bash
# select_map.sh — Interactive map selector. Lists folders, then maps,
# then calls launch_map.sh with the chosen map.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
MAPS_DIR="$REPO_DIR/maps"

# --- Helpers ---

print_header() {
    clear
    echo "=========================================="
    echo "           CIV13 MAP SELECTOR"
    echo "=========================================="
    echo ""
}

# --- Step 1: Select era/folder ---

print_header
echo "Select an era:"
echo ""

# Gather folders (skip WIP and zones)
FOLDERS=()
FOLDER_NAMES=()
i=1
for d in "$MAPS_DIR"/*/; do
    name=$(basename "$d")
    # Skip non-gameplay folders
    case "$name" in
        WIP|zones|special|campaign_archive) continue ;;
    esac
    # Count .dmm files
    count=$(find "$d" -maxdepth 1 -iname "*.dmm" -type f 2>/dev/null | wc -l)
    if [[ $count -eq 0 ]]; then
        continue
    fi
    FOLDERS+=("$d")
    FOLDER_NAMES+=("$name")
    printf "  %2d) %-30s (%d maps)\n" "$i" "$name" "$count"
    i=$((i + 1))
done

# Also offer WIP if it has maps
WIP_DIR="$MAPS_DIR/WIP"
if [[ -d "$WIP_DIR" ]]; then
    wip_count=$(find "$WIP_DIR" -maxdepth 1 -iname "*.dmm" -type f 2>/dev/null | wc -l)
    if [[ $wip_count -gt 0 ]]; then
        FOLDERS+=("$WIP_DIR")
        FOLDER_NAMES+=("WIP")
        printf "  %2d) %-30s (%d maps)\n" "$i" "WIP" "$wip_count"
        i=$((i + 1))
    fi
fi

TOTAL_FOLDERS=$i
echo ""
read -p "  Select folder [1-$((TOTAL_FOLDERS - 1))]: " FOLDER_CHOICE

# Validate
if ! [[ "$FOLDER_CHOICE" =~ ^[0-9]+$ ]] || [[ "$FOLDER_CHOICE" -lt 1 ]] || [[ "$FOLDER_CHOICE" -ge "$TOTAL_FOLDERS" ]]; then
    echo "Invalid selection."
    exit 1
fi

SELECTED_FOLDER="${FOLDERS[$((FOLDER_CHOICE - 1))]}"
SELECTED_FOLDER_NAME="${FOLDER_NAMES[$((FOLDER_CHOICE - 1))]}"

# --- Step 2: Select map from folder ---

print_header
echo "Folder: $SELECTED_FOLDER_NAME"
echo ""
echo "Select a map:"
echo ""

MAPS=()
MAP_NAMES=()
i=1

# List .dmm files directly in the folder
for f in "$SELECTED_FOLDER"*.dmm; do
    [[ -f "$f" ]] || continue
    basename_no_ext=$(basename "$f" .dmm)
    MAPS+=("$basename_no_ext")
    MAP_NAMES+=("$basename_no_ext")
    printf "  %2d) %s\n" "$i" "$basename_no_ext"
    i=$((i + 1))
done

# Also check one level down (e.g. nomads/nomads_continent.dmm)
for subdir in "$SELECTED_FOLDER"*/; do
    [[ -d "$subdir" ]] || continue
    subname=$(basename "$subdir")
    for f in "$subdir"*.dmm; do
        [[ -f "$f" ]] || continue
        basename_no_ext=$(basename "$f" .dmm)
        display="${subname}/${basename_no_ext}"
        MAPS+=("$basename_no_ext")
        MAP_NAMES+=("$display")
        printf "  %2d) %s\n" "$i" "$display"
        i=$((i + 1))
    done
done

TOTAL_MAPS=$i
if [[ $TOTAL_MAPS -eq 1 ]]; then
    echo "  No .dmm files found in $SELECTED_FOLDER_NAME."
    exit 1
fi

echo ""
read -p "  Select map [1-$((TOTAL_MAPS - 1))]: " MAP_CHOICE

# Validate
if ! [[ "$MAP_CHOICE" =~ ^[0-9]+$ ]] || [[ "$MAP_CHOICE" -lt 1 ]] || [[ "$MAP_CHOICE" -ge "$TOTAL_MAPS" ]]; then
    echo "Invalid selection."
    exit 1
fi

SELECTED_MAP="${MAPS[$((MAP_CHOICE - 1))]}"
SELECTED_DISPLAY="${MAP_NAMES[$((MAP_CHOICE - 1))]}"

# --- Step 3: Confirm and launch ---

print_header
echo "Map: $SELECTED_DISPLAY"
echo "ID:  $SELECTED_MAP"
echo ""
echo "Launching..."
echo ""

exec "$SCRIPT_DIR/launch_map.sh" "$SELECTED_MAP"

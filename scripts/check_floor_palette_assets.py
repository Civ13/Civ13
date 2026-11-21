"""Check the dungeon floor palette DMI and mapper type contract without BYOND."""
import re
import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DMI_DIR = ROOT / "icons/turf/flooring"
COVER_SOURCE = ROOT / "code/game/objects/covers_types/cover_floortypes.dm"
PALETTES = {
    "cobble_trim.dmi": {
        "sill_center": 4, "sill_cap_left": 4, "sill_cap_right": 4,
        "trim_straight": 4, "trim_corner_inside": 4,
        "trim_corner_outside": 4, "trim_stop": 4, "trim_stop_reverse": 4,
    },
    "terracotta.dmi": {
        "terracotta": 1, "terracotta_edge": 4, "terracotta_inner": 4,
        "terracotta_outer": 4, "terracotta_inset": 1,
    },
}


def dmi_states(path):
    data = path.read_bytes()
    assert data.startswith(b"\x89PNG\r\n\x1a\n"), path
    offset, description = 8, None
    while offset + 12 <= len(data):
        size, kind = struct.unpack_from(">I4s", data, offset)
        payload = data[offset + 8:offset + 8 + size]
        if kind == b"zTXt" and payload.startswith(b"Description\0\0"):
            description = zlib.decompress(payload[len(b"Description\0\0"):]).decode()
            break
        if kind == b"tEXt" and payload.startswith(b"Description\0"):
            description = payload[len(b"Description\0"):].decode()
            break
        offset += size + 12
    assert description and "# BEGIN DMI" in description, path
    for key in ("width", "height"):
        assert re.search(rf"^\s*{key}\s*=\s*32\s*$", description, re.M), path
    states = {}
    for match in re.finditer(r'^state\s*=\s*"([^"]+)"\s*\n\s*dirs\s*=\s*(\d+)\s*\n\s*frames\s*=\s*(\d+)', description, re.M):
        name, dirs, frames = match.groups()
        assert name not in states and int(frames) == 1, (path, name)
        states[name] = int(dirs)
    return states


def main():
    source = COVER_SOURCE.read_text().split("// Decorative flooring pieces", 1)[1]
    dme_path = str(COVER_SOURCE.relative_to(ROOT)).replace("/", chr(92))
    assert f'#include "{dme_path}"' in (ROOT / "civ13.dme").read_text()
    asset_for_type = {}
    found = {name: set() for name in PALETTES}
    for block in re.split(r"(?=^/obj/covers/)", source, flags=re.M):
        path = block.splitlines()[0] if block else ""
        if not path.startswith("/obj/covers/"):
            continue
        icon = re.search(r"^\s*icon = 'icons/turf/flooring/([^']+)'$", block, re.M)
        state = re.search(r'^\s*icon_state = "([^"]+)"$', block, re.M)
        assert state, path
        asset = icon[1] if icon else asset_for_type[path.rsplit("/", 1)[0]]
        assert state[1] not in found[asset], (path, state[1])
        asset_for_type[path] = asset
        found[asset].add(state[1])
    for name, expected in PALETTES.items():
        assert dmi_states(DMI_DIR / name) == expected, name
        assert found[name] == expected.keys(), name
    print("13 mapper floor covers match both 32px DMI sheets; frame and direction counts passed.")


if __name__ == "__main__":
    main()

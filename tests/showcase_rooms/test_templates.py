"""Offline checks for the furnished showcase room templates.

Parses every maps/zones/showcase/*.dmm with the same rules as the runtime
reader in code/modules/dmm_suite/reader.dm, then checks the room contract the
"Load Showcase Room" admin verb relies on. No BYOND compiler or world runs.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
ROOM_DIR = ROOT / "maps/zones/showcase"
VERB = ROOT / "code/modules/admin/showcase_rooms.dm"
EXPECTED_ROOMS = {"smithy", "kitchen", "tavern", "workshop", "farm_shed", "infirmary"}
DOOR = "/obj/structure/simple_door/key_door/anyone/wood"
SUPPORT = "/obj/structure/roof_support"
GUIDE = "/obj/item/weapon/paper"

_MODEL = re.compile(r'^"([A-Za-z]+)" = \((.*)\)$')
_GRID = re.compile(r'\n\n\(1,1,1\) = \{"\n((?:[A-Za-z]*\n)*)"\}\n?$')
_IDENT = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
_SKIP = {"proc", "verb", "var", "tmp", "static", "global", "const"}
_BLOCK_COMMENT = re.compile(r"/\*.*?\*/", re.S)
_STRING = re.compile(r'"(?:[^"\\\n]|\\.)*"')


def declared_types(code_root=ROOT / "code"):
    """Type paths declared in DM source, following tab-indented nesting."""
    types = set()
    for path in sorted(code_root.rglob("*.dm")):
        src = path.read_text(encoding="utf-8", errors="replace")
        src = _BLOCK_COMMENT.sub(lambda m: "\n" * m.group(0).count("\n"), src)
        stack = []
        for raw in src.split("\n"):
            line = _STRING.sub('""', raw.split("//", 1)[0]).rstrip()
            if not line.strip():
                continue
            indent = len(line) - len(line.lstrip("\t"))
            while stack and stack[-1][0] >= indent:
                stack.pop()
            body = line.strip()
            if "(" in body or "=" in body or " " in body:
                continue
            parts = [p for p in body.strip("/").split("/") if p]
            if not parts or not all(_IDENT.match(p) for p in parts) or any(p in _SKIP for p in parts):
                continue
            if indent:
                if not stack:
                    continue
                parts = stack[-1][1] + parts
            types.add("/" + "/".join(parts))
            stack.append((indent, parts))
    return types


def split_models(contents):
    """Split a model list on top-level commas, ignoring commas in {} and strings."""
    out, depth, quoted, start = [], 0, False, 0
    for i, ch in enumerate(contents):
        if ch == '"' and (i == 0 or contents[i - 1] != "\\"):
            quoted = not quoted
        elif not quoted and ch == "{":
            depth += 1
        elif not quoted and ch == "}":
            depth -= 1
        elif not quoted and depth == 0 and ch == ",":
            out.append(contents[start:i])
            start = i + 1
    out.append(contents[start:])
    return out


def parse(path):
    text = path.read_text(encoding="utf-8")
    assert "\r" not in text, f"{path.name}: CRLF line endings break the runtime reader"
    head, sep, _ = text.partition("\n\n(1,1,1) = {\"\n")
    assert sep, f"{path.name}: missing single z-level grid block"
    grid = _GRID.search(text)
    assert grid, f"{path.name}: grid must hold letter keys only"
    models = {}
    for line in head.split("\n"):
        match = _MODEL.match(line)
        assert match, f"{path.name}: unreadable model line {line!r}"
        models[match.group(1)] = [m.split("{", 1)[0] for m in split_models(match.group(2))]
    rows = grid.group(1).rstrip("\n").split("\n")
    key_len = {len(k) for k in models}
    assert len(key_len) == 1, f"{path.name}: mixed key lengths {key_len}"
    key_len = key_len.pop()
    width = len(rows[0]) // key_len
    tiles = []
    for row in rows:
        assert len(row) == width * key_len, f"{path.name}: ragged grid row"
        keys = [row[i:i + key_len] for i in range(0, len(row), key_len)]
        for key in keys:
            assert key in models, f"{path.name}: undefined key {key}"
        tiles.append([models[k] for k in keys])
    # File rows run north to south; flip so tiles[y][x] has y = 0 at the south edge.
    tiles.reverse()
    return text, models, tiles


class ShowcaseTemplates(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.rooms = {p.stem: parse(p) for p in sorted(ROOM_DIR.glob("*.dmm"))}
        cls.types = declared_types()

    def test_expected_rooms_exist(self):
        self.assertEqual(set(self.rooms), EXPECTED_ROOMS)

    def test_every_path_is_declared_and_loadable(self):
        for name, (_, models, _) in self.rooms.items():
            for key, paths in models.items():
                turfs = [p for p in paths if p.startswith("/turf/")]
                with self.subTest(room=name, key=key):
                    self.assertEqual(len(turfs), 1, "each tile needs exactly one turf")
                    self.assertEqual(paths[-1], turfs[0], "the turf comes after the objects")
                    for p in paths:
                        self.assertIn(p, self.types)
                        # The runtime reader locates areas instead of creating them,
                        # and skips metadata; rooms must inherit the host area.
                        self.assertFalse(p.startswith("/area"))
                        self.assertFalse(p.startswith("/obj/map_metadata"))

    def test_walled_room_with_door_where_the_verb_expects_it(self):
        for name, (_, _, tiles) in self.rooms.items():
            height, width = len(tiles), len(tiles[0])
            door_x = width // 2  # the verb uses x1 = origin.x - round(width / 2)
            with self.subTest(room=name):
                for y in range(height):
                    for x in range(width):
                        edge = x in (0, width - 1) or y in (0, height - 1)
                        turf = tiles[y][x][-1]
                        if (x, y) == (door_x, 0):
                            self.assertIn(DOOR, tiles[y][x])
                            self.assertFalse(turf.startswith("/turf/wall"))
                        elif edge:
                            self.assertTrue(turf.startswith("/turf/wall"), (x, y))
                        else:
                            self.assertFalse(turf.startswith("/turf/wall"), (x, y))
                            self.assertNotIn(DOOR, tiles[y][x])

    def test_optional_roof_has_support_everywhere(self):
        # Mirrors /obj/roof/proc/collapse_check: a wall within 2 tiles or a roof
        # support within 3 tiles (or a door underneath) keeps the roof up.
        for name, (_, _, tiles) in self.rooms.items():
            height, width = len(tiles), len(tiles[0])
            walls = [(x, y) for y in range(height) for x in range(width) if tiles[y][x][-1].startswith("/turf/wall")]
            supports = [(x, y) for y in range(height) for x in range(width) if SUPPORT in tiles[y][x]]
            with self.subTest(room=name):
                self.assertTrue(supports)
                for y in range(height):
                    for x in range(width):
                        if tiles[y][x][-1].startswith("/turf/wall") or DOOR in tiles[y][x]:
                            continue
                        near_wall = any(max(abs(x - a), abs(y - b)) <= 2 for a, b in walls)
                        near_support = any(max(abs(x - a), abs(y - b)) <= 3 for a, b in supports)
                        self.assertTrue(near_wall or near_support, (x, y))

    def test_each_room_has_a_guide_and_lighting(self):
        for name, (text, models, _) in self.rooms.items():
            with self.subTest(room=name):
                self.assertEqual(sum(GUIDE in paths for paths in models.values()), 1)
                self.assertIn(' guide"; info = "<b>', text)
                self.assertTrue(any("/obj/item/flashlight/lantern/on/anchored" in p for p in models.values()))

    def test_verb_matches_template_contract(self):
        source = VERB.read_text(encoding="utf-8")
        self.assertIn('#define SHOWCASE_ROOM_DIR "maps/zones/showcase/"', source)
        self.assertIn("var/x1 = origin.x - round(width / 2)", source)
        self.assertIn("var/y1 = origin.y + 1", source)
        # The movement recheck must reject a different z-level before clearing.
        recheck = source.index("origin.y != y1 - 1 || origin.z != z")
        self.assertLess(source.index("var/z = origin.z"), recheck)
        self.assertLess(recheck, source.index("showcase_room_clear_footprint(x1, y1, x2, y2, z, origin)"))
        self.assertIn("if (!check_rights(R_SPAWN))", source)
        self.assertIn("suite.read_map(dmm_text, x1, y1, z)", source)
        verbs = (ROOT / "code/modules/admin/admin_verbs.dm").read_text(encoding="utf-8")
        self.assertIn("/client/proc/load_showcase_room", verbs)
        dme = (ROOT / "civ13.dme").read_text(encoding="utf-8")
        self.assertIn('#include "code\\modules\\admin\\showcase_rooms.dm"', dme)


if __name__ == "__main__":
    unittest.main()

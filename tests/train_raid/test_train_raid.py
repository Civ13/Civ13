"""Offline checks for the generated Train Raid map and mode source.

They regenerate the map from the generator, parse the checked-in DMM, and
check the geometry the mode relies on: both shuttles docked in their berths,
bridge gates on every bridge cell, crew doors on the airlock, spawn and store
landmarks inside the crew-only rooms, loot pads on every Hauler anchor with
non-decreasing tiers rear to front, and a walking route from each shuttle's
boarding ports across its bridges to every Hauler section. They never run
BYOND, so they are not movement, loot or round-flow acceptance.

Run from the repository root:
    python3 -I -B -m unittest tests/train_raid/test_train_raid.py
"""
from collections import deque
import json
from pathlib import Path
import re
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))
import build  # noqa: E402

MAP = ROOT / "maps/EFT/train_raid.dmm"
LAYOUT = ROOT / "maps/EFT/train_raid.layout.json"
MODE = ROOT / "code/game/objects/map_metadata/train_raid.dm"
DME = ROOT / "civ13.dme"
DEFINES = ROOT / "code/__defines/maps.dm"
DEFINITION = re.compile(r'^"([a-zA-Z]{2})" = \((.*)\)$')
PASSABLE_TURFS = ("/turf/floor/",)
BLOCKING_ATOMS = ("/turf/wall/", "/obj/structure/closet", "/obj/structure/table", "/obj/structure/bed",
                  "/obj/structure/props/engineprops", "/obj/structure/anvil", "/obj/structure/sink",
                  "/obj/structure/toilet", "/obj/structure/train_raid_helm",
                  "/obj/structure/simple_door/train_raid_crew")


def split_atoms(body):
    atoms, depth, current = [], 0, []
    for char in body:
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
        if char == "," and depth == 0:
            atoms.append("".join(current))
            current = []
        else:
            current.append(char)
    atoms.append("".join(current))
    return atoms


def parse(text):
    lines = text.split("\n")
    definitions = {}
    index = 1
    while lines[index]:
        match = DEFINITION.match(lines[index])
        if not match:
            raise ValueError(f"Bad definition line {index + 1}: {lines[index][:60]}")
        definitions[match.group(1)] = split_atoms(match.group(2))
        index += 1
    grid = {}
    z = 0
    while index < len(lines):
        line = lines[index]
        if line.startswith("(1,1,"):
            z = int(line[5:line.index(")")])
            rows = []
            index += 1
            while lines[index] != '"}':
                rows.append(lines[index])
                index += 1
            height = len(rows)
            for row_index, row in enumerate(rows):
                y = height - row_index
                for x in range(len(row) // 2):
                    grid[x + 1, y, z] = definitions[row[2 * x:2 * x + 2]]
        index += 1
    return definitions, grid


def walkable(atoms):
    turf = [a for a in atoms if a.startswith("/turf/")][0]
    if not turf.startswith(PASSABLE_TURFS):
        return False
    return not any(a.startswith(BLOCKING_ATOMS) for a in atoms)


class TrainRaidMapTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.outputs = build.outputs()
        cls.text = MAP.read_text(encoding="utf-8")
        cls.layout = json.loads(LAYOUT.read_text(encoding="utf-8"))
        cls.definitions, cls.grid = parse(cls.text)
        cls.mode = MODE.read_text(encoding="utf-8")

    def atoms_at(self, x, y, z):
        return self.grid[x, y, z]

    def test_outputs_are_current(self):
        self.assertEqual(self.outputs[build.MAP_PATH], self.text)
        self.assertEqual(self.outputs[build.LAYOUT_PATH], LAYOUT.read_text(encoding="utf-8"))

    def test_world_shape(self):
        world = self.layout["world"]
        self.assertEqual((world["width"], world["height"], world["levels"]), (256, 256, 4))
        self.assertEqual(len(self.grid), 256 * 256 * 4)

    def test_single_metadata_object(self):
        count = sum(1 for atoms in self.grid.values() if "/obj/map_metadata/train_raid" in atoms)
        self.assertEqual(count, 1)
        self.assertNotIn("/obj/map_metadata/eft_factory", self.text)

    def test_no_study_names_remain(self):
        self.assertNotIn("draft", self.text.lower())
        self.assertNotIn("dagger_draft", self.text)

    def test_shuttles_docked_with_crew_rooms(self):
        for crew, data in self.layout["crews"].items():
            x0, y0, x1, y1 = data["bounds"]
            z0, z1 = data["z"]
            # Hull rings on every deck; the ground deck has a wood crew floor.
            for z in range(z0, z1 + 1):
                for x in range(x0, x1 + 1):
                    self.assertIn("/turf/wall/iron", " ".join(self.atoms_at(x, y0, z)))
                    self.assertIn("/turf/wall/iron", " ".join(self.atoms_at(x, y1, z)))
            for px, py, pz in data["spawn_points"]:
                atoms = self.atoms_at(px, py, pz)
                self.assertIn(f'/obj/effect/landmark{{name = "JoinLateTrain{crew.title()}"}}', atoms)
                self.assertTrue(any(a.endswith(f"/area/train_raid/shuttle/{crew}/crew") for a in atoms), atoms)
            for px, py, pz in data["store_points"]:
                atoms = self.atoms_at(px, py, pz)
                self.assertIn(f'/obj/effect/landmark{{name = "TrainStores{crew.title()}"}}', atoms)
                self.assertTrue(any(a.endswith(f"/area/train_raid/shuttle/{crew}/crew") for a in atoms))
            hx, hy, hz = data["helm"]
            self.assertIn(f'/obj/structure/train_raid_helm{{crew = "{crew}"}}', self.atoms_at(hx, hy, hz))
            for dx, dy, dz in data["airlock_doors"]:
                self.assertIn(f'/obj/structure/simple_door/train_raid_crew{{crew = "{crew}"}}', self.atoms_at(dx, dy, dz))
            for bx, by, bz in data["bridge_cells"]:
                self.assertIn(f'/obj/structure/train_raid_bridge{{crew = "{crew}"}}', self.atoms_at(bx, by, bz))
            # Stair pairs are unique per shuttle so the two copies never link.
            for z in range(z0, z1 + 1):
                for x in range(x0, x1 + 1):
                    for y in range(y0, y1 + 1):
                        for atom in self.atoms_at(x, y, z):
                            if "area_id" in atom:
                                self.assertIn(f'area_id = "train_raid_{crew}_', atom)

    def test_crew_rooms_hold_every_landmark_and_no_other_door_type(self):
        crew_doors = [p for p, atoms in self.grid.items() if any("train_raid_crew" in a for a in atoms)]
        self.assertEqual(len(crew_doors), 4)
        for crew, data in self.layout["crews"].items():
            x0, y0, x1, y1 = data["crew_bounds"]
            z = data["z"][0]
            locked = [a for x in range(x0, x1 + 1) for y in range(y0, y1 + 1) for a in self.atoms_at(x, y, z) if "locked = 1" in a]
            self.assertEqual(locked, [])

    def test_loot_pads_cover_every_anchor_with_rising_tiers(self):
        sections = self.layout["sections"]
        tiers = [s["tier"] for s in sections]
        self.assertEqual(tiers, sorted(tiers))
        self.assertLess(tiers[0], tiers[-1])
        total = 0
        for section in sections:
            x0, y0, x1, y1 = section["world_bounds"]
            pads = 0
            for x in range(x0, x1 + 1):
                for y in range(y0, y1 + 1):
                    atoms = self.atoms_at(x, y, 1)
                    has_anchor = any(a.startswith(("/obj/structure/closet/crate", "/obj/structure/table/rack")) for a in atoms)
                    pad = [a for a in atoms if a.startswith("/obj/effect/train_raid_loot")]
                    self.assertEqual(bool(pad), has_anchor, (x, y, atoms))
                    if pad:
                        self.assertEqual(pad[0], f'/obj/effect/train_raid_loot{{tier = {section["tier"]}}}')
                        pads += 1
            self.assertEqual(pads, section["loot_pads"])
            total += pads
        self.assertGreater(total, 200)
        hauler_beds = sum(1 for p, atoms in self.grid.items() if "/obj/structure/bed/train_raid" in atoms
                          and any(a.endswith("/area/train_raid/hauler/coaches") for a in atoms))
        self.assertEqual(hauler_beds, 20)

    def test_hauler_doors_open_without_keys(self):
        for atoms in self.grid.values():
            if not any(a.endswith("/area/train_raid/hauler") or "/area/train_raid/hauler/" in a for a in atoms):
                continue
            for atom in atoms:
                if atom.startswith("/obj/structure/simple_door"):
                    self.assertNotIn("locked", atom)
                    self.assertNotIn("key_door", atom)

    def flood(self, start, z=1):
        seen = {start}
        queue = deque([start])
        while queue:
            x, y = queue.popleft()
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if (nx, ny) in seen or (nx, ny, z) not in self.grid:
                    continue
                if walkable(self.atoms_at(nx, ny, z)):
                    seen.add((nx, ny))
                    queue.append((nx, ny))
        return seen

    def test_every_section_reachable_from_each_shuttle(self):
        for crew, data in self.layout["crews"].items():
            port_x, port_y = data["boarding_ports"][0]
            inside_x = port_x - 1 if crew == "west" else port_x + 1
            reach = self.flood((inside_x, port_y))
            # Crew doors block the public route; the crew's own bunks lie behind them.
            for px, py, pz in data["spawn_points"]:
                self.assertFalse((px, py) in reach, f"{crew} spawn {px},{py} is reachable without passing a crew door")
            inner, outer = sorted(data["airlock_doors"], key=lambda door: door[1])
            steps = ((1, 0), (-1, 0), (0, 1), (0, -1))
            self.assertTrue(any((outer[0] + sx, outer[1] + sy) in reach for sx, sy in steps),
                            f"{crew} outer airlock door does not touch the open carriage")
            self.assertFalse(any((inner[0] + sx, inner[1] + sy) in reach for sx, sy in steps),
                             f"{crew} inner airlock door is reachable without passing the outer door")
            for section in self.layout["sections"]:
                x0, y0, x1, y1 = section["world_bounds"]
                interior = [(x, y) for x in range(x0 + 1, x1) for y in range(y0 + 1, y1) if walkable(self.atoms_at(x, y, 1))]
                self.assertTrue(any(p in reach for p in interior), f"{section['id']} unreachable from {crew} shuttle")
            other = "east" if crew == "west" else "west"
            ox, oy = self.layout["crews"][other]["spawn_points"][0][:2]
            self.assertFalse((ox, oy) in reach, "crew doors must separate the two shuttles' crew rooms")


class TrainRaidSourceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.mode = MODE.read_text(encoding="utf-8")

    def test_wired_into_build(self):
        self.assertIn('#include "code\\game\\objects\\map_metadata\\train_raid.dm"', DME.read_text(encoding="utf-8"))
        self.assertIn('#define MAP_TRAIN_RAID "TRAIN_RAID"', DEFINES.read_text(encoding="utf-8"))

    def test_mode_contract(self):
        for needle in ("ID = MAP_TRAIN_RAID", "var/lives_per_raider = 3", "var/round_duration = 60 MINUTES",
                       "var/boarding_window = 5 MINUTES", "var/recall_travel = 3 MINUTES",
                       "var/docking_window = 2 MINUTES", "var/recall_cooldown = 5 MINUTES",
                       "/hook/death/proc/train_raid_death", "proc/collapse()", "proc/recall(mob/living/human/H)",
                       "proc/claim_bed(", "/obj/item/train_raid_balloon/afterattack", "/obj/item/train_raid_beacon/attack_self",
                       '/datum/job/civilian/train_raid/west', '/datum/job/civilian/train_raid/east'):
            self.assertIn(needle, self.mode)

    def test_player_text_uses_civ13_names(self):
        strings = re.findall(r'"([^"\n]*)"', self.mode)
        for text in strings:
            lowered = text.lower()
            self.assertNotIn("skyhook", lowered)
            self.assertNotIn("enginefall", lowered)
            self.assertNotIn("dagger", lowered)

    def test_loot_tables_reference_existing_types(self):
        sources = "\n".join(path.read_text(encoding="utf-8") for path in (
            ROOT / "code/game/objects/effects/spawners/loot.dm", ROOT / "code/game/objects/random.dm", MODE))
        for match in re.finditer(r"return list\(([^\n]*)\)", self.mode):
            for entry in match.group(1).split(","):
                entry = entry.strip()
                if entry == "null" or not entry.startswith("/"):
                    continue
                self.assertRegex(sources, re.escape(entry) + r"(\s|\n|$|/)", entry)


if __name__ == "__main__":
    unittest.main()

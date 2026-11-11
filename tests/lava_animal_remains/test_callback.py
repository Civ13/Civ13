"""Project the delayed lava-animal callback from its actual DM source.

This is a small offline source projection, not a BYOND runtime test.
"""

from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "code/modules/1713/natural_disasters.dm"
SIGNATURE = "/turf/floor/lava/proc/lava_animal_remains(mob/living/L)"


def callback_body(source):
    match = re.search(r"^" + re.escape(SIGNATURE) + r"[ \t]*$", source, re.M)
    if not match:
        raise AssertionError("Lava animal callback missing")
    rest = source[match.end():]
    end = re.search(r"^\S", rest, re.M)
    return rest[:end.start()] if end else rest


def project_callback(source, location):
    """Evaluate the callback's small supported DM subset, failing on drift.

    location is None for a missing target, 'land' after escape, or either
    'original lava' or 'other lava' for a living target on lava.
    """
    alive = location is not None
    on_lava = location in ("original lava", "other lava")
    deleted = False
    ash = None
    current_lava = None
    conditions = []

    def condition(text):
        if text == "L":
            return alive
        if text == "L && istype(L.loc, /turf/floor/lava)":
            return alive and on_lava
        raise AssertionError(f"Review changed callback condition: {text}")

    def action(text):
        nonlocal deleted, ash, current_lava
        if text == "qdel(L)":
            deleted = True
        elif text == "var/turf/floor/lava/current_lava = L.loc":
            current_lava = location
        elif re.fullmatch(r"new\s*/obj/effect/decal/cleanable/ash\(src\)", text):
            ash = "original lava"
        elif re.fullmatch(r"new\s*/obj/effect/decal/cleanable/ash\(current_lava\)", text):
            ash = current_lava
        else:
            raise AssertionError(f"Review changed callback action: {text}")

    for line in callback_body(source).splitlines():
        if not line.strip() or line.lstrip().startswith("//"):
            continue
        depth = len(line) - len(line.lstrip("\t"))
        statement = line.strip()
        while conditions and conditions[-1][0] >= depth:
            conditions.pop()
        match = re.fullmatch(r"if\((.*?)\)(?:\s+(.+))?", statement)
        if match:
            selected = condition(match.group(1))
            if match.group(2):
                if selected and all(item[1] for item in conditions):
                    action(match.group(2))
            else:
                conditions.append((depth, selected))
        elif all(item[1] for item in conditions):
            action(statement)
        elif not (statement in ("qdel(L)", "var/turf/floor/lava/current_lava = L.loc") or re.fullmatch(
                r"new\s*/obj/effect/decal/cleanable/ash\((?:src|current_lava)\)", statement)):
            raise AssertionError(f"Review changed callback action: {statement}")
    return deleted, ash


class LavaAnimalRemains(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = SOURCE.read_text(encoding="utf-8")

    def test_escaped_animal_survives_without_ash(self):
        self.assertEqual(project_callback(self.source, "land"), (False, None))

    def test_animal_still_on_lava_is_removed_with_ash(self):
        self.assertEqual(project_callback(self.source, "original lava"), (True, "original lava"))

    def test_missing_animal_produces_no_ash(self):
        self.assertEqual(project_callback(self.source, None), (False, None))

    def test_animal_on_another_lava_tile_remains_eligible(self):
        self.assertEqual(project_callback(self.source, "other lava"), (True, "other lava"))


if __name__ == "__main__":
    unittest.main()

"""Execute the production occupancy predicate with small offline type adapters.

This projects the DM body, not BYOND's native turf or object implementation.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
ECOLOGY = (ROOT / "code/modules/ecology/ecology_spawning.dm").read_text(encoding="utf-8")
FLORA = (ROOT / "code/modules/ecology/flora_regrowth.dm").read_text(encoding="utf-8")


def body(source, signature):
    match = re.search(rf"(?m)^{re.escape(signature)}[^\n]*\n((?:\t[^\n]*\n|\n)*)", source)
    if not match:
        raise AssertionError(f"missing {signature}")
    return match.group(1)


def project(source):
    lines = ["def blocked(T, ignored=None):"]
    for raw in body(source, "/proc/ecology_site_blocked(").splitlines():
        if not raw.strip():
            continue
        depth = len(raw) - len(raw.lstrip("\t"))
        line = raw.strip()
        if line == "for (var/atom/movable/AM in T)":
            line = "for AM in T:"
        elif line == "if (AM == ignored)":
            line = "if AM is ignored:"
        elif line.startswith("if (") and line.endswith(")"):
            condition = line[4:-1].replace("||", "or")
            condition = re.sub(r"istype\(AM, (/[^)]+)\)", lambda m: f"istype(AM, '{m[1]}')", condition)
            if re.search(r"[^a-zA-Z0-9_.' /(),-]", condition):
                raise AssertionError(f"unreviewed condition: {condition}")
            line = f"if {condition}:"
        elif line in ("continue", "return TRUE", "return FALSE"):
            line = line.replace("TRUE", "True").replace("FALSE", "False")
        else:
            raise AssertionError(f"unreviewed line: {line}")
        lines.append("    " * depth + line)
    env = {"istype": lambda obj, kind: kind in obj.kinds}
    exec(compile("\n".join(lines), "<production ecology predicate>", "exec"), env)
    return env["blocked"]


class Occupant:
    def __init__(self, density=False, *kinds):
        self.density = density
        self.kinds = kinds


class SiteOccupancy(unittest.TestCase):
    def test_actual_predicate_and_negative_controls(self):
        blocked = project(ECOLOGY)
        item = Occupant()
        stump = Occupant(False, "/obj/structure")
        self.assertFalse(blocked([]))
        self.assertFalse(blocked([item]))
        self.assertTrue(blocked([stump]))
        self.assertFalse(blocked([stump], stump))
        for expression, occupant in (
            ("AM.density", Occupant(True)),
            ("istype(AM, /mob/living)", Occupant(False, "/mob/living")),
            ("istype(AM, /obj/structure)", Occupant(False, "/obj/structure")),
            ("istype(AM, /obj/covers)", Occupant(False, "/obj/covers")),
        ):
            with self.subTest(expression=expression):
                self.assertTrue(blocked([stump, occupant], stump))
                omitted = ECOLOGY.replace(expression + " || ", "", 1) if expression != "istype(AM, /obj/covers)" else ECOLOGY.replace(" || " + expression, "", 1)
                self.assertFalse(project(omitted)([occupant]))
        self.assertTrue(blocked([stump, Occupant(False, "/obj/structure")], stump))

    def test_callers_retain_distinct_guards_and_order(self):
        wildlife = body(ECOLOGY, "/proc/ecology_habitat_error(")
        stump = body(FLORA, "/datum/flora_regrowth/proc/regrow_stump(")
        self.assertLess(wildlife.index('return "ground"'), wildlife.index('return "habitat"'))
        self.assertLess(wildlife.index('return "habitat"'), wildlife.index('return "roofed"'))
        self.assertLess(wildlife.index("T.contents.len > 32"), wildlife.index("ecology_site_blocked(T)"))
        self.assertIn('if (ecology_site_blocked(T))\n\t\treturn "occupied"', wildlife)
        self.assertLess(stump.index("locate(/obj/roof)"), stump.index("ecology_site_blocked(T, S)"))
        self.assertLess(stump.index("ecology_site_blocked(T, S)"), stump.index("ecology_visible_to_players"))
        self.assertNotIn("T.contents.len", stump)


if __name__ == "__main__":
    unittest.main()

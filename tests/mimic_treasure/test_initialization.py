"""Offline projection of the mimic chest's constructor ordering.

This reads the production DM; it does not compile or execute BYOND.
"""

from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[2]
CRATES = ROOT / "code/modules/1713/crates.dm"
MIMIC = ROOT / "code/game/mob/living/simple_animal/hostile/mimic.dm"


def proc(source, signature):
    match = re.search(r"^" + re.escape(signature) + r"\s*$", source, re.M)
    if not match:
        raise AssertionError(f"Missing {signature}")
    rest = source[match.end():]
    end = re.search(r"^\S", rest, re.M)
    return rest[:end.start()] if end else rest


def project_chest(source, rarity):
    """Project the constructor's parent call and selected paths assignment.

    Random counts use the source minimum. All four tables have guaranteed loot,
    so this also checks the least generous outcome of each rarity branch.
    """
    parent = proc(source, "/obj/structure/closet/crate/New()")
    if not re.search(r"(?m)^\tfor \(var/typepath in paths\)\s*$", parent):
        raise AssertionError("Review changed crate population loop")
    if not re.search(r"(?m)^\t\tvar/limit = paths\[typepath\]\s*$", parent):
        raise AssertionError("Review changed loot count lookup")
    if not re.search(r"(?m)^\t\tfor \(var/v in 1 to limit\)\s*$", parent):
        raise AssertionError("Review changed crate population count")
    if not re.search(r"(?m)^\t\t\tnew typepath \(src\)\s*$", parent):
        raise AssertionError("Review changed crate item construction")

    body = proc(source, "obj/structure/closet/crate/loottreasurechest/New()")
    branches = list(re.finditer(
        r"(?ms)^\t(?:if\(rarity\s*<=\s*2\)|"
        r"else if\(rarity > 2 && rarity <= 4\)|"
        r"else if\(rarity > 4 && rarity <= 8\)|else)\s*\n"
        r"\t\tpaths = list\((.*?)\)\s*(?=\n\t(?:else|for |\.\.\(\)))", body))
    if len(branches) != 4:
        raise AssertionError("Review changed rarity branch layout")
    branch_index = 0 if rarity <= 2 else 1 if rarity <= 4 else 2 if rarity <= 8 else 3
    selected = branches[branch_index]
    entries = re.findall(r"(/obj/[\w/]+)\s*=\s*(?:rand\((\d+),\s*\d+\)|(\d+))", selected.group(1))
    if not entries:
        raise AssertionError("No recognized loot entries")
    if len(entries) != len(re.findall(r"/obj/[\w/]+\s*=", selected.group(1))):
        raise AssertionError("Review unrecognized loot entry")
    chosen = {path: int(low or fixed) for path, low, fixed in entries}
    calls = list(re.finditer(r"(?m)^\t\.\.\(\)\s*$", body))
    if len(calls) != 1:
        raise AssertionError("Review changed parent constructor dispatch")
    paths_at_parent_call = chosen if selected.start() < calls[0].start() else {}
    return {kind: count for kind, count in paths_at_parent_call.items() if count > 0}


class MimicTreasureInitialization(unittest.TestCase):
    def test_death_creates_treasure_chest(self):
        body = proc(MIMIC.read_text(), "/mob/living/simple_animal/hostile/mimic/death()")
        self.assertRegex(body, r"new\s*/obj/structure/closet/crate/loottreasurechest\(src\.loc\)")

    def test_each_rarity_populates_guaranteed_loot(self):
        source = CRATES.read_text()
        for rarity in (0, 2, 3, 4, 5, 8, 9, 10):
            with self.subTest(rarity=rarity):
                items = project_chest(source, rarity)
                self.assertGreaterEqual(items.get("/obj/item/stack/money/goldnugget", 0), 1,
                                        "parent populated before the selected treasure paths existed")

    def test_saved_construction_returns_before_randomization(self):
        source = CRATES.read_text()
        body = proc(source, "obj/structure/closet/crate/loottreasurechest/New()")
        guard = re.search(r"(?m)^\tif \(persistence_saved_atom_construction\)\s*\n\t\treturn \.\.\(\)\s*$", body)
        self.assertIsNotNone(guard, "restoring a chest must bypass fresh random loot")
        self.assertLess(guard.start(), body.index("var/rarity = rand(0,10)"))
        self.assertRegex(source, r"/obj/structure/closet/crate/var/list/paths = list\(\)")

    def test_random_amount_applies_only_to_spawned_stacks(self):
        body = proc(CRATES.read_text(), "obj/structure/closet/crate/loottreasurechest/New()")
        self.assertRegex(body, r"(?m)^\tfor \(var/obj/item/stack/S in contents\)\s*\n"
                               r"\t\tS\.amount = rand\(1\+rarity,\(rarity\+1\)\*2\)")
        self.assertLess(body.index("\n\t..()"), body.index("\n\tfor (var/obj/item/stack/S in contents)"))


if __name__ == "__main__":
    unittest.main()

"""Offline source contracts and a bounded fishing-completion projection.

This is not a DM interpreter or native gameplay test. Production completion
blocks are admitted only if their exact normalized shape matches the reviewed
subset; the small model then projects the stock guard, chance, debit and product
ordering. Native do_after scheduling, chat, constructors and save/load remain
outside this evidence. No subprocess, network or BYOND invocation is used.
"""

import argparse
from dataclasses import dataclass, field
import itertools
from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[2]
SOURCE_PATH = Path("code/game/mob/living/simple_animal/friendly/static.dm")
ROUTES = (("modern", 120, 40), ("ordinary", 150, 30), ("branch", 120, 20))
EXPECTED_BODY = '''if (prob(CHANCE))
	to_chat(H, "You got a fish!")
	counter = (counter-1)
	if (species == "salmon")
		new/obj/item/weapon/reagent_containers/food/snacks/rawfish/salmon(H.loc)
	else if (species == "cod")
		new/obj/item/weapon/reagent_containers/food/snacks/rawfish/cod(H.loc)
	else
		new/obj/item/weapon/reagent_containers/food/snacks/rawfish(H.loc)
	if (counter <= 0)
		invisibility = 101
	get_fish()
	return
else
	to_chat(H, "You can't seem to get anything to bite...")
	return'''


def procedure(source, signature):
    start = source.index(signature + "\n")
    end = re.search(r"(?m)^/", source[start + len(signature) + 1:])
    stop = start + len(signature) + 1 + end.start() if end else len(source)
    return source[start:stop]


def completion_blocks(source):
    body = procedure(source, "/obj/structure/fish/attackby(var/obj/item/W as obj, var/mob/living/human/H as mob)")
    lines = body.splitlines()
    result = []
    for index, line in enumerate(lines):
        match = re.fullmatch(r"(\t+)if \(do_after\(H, (120|150), src\)\)", line)
        if not match:
            continue
        indent = match[1]
        collected = []
        for child in lines[index + 1:]:
            if child and not child.startswith(indent + "\t"):
                break
            if child:
                collected.append(child[len(indent) + 1:])
        result.append((int(match[2]), "\n".join(collected)))
    if len(result) != 3:
        raise ValueError("expected exactly three fishing completion routes")
    return result


def projection(source):
    """Fail closed on body drift; absence of a guard is allowed for controls."""
    result = {}
    for (name, delay, chance), (actual_delay, block) in zip(ROUTES, completion_blocks(source)):
        guarded = block.startswith("if (counter <= 0)\n\treturn\n")
        if guarded:
            block = block[len("if (counter <= 0)\n\treturn\n"):]
        expected = EXPECTED_BODY.replace("CHANCE", str(chance))
        if actual_delay != delay or block != expected:
            raise ValueError("unreviewed completion shape: " + name)
        result[name] = guarded
    return result


def omit_guard(source, route):
    delay, block = completion_blocks(source)[route]
    if not block.startswith("if (counter <= 0)\n\treturn\n"):
        raise ValueError("control needs a current guard")
    # The three route starts have identical indentation but distinct subsequent
    # chance lines. Replace the exact selected wait/guard/chance sequence once.
    chance = ROUTES[route][2]
    old = (f"\t\t\tif (do_after(H, {delay}, src))\n"
           "\t\t\t\tif (counter <= 0)\n\t\t\t\t\treturn\n"
           f"\t\t\t\tif (prob({chance}))")
    new = f"\t\t\tif (do_after(H, {delay}, src))\n\t\t\t\tif (prob({chance}))"
    if source.count(old) != 1:
        raise ValueError("selected control anchor is not unique")
    return source.replace(old, new, 1)


@dataclass
class School:
    counter: int
    species: str = "fish"
    products: list = field(default_factory=list)
    chance_rolls: list = field(default_factory=list)
    pending_refills: int = 0
    hidden: bool = False

    def admit(self, route):
        # Source contract below binds the existing entry stock predicates.
        return route if self.counter > 0 else None

    def complete(self, route, guards, *, waited=True, bite=True):
        if route is None or not waited:
            return
        if guards[route] and self.counter <= 0:
            return
        self.chance_rolls.append(route)
        if not bite:
            return
        self.counter -= 1
        self.products.append(self.species if self.species in ("salmon", "cod") else "fish")
        if self.counter <= 0:
            self.hidden = True
        # This projects the existing one-callback-per-success refill call. It
        # deliberately does not model callback ownership or persistence.
        if self.counter < 2:
            self.pending_refills += 1

    def refill(self):
        if self.pending_refills <= 0:
            raise ValueError("no owned model callback to consume")
        self.pending_refills -= 1
        self.counter += 1
        self.hidden = False


class FishingStockContract(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = (ROOT / SOURCE_PATH).read_text()
        cls.guards = projection(cls.source)

    def test_all_routes_recheck_stock_after_wait(self):
        self.assertEqual(self.guards, {route: True for route, _, _ in ROUTES})

    def test_entry_routes_and_wait_probability_contract(self):
        body = procedure(self.source, "/obj/structure/fish/attackby(var/obj/item/W as obj, var/mob/living/human/H as mob)")
        self.assertIn("if (istype(W, /obj/item/weapon/fishing) && counter > 0)", body)
        self.assertIn("else if (istype(W, /obj/item/weapon/branch) && counter > 0)", body)
        self.assertIn("if (istype(W, /obj/item/weapon/fishing/modern))", body)
        self.assertIn("if (B.sharpened)", body)
        self.assertEqual([delay for delay, _ in completion_blocks(self.source)], [120, 150, 120])
        self.assertEqual(re.findall(r"prob\((\d+)\)", body), ["40", "30", "20"])

    def test_debit_precedes_every_product_constructor(self):
        for _, block in completion_blocks(self.source):
            debit = block.index("counter = (counter-1)")
            for match in re.finditer("new/obj/", block):
                self.assertLess(debit, match.start())
            self.assertNotRegex(block[:debit], r"\b(sleep|spawn|input|do_after|call)\s*\(")

    def test_last_unit_competing_completion_pairs(self):
        for first, second in itertools.product(self.guards, repeat=2):
            with self.subTest(first=first, second=second):
                school = School(1)
                attempts = [school.admit(first), school.admit(second)]
                for attempt in attempts:
                    school.complete(attempt, self.guards)
                self.assertEqual((school.counter, len(school.products), school.pending_refills), (0, 1, 1))
                self.assertEqual(school.chance_rolls, [first])

    def test_two_units_three_waiters(self):
        for routes in itertools.product(self.guards, repeat=3):
            with self.subTest(routes=routes):
                school = School(2)
                admitted = [school.admit(route) for route in routes]
                for route in admitted:
                    school.complete(route, self.guards)
                self.assertEqual((school.counter, len(school.products), school.pending_refills), (0, 2, 2))

    def test_success_species_and_existing_refill(self):
        for route, species in itertools.product(self.guards, ("fish", "salmon", "cod")):
            school = School(1, species)
            school.complete(school.admit(route), self.guards)
            self.assertEqual(school.products, [species])
            self.assertTrue(school.hidden)
            school.refill()
            self.assertEqual((school.counter, school.pending_refills, school.hidden), (1, 0, False))

    def test_cancelled_wait_has_no_roll_debit_product_or_refill(self):
        for route in self.guards:
            school = School(1)
            school.complete(school.admit(route), self.guards, waited=False)
            self.assertEqual((school.counter, school.products, school.chance_rolls, school.pending_refills), (1, [], [], 0))

    def test_unsuccessful_chance_preserves_stock(self):
        for route in self.guards:
            school = School(1)
            school.complete(school.admit(route), self.guards, bite=False)
            self.assertEqual((school.counter, school.products, school.chance_rolls, school.pending_refills), (1, [], [route], 0))

    def test_empty_entry_still_has_no_wait_or_roll(self):
        for counter, route in itertools.product((0, -1), self.guards):
            school = School(counter)
            self.assertIsNone(school.admit(route))
            school.complete(school.admit(route), self.guards)
            self.assertEqual((school.counter, school.products, school.chance_rolls), (counter, [], []))

    def test_refill_before_second_completion_allows_paid_unit(self):
        for first, second in itertools.product(self.guards, repeat=2):
            school = School(1)
            attempts = [school.admit(first), school.admit(second)]
            school.complete(attempts[0], self.guards)
            school.refill()
            school.complete(attempts[1], self.guards)
            self.assertEqual((school.counter, len(school.products), school.pending_refills), (0, 2, 1))

    def test_each_single_route_guard_control_reproduces_deficit(self):
        for index, (route, _, _) in enumerate(ROUTES):
            with self.subTest(route=route):
                guards = projection(omit_guard(self.source, index))
                school = School(1)
                admitted = [school.admit("modern"), school.admit(route)]
                for attempt in admitted:
                    school.complete(attempt, guards)
                self.assertEqual((school.counter, len(school.products), school.pending_refills), (-1, 2, 2))

    def test_existing_refill_contract_unchanged(self):
        body = procedure(self.source, "/obj/structure/fish/proc/get_fish()")
        self.assertEqual(body.strip(), '''/obj/structure/fish/proc/get_fish()
\tif (counter < 2)
\t\tspawn(rand(3000,3600))
\t\t\tcounter = (counter+1)
\t\t\tif (invisibility == 101)
\t\t\t\tinvisibility = 0
\t\t\t\tupdate_icon()''')

    def test_projection_rejects_unreviewed_probability_or_debit(self):
        for before, after in (("prob(40)", "prob(41)"), ("counter = (counter-1)", "counter = (counter+1)")):
            with self.assertRaises(ValueError):
                projection(self.source.replace(before, after, 1))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("--source-root", type=Path)
    args, remaining = parser.parse_known_args()
    if args.source_root is not None:
        ROOT = args.source_root.resolve()
    unittest.main(argv=[__file__, *remaining])

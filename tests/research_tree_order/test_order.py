"""Groundwork order of the research tree (Val, 2026-11-14).

A prerequisite must be a real need, so players can leave alone the branches
they do not care about. Offline source checks of research_node.dm.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
NODE = re.compile(
    r'register_research_node\(new /datum/research_node\("(\w+)", "([^"]+)", "(\w+)", (\d+), (\d+), '
    r'(\w+), (null|list\([^)]*\)), (\d+)')
MILITARY = ("Military", "Armour")


def load():
    text = (ROOT / "code/modules/research_tree/research_node.dm").read_text(encoding="utf-8-sig")
    nodes = {}
    for m in NODE.finditer(text):
        nodes[m[1]] = {
            "name": m[2], "category": m[3], "milestone": m[6] == "RESEARCH_MODE_PROTOTYPE",
            "prereqs": re.findall(r'"(\w+)"', m[7]), "era": int(m[8])}
    recipes = {}
    for m in re.finditer(r'^\s*"/[^"]+"\s*=\s*"(\w+)"', text, re.M):
        recipes[m[1]] = recipes.get(m[1], 0) + 1
    return nodes, recipes


def milestones_by_era(nodes):
    found = {}
    for node_id, node in nodes.items():
        if node["milestone"]:
            found.setdefault(node["era"], set()).add(node_id)
    return found


def ancestors(nodes, node_id, seen=None):
    seen = set() if seen is None else seen
    for req in nodes[node_id]["prereqs"]:
        if req not in seen:
            seen.add(req)
            ancestors(nodes, req, seen)
    return seen


class TreeShape(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.nodes, cls.recipes = load()

    def test_parsed_whole_tree(self):
        self.assertGreaterEqual(len(self.nodes), 121)

    def test_prereqs_exist_and_are_not_from_a_later_era(self):
        for node_id, node in self.nodes.items():
            for req in node["prereqs"]:
                self.assertIn(req, self.nodes, node_id)
                self.assertLessEqual(self.nodes[req]["era"], node["era"], "%s needs later-era %s" % (node_id, req))

    def test_no_loops(self):
        for node_id in self.nodes:
            self.assertNotIn(node_id, ancestors(self.nodes, node_id), node_id)

    def test_no_civil_node_needs_a_military_one(self):
        for node_id, node in self.nodes.items():
            if node["category"] in MILITARY:
                continue
            for req in ancestors(self.nodes, node_id):
                self.assertNotIn(self.nodes[req]["category"], MILITARY, "%s needs military %s" % (node_id, req))

    def test_military_lines_need_no_other_civil_branch(self):
        # Arms, artillery and armour lean only on the trunk (tools, metals,
        # power) and on what they are physically built from.
        allowed = {
            "basic_tools", "bronze_working", "iron_smithing", "tatara_smelting", "blast_furnaces", "steelmaking", "alloys",
            "resource_processing", "watermills", "steam_power", "combustion",
            "early_cells", "galvanic_cells", "electricity",
            "primitive_construction", "stone_masonry", "carts", "wagons_ships",
            "powered_flight", "aviation_rocketry",
            "workshops", "factories", "assembly_line", "automation", "digital_computing",
            "digital_networks", "consumer_electronics"}
        for node_id, node in self.nodes.items():
            if node["category"] not in MILITARY:
                continue
            for req in ancestors(self.nodes, node_id):
                if self.nodes[req]["category"] not in MILITARY:
                    self.assertIn(req, allowed, "%s needs civil %s" % (node_id, req))

    def test_early_practice_tasks_can_be_done(self):
        # practice_work.dm asks for things "taught by" each prerequisite of a
        # node below era tier 5, so those prerequisites must teach a recipe.
        for node_id, node in self.nodes.items():
            if node["era"] >= 5:
                continue
            for req in node["prereqs"]:
                self.assertGreater(self.recipes.get(req, 0), 0, "%s practises %s, which teaches nothing" % (node_id, req))


class Bypasses(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.nodes, _ = load()

    def assert_free_of(self, node_id, *skipped):
        found = ancestors(self.nodes, node_id)
        for other in skipped:
            self.assertNotIn(other, found, "%s still needs %s" % (node_id, other))

    def test_farmers_can_skip_irrigation(self):
        for node_id in ("advanced_agriculture", "soil_science", "crop_breeding"):
            self.assertEqual(ancestors(self.nodes, node_id) - {"advanced_agriculture"}, {"basic_agriculture"})
        self.assertIn("irrigation", ancestors(self.nodes, "hydroponics"))

    def test_era_flavour_nodes_gate_nothing_outside_their_line(self):
        dependents = {}
        for node_id, node in self.nodes.items():
            for req in node["prereqs"]:
                dependents.setdefault(req, set()).add(node_id)
        for side in ("imperial_architecture", "classical_dress", "siege_engines", "mail_plate", "fine_garments", "monuments"):
            self.assertFalse(dependents.get(side), side)
        self.assertEqual(dependents.get("irrigation"), {"hydroponics"})

    def test_specialist_paths(self):
        self.assert_free_of("rocketry", "missiles", "mechanized_war", "cannon", "automobiles", "rail_steam")
        self.assert_free_of("uav_drones", "missiles", "mechanized_war")
        self.assert_free_of("powered_flight", "automobiles", "rail_steam", "wagons_ships")
        self.assert_free_of("cannon", "siege_engines", "imperial_architecture", "brickmaking")
        self.assert_free_of("mechanized_war", "siege_engines", "imperial_architecture", "brickmaking")
        self.assert_free_of("naval_mines", "field_artillery", "rail_steam")
        self.assert_free_of("emergency_medicine", "bronze_working", "printing_currency")
        self.assert_free_of("factories", "printing_currency")
        self.assert_free_of("fine_arts", "monuments", "stone_masonry")
        self.assert_free_of("tailoring", "classical_dress")
        self.assert_free_of("reinforced_concrete", "imperial_architecture")

    def test_trunk_is_honest(self):
        for node_id, needed in (
                ("steam_power", "iron_smithing"), ("electricity", "galvanic_cells"),
                ("nuclear_power", "electricity"), ("nuclear_power", "alloys"),
                ("iron_tools", "iron_smithing"), ("bronze_weapons", "bronze_working"),
                ("watermills", "resource_processing"), ("textile_mills", "steam_power")):
            self.assertIn(needed, ancestors(self.nodes, node_id), node_id)

    def test_every_branch_can_be_entered_without_the_trunk(self):
        for root in ("basic_tools", "primitive_construction", "pottery_storage", "ritual_worship", "papermaking",
                     "early_economy", "weaving", "basic_furniture", "carts", "basic_agriculture", "stone_arms",
                     "archery", "field_defenses", "padded_armor", "herbalism", "hygiene", "law_order"):
            self.assertEqual(self.nodes[root]["prereqs"], [], root)

    def test_milestones_and_their_peaceful_twins(self):
        milestones = {}
        for node_id, node in self.nodes.items():
            if node["milestone"]:
                milestones.setdefault(node["era"], set()).add(node_id)
        self.assertEqual(milestones, {
            1: {"bronze_working"}, 2: {"iron_smithing"}, 3: {"gunpowder", "printing_currency"},
            4: {"steam_power"}, 5: {"electricity"}, 6: {"mechanized_war", "powered_flight"},
            7: {"nuclear_power"}, 8: {"digital_computing"}, 9: {"digital_networks"}})

    def test_weapon_eras_can_be_opened_without_weapons(self):
        for era, twins in milestones_by_era(self.nodes).items():
            civil = [i for i in twins if self.nodes[i]["category"] not in MILITARY]
            self.assertTrue(civil, "era %d opens only through weapons" % era)
            for node_id in civil:
                for req in ancestors(self.nodes, node_id):
                    self.assertNotIn(self.nodes[req]["category"], MILITARY, node_id)

    def test_milestone_proofs_are_taught_by_earlier_groundwork(self):
        # A proof item must not be gated on the milestone it proves.
        text = (ROOT / "code/modules/research_tree/research_node.dm").read_text(encoding="utf-8-sig")
        for node_id, proof in re.findall(r'research_node\("(\w+)", [^\n]*RESEARCH_MODE_PROTOTYPE, [^\n]*?, \d+, (/obj/[\w/]+)\)', text):
            owner = re.search(r'^\s*"%s"\s*=\s*"(\w+)"' % re.escape(proof), text, re.M)
            if owner:
                self.assertNotEqual(owner[1], node_id, proof)
                self.assertLessEqual(self.nodes[owner[1]]["era"], self.nodes[node_id]["era"], proof)

if __name__ == "__main__":
    unittest.main()


class RecipePlacement(unittest.TestCase):
    """Recipes sit under the subject they belong to (Val, 2026-11-14)."""

    @classmethod
    def setUpClass(cls):
        cls.nodes, _ = load()
        text = (ROOT / "code/modules/research_tree/research_node.dm").read_text(encoding="utf-8-sig")
        cls.gates = dict(re.findall(r'^\s*"(/[^"]+)"\s*=\s*"(\w+)"', text, re.M))

    def test_firearm_and_blade_subjects_teach_no_armour(self):
        armour = ("/obj/item/clothing/head/helmet/", "/obj/item/clothing/suit/armor/",
                  "/obj/item/clothing/accessory/armor/", "/obj/item/clothing/gloves/gauntlets")
        for path, node in self.gates.items():
            if path.startswith(armour):
                self.assertNotIn(node, ("steel_blades", "rifling", "cartridge_ammo", "selfloading_firearms",
                                        "automatic_weapons"), path)

    def test_metal_armour_needs_its_metal(self):
        self.assertIn("iron_smithing", ancestors(self.nodes, "mail_plate"))
        self.assertIn("steelmaking", ancestors(self.nodes, "trench_warfare"))
        self.assertIn("alloys", ancestors(self.nodes, "modern_armor"))

    def test_single_items_sit_with_their_kind(self):
        for path, node in (
                ("/obj/item/ammo_casing/bolt", "crossbows"),
                ("/obj/item/weapon/material/pickaxe/stone", "basic_tools"),
                ("/obj/item/weapon/material/kitchen/utensil/knife/bone", "basic_tools"),
                ("/obj/structure/simple_door/key_door/anyone/ship", "wagons_ships"),
                ("/obj/structure/closet/crate/cart/bronze", "carts"),
                ("/obj/item/stack/cable_coil/white", "galvanic_cells")):
            self.assertEqual(self.gates.get(path), node, path)

    def test_a_proof_is_taught_by_a_prerequisite_of_its_milestone(self):
        self.assertIn(self.gates["/obj/item/weapon/geiger_counter"], self.nodes["nuclear_power"]["prereqs"])
        # Electricity's proof is a spool of cable: plain cable is taught by its prerequisite.
        self.assertIn(self.gates["/obj/item/stack/cable_coil/white"], self.nodes["electricity"]["prereqs"])

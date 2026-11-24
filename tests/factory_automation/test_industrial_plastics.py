"""Offline catalog assertions; see fabricators_probe.dm for native behavior."""
import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
PELLETS = "/obj/item/stack/polymer_pellets"
MOLDER = "/obj/structure/factory_fabricator/plastic_molder"


class IndustrialPlasticsCatalog(unittest.TestCase):
    def test_all_molding_dies_use_only_dedicated_stock(self):
        rows = {
            name: (product, int(out), inputs, int(time), int(tier), node)
            for name, product, out, inputs, time, tier, node in (
                line.removeprefix("FACTORY: ").split("|")
                for line in (ROOT / "config/crafting/factory_recipes.txt").read_text().splitlines()
                if line.startswith("FACTORY: ")
            )
        }
        molds = {name: row for name, row in rows.items() if PELLETS in row[2]}
        self.assertEqual(set(molds), {
            "Extrusion - plastic sheet", "Injection - plastic comb",
            "Injection - plastic tool handle", "Blow molding - empty plastic bottle",
            "Blow molding - plastic play ball", "Film forming - plastic bag",
        })
        self.assertEqual(molds["Injection - plastic tool handle"], (
            "/obj/item/weapon/material/handle/molded", 1, f"{PELLETS}=2",
            40, 1, "industrial_plastics"))
        self.assertEqual(molds["Blow molding - empty plastic bottle"][0],
                         "/obj/item/weapon/reagent_containers/food/drinks/bottle/plastic")
        for name, (_, out, inputs, _, tier, node) in molds.items():
            with self.subTest(name=name):
                self.assertEqual((out, tier, node), (1, 1, "industrial_plastics"))
                self.assertEqual(inputs, f"{PELLETS}={2 if 'tool handle' in name else 1}")
        self.assertNotIn(PELLETS, rows["printed screwdriver"][2])
        self.assertNotIn(PELLETS, rows["resin printed dice"][2])

    def test_generated_atlas_exposes_all_inputs_and_machine_boundary(self):
        atlas = json.loads((ROOT / "UI/crafting-atlas.json").read_text())
        entries = list(atlas["recipes"])
        if isinstance(atlas["recipes"], dict):
            entries = list(atlas["recipes"].values())
        all_names = {row["name"]: row for row in entries}
        costs = {
            "Bakelizer: polymerize petroleum into thermoplastic pellets": ("petroleum", 5),
            "Reaction bench: granulate polyethylene": ("polyethylene", 4),
            "Reaction bench: granulate polypropylene": ("polypropylene", 4),
        }
        for name, (reagent, cost) in costs.items():
            with self.subTest(name=name):
                row = all_names[name]
                self.assertEqual(row["research_nodes"], ["industrial_plastics"])
                self.assertEqual([(x["id"], int(x["quantity"])) for x in row["inputs"]],
                                 [(reagent, cost)])
                self.assertEqual(row["outputs"][0]["id"], PELLETS)
        for name, row in all_names.items():
            if name.startswith(("Extrusion - ", "Injection - ", "Blow molding - ", "Film forming - ")):
                self.assertIn("Plastics molding machine only", row["conditions"])
        self.assertTrue(any(MOLDER == x["id"] for row in entries for x in row["outputs"]))


if __name__ == "__main__":
    unittest.main()

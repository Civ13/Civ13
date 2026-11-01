"""Executable hypothetical candidate proof; no DM or native savefiles used."""
from copy import deepcopy
from pathlib import Path
import unittest

from human_spatial_candidate_model import LINKS, supported


def candidate():
    return {"human_type": "/mob/living/human", "human_ref": 10, "origin_turf_ref": 1,
            "bounds": (0, 0, 32, 32), "dimensions": (4, 4, 1), "constructors_and_defaults_audited": True,
            "position": {"x": 1, "y": 1, "z": 1, "sx": 2, "sy": 2},
            "links": {key: None for key in LINKS},
            "saved_edges": [(1, 10), (10, 20), (20, 21)], "slots": {"back": 20},
            "incoming_references": [(40, "target", 10)],
            "cells": {(1, 1, 1): {"type": "/turf/floor/dirt", "density": 0,
                                   "occupants": [{"ref": 10}]},
                      (2, 1, 1): {"type": "/turf/floor/grass", "density": 0,
                                   "occupants": [{"ref": 30, "type": "/obj/item/weapon/pen", "density": 0, "hooks_audited": True}]},
                      (1, 2, 1): {"type": "/turf/floor/wood", "density": 0},
                      (2, 2, 1): {"type": "/turf/floor/dirt", "density": 0}}}


class CandidateTests(unittest.TestCase):
    def test_positive_nonzero_offset_nested_bag_and_nondense_pen(self):
        self.assertTrue(supported(candidate()))

    def test_each_unsafe_change_refuses(self):
        def wall(c): c["cells"][(2, 2, 1)]["type"] = "/turf/wall"
        def dense_pen(c): c["cells"][(2, 1, 1)]["occupants"][0]["density"] = 1
        def unknown(c): c["cells"][(2, 1, 1)]["occupants"][0]["type"] = "/obj/structure/vehicleparts/frame"
        def buckle(c): c["links"]["buckled"] = 50
        def missing_default(c): del c["links"]["riding"]
        def duplicate(c): c["saved_edges"].append((40, 20))
        def missing_cell(c): del c["cells"][(2, 2, 1)]
        def unsafe_hook(c): c["cells"][(2, 1, 1)]["occupants"][0]["hooks_audited"] = False
        def reciprocal(c): c["incoming_references"].append((50, "buckled_mob", 10))
        def misplaced(c): c["saved_edges"][0] = (2, 10)
        for mutate in (wall, dense_pen, unknown, buckle, missing_default, duplicate, missing_cell, unsafe_hook, reciprocal, misplaced):
            case = deepcopy(candidate())
            mutate(case)
            with self.subTest(mutation=mutate.__name__): self.assertFalse(supported(case))

    def test_audited_default_and_known_parent_are_required(self):
        a = candidate(); a["constructors_and_defaults_audited"] = False
        self.assertFalse(supported(a))
        b = candidate(); b["slots"]["back"] = 21
        self.assertFalse(supported(b))

    def test_code_has_default_canpass_and_known_subtype_exception(self):
        root = Path(__file__).resolve().parents[2]
        atoms = (root / "code/game/atoms.dm").read_text()
        self.assertIn("return (!density || !height || air_group)", atoms)
        tape = (root / "code/game/objects/items/weapons/policetape.dm").read_text()
        self.assertIn("/obj/item/tape/CanPass(", tape)
        self.assertNotIn("/obj/item/tape", {item["type"] for cell in candidate()["cells"].values() for item in cell.get("occupants", []) if "type" in item})


if __name__ == "__main__":
    unittest.main()

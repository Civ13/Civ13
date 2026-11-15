"""Offline checks for tools/agent-control/region_move.py. No server is contacted."""
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/agent-control"))
import region_move  # noqa: E402


class FakeClient:
    """Records requests and answers like the operator agent would."""
    def __init__(self, depart_result):
        self.depart_result = depart_result
        self.requests = []

    def request(self, action, args=None):
        self.requests.append((action, args))
        if action == "inspect":
            return {"ok": 1, "result": {"ref": "[0x1]", "x": 5, "y": 6, "z": 1, "contents": []}}
        if action == "spawn_atom":
            return {"ok": 1, "result": {"spawned": [{"ref": "[0x9]"}]}}
        if action == "call_proc" and args["proc"] == "depart":
            return {"ok": 1, "result": {"done": 1, "result": self.depart_result}}
        return {"ok": 1, "result": {"done": 1, "result": None}}


class RegionMoveTests(unittest.TestCase):
    def test_refusals_name_only_top_level_items(self):
        msg = ("Leave these behind first: backpack (take out roasted dried meat, small copper pot and bone pieces), "
               "leather belt, waterskin, torch and pack basket (take out dried meat and leaf bundles).")
        self.assertEqual(region_move.refused_names(msg), ["backpack", "leather belt", "waterskin", "torch", "pack basket"])
        self.assertEqual(region_move.refused_names("Leave these behind first: fur coat."), ["fur coat"])
        self.assertEqual(region_move.refused_names({"list": []}), [])

    def test_agent_values_flatten(self):
        value = {"assoc": [["Danish", 43.75], ["German", {"list": [1, 2]}]]}
        self.assertEqual(region_move.flat(value), {"Danish": 43.75, "German": [1, 2]})

    def test_compare_counts_duplicates(self):
        want = region_move.item_rows([{"type": "/a", "name": "meat", "amount": 1, "contents": []}] * 3)
        got = region_move.item_rows([{"type": "/a", "name": "meat", "amount": 1, "contents": []}] * 2)
        missing, extra = region_move.compare(want, got)
        self.assertEqual(len(missing), 1)
        self.assertEqual(extra, [])

    def test_material_from_name(self):
        self.assertEqual(region_move.material_of("/obj/item/weapon/material/spear", "bronze spear"), "bronze")
        self.assertIsNone(region_move.material_of("/obj/item/weapon/paddle", "bronze paddle"))
        self.assertIsNone(region_move.material_of("/obj/item/weapon/material/spear", "spear"))

    def test_failed_departure_never_leaves_them_in_the_gate(self):
        fake = FakeClient("The trail is busy. Try again in a moment.")
        result = region_move.send(region_move.Region(None, "a", client=fake), "someone", "b")
        self.assertNotEqual(result, "departed")
        procs = [a["proc"] for k, a in fake.requests if k == "call_proc"]
        self.assertIn("forceMove", procs)
        self.assertEqual(fake.requests[-1][0], "delete_atom")

    def test_departed_player_is_not_pulled_back(self):
        fake = FakeClient("departed")
        region_move.send(region_move.Region(None, "a", client=fake), "someone", "b")
        procs = [a["proc"] for k, a in fake.requests if k == "call_proc"]
        self.assertNotIn("forceMove", procs)
        self.assertEqual(fake.requests[-1][0], "delete_atom")


if __name__ == "__main__":
    unittest.main()

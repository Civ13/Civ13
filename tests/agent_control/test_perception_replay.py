"""Synthetic replay of production perception and model-action parsing; no live service."""
import copy
import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "agent-control"))
import autopilot
import senses


class ReplayClient:
    def __init__(self):
        self.reply = None
        self.calls = []

    def request(self, action, args):
        self.calls.append((action, copy.deepcopy(args)))
        return copy.deepcopy(self.reply)


class PerceptionReplayTests(unittest.TestCase):
    def setUp(self):
        self.now = 0
        self.raw = ReplayClient()
        self.client = senses.SensesClient(self.raw, clock=lambda: self.now)

    def observe(self, result, *, at, radius=5):
        self.now = at
        self.raw.reply = {"ok": True, "result": result}
        return self.client.request("character_observe", {"character": "fixture-character", "radius": radius})["result"]

    @staticmethod
    def frame(rev, nearby=(), **extra):
        return dict({"self": {"ref": "[0x9]", "x": 10, "y": 20, "z": 1}, "rev": rev, "nearby": list(nearby)}, **extra)

    def news(self):
        return self.client.take_news("fixture-character")

    def test_synthetic_replay_targets_only_current_observations(self):
        fixture = json.loads((Path(__file__).parent / "fixtures/perception-v1.json").read_text(encoding="utf-8"))
        self.assertEqual(fixture["schema"], 1)
        for frame in fixture["frames"]:
            with self.subTest(at=frame["at"]):
                observation = self.observe(frame["result"], at=frame["at"])
                self.assertEqual([row["name"] for row in observation["nearby"]], frame["expected_nearby"])
                observation["news"] = self.news()
                self.assertEqual(observation["news"].get("last_seen", []), [frame["last_seen"]] if "last_seen" in frame else [])
                _, refs = autopilot.summarize(observation)
                self.assertEqual(autopilot.parse_decision(frame["model"], refs), frame["expected_action"])
                for row in observation["nearby"]:
                    self.assertFalse(any(key.startswith("_") for key in row))
                for row in observation["news"].get("last_seen", []):
                    self.assertNotIn("ref", row)

    def test_unchanged_delta_refreshes_last_visible_time_and_position(self):
        row = {"ref": "[0x2]", "name": "fixture tree", "dx": 3, "dy": 1}
        self.observe(self.frame(1, [row]), at=10)
        result = self.frame(2, changes_since=1, nearby_removed=[])
        result["self"]["x"] = 11
        observed = self.observe(result, at=20)
        self.assertEqual(observed["nearby"][0]["dx"], 2)
        self.observe(self.frame(3, changes_since=2, nearby_removed=["[0x2]"]), at=21)
        memory = self.news()["last_seen"][0]
        self.assertEqual(memory["age_s"], 1)
        self.assertEqual(memory["last_seen_rev"], 2)
        self.assertEqual(memory["position"], {"x": 13, "y": 21, "z": 1})
        self.now = 25
        self.assertEqual(self.news()["last_seen"][0]["age_s"], 5)

    def test_memories_expire_and_are_bounded(self):
        state = senses._Seen()
        for i in range(senses.LAST_SEEN_MAX + 20):
            self.client._remember(state, str(i), {"name": "fixture", "_seen_at": 0})
        self.assertEqual(len(state.last_seen), senses.LAST_SEEN_MAX)
        self.assertNotIn("0", state.last_seen)
        self.now = senses.LAST_SEEN_TTL + 1
        self.assertEqual(self.client._memories(state), [])
        self.assertEqual(state.last_seen, {})

    def test_full_refresh_loss_reappearance_and_unknown_position(self):
        self.observe({"rev": 1, "nearby": [{"ref": "[0x2]", "name": "fixture"}]}, at=10)
        self.observe({"rev": 2, "nearby": []}, at=12)
        memory = self.news()["last_seen"][0]
        self.assertEqual(memory["age_s"], 2)
        self.assertNotIn("position", memory)
        self.observe(self.frame(3, [{"ref": "[0x2]", "name": "fixture", "dx": 1, "dy": 0}]), at=15)
        self.assertNotIn("last_seen", self.news())

    def test_radius_change_does_not_invent_departure(self):
        self.observe(self.frame(1, [{"ref": "[0x2]", "name": "fixture", "dx": 4, "dy": 0}]), at=10)
        self.observe(self.frame(2), at=20, radius=1)
        self.assertEqual(self.news()["left"], [])
        self.assertNotIn("last_seen", self.news())

    def test_revision_restart_and_level_change_discard_old_identity(self):
        for kind in ("rev", "z"):
            with self.subTest(kind=kind):
                self.setUp()
                self.observe(self.frame(10, [{"ref": "[0x2]", "name": "fixture", "dx": 1, "dy": 0}]), at=1)
                self.observe(self.frame(11), at=2)
                self.assertIn("last_seen", self.news())
                result = self.frame(1 if kind == "rev" else 12)
                if kind == "z":
                    result["self"]["z"] = 2
                self.observe(result, at=3)
                self.assertNotIn("last_seen", self.news())

    def test_failed_observation_does_not_refresh_memory(self):
        self.observe(self.frame(1, [{"ref": "[0x2]", "name": "fixture", "dx": 1, "dy": 0}]), at=1)
        self.observe(self.frame(2), at=2)
        self.now = 9
        self.raw.reply = {"ok": False, "error": "forbidden"}
        self.client.request("character_observe", {"character": "fixture-character"})
        self.assertEqual(self.news()["last_seen"][0]["age_s"], 8)

    def test_memory_text_cannot_claim_current_truth(self):
        row = {"name": "fixture wolf", "age_s": 4, "position": {"x": 1, "y": 2, "z": 3}}
        line = senses.last_seen_lines([row])[0]
        self.assertIn("stale", line)
        self.assertIn("4 seconds ago", line)
        self.assertIn("current location unknown", line)
        self.assertIn("(1,2,3)", line)


if __name__ == "__main__":
    unittest.main()

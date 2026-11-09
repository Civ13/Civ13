"""Offline navigation replays, not native collision or visibility acceptance.

The route replies and movement receipts below are scripted. They check that
the client asks the game for a new route instead of inventing a detour, and
that blocked or unavailable destinations cannot cause unbounded retries.
"""

import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "agent-control"))

import boats  # noqa: E402
import autopilot  # noqa: E402


def route(moves, mode="walk", **fields):
    return {"ok": True, "result": {"reachable": True,
            "legs": [{"mode": mode, "moves": moves}] if moves else [], **fields}}


class Replay:
    def __init__(self, replies, summaries):
        self.replies = list(replies)
        self.summaries = list(summaries)
        self.queries = []
        self.actions = []

    def request(self, action, args):
        if action != "character_route":
            raise AssertionError(f"unexpected request: {action}")
        self.queries.append(dict(args))
        if not self.replies:
            raise AssertionError("replanned beyond the scripted bound")
        return self.replies.pop(0)

    def run(self, steps, since):
        self.actions.append([dict(step) for step in steps])
        if not self.summaries:
            raise AssertionError("requeued beyond the scripted bound")
        return self.summaries.pop(0), since + 1

    def travel(self):
        return boats.travel(self, "character", {"x": 12, "y": 20}, 0,
                            {"run": self.run, "craft_steps": None})

    def walk(self):
        return boats.route_to(self, "character", [12, 20], 0, self.run)


class NavigationReplayTests(unittest.TestCase):
    def test_approach_stops_when_a_target_is_missing_or_leaves_view(self):
        for initially_visible in (False, True):
            with self.subTest(initially_visible=initially_visible):
                class Client:
                    moves = 0

                    def request(self, action, args):
                        if action == "character_queue":
                            self.moves += 1
                            return {"ok": True, "result": {"queued": [self.moves]}}
                        if action != "character_observe":
                            raise AssertionError(f"unexpected request: {action}")
                        nearby = ([{"ref": "target", "name": "tree", "dx": 0, "dy": 4}]
                                  if initially_visible and not self.moves else [])
                        rows = ([{"id": self.moves, "do": "move", "ok": True, "detail": "done"}]
                                if self.moves else [])
                        return {"ok": True, "result": {"self": {"x": 10, "y": 20 + self.moves},
                                "nearby": nearby, "queue": {"pending": [], "running": False, "results": rows}}}

                client = Client()
                ok, detail, _ = autopilot.approach(client, "character", "target", 0)
                self.assertFalse(ok)
                self.assertEqual(detail, "lost sight of the target")
                self.assertEqual(client.moves, int(initially_visible))

    def test_changed_terrain_uses_a_fresh_game_route(self):
        for mode in ("walk", "boat"):
            with self.subTest(mode=mode):
                aboard = {"name": "raft", "role": "driver"} if mode == "boat" else None
                replay = Replay([route("e", mode, aboard=aboard),
                                 route("n", mode, aboard=aboard), route("")],
                                ["move ok (blocked)", "move ok (done)"])
                ok, detail, since = replay.travel()
                self.assertTrue(ok, detail)
                self.assertEqual(since, 2)
                self.assertEqual([chunk[0]["dir"] for chunk in replay.actions], ["east", "north"])
                self.assertEqual(len(replay.queries), 3)
                self.assertTrue(all(query == {"character": "character", "x": 12, "y": 20}
                                    for query in replay.queries))

    def test_an_unchanged_blocked_route_stops_after_one_replan(self):
        for mode in ("walk", "boat"):
            with self.subTest(mode=mode):
                aboard = {"name": "raft", "role": "driver"} if mode == "boat" else None
                replay = Replay([route("e", mode, aboard=aboard)] * 2,
                                ["move ok (blocked)"] * 2)
                ok, detail, since = replay.travel()
                self.assertFalse(ok, detail)
                self.assertEqual(len(replay.queries), 2)
                self.assertEqual(len(replay.actions), 2)
                self.assertEqual(since, 2)

    def test_boarding_walk_replans_changed_terrain_once(self):
        replay = Replay([route("e"), route("n"), route("")],
                        ["move ok (blocked)", "move ok (done)"])
        ok, detail, _ = replay.walk()
        self.assertTrue(ok, detail)
        self.assertEqual([chunk[0]["dir"] for chunk in replay.actions], ["east", "north"])
        self.assertEqual(len(replay.queries), 3)

    def test_boarding_walk_does_not_retry_permanent_blockage(self):
        replay = Replay([route("e")] * 2, ["move ok (blocked)"] * 2)
        ok, detail, _ = replay.walk()
        self.assertFalse(ok)
        self.assertEqual(detail, "blocked")
        self.assertEqual(len(replay.queries), 2)

    def test_a_destination_that_becomes_unreachable_stops(self):
        for method in ("travel", "walk"):
            with self.subTest(method=method):
                replay = Replay([route("e"), {"ok": True, "result": {
                    "reachable": False, "reason": "no way after terrain changed"}}],
                    ["move ok (blocked)"])
                ok, detail, _ = getattr(replay, method)()
                self.assertFalse(ok)
                self.assertIn("no way after terrain changed", detail)
                self.assertEqual(len(replay.actions), 1)

    def test_missing_or_wrong_level_target_does_not_move(self):
        for method in ("travel", "walk"):
            with self.subTest(method=method):
                replay = Replay([{"ok": False, "error": "bad_target",
                                  "detail": "the goal must be on the character's z level"}], [])
                ok, detail, _ = getattr(replay, method)()
                self.assertFalse(ok)
                self.assertIn("bad_target", detail)
                self.assertEqual(replay.actions, [])

    def test_failed_and_refused_actions_are_not_replayed(self):
        for method in ("travel", "walk"):
            for summary in ("move failed (not_controlled)", "refused (forbidden)",
                            "move ok (blocked); move failed (runtime_error)"):
                with self.subTest(method=method, summary=summary):
                    replay = Replay([route("e")], [summary])
                    ok, _, _ = getattr(replay, method)()
                    self.assertFalse(ok)
                    self.assertEqual(len(replay.queries), 1)
                    self.assertEqual(len(replay.actions), 1)

    def test_partial_progress_does_not_hide_a_failure_or_unknown_outcome(self):
        for method in ("travel", "walk"):
            for summary in ("move ok (done); move failed (not_controlled)",
                            "move ok (done); pending (missing receipts)", "", "move pending (still running)"):
                with self.subTest(method=method, summary=summary):
                    replay = Replay([route("ee")], [summary])
                    ok, _, _ = getattr(replay, method)()
                    self.assertFalse(ok)
                    self.assertEqual(len(replay.queries), 1)
                    self.assertEqual(len(replay.actions), 1)

    def test_a_known_skipped_suffix_is_safe_to_replan(self):
        for method in ("travel", "walk"):
            with self.subTest(method=method):
                replay = Replay([route("ee"), route("n"), route("")],
                                ["move ok (blocked); move failed (skipped: an earlier move was blocked)",
                                 "move ok (done)"])
                ok, detail, _ = getattr(replay, method)()
                self.assertTrue(ok, detail)
                self.assertEqual(len(replay.queries), 3)

    def test_execute_formats_blocked_receipts_for_the_route_replan(self):
        class Client(Replay):
            serial = 0
            results = []

            def request(self, action, args):
                if action == "character_queue":
                    self.actions.append(args["actions"])
                    self.results = []
                    for index, step in enumerate(args["actions"]):
                        self.serial += 1
                        blocked = len(self.actions) == 1
                        self.results.append({"id": self.serial, "do": step["do"],
                                             "ok": not blocked or index == 0,
                                             "detail": ("blocked" if index == 0 else "skipped: an earlier move was blocked")
                                             if blocked else "done"})
                    return {"ok": True, "result": {"queued": [row["id"] for row in self.results]}}
                if action == "character_observe":
                    return {"ok": True, "result": {"self": {}, "queue": {
                        "pending": [], "running": False, "results": self.results}}}
                return super().request(action, args)

        client = Client([route("ee"), route("n"), route("")], [])
        ok, detail, since = boats.travel(client, "character", {"x": 12, "y": 20}, 0,
                                        {"run": lambda steps, cursor: autopilot.execute(client, "character", steps, cursor),
                                         "craft_steps": None})
        self.assertTrue(ok, detail)
        self.assertEqual(since, 3)
        self.assertEqual(len(client.queries), 3)
        self.assertEqual(len(client.actions), 2)

    def test_ambiguous_receipt_exception_never_replans(self):
        replay = Replay([route("e")], [])

        def uncertain(steps, since):
            replay.actions.append(steps)
            raise autopilot.ContractError("queued action timed out; outcome is uncertain")

        with self.assertRaises(autopilot.ContractError):
            boats.travel(replay, "character", {"x": 12, "y": 20}, 0,
                         {"run": uncertain, "craft_steps": None})
        self.assertEqual(len(replay.queries), 1)
        self.assertEqual(len(replay.actions), 1)

    def test_partial_blockage_replans_from_the_confirmed_position(self):
        replay = Replay([route("eee"), route("n"), route("")],
                        ["move ok (done); move ok (blocked); move failed (skipped: an earlier move was blocked)",
                         "move ok (done)"])
        ok, detail, _ = replay.travel()
        self.assertTrue(ok, detail)
        self.assertIn("travelled 2 tiles", detail)
        self.assertEqual([chunk[0]["dir"] for chunk in replay.actions], ["east", "north"])

    def test_only_confirmed_blocked_receipts_allow_a_replan(self):
        self.assertTrue(boats._can_replan("move ok (blocked)", 0))
        self.assertFalse(boats._can_replan("move ok (blocked)", boats.BLOCKED_REPLANS))
        for summary in ("", "move pending (still running)", "move ok (done)",
                        "move ok (blocked); pending (missing receipts)",
                        "move ok (blocked); move failed (runtime_error)",
                        "refused (forbidden)"):
            with self.subTest(summary=summary):
                self.assertFalse(boats._can_replan(summary, 0))

    def test_semantic_destination_is_a_same_level_remembered_waypoint(self):
        me = {"x": 10, "y": 20, "z": 2}
        places = {"water": [{"x": 10, "y": 20, "z": 3},
                            {"x": 12, "y": 20, "z": 2},
                            {"x": 30, "y": 20, "z": 2}]}
        self.assertEqual(boats.target_of({"to": "water"}, me, places), (12, 20, ""))
        x, y, detail = boats.target_of({"to": "home"}, me, home={"x": 10, "y": 20, "z": 3})
        self.assertIsNone(x)
        self.assertIsNone(y)
        self.assertIn("no home on this level", detail)


if __name__ == "__main__":
    unittest.main()

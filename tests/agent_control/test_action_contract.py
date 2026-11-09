"""Sanitized deterministic replay of autopilot acceptance and completion boundaries."""
import concurrent.futures
import copy
import json
from pathlib import Path
import sys
import threading
import unittest
from unittest.mock import patch
import urllib.parse

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/agent-control"))
import autopilot
from action_contract import QueueClient, DecisionSlot, ModelWorker, targets_current
from civ13_agent import AgentClient, ContractError


class World:
    """Synthetic transport only. Never contacts a server or a model."""
    def __init__(self):
        self.calls = []
        self.guard = "a" * 32
        self.ids = []
        self.receipts = []
        self.running = False
        self.accepted_id = None
        self.fail = False

    def transport(self, host, port, query, timeout):
        q = dict(urllib.parse.parse_qsl(query))
        args = json.loads(q.get("args", "{}"))
        self.calls.append((q["action"], args))
        if q["action"] == "character_observe":
            result = {"self": {"ref": "[0x1]", "busy": False}, "nearby": [],
                      "queue": {"guard": self.guard, "pending": [], "running": self.running,
                                "results": copy.deepcopy(self.receipts)}}
        elif q["action"] == "character_queue":
            if self.fail:
                raise TimeoutError("synthetic disconnected write")
            self.accepted_id = q["request_id"]
            self.ids = list(range(1, 1 + len(args.get("actions", []))))
            self.actions = args.get("actions", [])
            result = {"state": "accepted", "request_id": q["request_id"], "queued": self.ids}
            self.running = bool(self.ids)
        else:
            result = {}
        return json.dumps({"ok": 1, "action": q["action"], "request_id": q["request_id"], "result": result})

    def finish(self):
        self.running = False
        self.receipts = [{"id": i, "do": a["do"], "ok": 1, "state": "completed", "detail": "done",
                          "request_id": self.accepted_id, "time": 12} for i, a in zip(self.ids, self.actions)]

    def client(self):
        return QueueClient(AgentClient("synthetic", "not-a-real-credential", transport=self.transport, correlated=True))


class CorrelationTests(unittest.TestCase):
    def test_rejects_missing_stale_wrong_action_and_malformed_receipts(self):
        for alter in (lambda q: {"ok": 1}, lambda q: {"ok": 1, "request_id": "old", "action": "status", "result": {}},
                      lambda q: {"ok": 1, "request_id": q["request_id"], "action": "restart", "result": {}},
                      lambda q: {"ok": "true", "request_id": q["request_id"]}):
            with self.subTest(alter=alter):
                def transport(h, p, query, t):
                    return json.dumps(alter(dict(urllib.parse.parse_qsl(query))))
                client = AgentClient("synthetic", "fake", transport=transport, correlated=True)
                with self.assertRaises(ContractError):
                    client.request("status")

    def test_duplicate_json_fields_fail_closed(self):
        client = AgentClient("synthetic", "fake", correlated=True,
                             transport=lambda *args: '{"ok": false, "ok": true}')
        with self.assertRaises(ContractError):
            client.request("status")

    def test_nonfinite_reply_is_malformed(self):
        client = AgentClient("synthetic", "fake", correlated=True,
                             transport=lambda *args: '{"ok": true, "result": NaN}')
        with self.assertRaises(ContractError):
            client.request("status")

    def test_ids_are_unique_and_errors_stay_correlated(self):
        ids = []
        def transport(h, p, query, t):
            q = dict(urllib.parse.parse_qsl(query))
            ids.append(q["request_id"])
            return json.dumps({"ok": 0, "error": "forbidden", "request_id": q["request_id"]})
        client = AgentClient("synthetic", "fake", transport=transport, correlated=True)
        self.assertFalse(client.request("status")["ok"])
        self.assertFalse(client.request("status")["ok"])
        self.assertEqual(len(set(ids)), 2)


class ReceiptTests(unittest.TestCase):
    def setUp(self):
        self.world = World()
        self.client = self.world.client()
        self.args = {"character": "[0x1]", "actions": [{"do": "face", "dir": "north"}]}

    def observe(self):
        return self.client.request("character_observe", {"character": "[0x1]"})

    def accept(self):
        self.observe()
        return self.client.request("character_queue", self.args)

    def test_no_observation_means_no_mutation(self):
        with self.assertRaises(ContractError):
            self.client.request("character_queue", self.args)
        self.assertEqual(self.world.calls, [])

    def test_acceptance_is_not_completion_and_only_one_action_is_pending(self):
        reply = self.accept()
        self.assertEqual(reply["result"]["state"], "accepted")
        self.assertEqual(self.world.calls[-1][1]["guard"], "a" * 32)
        with self.assertRaises(ContractError):
            self.client.request("character_queue", self.args)
        self.assertEqual(len(self.world.calls), 2)
        self.observe()
        self.assertIn("[0x1]", self.client.pending)
        self.world.finish()
        result = self.observe()["result"]
        self.assertEqual(result["queue"]["results"][0]["state"], "completed")
        self.assertNotIn("[0x1]", self.client.pending)

    def test_missing_wrong_duplicate_and_out_of_order_completions_are_not_success(self):
        for kind in ("missing", "wrong_request", "duplicate", "wrong_action", "out_of_order", "changed"):
            with self.subTest(kind=kind):
                self.setUp()
                self.args["actions"] *= 2
                self.accept()
                self.world.finish()
                if kind == "missing":
                    self.world.receipts = []
                elif kind == "wrong_request":
                    self.world.receipts[0]["request_id"] = "old"
                elif kind == "duplicate":
                    self.world.receipts.append(copy.deepcopy(self.world.receipts[0]))
                elif kind == "wrong_action":
                    self.world.receipts[0]["do"] = "say"
                elif kind == "out_of_order":
                    self.world.receipts.reverse()
                elif kind == "changed":
                    self.world.running = True
                    self.observe()
                    self.world.receipts[0]["detail"] = "different"
                with self.assertRaises(ContractError):
                    self.observe()
                self.assertTrue(self.client.halted)

    def test_early_cancelled_suffix_does_not_skip_late_running_completion(self):
        self.args["actions"] *= 2
        self.accept()
        self.world.finish()
        first, second = self.world.receipts
        second["ok"], second["detail"] = 0, "cancelled"
        self.world.receipts = [second]
        self.world.running = True
        self.observe()
        self.assertIn("[0x1]", self.client.pending)
        self.world.receipts = [first, second]
        self.world.running = False
        reply = self.client.request("character_observe", {"character": "[0x1]", "queue_since": 2})
        self.assertEqual(self.world.calls[-1][1]["queue_since"], 0)
        self.assertEqual([r["id"] for r in reply["result"]["queue"]["results"]], [1, 2])
        self.assertNotIn("[0x1]", self.client.pending)

    def test_write_timeout_is_never_replayed_after_reconnect(self):
        self.observe()
        self.world.fail = True
        client = autopilot.RetryingClient(self.client, sleep=lambda n: self.fail("mutation retried"))
        with self.assertRaises(ContractError):
            client.request("character_queue", self.args)
        self.world.fail = False
        self.observe()
        with self.assertRaises(ContractError):
            client.request("character_queue", self.args)
        self.assertEqual([a for a, _ in self.world.calls].count("character_queue"), 1)

    def test_clear_is_a_new_guarded_action_not_a_claim_to_undo_effects(self):
        self.accept()
        self.observe()
        cancelled = self.client.request("character_queue", {"character": "[0x1]", "clear": True})
        self.assertEqual(cancelled["result"]["state"], "accepted")
        self.assertNotIn("[0x1]", self.client.pending)
        self.assertEqual(self.world.calls[-1][1]["guard"], "a" * 32)
        self.assertIn("cancel_request_id", self.world.calls[-1][1])

    def test_exit_without_own_work_does_not_cancel_someone_elses_queue(self):
        self.observe()
        self.client.request("character_queue", {"character": "[0x1]", "clear": True})
        self.assertEqual([a for a, _ in self.world.calls], ["character_observe"])

    def test_pause_and_concurrent_request_cannot_send_mutations(self):
        self.observe()
        with patch.object(self.client, "paused", return_value=True):
            with self.assertRaises(ContractError):
                self.client.request("character_queue", self.args)
        self.assertEqual(len(self.world.calls), 1)
        self.client.lock.acquire()
        try:
            with self.assertRaises(ContractError):
                self.client.request("character_queue", self.args)
        finally:
            self.client.lock.release()
        self.assertEqual(len(self.world.calls), 1)

    def test_wait_timeout_and_refusal_are_not_empty_success(self):
        self.accept()
        with patch.object(autopilot.time, "monotonic", side_effect=[0, 31]):
            with self.assertRaises(ContractError):
                autopilot.wait_for_queue(self.client, "[0x1]", 0)
        class Refused:
            def request(self, *args):
                return {"ok": False, "error": "forbidden"}
        with self.assertRaises(ContractError):
            autopilot.wait_for_queue(Refused(), "[0x1]", 0)

    def test_hard_failed_chunk_does_not_execute_later_high_level_step(self):
        class Failed:
            def request(self, action, args=None):
                if action == "character_queue":
                    return {"ok": True}
                return {"ok": True, "result": {"self": {}, "queue": {"pending": [], "running": False,
                        "results": [{"id": 1, "do": "click", "ok": False, "detail": "out_of_view"}]}}}
        with patch.object(autopilot, "approach", side_effect=AssertionError("later work ran")):
            summary, _ = autopilot.execute(Failed(), "[0x1]", [{"do": "click", "target": "[0x2]"},
                                                              {"do": "go", "target": "[0x2]"}], 0)
        self.assertIn("failed", summary)
        self.assertTrue(summary.endswith("stopped there"))


class DecisionTests(unittest.TestCase):
    def test_one_pending_and_one_use_with_expiry_cancel_and_changed_state(self):
        now = [0]
        slot = DecisionSlot(lambda: now[0])
        observation = {"self": {"ref": "[0x1]", "x": 1}}
        ident = slot.begin(observation, 10)
        with self.assertRaises(ContractError):
            slot.begin(observation, 10)
        with self.assertRaises(ContractError):
            slot.complete("unsolicited", observation)
        self.assertTrue(slot.complete(ident, observation))
        with self.assertRaises(ContractError):
            slot.complete(ident, observation)
        ident = slot.begin(observation, 10)
        now[0] = 11
        self.assertFalse(slot.complete(ident, observation))
        ident = slot.begin(observation, 10)
        self.assertFalse(slot.complete(ident, {"self": {"ref": "[0x1]", "x": 2}}))
        ident = slot.begin(observation, 10)
        slot.cancel()
        with self.assertRaises(ContractError):
            slot.complete(ident, observation)

    def test_lost_changed_and_moved_targets_invalidate_answer(self):
        before = {"self": {"ref": "[0x1]"}, "nearby": [{"ref": "[0x2]", "name": "tree", "dx": 1}]}
        plan = [{"do": "click", "target": "[0x2]"}]
        self.assertTrue(targets_current(plan, before, before))
        self.assertFalse(targets_current(plan, before, {"nearby": []}))
        for field, value in (("name", "wolf"), ("dx", 2), ("type", "/hidden"), ("sickness", 1),
                             ("safe_to_mine", False), ("branches", 0), ("amount", 1), ("holds", "contaminated")):
            after = copy.deepcopy(before)
            after["nearby"][0][field] = value
            self.assertFalse(targets_current(plan, before, after))

    def test_full_target_metadata_and_fresh_expansion_are_required(self):
        before = {"self": {"ref": "[0x1]"}, "terrain": [{"ref": "turf:2,1,1", "name": "water", "sickness": 0}]}
        after = copy.deepcopy(before)
        after["terrain"][0]["sickness"] = 1
        self.assertFalse(targets_current([{"skill": "drink", "target": "turf:2,1,1"}], before, after))
        source = (ROOT / "tools/agent-control/autopilot.py").read_text(encoding="utf-8")
        final_look = source.index('current = checked["result"]')
        expansion = source.index('steps, error = expand_plan(plan, self_state', final_look)
        self.assertLess(source.index('observation = current', final_look), expansion)
        self.assertLess(source.index('self_state = current.get("self", {})', final_look), expansion)
        self.assertLess(source.index('reflex(current, self_state)', final_look), expansion)

    def test_continuous_needs_and_positive_oven_fuel_do_not_starve_actions(self):
        before = {"self": {"ref": "[0x1]", "health": 90, "blood": 400, "wounds": [{"damage": 3}]},
                  "nearby": [{"ref": "[0x2]", "name": "oven", "lit": 1, "fuel": 20.0}]}
        after = copy.deepcopy(before)
        after["self"].update(health=89, blood=399, wounds=[{"damage": 4}])
        after["nearby"][0]["fuel"] = 19.8
        slot = DecisionSlot()
        self.assertTrue(slot.complete(slot.begin(before, 10), after))
        self.assertTrue(targets_current([{"target": "[0x2]"}], before, after))
        after["nearby"][0]["fuel"] = 0
        self.assertFalse(targets_current([{"target": "[0x2]"}], before, after))

    def test_watcher_shutdown_wait_is_bounded_and_never_kills_children(self):
        class Child:
            def poll(self):
                return None
        now = [0]
        def sleep(seconds):
            now[0] += seconds
        result = autopilot.stop_watch_children({"x": {"process": Child()}}, clock=lambda: now[0], sleep=sleep, timeout=1)
        self.assertEqual(result, autopilot.CONTRACT_EXIT)
        self.assertEqual(now[0], 1)

    def test_already_finished_answer_cannot_bypass_deadline_or_pause(self):
        future = concurrent.futures.Future()
        future.set_result('{"do":"wait"}')
        args = type("Args", (), {"timeout": 1})()
        self.assertEqual(autopilot.wait_for_model(future, args, 1, lambda: "", clock=lambda: 2)[0], None)
        with patch.object(autopilot, "operator_paused", return_value=True):
            self.assertEqual(autopilot.wait_for_model(future, args, None, lambda: "")[0], None)

    def test_watcher_holds_ambiguous_runs_and_propagates_pause_file(self):
        class Child:
            def poll(self):
                return autopilot.CONTRACT_EXIT
        runs = {"[0x1]": {"process": Child(), "at": 0, "goal": "synthetic", "failed": False}}
        rows = [{"ref": "[0x1]", "kind": "spawned", "stat": 0, "waiting": True}]
        autopilot.reap_runs(runs, rows)
        self.assertTrue(runs["[0x1]"]["held"])
        self.assertEqual(autopilot.watch_targets(rows, runs, 999999), [])
        args = type("Args", (), {"goal": "synthetic", "pause_file": "operator.pause"})()
        command = autopilot.watch_command(args, rows[0])
        self.assertEqual(command[command.index("--pause-file") + 1], "operator.pause")

    def test_hung_inference_has_one_daemon_owner_and_no_game_callback(self):
        release = threading.Event()
        worker = ModelWorker()
        future = worker.submit(lambda: (release.wait(2), "late answer")[1])
        try:
            with self.assertRaises(ContractError):
                worker.submit(lambda: "second")
            thread = next(t for t in threading.enumerate() if t.name == "civ13-model")
            self.assertTrue(thread.daemon)
        finally:
            release.set()
        self.assertEqual(future.result(timeout=3), "late answer")


if __name__ == "__main__":
    unittest.main()

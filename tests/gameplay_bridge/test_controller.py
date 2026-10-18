"""Controller tests inject all transport and time; no Ollama/game is contacted."""
import copy
import json
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "scripts" / "gameplay_bridge"))
from bridge import Rejected
from controller import Controller
from test_bridge import CONTROL, observation


class ControllerTests(unittest.TestCase):
    def setUp(self):
        self.now = 0
        self.requests = []
        self.reports = []
        self.model_action = {"type": "say", "text": "I can carry food"}
        self.status = "executed"
        self.obs = observation()
        self.change_snapshot = False

    def transport(self, port, path, data, token=None, **kwargs):
        self.requests.append((port, path, copy.deepcopy(data), token, kwargs))
        if path == "/v1/observation":
            result = copy.deepcopy(self.obs)
            if self.change_snapshot and len(self.requests) > 2:
                result["observation_seq"] += 1
            return {"observation": result}
        if path == "/api/chat":
            return {"message": {"content": json.dumps(self.model_action)}}
        if path == "/v1/action":
            return {"request_id": data["request_id"], "status": self.status}
        return {"status": "stopped"}

    def sleep(self, seconds):
        self.now += seconds

    def controller(self):
        return Controller(CONTROL, "synthetic-local-model", transport=self.transport,
                          clock=lambda: self.now, sleep=self.sleep, report=self.reports.append)

    def test_bounded_loop_separates_tokens_and_stops_on_exit(self):
        result = self.controller().run(2)
        self.assertEqual(result, {"model_calls": 2, "executed_receipts": 2})
        self.assertEqual(self.requests[-1][1], "/v1/stop")
        for port, path, data, token, options in self.requests:
            self.assertGreater(options["timeout"], 0)
            if port == 11434:
                self.assertIsNone(token)
                self.assertNotIn(CONTROL, json.dumps(data))
                self.assertEqual(data["options"]["num_predict"], 128)
                self.assertEqual(len(data["messages"]), 2)

    def test_untrusted_model_cannot_call_proc_or_bypass_validation(self):
        self.model_action = {"type": "proc", "name": "delete_world"}
        self.controller().run(1)
        self.assertFalse(any(r[1] == "/v1/action" for r in self.requests))
        self.assertEqual(self.requests[-1][1], "/v1/stop")

    def test_model_stop_is_respected(self):
        self.model_action = {"stop": True}
        self.assertEqual(self.controller().run(4)["model_calls"], 1)
        self.assertEqual(self.requests[-1][1], "/v1/stop")

    def test_stale_model_proposal_is_never_rebased(self):
        self.change_snapshot = True
        self.controller().run(1)
        self.assertFalse(any(r[1] == "/v1/action" for r in self.requests))
        self.assertIn("stale model proposal discarded", self.reports)

    def test_three_failures_stop_without_success_claim(self):
        self.status = "blocked"
        result = self.controller().run(12)
        self.assertEqual(result, {"model_calls": 3, "executed_receipts": 0})
        self.assertEqual(self.requests[-1][1], "/v1/stop")

    def test_uncertain_delivery_retries_same_id_then_stops(self):
        self.status = "queued"
        result = self.controller().run(12)
        actions = [r[2] for r in self.requests if r[1] == "/v1/action"]
        self.assertEqual(len(actions), 16)
        self.assertTrue(all(a == actions[0] for a in actions))
        self.assertEqual(result["executed_receipts"], 0)
        self.assertEqual(self.requests[-1][1], "/v1/stop")

    def test_step_limit_cannot_be_expanded_by_configuration(self):
        for steps in (0, 13, True):
            with self.assertRaises(Rejected):
                self.controller().run(steps)
        self.assertEqual(self.requests, [])

    def test_transport_failure_still_attempts_stop(self):
        def failed(port, path, *args, **kwargs):
            self.requests.append((port, path))
            raise OSError("synthetic offline")
        c = self.controller()
        c.transport = failed
        c.run(1)
        self.assertEqual(self.requests[-1][1], "/v1/stop")
        self.assertIn("stop unconfirmed: use the local in-game STOP control", self.reports)


if __name__ == "__main__":
    unittest.main()

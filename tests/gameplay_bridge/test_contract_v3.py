"""Actual mailbox/delta contracts and source omission controls. No native proof."""
import copy
import json
from pathlib import Path
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts/gameplay_bridge"))
from bridge import Broker, Rejected, action_valid, observation_valid
from catalog import CATALOG, action_error, discovery, dm_catalog
from test_bridge import GAME, CONTROL, observation, request


def snapshot(seq=1, action_seq=1):
    obs = observation(seq, action_seq)
    obs.update(version=3, complete=1, limit_reason="none")
    obs["entities"][0]["id"] = "e1"  # Same public entity across snapshots.
    return obs


def proposal(obs=None, **kwargs):
    result = request(obs or snapshot(), **kwargs)
    result["version"] = 3
    return result


def stable_source_contract(source):
    """Structural gate only: deliberately does not interpret or execute DM."""
    return all(anchor in source for anchor in (
        'var/id = entity_ids[A]', 'next_entity_ids[A] = id',
        'entity_ids = next_entity_ids', 'entity_serial >= 999870',
        '"complete"=complete', '"limit_reason"=limit_reason',
        'length(json_encode(snapshot)) > 24576',
        'action_lease.request_id != reply["cancel"]',
        'action_lease.cancelled = TRUE'))


class ContractV3(unittest.TestCase):
    def setUp(self):
        self.now = 10.0
        self.b = Broker("fixture-a", GAME, CONTROL, clock=lambda: self.now)
        self.obs = snapshot()
        self.exchange(self.obs)

    def exchange(self, obs, receipt=None):
        return self.b.route("/v1/game/exchange", "Bearer " + GAME,
                            {"observation": obs, "receipt": receipt})

    def control(self, operation="status", **changes):
        body = {"version": 3, "operation": operation, "assignment": "fixture-a",
                "epoch": "epoch-a", "request_id": "request-1"}
        body.update(changes)
        return self.b.route("/v1/action", "Bearer " + CONTROL, body)

    def delta(self, seq=1, epoch="epoch-a"):
        return self.b.route("/v1/observation", "Bearer " + CONTROL,
                            {"version": 3, "epoch": epoch, "base_seq": seq})

    def test_discovery_is_inert_complete_and_same_validator_catalog(self):
        d = discovery()
        self.assertEqual({r["id"] for r in d["actions"]}, set(CATALOG))
        for row in d["actions"]:
            args = {key: (value[0] if isinstance(value, list) else
                          "hello" if value == "speech_160" else "e1")
                    for key, value in row["arguments"].items()}
            self.assertEqual(action_valid({"type": row["id"], **args}), row["id"])
        for row in d["unsupported"]:
            self.assertEqual(action_error({"type": row["id"]}), "unsupported_action")
        self.assertFalse(d["native_verified"])
        self.assertEqual(d["availability"], "disabled_source_only")
        self.assertLess(len(json.dumps(d).encode()), 32768)
        d["actions"][0]["arguments"].clear()
        self.assertTrue(discovery()["actions"][0]["arguments"])

    def test_discovery_command_requires_no_configuration(self):
        result = subprocess.run([sys.executable, "-B", str(ROOT / "scripts/gameplay_bridge/bridge.py"), "discover"],
                                capture_output=True, text=True, timeout=5, check=True)
        self.assertEqual(json.loads(result.stdout), discovery())

    def test_unsupported_versions_unknown_fields_and_unhashable_actions_reject(self):
        for value in (1, 4, True, "3"):
            obs = snapshot(); obs["version"] = value
            with self.assertRaises(Rejected): observation_valid(obs)
        for action in ({"type": []}, {"type": "move", "direction": "north", "proc": "spawn"},
                       {"type": "craft", "target": "e1", "recipe": "/proc/anything"}):
            with self.assertRaises(Rejected): action_valid(action)
        with self.assertRaises(Rejected):
            self.b.submit({**proposal(), "version": 2})

    def test_exact_id_status_and_cancel_keep_assignment_epoch_and_roles(self):
        self.b.submit(proposal())
        self.assertEqual(self.control()["status"], "queued")
        for changes in ({"epoch": "old"}, {"assignment": "other"}, {"request_id": "unknown"},
                        {"request_id": "\\ref[secret]"}, {"version": True}):
            with self.assertRaises(Rejected): self.control(**changes)
        with self.assertRaisesRegex(Rejected, "unauthorized"):
            self.b.route("/v1/action", "Bearer " + GAME,
                         {"version":3,"operation":"cancel","assignment":"fixture-a","epoch":"epoch-a","request_id":"request-1"})
        self.assertEqual(self.control()["status"], "queued")

    def test_queued_cancel_is_terminal_and_never_dispatched(self):
        original = proposal(); self.b.submit(original)
        self.assertEqual(self.control("cancel")["status"], "cancelled")
        self.assertIsNone(self.exchange(snapshot(2))["action"])
        self.assertEqual(self.b.submit(original)["status"], "cancelled")
        self.assertEqual(self.control("cancel")["status"], "cancelled")

    def test_inflight_cancel_waits_for_original_worker_receipt(self):
        self.b.submit(proposal())
        self.assertIsNotNone(self.exchange(snapshot(2))["action"])
        self.assertEqual(self.control()["status"], "dispatched")
        self.assertEqual(self.control("cancel")["status"], "cancel_requested")
        self.assertEqual(self.exchange(snapshot(3))["cancel"], "request-1")
        with self.assertRaisesRegex(Rejected, "busy"):
            self.b.submit(proposal(snapshot(3), request_id="request-2"))
        result = self.exchange(snapshot(4, 2), {"request_id":"request-1","status":"cancelled","reason":"cancelled","detail":""})
        self.assertIsNone(result["cancel"])
        self.assertIsNone(self.b.inflight)
        self.assertEqual(self.control()["status"], "cancelled")

    def test_cancel_can_lose_race_to_observed_completion_without_rollback(self):
        self.b.submit(proposal()); self.exchange(snapshot(2)); self.control("cancel")
        self.exchange(snapshot(3, 2), {"request_id":"request-1","status":"completed","reason":"none","detail":""})
        self.assertEqual(self.control()["status"], "completed")
        self.assertEqual(self.control("cancel")["status"], "completed")

    def test_uncertain_timeout_never_frees_worker(self):
        self.b.submit(proposal()); self.exchange(snapshot(2)); self.control("cancel")
        self.now += 31
        self.assertEqual(self.control()["status"], "unknown")
        self.assertEqual(self.b.inflight, "request-1")
        self.assertEqual(self.b.cancel_id, "request-1")
        self.exchange(snapshot(3, 2), {"request_id":"request-1","status":"cancelled","reason":"cancelled","detail":""})
        self.assertEqual(self.control()["status"], "cancelled")

    def test_cancel_after_uncertain_status_still_reaches_original_worker(self):
        self.b.submit(proposal()); self.exchange(snapshot(2)); self.now += 31
        self.assertEqual(self.control()["status"],"unknown")
        self.assertEqual(self.control("cancel")["status"],"unknown")
        self.assertEqual(self.b.cancel_id,"request-1")
        self.assertEqual(self.b.inflight,"request-1")

    def test_uncertain_game_receipt_never_acknowledges_quiescence(self):
        self.b.submit(proposal()); self.exchange(snapshot(2))
        uncertain={"request_id":"request-1","status":"unknown","reason":"transport_uncertain","detail":""}
        with self.assertRaisesRegex(Rejected,"receipt"):
            self.exchange(snapshot(3,2),uncertain)
        self.assertEqual(self.b.inflight,"request-1")
        self.now += 1.1
        self.exchange(snapshot(3,2))
        with self.assertRaisesRegex(Rejected,"busy"):
            self.b.submit(proposal(snapshot(3,2),request_id="request-2"))
        self.now += 31
        self.assertEqual(self.control()["status"],"unknown")
        self.exchange(snapshot(4,2),{"request_id":"request-1","status":"completed","reason":"none","detail":""})
        self.assertEqual(self.control()["status"],"completed")
        self.assertEqual(self.b.submit(proposal(snapshot(4,2),request_id="request-2"))["status"],"queued")

    def test_mutating_caller_proposal_cannot_change_validated_dispatch(self):
        original=proposal(); self.b.submit(original)
        original["action"]["direction"]="/proc/hidden"
        delivered=self.exchange(snapshot(2))["action"]
        self.assertEqual(delivered["action"]["direction"],"north")

    def test_controller_v3_polls_dispatched_until_observed_completed(self):
        from controller import Controller
        calls=[]; polls=[]
        def transport(port,path,packet,token=None,**kwargs):
            calls.append((path,copy.deepcopy(packet)))
            if path=="/v1/observation": return {"observation":snapshot()}
            if path=="/api/chat": return {"message":{"content":'{"type":"move","direction":"north"}'}}
            if path=="/v1/stop": return {"status":"stopped"}
            if packet.get("operation")=="status":
                polls.append(packet)
                return {"request_id":packet["request_id"],"status":"completed","reason":"none","detail":""}
            self.assertEqual(packet["version"],3)
            return {"request_id":packet["request_id"],"status":"dispatched","reason":"none","detail":""}
        c=Controller(CONTROL,"inert-model",transport=transport,clock=lambda:self.now,
                     sleep=lambda seconds:setattr(self,"now",self.now+seconds),report=lambda value:None)
        self.assertEqual(c.run(1)["executed_receipts"],1)
        self.assertEqual(len(polls),1)
        self.assertEqual(calls[-1][0],"/v1/stop")

    def test_stop_retains_scoped_uncertain_status_without_exposing_observation(self):
        self.b.submit(proposal()); self.exchange(snapshot(2)); self.b.stop()
        self.assertEqual(self.control()["status"], "cancel_requested")
        with self.assertRaisesRegex(Rejected,"stopped"): self.b.current()

    def test_receipt_identity_status_reason_and_hidden_details_are_bounded(self):
        self.b.submit(proposal()); self.exchange(snapshot(2))
        for receipt in (
            {"request_id":"other","status":"completed","reason":"none","detail":""},
            {"request_id":"request-1","status":"completed","reason":"cancelled","detail":""},
            {"request_id":"request-1","status":"denied","reason":"secret_container_present","detail":""},
            {"request_id":"request-1","status":"denied","reason":[],"detail":""},
            {"request_id":"request-1","status":"completed","reason":"none","detail":"x"*513}):
            with self.assertRaises(Rejected): self.exchange(snapshot(3, 2),receipt)
        self.assertEqual(self.control()["status"],"dispatched")

    def test_idempotency_conflict_and_evicted_receipt_cannot_execute(self):
        original=proposal(); self.b.submit(original)
        with self.assertRaisesRegex(Rejected,"request_id_conflict"):
            self.b.submit(proposal(kind={"type":"move","direction":"south"}))
        self.control("cancel")
        # Populate bounded retention with independent inert historical records.
        for i in range(64): self.b.remember("later-"+str(i),"digest",{"status":"completed"})
        with self.assertRaisesRegex(Rejected,"receipt_expired"): self.control()
        self.exchange(snapshot(2, 2)); self.now += 1
        with self.assertRaisesRegex(Rejected,"stale"): self.b.submit(original)

    def test_deltas_keep_stable_ids_and_remove_without_hidden_reason(self):
        new=snapshot(2); new["entities"][0]["name"]="visible change"
        self.exchange(new)
        result=self.delta()
        self.assertEqual(result["kind"],"delta")
        self.assertEqual(result["entities"][0]["id"],"e1")
        empty=snapshot(3); empty["entities"]=[]; self.exchange(empty)
        result=self.delta(2)
        self.assertEqual(result["removed"],["e1"])
        self.assertNotIn("destroyed",json.dumps(result))

    def test_history_eviction_epoch_and_partial_require_full_reset(self):
        for seq in range(2,7): self.exchange(snapshot(seq))
        self.assertLessEqual(len(self.b.history.rows),4)
        self.assertTrue(self.delta(1)["reset_required"])
        self.assertTrue(self.delta(6,"old-epoch")["reset_required"])
        partial=snapshot(7);partial.update(complete=0,limit_reason="visit_limit")
        self.exchange(partial)
        self.assertTrue(self.delta(6)["reset_required"])
        self.assertEqual(self.delta(6)["observation"]["limit_reason"],"visit_limit")
        for changes in ({"complete":1,"limit_reason":"visit_limit"}, {"complete":0,"limit_reason":"none"},
                        {"complete":"yes"}, {"limit_reason":"hidden object"}):
            bad=snapshot(8);bad.update(changes)
            with self.assertRaises(Rejected): self.exchange(bad)

    def test_delta_moves_own_item_between_sections_without_duplicate_identity(self):
        new=snapshot(2); new["inventory"]=new["entities"];new["entities"]=[]
        self.exchange(new)
        result=self.delta()
        self.assertEqual(result["inventory"][0]["id"],"e1")
        self.assertEqual(result["entities"],[])
        self.assertEqual(result["removed"],[])

    def test_history_owns_data_and_oversized_or_private_fields_reject(self):
        saved=copy.deepcopy(self.b.history.rows[1])
        self.obs["entities"][0]["name"]="changed outside history"
        self.assertEqual(self.b.history.rows[1],saved)
        for key,value in (("ckey","secret"),("contents",[]),("ref","\\ref[hidden]")):
            bad=snapshot(2);bad["entities"][0][key]=value
            with self.assertRaises(Rejected): observation_valid(bad)
        bad=snapshot(2);bad["padding"]="x"*32768
        with self.assertRaisesRegex(Rejected,"size"): observation_valid(bad)

    def test_generated_dm_catalog_and_unsafe_omission_controls(self):
        path=ROOT/"code/modules/gameplay_bridge/catalog.dm"
        self.assertEqual(path.read_text(),dm_catalog())
        for mutation in (dm_catalog().replace('"craft"','"eval"',1),dm_catalog().replace('A.len != keys.len','FALSE',1)):
            self.assertNotEqual(path.read_text(),mutation)
        source=(ROOT/"code/modules/gameplay_bridge/bridge.dm").read_text()
        self.assertTrue(stable_source_contract(source))
        for anchor in ('var/id = entity_ids[A]', 'entity_ids = next_entity_ids',
                       'length(json_encode(snapshot)) > 24576', 'action_lease.request_id != reply["cancel"]'):
            self.assertFalse(stable_source_contract(source.replace(anchor,"omitted",1)))
        self.assertNotIn("CIV13_GAMEPLAY_BRIDGE",(ROOT/"civ13.dme").read_text())


if __name__ == "__main__": unittest.main()

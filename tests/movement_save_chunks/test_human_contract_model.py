"""Tests of the proposed contract, not evidence that production implements it."""
from copy import deepcopy
from pathlib import Path
import unittest

from human_contract_model import HumanCapture, MovementDenied, Refused


CAPS = {"hooks_audited", "reference_fence", "all_player_paths"}


def attempt():
    humans = {"human": {"turf": "A", "z": 1, "direct_turf": True, "offset": (2, 4),
                         "owned": ["bag", "coin"], "slots": {"hand": "bag"}}}
    items = {"bag": {"owner": "human"}, "coin": {"owner": "bag"}}
    result = HumanCapture(humans, items, capabilities=CAPS)
    result.admit()
    return result


class HumanContractTests(unittest.TestCase):
    def test_absent_production_capability_refuses_admission(self):
        for missing in CAPS:
            a = attempt()
            a.capabilities.remove(missing)
            with self.subTest(missing=missing), self.assertRaises(Refused):
                a.admit()
            self.assertIsNone(a.marker)

    def test_walk_after_capture_keeps_origin_and_inventory_snapshot(self):
        a = attempt()
        a.capture("human")
        a.move("human", "B", 1)
        a.finish()
        human, items = a.records["human"]
        self.assertEqual(a.spatial, {"human": "A"})
        self.assertEqual(human["slots"]["hand"], "bag")
        self.assertEqual(human["offset"], (2, 4))
        self.assertEqual(items["coin"]["owner"], "bag")
        self.assertEqual(a.marker, "new")

    def test_drop_after_detached_capture_reuses_original_ownership(self):
        a = attempt()
        a.capture("human")
        a.transfer("bag", "ground")
        self.assertFalse(a.observe_item("bag", "ground", traversal=True))
        a.finish()
        self.assertEqual(a.records["human"][1]["bag"]["owner"], "human")
        self.assertEqual(a.marker, "new")

    def test_field_reference_after_transfer_fails_before_marker(self):
        a = attempt()
        previous = deepcopy(a.previous)
        a.capture("human")
        a.transfer("coin", "other")
        with self.assertRaises(Refused): a.observe_item("coin", "other")
        with self.assertRaises(Refused): a.finish()
        self.assertIsNone(a.marker)
        self.assertEqual(a.previous, previous)
        self.assertFalse(a.working)

    def test_cross_level_refusal_does_not_invalidate_save(self):
        a = attempt()
        with self.assertRaises(MovementDenied): a.move("human", "B", 2)
        self.assertEqual(a.humans["human"]["turf"], "A")
        a.finish()
        self.assertEqual(a.marker, "new")

    def test_prior_external_capture_rejects_new_group(self):
        a = attempt()
        self.assertTrue(a.observe_item("bag", "elsewhere"))
        with self.assertRaises(Refused): a.capture("human")
        self.assertIsNone(a.marker)

    def test_second_human_cannot_capture_first_humans_member(self):
        a = attempt()
        a.humans["other"] = {"turf": "B", "z": 1, "direct_turf": True,
                             "owned": [], "slots": {"hand": None}}
        a.roster = tuple(a.humans)
        a.capture("human")
        a.transfer("bag", "other")
        a.humans["other"]["owned"] = ["bag", "coin"]
        a.humans["other"]["slots"]["hand"] = "bag"
        with self.assertRaises(Refused): a.capture("other")
        self.assertIsNone(a.marker)

    def test_bad_slots_cycles_external_owners_and_missing_item_refuse(self):
        def cycle(a): a.inventory["bag"]["owner"] = "coin"
        def slot(a): a.humans["human"]["slots"]["hand"] = "coin"
        def external(a): a.inventory["coin"]["owner"] = "other"
        def missing(a): del a.inventory["coin"]
        for mutate in (cycle, slot, external, missing):
            a = attempt()
            mutate(a)
            with self.subTest(mutate=mutate.__name__), self.assertRaises(Refused):
                a.capture("human")
            self.assertIsNone(a.marker)

    def test_interleaved_mutation_cannot_publish_partial_stage(self):
        a = attempt()
        previous = deepcopy(a.previous)
        with self.assertRaises(Refused):
            a.capture("human", during_capture=lambda model: model.move("human", "B", 1))
        self.assertFalse(a.working)
        self.assertEqual(a.records, {})
        self.assertIsNone(a.marker)
        self.assertEqual(a.previous, previous)

    def test_duplicate_spatial_owner_cannot_publish(self):
        a = attempt()
        a.capture("human")
        a.spatial["human"] = "B"
        with self.assertRaises(Refused): a.finish()
        self.assertIsNone(a.marker)

    def test_inflight_and_coupled_states_refuse(self):
        for field in ("inflight", "coupled"):
            a = attempt()
            a.humans["human"][field] = True
            with self.subTest(field=field), self.assertRaises(Refused): a.capture("human")

    def test_deleted_roster_and_hook_exception_preserve_previous(self):
        a = attempt()
        previous = deepcopy(a.previous)
        del a.humans["human"]
        with self.assertRaises(Refused): a.finish()
        self.assertEqual(a.previous, previous)
        b = attempt()
        def broken(_): raise RuntimeError("hook failure")
        with self.assertRaises(RuntimeError): b.capture("human", during_capture=broken)
        with self.assertRaises(Refused): b.finish()
        self.assertIsNone(b.marker)
        self.assertFalse(b.working)


class ExistingSourceBoundaryTests(unittest.TestCase):
    """Pin the protections that this proposal must not silently bypass."""
    root = Path(__file__).resolve().parents[2]

    def test_human_guard_and_cross_level_guard_remain(self):
        human = (self.root / "code/game/mob/living/carbon/human/subtile_movement.dm").read_text()
        valid = human.split("/datum/human_subtile_transaction/proc/valid(", 1)[1].split("\n/datum/", 1)[0]
        self.assertIn("persistence_save_in_progress", valid)
        mover = (self.root / "code/game/atoms_movable.dm").read_text()
        self.assertIn("persistence_movement_allowed", mover)
        self.assertIn("persistence_save_active()", mover)

    def test_candidate_marker_follows_roster_drain_and_prior_backup(self):
        saving = (self.root / "code/modules/persistence/saving.dm").read_text()
        body = saving.split("/map_storage/proc/save_world_contents(", 1)[1].split("/map_storage/proc/BuildVarDirectory", 1)[0]
        self.assertLess(body.index('fcopy("map_saves/save_complete.txt"'), body.index('fdel("map_saves/save_complete.txt")'))
        self.assertLess(body.index("drain_moving_save_roster(savefile)"), body.index('text2file(generation,"map_saves/save_complete.txt")'))

    def test_preflight_is_bounded_unwired_and_cannot_authorize_capture(self):
        saving = (self.root / "code/modules/persistence/saving.dm").read_text()
        body = saving.split("/datum/moving_human_ownership_preflight\n", 1)[1].split("\n/datum/moving_save_preflight\n", 1)[0]
        self.assertEqual(saving.count("/datum/moving_human_ownership_preflight"), 1)
        self.assertIn("#ifdef CIV13_HUMAN_SUBTILE_CAPTURE_SOURCE\n", saving)
        self.assertIn("\n#endif\n", body)
        dme = (self.root / "civ13.dme").read_text()
        self.assertLess(dme.index(r"code\game\mob\living\carbon\human\subtile_movement.dm"), dme.index(r"code\modules\persistence\saving.dm"))
        for guard in ("queue.len > 128", "parent.contents.len > 128 - queue.len",
                      "world.time != start_tick", "child.loc != parent", "item.loc != H",
                      "isDeleted(member)", "member.contents.len != counts[",
                      "H.human_subtile_transaction != transaction", "transaction.expected, start_position"):
            self.assertIn(guard, body)
        for forbidden in ("before_save(", "BuildVarDirectory(", "bind_entry(", "saving_references[", "sleep(", "finish(", "wait_paid_interval("):
            self.assertNotIn(forbidden, body)
        self.assertLess(body.index("root = H"), body.index("members = queue"))
        self.assertLess(body.index("members = queue"), body.index("return TRUE"))
        self.assertLess(body.index("for(var/key in slot_names)\n\t\t\tif(H.vars[key] != local_slots[key])"), body.index("root = H"))

    def test_actual_human_handoff_cannot_finish_inside_capture(self):
        source = (self.root / "code/game/mob/living/carbon/human/subtile_movement.dm").read_text()
        before = source.split("/mob/living/human/before_save()", 1)[1].split("\n/mob/", 1)[0]
        self.assertIn("if (human_subtile_pulse)", before)
        self.assertIn("human_subtile_transaction.cancelled = TRUE", before)
        paid = source.split("/datum/human_subtile_transaction/proc/wait_paid_interval()", 1)[1].split("\n/datum/", 1)[0]
        self.assertIn("sleep(world.tick_lag)", paid)
        finish = source.split("/datum/human_subtile_transaction/proc/finish()", 1)[1].split("\n/mob/", 1)[0]
        self.assertIn("complete()", finish)


if __name__ == "__main__":
    unittest.main()

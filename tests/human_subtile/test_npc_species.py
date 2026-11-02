"""Offline source contracts for staged species movement, without BYOND."""
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch
import importlib.util
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]


class SpeciesContracts(unittest.TestCase):
    def test_crab_retains_one_lateral_choice_and_legacy_path(self):
        source = (ROOT / 'code/game/mob/living/simple_animal/friendly/crab.dm').read_text(encoding='utf-8')
        life = source.split('/mob/living/simple_animal/crab/Life()\n', 1)[1].split('/mob/living/simple_animal/crab/small/crab_san', 1)[0]
        for token in ('if (!ckey && !stat)', 'isturf(loc) && !resting && !buckled',
                      'turns_since_move >= move_to_delay', 'get_step(src, pick(4, 8))',
                      'if (npc_subtile_species_enabled && npc_subtile_enabled)', 'ai_step(destination, move_to_delay, TRUE)',
                      'moved = Move(destination)', 'if (moved)', 'turns_since_move = FALSE'):
            self.assertIn(token, life)
        self.assertEqual(life.count('pick(4, 8)'), 1)
        self.assertLess(life.index('pick(4, 8)'), life.index('if (npc_subtile_species_enabled && npc_subtile_enabled)'))

    def test_both_flags_choose_staged_or_legacy_without_missing_fallback(self):
        source = (ROOT / "code/game/mob/living/simple_animal/subtile_movement.dm").read_text(encoding="utf-8")
        crab = (ROOT / "code/game/mob/living/simple_animal/friendly/crab.dm").read_text(encoding="utf-8")
        wrapper = source.split("/mob/living/simple_animal/proc/npc_subtile_species_walk(", 1)[1].split("/mob/living/simple_animal/proc/npc_subtile_start_wild_walk(", 1)[0]
        life = crab.split("/mob/living/simple_animal/crab/Life()\n", 1)[1].split("/mob/living/simple_animal/crab/small/crab_san", 1)[0]
        self.assertIn("if (!npc_subtile_species_enabled || !npc_subtile_enabled)", wrapper)
        self.assertIn("if (!npc_subtile_species_legacy_ready())\n\t\t\treturn FALSE", wrapper)
        self.assertIn("if (npc_subtile_species_enabled && npc_subtile_enabled)", life)
        self.assertIn("else if (npc_subtile_species_legacy_ready())\n\t\t\t\t\tmoved = Move(destination)", life)
        for call in ("walk_rand(src, lag)", "walk_towards(src, target, lag)", "walk_away_od(src, target, distance_limit, lag)", "walk_to(src, target, distance_limit, lag)", "walk(src, direction, lag)"):
            self.assertIn(call, wrapper)
        for base in (False, True):
            for species in (False, True):
                self.assertEqual((not species or not base), not (species and base))

    def test_legacy_readiness_projects_real_source_and_fails_closed(self):
        source = (ROOT / "code/game/mob/living/simple_animal/subtile_movement.dm").read_text(encoding="utf-8")
        spec = importlib.util.spec_from_file_location("species_fallback_adapter", ROOT / "tests/save_movement/source_adapter.py")
        adapter = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(adapter)
        world = SimpleNamespace(time=10)
        fields = ("npc_subtile_transaction", "npc_subtile_pulse", "npc_subtile_until",
                  "npc_subtile_offset_owned", "step_x", "step_y", "npc_subtile_stop_wild_walk",
                  "npc_subtile_pending_intent", "npc_subtile_intent_valid", "npc_subtile_wild_walk")
        with patch.object(adapter, "FIELDS", adapter.FIELDS + fields):
            ready = adapter.project(source, "/mob/living/simple_animal/proc/npc_subtile_species_legacy_ready",
                                    "src", {"world": world}, method=True)
        actor = SimpleNamespace(npc_subtile_transaction=None, npc_subtile_pulse=None,
            npc_subtile_until=10, npc_subtile_offset_owned=False, step_x=0, step_y=0,
            npc_subtile_pending_intent=None, npc_subtile_wild_walk=None)
        calls = []
        def stop():
            calls.append("stop")
        actor.npc_subtile_stop_wild_walk=stop
        actor.npc_subtile_intent_valid=lambda owner: True
        self.assertTrue(ready(actor))
        self.assertEqual(calls, ["stop"])
        for field, value in (("npc_subtile_transaction", object()), ("npc_subtile_pulse", object()),
                             ("npc_subtile_until", 11), ("npc_subtile_pending_intent", object())):
            with self.subTest(field=field):
                old=getattr(actor,field); setattr(actor,field,value)
                self.assertFalse(ready(actor))
                setattr(actor,field,old)
        actor.npc_subtile_offset_owned=True; actor.step_x=2
        self.assertFalse(ready(actor))
        actor.step_x=0; actor.npc_subtile_intent_valid=lambda owner: False
        calls.clear()
        self.assertFalse(ready(actor))
        self.assertEqual(calls, [], "another owner must be checked before retiring a wild owner")

    def test_setter_retires_wild_owner_only_after_safe_admission(self):
        source = (ROOT / "code/game/mob/living/simple_animal/subtile_movement.dm").read_text(encoding="utf-8")
        setter = source.split("/mob/living/simple_animal/proc/set_npc_subtile(enabled)\n",1)[1].split("\n/",1)[0]
        self.assertLess(setter.index("npc_subtile_transaction || npc_subtile_pulse"), setter.index("npc_subtile_stop_wild_walk()"))
        self.assertLess(setter.index("if (!enabled)"), setter.index("npc_subtile_stop_wild_walk()"))
        self.assertLess(setter.index("npc_subtile_stop_wild_walk()"), setter.index("npc_subtile_offset_owned = FALSE"))

    def test_setter_executes_real_wild_retirement_and_refuses_active_state(self):
        source = (ROOT / "code/game/mob/living/simple_animal/subtile_movement.dm").read_text(encoding="utf-8")
        spec = importlib.util.spec_from_file_location("species_setter_adapter", ROOT / "tests/save_movement/source_adapter.py")
        adapter = importlib.util.module_from_spec(spec); spec.loader.exec_module(adapter)
        fields = ("npc_subtile_transaction", "npc_subtile_pulse", "npc_subtile_shape",
                  "npc_subtile_offset_owned", "step_x", "step_y", "npc_subtile_enabled",
                  "npc_subtile_stop_pursuit", "npc_subtile_stop_wild_walk", "npc_subtile_release_glide",
                  "npc_subtile_cancel_pending", "npc_subtile_wild_walk", "npc_subtile_release_generation", "npc_subtile_intent_valid")
        with patch.object(adapter, "FIELDS", adapter.FIELDS + fields):
            stop = adapter.project(source, "/mob/living/simple_animal/proc/npc_subtile_stop_wild_walk",
                                   "src, cancel_pending=True", {}, method=True)
            setter = adapter.project(source, "/mob/living/simple_animal/proc/set_npc_subtile",
                                     "src, enabled", {}, method=True)
        calls = []
        actor = SimpleNamespace(npc_subtile_transaction=None, npc_subtile_pulse=None,
            npc_subtile_shape=lambda: True, npc_subtile_offset_owned=False, step_x=0, step_y=0,
            npc_subtile_enabled=True, npc_subtile_stop_pursuit=lambda: calls.append("pursuit"),
            npc_subtile_release_glide=lambda: calls.append("glide"),
            npc_subtile_cancel_pending=lambda kind: calls.append(("cancel",kind)),
            npc_subtile_intent_valid=lambda owner: True,
            npc_subtile_release_generation=lambda gen, transfer: calls.append(("release",gen,transfer)))
        owner=SimpleNamespace(generation=7,cancelled=False,detach_transaction=lambda: calls.append("detach"))
        actor.npc_subtile_wild_walk=owner
        actor.npc_subtile_stop_wild_walk=lambda: stop(actor)
        actor.npc_subtile_transaction=object()
        self.assertFalse(setter(actor,False)); self.assertIs(actor.npc_subtile_wild_walk,owner)
        self.assertFalse(owner.cancelled); self.assertEqual(calls, [])
        actor.npc_subtile_transaction=None; actor.npc_subtile_offset_owned=True; actor.step_x=2
        self.assertFalse(setter(actor,False)); self.assertIs(actor.npc_subtile_wild_walk,owner)
        self.assertEqual(calls, [])
        actor.step_x=0
        actor.npc_subtile_intent_valid=lambda owner: False
        self.assertFalse(setter(actor,False)); self.assertIs(actor.npc_subtile_wild_walk,owner)
        self.assertEqual(calls, [])
        actor.npc_subtile_intent_valid=lambda owner: True
        self.assertTrue(setter(actor,False))
        self.assertFalse(actor.npc_subtile_enabled); self.assertTrue(owner.cancelled)
        self.assertIsNone(actor.npc_subtile_wild_walk)
        self.assertEqual(calls,["pursuit",("cancel","wild"),("release",7,True),"detach","glide"])

    def test_readiness_mutants_fail_the_original_safety_oracles(self):
        source = (ROOT / "code/game/mob/living/simple_animal/subtile_movement.dm").read_text(encoding="utf-8")
        spec = importlib.util.spec_from_file_location("species_mutation_adapter", ROOT / "tests/save_movement/source_adapter.py")
        adapter = importlib.util.module_from_spec(spec); spec.loader.exec_module(adapter)
        fields = ("npc_subtile_transaction", "npc_subtile_pulse", "npc_subtile_until",
                  "npc_subtile_offset_owned", "step_x", "step_y", "npc_subtile_stop_wild_walk",
                  "npc_subtile_pending_intent", "npc_subtile_intent_valid", "npc_subtile_wild_walk")
        declaration="/mob/living/simple_animal/proc/npc_subtile_species_legacy_ready"
        for remove, change in (("npc_subtile_pulse || ", ("npc_subtile_pulse",object())),
                               ("world.time < npc_subtile_until || ", ("npc_subtile_until",11)),
                               ("(npc_subtile_offset_owned && (step_x || step_y))", ("step_x",2))):
            with self.subTest(remove=remove):
                marker=source.index(declaration)
                original=source[marker:].split("\n/",1)[0]
                self.assertEqual(original.count(remove),1)
                mutated=source[:marker]+source[marker:].replace(remove,"FALSE" if remove.startswith("(") else "",1)
                actor=SimpleNamespace(npc_subtile_transaction=None,npc_subtile_pulse=None,
                    npc_subtile_until=10,npc_subtile_offset_owned=True,step_x=0,step_y=0,
                    npc_subtile_pending_intent=None,npc_subtile_wild_walk=None,npc_subtile_stop_wild_walk=lambda:None,
                    npc_subtile_intent_valid=lambda owner:True)
                setattr(actor,*change)
                with patch.object(adapter,"FIELDS",adapter.FIELDS+fields):
                    mutant=adapter.project(mutated,declaration,"src",{"world":SimpleNamespace(time=10)},method=True)
                with self.assertRaises(AssertionError):
                    self.assertFalse(mutant(actor))

    def test_species_stage_is_off_and_not_saved(self):
        source = (ROOT / 'code/game/mob/living/simple_animal/subtile_movement.dm').read_text(encoding='utf-8')
        self.assertIn('var/npc_subtile_species_enabled = FALSE', source)
        self.assertIn('"npc_subtile_species_enabled"', source)
        for path in (ROOT / 'code').rglob('*.dm'):
            self.assertNotIn('npc_subtile_species_enabled = TRUE',
                             path.read_text(encoding='utf-8', errors='replace'), str(path))


if __name__ == '__main__':
    unittest.main()

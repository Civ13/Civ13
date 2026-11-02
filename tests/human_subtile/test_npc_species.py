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


    def test_continuous_fallback_source_executes_ownership_contract(self):
        source = (ROOT / 'code/game/mob/living/simple_animal/subtile_movement.dm').read_text(encoding='utf-8')
        spec = importlib.util.spec_from_file_location('continuous_fallback_adapter', ROOT / 'tests/save_movement/source_adapter.py')
        adapter = importlib.util.module_from_spec(spec); spec.loader.exec_module(adapter)
        fields = ('npc_subtile_transaction', 'npc_subtile_pulse', 'npc_subtile_until',
                  'npc_subtile_offset_owned', 'step_x', 'step_y', 'npc_subtile_follow',
                  'npc_subtile_flee', 'npc_subtile_pet_walk', 'npc_subtile_pursuit',
                  'npc_subtile_recovery', 'npc_subtile_wild_walk', 'npc_subtile_pending_intent',
                  'npc_subtile_intent_valid', 'npc_subtile_stop_follow', 'npc_subtile_stop_flee',
                  'npc_subtile_stop_pet_walk')
        with patch.object(adapter, 'FIELDS', adapter.FIELDS + fields):
            ready = adapter.project(source, '/mob/living/simple_animal/proc/npc_subtile_continuous_legacy_ready',
                                    'src, kind', {'world': SimpleNamespace(time=10)}, method=True)
        names = {'follow':'npc_subtile_follow', 'flee':'npc_subtile_flee', 'pet':'npc_subtile_pet_walk'}
        for kind, field in names.items():
            with self.subTest(kind=kind):
                owner = object(); calls = []
                actor = SimpleNamespace(npc_subtile_transaction=None, npc_subtile_pulse=None, npc_subtile_until=10,
                    npc_subtile_offset_owned=False, step_x=0, step_y=0, npc_subtile_follow=None,
                    npc_subtile_flee=None, npc_subtile_pet_walk=None, npc_subtile_pursuit=None,
                    npc_subtile_recovery=None, npc_subtile_wild_walk=None, npc_subtile_pending_intent=None)
                setattr(actor, field, owner)
                def valid(candidate):
                    owners = [getattr(actor, f) for f in (*names.values(), 'npc_subtile_pursuit', 'npc_subtile_recovery', 'npc_subtile_wild_walk')]
                    return all(x is None or x is candidate for x in owners) and (candidate is None or candidate in owners)
                actor.npc_subtile_intent_valid = valid
                def stop(k, f):
                    calls.append(k); setattr(actor, f, None)
                    if actor.npc_subtile_pending_intent and actor.npc_subtile_pending_intent.kind == k:
                        actor.npc_subtile_pending_intent = None
                for k, f in names.items():
                    setattr(actor, 'npc_subtile_stop_' + ('pet_walk' if k == 'pet' else k), lambda k=k,f=f: stop(k,f))
                for field_name, value in (('npc_subtile_transaction',object()),('npc_subtile_pulse',object()),('npc_subtile_until',11),('npc_subtile_pursuit',object()),('npc_subtile_recovery',object()),('npc_subtile_pending_intent',SimpleNamespace(kind='other'))):
                    with self.subTest(blocker=field_name):
                        old=getattr(actor, field_name); setattr(actor, field_name, value); calls.clear()
                        self.assertFalse(ready(actor,kind)); self.assertEqual(calls,[])
                        self.assertIs(getattr(actor,field),owner); setattr(actor, field_name,old)
                actor.npc_subtile_offset_owned=True; actor.step_x=2; calls.clear()
                self.assertFalse(ready(actor,kind)); self.assertEqual(calls,[]); actor.step_x=0
                actor.npc_subtile_pending_intent=SimpleNamespace(kind=kind)
                self.assertTrue(ready(actor,kind)); self.assertEqual(calls,[kind])
                self.assertIsNone(getattr(actor,field)); self.assertIsNone(actor.npc_subtile_pending_intent)
                self.assertFalse(ready(actor,'unknown'))

    def test_continuous_producers_route_mixed_flags_to_guarded_native_path(self):
        paths = {'follow': ('simple_animal.dm','npc_subtile_start_follow(following_mob)','walk_to(src, following_mob, 1, 6)'),
                 'flee': ('simple_ai.dm','npc_subtile_start_flee(H, 7, npc_subtile_native_interval(2), flee_receipt)','walk_away_od(src, H, 7, 2)'),
                 'pet_to': ('simple_animal.dm','npc_subtile_start_pet_walk(movement_target, "towards", 0, npc_subtile_native_interval(3))','walk_to(src, movement_target, 0, 3)'),
                 'pet_away': ('simple_animal.dm','npc_subtile_start_pet_walk(flee_target, "away", 7, npc_subtile_native_interval(2))','walk_away_od(src, flee_target, 7, 2)'),
                 'cat': ('friendly/cat.dm','npc_subtile_start_pet_walk(movement_target, "towards", near_dist, npc_subtile_native_interval(4))','walk_to(src, movement_target, near_dist, 4)')}
        base=ROOT/'code/game/mob/living/simple_animal'
        for label,(path,staged,native) in paths.items():
            kind = 'pet' if label.startswith('pet') or label == 'cat' else label
            pattern = r'if \(npc_subtile_'+kind+r'_enabled && npc_subtile_enabled\)\n(?:[^\n]*\n){0,5}?[^\n]*'+re.escape(staged)+r'[^\n]*\n(?:[^\n]*\n){0,6}?\s*else if \(npc_subtile_enabled \|\| npc_subtile_continuous_legacy_ready\("'+kind+r'"\)\)\n\s*'+re.escape(native)
            with self.subTest(producer=label):
                text=(base/path).read_text(encoding='utf-8')
                match=re.search(pattern,text)
                self.assertIsNotNone(match,label)
                prior=match.group().replace(' && npc_subtile_enabled','',1)
                self.assertNotRegex(prior,pattern,'old single-flag branch must fail')
                unguarded=match.group().replace(' || npc_subtile_continuous_legacy_ready("'+kind+'")','',1)
                self.assertNotRegex(unguarded,pattern,'unguarded native fallback must fail')
        for path in ('friendly/cat.dm','friendly/dogs.dm'):
            source=(base/path).read_text(encoding='utf-8')
            self.assertIn('turns_since_scan > 5 && (npc_subtile_enabled || npc_subtile_continuous_legacy_ready("pet"))',source)
        cat=(base/'friendly/cat.dm').read_text(encoding='utf-8')
        self.assertEqual(cat.count('if (!npc_subtile_enabled && !npc_subtile_continuous_legacy_ready("pet"))'),2)


    def test_real_flee_retirement_cannot_cancel_replacement_ticket(self):
        source=(ROOT/'code/game/mob/living/simple_animal/subtile_movement.dm').read_text(encoding='utf-8')
        spec=importlib.util.spec_from_file_location('flee_stop_adapter',ROOT/'tests/save_movement/source_adapter.py')
        adapter=importlib.util.module_from_spec(spec); spec.loader.exec_module(adapter)
        fields=('npc_subtile_pending_intent','npc_subtile_flee_ticket','npc_subtile_flee',
                'npc_subtile_cancel_pending','npc_subtile_release_generation','npc_subtile_stop_flee','move_gen')
        with patch.object(adapter,'FIELDS',adapter.FIELDS+fields):
            stop=adapter.project(source,'/mob/living/simple_animal/proc/npc_subtile_stop_flee',
                                 'src, cancel_pending=True',{},method=True)
            expire=adapter.project(source,'/mob/living/simple_animal/proc/npc_subtile_stop_flee_ticket',
                                   'src, ticket',{'isnull':lambda x:x is None},method=True)
        old,new=object(),object(); releases=[]
        actor=SimpleNamespace(npc_subtile_pending_intent=SimpleNamespace(kind='flee',flee_ticket=old),
                              npc_subtile_flee_ticket=old,npc_subtile_flee=SimpleNamespace(flee_ticket=old,generation=4,cancelled=False),move_gen=4)
        actor.npc_subtile_cancel_pending=lambda kind:setattr(actor,'npc_subtile_pending_intent',None)
        actor.npc_subtile_release_generation=lambda generation,owned:releases.append((generation,owned))
        actor.npc_subtile_stop_flee=lambda cancel_pending=True:stop(actor,cancel_pending)
        stop(actor)
        self.assertIsNone(actor.npc_subtile_pending_intent); self.assertIsNone(actor.npc_subtile_flee_ticket)
        self.assertIsNone(actor.npc_subtile_flee); self.assertEqual(releases,[(4,True)])
        replacement=SimpleNamespace(flee_ticket=new,generation=5,cancelled=False)
        actor.npc_subtile_flee_ticket=new; actor.npc_subtile_flee=replacement; actor.move_gen=5
        self.assertFalse(expire(actor,old)); self.assertIs(actor.npc_subtile_flee,replacement)
        self.assertIs(actor.npc_subtile_flee_ticket,new); self.assertEqual(releases,[(4,True)])


if __name__ == '__main__':
    unittest.main()

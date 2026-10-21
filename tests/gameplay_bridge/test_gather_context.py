"""Offline source controls and abstract ownership oracle, never DM/native."""
from dataclasses import dataclass
import copy
import hashlib
import json
from pathlib import Path
import unittest

import sys
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts" / "gameplay_bridge"))
from gather_context import PATHS, FEATURE, MARKER, DISABLED_SHA256, project, verify_disabled


def sources(folder):
    files = {p:(ROOT/p).read_text(encoding="utf-8") for p in PATHS}
    if folder != "enabled": return files
    result = {}; symbols = {FEATURE}
    for p in PATHS:
        result[p], symbols = project(files[p], symbols)
    return result


def source_contract(files):
    helper, grass, bridge, mechanics=(files[p] for p in PATHS)
    required={
        'supplied_only_capture':(helper,'gameplay_lease = gameplay_context'),
        'runtime_type':(helper,'if (!istype(gameplay_context, /datum/gameplay_action_lease))'),
        'one_use_claim':(helper,'if (!gameplay_lease.claim_gather_wait(user, target))'),
        'wake':(helper,'\t\tif (gameplay_lease && !gameplay_lease.valid())\n\t\t\t. = FALSE\n\t\t\tbreak'),
        'final':(helper,'\tif (gameplay_lease && !gameplay_lease.valid())\n\t\t. = FALSE'),
        'launch_context':(mechanics,'execute(R, run_generation, old_seq, old_time, old_entities, L)'),
        'execute_forward':(bridge,'survival_action(kind, target, A["recipe"], worker_context)'),
        'canonical_forward':(mechanics,'G.gather_grass_cuttings(actor, F, worker_context)'),
        'grass_forward':(grass,'grass_cutting_wait(user, gameplay_context)'),
        'helper_forward':(grass,'do_after(user, 30, src, gameplay_context = gameplay_context)'),
        'provided_postwait':(grass,'(!gameplay_context.wait_claimed || !gameplay_context.valid())'),
        'single_claim_field':(mechanics,'if (wait_claimed || !matches_gather_wait(user, wait_target))'),
        'current_identity':(mechanics,'!owner || owner != gameplay_bridge || owner.action_lease != src'),
        'body_identity':(mechanics,'body != user'),
        'target_identity':(mechanics,'target != wait_target'),
        'gather_kind':(mechanics,'target != wait_target || kind != "gather"'),
        'owner_identity':(mechanics,'owner != gameplay_bridge'),
        'generation':(bridge,'worker_context.run_generation != run_generation'),
        'request_identity':(bridge,'worker_context.request_id != R["request_id"]'),
        'gather_only_ready':(mechanics,'return kind == "gather"'),
    }
    failures=[key for key,(text,anchor) in required.items() if anchor not in text]
    if 'wait_lease(' in ''.join(files.values()): failures.append('ambient_lookup')
    start=helper.index('/proc/do_after(');body=helper[start:]
    if not body.index('claim_gather_wait(user, target)')<body.index('user.survival_action_started()'): failures.append('callback_entry_order')
    if not body.rindex('gameplay_lease.valid()')>body.index('user.survival_action_finished()'): failures.append('callback_final_order')
    return failures,required


@dataclass
class Actor:
    may:bool=True
    activities:int=0
    started:int=0
    finished:int=0


class Service:
    generation=1
    current=None


class Lease:
    def __init__(self,service,body,target):
        self.owner=service;self.body=body;self.target=target;self.kind='gather'
        self.generation=service.generation;self.claimed=False;self.cancelled=False
    def valid(self,service):
        return self.owner is service and service.current is self and self.generation==service.generation and not self.cancelled
    def claim(self,service,body,target):
        if self.claimed or self.body is not body or self.target is not target or self.kind!='gather' or not self.valid(service): return False
        self.claimed=True;return True


class Wait:
    def __init__(self,actor,lease,service):
        self.actor=actor;self.lease=lease;self.service=service;self.ok=True
    def wake(self):
        if self.lease and not self.lease.valid(self.service): self.ok=False
        return self.ok
    def finish(self):
        self.actor.may=True;self.actor.activities=max(0,self.actor.activities-1);self.actor.finished+=1
        if self.lease and not self.lease.valid(self.service):self.ok=False
        return self.ok


def begin(actor,target,service,context=None,repeat=True,ambient=False):
    if not actor.may:return None
    if ambient and context is None:context=service.current  # Deliberately unsafe old proposal.
    captured=None
    if context is not None:
        if not isinstance(context,Lease) or not context.claim(service,actor,target):return None
        captured=context
    actor.activities+=1;actor.started+=1
    if repeat:actor.may=False
    return Wait(actor,captured,service)


class GatherContextTests(unittest.TestCase):
    def setUp(self):
        self.files=sources('enabled')
    def test_projector_calibrated_nested_truth_table(self):
        text='top\n#ifdef '+FEATURE+'\nf\n#ifdef '+MARKER+'\nboth\n#else\nf-only\n#endif\n#else\nno-f\n#endif\nbottom\n'
        for flags,middle in ((set(),'no-f'),({MARKER},'no-f'),({FEATURE},'f\nf-only'),({FEATURE,MARKER},'f\nboth')):
            self.assertEqual(project(text,flags)[0],'top\n'+middle+'\nbottom\n')
        define='#ifdef '+FEATURE+'\n#define '+MARKER+'\n#endif\n#ifdef '+MARKER+'\nyes\n#else\nno\n#endif\n'
        self.assertEqual(project(define,set())[0],'no\n')
        self.assertEqual(project(define,{FEATURE})[0],'yes\n')
    def test_projector_refuses_unsupported_unbalanced_or_duplicate_else(self):
        for text in ('#if 1\nx\n#endif\n','#ifdef UNKNOWN\nx\n#endif\n','#ifdef '+FEATURE+'\nx\n','#else\n',
                     '#ifdef '+FEATURE+'\na\n#else\nb\n#else\nc\n#endif\n'):
            with self.assertRaises(ValueError):project(text,set())
    def test_complete_disabled_preprocessed_files_and_hashes_match(self):
        candidate=sources('candidate')
        verify_disabled(candidate)
        for path in PATHS:
            changed=dict(candidate);changed[path] += "// unexpected disabled change\n"
            with self.assertRaisesRegex(ValueError,"whole-file projection drift"):
                verify_disabled(changed)
    def test_enabled_actual_forwarding_type_identity_and_order_source_controls(self):
        self.assertEqual(source_contract(self.files)[0],[])
        _,required=source_contract(self.files)
        for name,(text,anchor) in required.items():
            changed=dict(self.files);path=next(p for p in PATHS if self.files[p] is text)
            changed[path]=text.replace(anchor,'OMITTED',1)
            # Order checks may fail closed on missing anchors as well.
            try:failures=source_contract(changed)[0]
            except ValueError:failures=['missing_order_anchor']
            self.assertTrue(failures,name)
    def test_callback_placement_unsafe_control_and_no_unconverted_readiness(self):
        h=self.files[PATHS[0]];capture=h[h.index('\tvar/datum/gameplay_action_lease/gameplay_lease'):h.index('\tuser.survival_action_started()',h.index('/proc/do_after('))]
        start=h.index('/proc/do_after(')
        changed=dict(self.files);changed[PATHS[0]]=h[:start]+h[start:].replace(capture,'',1).replace('\tuser.survival_action_started()\n','\tuser.survival_action_started()\n'+capture,1)
        self.assertIn('callback_entry_order',source_contract(changed)[0])
        mechanics=self.files[PATHS[3]]
        readiness=mechanics.split('/datum/gameplay_bridge/proc/wait_guards_ready(kind)\n',1)[1].split('/datum/gameplay_bridge/proc/sharp_flint()',1)[0]
        self.assertEqual(readiness.strip(),'return kind == "gather"')
        for kind in ('craft','refill','drink'):
            self.assertIn('wait_guards_ready("'+kind+'")',mechanics)
        self.assertNotIn('wait_guards_ready()', ''.join(self.files.values()))
        self.assertNotIn('wait_lease(', ''.join(self.files.values()))
    def test_operator_json_cannot_supply_a_context(self):
        from catalog import action_error
        self.assertIsNone(action_error({"type":"gather","target":"visible_grass"}))
        for key in ("context","gameplay_context","worker_context","lease","owner","body"):
            self.assertEqual(action_error({"type":"gather","target":"visible_grass",key:"forged"}),"schema")

    def test_grass_dispatch_water_and_ordinary_callbacks_stay_stock(self):
        grass=self.files[PATHS[1]]
        self.assertIn('G.gather_grass_cuttings(user, F)\n\t\t\treturn TRUE',grass)
        self.assertIn('do_after(user, 15, src, check_for_repeats = FALSE)',grass)
        self.assertIn('should_save = FALSE',self.files[PATHS[3]])
        self.assertNotIn('/mob/var',self.files[PATHS[3]])
        helper=self.files[PATHS[0]]
        a=helper.index('/proc/do_after(');b=helper.index('//Returns a list of all mobs',a)
        wait=helper[a:b]
        self.assertEqual(wait.count('user.survival_action_started()'),1)
        self.assertEqual(wait.count('user.survival_action_finished()'),1)
        self.assertLess(wait.index('user.may_do_after = TRUE'),wait.index('user.survival_action_finished()'))

    def test_forged_invalid_and_wrong_scope_context_deny_before_callbacks(self):
        for fault in ('type','body','target','kind','owner','generation','pointer'):
            actor=Actor();site=object();service=Service();lease=Lease(service,actor,site);service.current=lease;context=lease
            if fault=='type':context={'lease':lease}
            elif fault=='body':lease.body=Actor()
            elif fault=='target':lease.target=object()
            elif fault=='kind':lease.kind='refill'
            elif fault=='owner':lease.owner=Service()
            elif fault=='generation':service.generation+=1
            elif fault=='pointer':context=copy.copy(lease)
            self.assertIsNone(begin(actor,site,service,context),fault)
            self.assertEqual((actor.started,actor.finished,actor.activities),(0,0,0))
    def test_one_use_replay_and_nested_claim_rejected(self):
        actor=Actor();site=object();service=Service();lease=Lease(service,actor,site);service.current=lease
        wait=begin(actor,site,service,lease)
        self.assertIsNotNone(wait);self.assertIsNone(begin(actor,site,service,lease))
        self.assertTrue(wait.finish());self.assertIsNone(begin(actor,site,service,lease))
        self.assertEqual((actor.started,actor.finished,actor.activities),(1,1,0))
    def test_unrelated_false_first_wait_never_borrows_agent_lease(self):
        actor=Actor();site=object();service=Service();lease=Lease(service,actor,site);service.current=lease
        ordinary=begin(actor,site,service,None,repeat=False)
        self.assertIsNone(ordinary.lease)
        agent=begin(actor,site,service,lease);lease.cancelled=True
        self.assertFalse(agent.wake());self.assertFalse(agent.finish())
        self.assertTrue(ordinary.wake());self.assertTrue(ordinary.finish())
        self.assertEqual((actor.started,actor.finished,actor.activities),(2,2,0))
    def test_ambient_lookup_mutation_detects_unrelated_wait_interference(self):
        actor=Actor();site=object();service=Service();lease=Lease(service,actor,site);service.current=lease
        ordinary=begin(actor,site,service,None,repeat=False,ambient=True)
        lease.cancelled=True
        self.assertFalse(ordinary.wake())  # Unsafe variant fails ordinary-survival oracle.
        self.assertFalse(ordinary.finish())
    def test_stock_false_first_unlock_behavior_is_preserved_without_context(self):
        actor=Actor();site=object();service=Service()
        a=begin(actor,site,service,repeat=False);b=begin(actor,site,service)
        self.assertFalse(actor.may);self.assertTrue(a.finish());self.assertTrue(actor.may)
        c=begin(actor,site,service);self.assertIsNotNone(c)
        self.assertTrue(b.finish());self.assertTrue(c.finish());self.assertEqual(actor.activities,0)
    def test_old_context_never_borrows_replacement_and_zero_delay_final_checks(self):
        actor=Actor();site=object();service=Service();old=Lease(service,actor,site);service.current=old
        wait=begin(actor,site,service,old);old.cancelled=True
        new=Lease(service,actor,site);service.current=new
        self.assertFalse(wait.wake());self.assertFalse(wait.finish());self.assertIs(service.current,new);self.assertFalse(new.claimed)
        wait2=begin(actor,site,service,new);new.cancelled=True
        self.assertFalse(wait2.finish())  # No wake: zero-delay final guard.
        self.assertEqual(actor.started,actor.finished);self.assertEqual(actor.activities,0)

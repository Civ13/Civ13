import copy
import re
import unittest
from pathlib import Path
import scheduler_hostile_contract as C
import scheduler_hostile_stage as S

HERE = Path(__file__).resolve().parent

def event(kind, at, **kw):
    row = dict(event=kind, phase="wander", at=at, x=8, y=7, z=1, sx=0, sy=0,
        bx=0, by=0, bw=32, bh=32, generation=1, stance=0, owned=0,
        transaction=0, transaction_old=0, transaction_generation=None, transaction_owner=None,
        pulse=0, pursuit=0, pursuit_old=0, wild=0, follow=0, flee=0, pet=0,
        recovery=0, pending=0, target_matches=0, actor_faction="neutral",
        target_faction=None, target_x=None, target_y=None, target_z=None,
        target_sx=None, target_sy=None, target_bx=None, target_by=None, target_bw=None, target_bh=None,
        target_damage=None, target_adjacent=0, old_finished=0, old_completions=0,
        wander_moves=0, attacks=0, positive_attacks=0, damage_before=None, result=None, call_id=None)
    row.update(kw)
    return row

def good():
    events=[]; actor_x=8; actor_sx=0; tick=2.0; call_id=0
    def move(phase, owner, target, index):
        nonlocal actor_x,actor_sx,tick,call_id
        call_id+=1
        common=dict(phase=phase,x=actor_x,sx=actor_sx,call_id=call_id,transaction=1,pulse=1,
                    transaction_generation=2,transaction_owner=owner,owned=1,**target)
        if owner=="pursuit":common["pursuit"]=1
        if phase=="wander":common["wander_moves"]=index
        events.append(event("move_before",tick,**common))
        actor_sx+=2
        if actor_sx>=32:actor_x+=1;actor_sx-=32
        common.update(x=actor_x,sx=actor_sx)
        if phase=="wander":common["wander_moves"]=index+1
        events.append(event("move_after",tick,**common));tick+=0.5
    for i in range(16):move("wander","wander_or_direct",{},i)
    events.append(event("target_intro_before",tick,x=actor_x,sx=actor_sx,wander_moves=16));tick+=0.5
    target=dict(target_faction="fixture-human",target_x=13,target_y=7,target_z=1,
                target_sx=0,target_sy=0,target_bx=0,target_by=0,target_bw=32,target_bh=32,
                target_damage=0,target_matches=1,wander_moves=16)
    events.append(event("target_intro_after",tick,x=actor_x,sx=actor_sx,phase="acquire",**target));tick+=0.5
    for _ in range(48):move("acquire","pursuit",target,16)
    attack=dict(target,x=actor_x,sx=actor_sx,phase="acquire",target_adjacent=1,attacks=1,damage_before=0)
    events.append(event("attack_before",tick,**attack))
    events.append(event("attack_after",tick,**dict(attack,target_damage=12,positive_attacks=1)));tick+=0.5
    contact=dict(target,x=actor_x,sx=actor_sx,phase="acquire",target_damage=12,positive_attacks=1,attacks=1)
    events.append(event("target_relocate_before",tick,**contact))
    reacq=dict(contact,phase="reacquire",target_x=8)
    events.append(event("target_relocate_after",tick,**reacq));tick+=0.5
    call_id+=1
    before=dict(reacq,call_id=call_id,transaction=1,pulse=1,transaction_generation=3,
                transaction_owner="pursuit",pursuit=1,owned=1)
    events.append(event("move_before",tick,**before))
    events.append(event("move_after",tick,**dict(before,x=11,sx=30)));tick+=0.5
    loss=dict(reacq,x=11,sx=30,transaction=1,transaction_old=1,transaction_generation=3,
              transaction_owner="lost_pursuit",pursuit=1,pursuit_old=1,owned=1)
    events.append(event("target_loss_before",tick,**loss))
    lost=dict(loss,phase="lost",target_faction="neutral",target_matches=0)
    events.append(event("target_loss_after",tick,**lost));tick+=0.5
    settled=dict(lost,transaction=0,transaction_old=0,transaction_generation=None,
                 transaction_owner=None,pulse=0,pursuit=0,pursuit_old=0,old_completions=1)
    events.append(event("lost_completion_hook",tick,**settled))
    settled.update(phase="quiet",old_finished=1)
    events.append(event("quiet_start",tick+0.5,**settled))
    events.append(event("quiet_end",tick+4.5,**settled))
    events.append(event("cleanup",tick+5,**settled))
    return dict(started=0,ended=tick+6,tick_lag_ds=0.5,actual_clients=0,
                life_interval_ds=10,start_delay_ds=6,process_ticks=5,events=events)

def first(row, kind):
    return next(e for e in row["events"] if e["event"] == kind)

class ContractTests(unittest.TestCase):
    def setUp(self): self.row = good()
    def check_bad(self, mutate):
        mutate(self.row)
        with self.assertRaises(ValueError): C.validate(self.row)
    def test_good_trace(self):
        self.assertTrue(C.validate(self.row)["positive_contact"])
    def test_late_old_pulse_rejected(self):
        def mutate(r):
            e=copy.deepcopy(first(r,"target_loss_before")); e.update(event="move_before",phase="quiet",at=r["ended"]-1,call_id=999)
            r["events"].insert(-1,e)
        self.check_bad(mutate)
    def test_inflight_attack_rejected(self):
        self.check_bad(lambda r:first(r,"attack_before").update(transaction=1,transaction_generation=2,transaction_owner="pursuit"))
    def test_zero_damage_rejected(self):
        self.check_bad(lambda r:first(r,"attack_after").update(target_damage=0))
    def test_pursuit_without_progress_rejected(self):
        def mutate(r):
            for e in r["events"]:
                if e["event"]=="move_after" and e["phase"]=="acquire":e.update(x=9,sx=0)
        self.check_bad(mutate)
    def test_stale_target_faction_rejected(self):
        self.check_bad(lambda r:first(r,"target_loss_after").update(target_faction="fixture-human"))
    def test_faked_nonnormalized_offset_rejected(self):
        self.check_bad(lambda r:first(r,"quiet_start").update(x=10,sx=62))
    def test_missing_move_return_rejected(self):
        self.check_bad(lambda r:r["events"].remove(first(r,"move_after")))
    def test_wrong_old_completion_count_rejected(self):
        self.check_bad(lambda r:first(r,"quiet_end").update(old_completions=2))
    def test_equal_null_generation_rejected(self):
        self.check_bad(lambda r:first(r,"target_loss_before").update(transaction_generation=None))
    def test_fabricated_wander_counter_rejected(self):
        self.check_bad(lambda r:first(r,"move_after").update(sx=0))
    def test_overlapping_continuous_owners_rejected(self):
        self.check_bad(lambda r:first(r,"target_loss_before").update(wild=1))
    def test_post_loss_damage_rejected(self):
        self.check_bad(lambda r:first(r,"quiet_start").update(target_damage=13))
    def test_terminal_owner_reacquisition_rejected(self):
        self.check_bad(lambda r:first(r,"cleanup").update(recovery=1))
    def test_target_offset_alias_rejected(self):
        self.check_bad(lambda r:first(r,"attack_before").update(target_x=12,target_sx=32))
    def test_oversized_pulse_rejected(self):
        self.check_bad(lambda r:first(r,"move_after").update(sx=4))
    def test_unobserved_teleport_rejected(self):
        self.check_bad(lambda r:first(r,"attack_before").update(x=11))
    def test_missing_relocation_before_rejected(self):
        self.check_bad(lambda r:r["events"].remove(first(r,"target_relocate_before")))
    def test_partial_trace_binding_required(self):
        row=self.row
        receipt=dict(head="a"*40,error=None,port=0,byond_version=516,byond_build=1688,
            scope=C.SCOPE,transition_checks=1,transition_phase="quiet",transition_rows=[row],
            transition_partial=copy.deepcopy(row["events"]))
        self.assertTrue(C.validate_receipt(receipt,"a"*40)["positive_contact"])
        receipt["transition_partial"].pop()
        with self.assertRaises(ValueError): C.validate_receipt(receipt,"a"*40)
    def test_unknown_field_rejected(self):
        self.check_bad(lambda r:first(r,"sample").update(extra=1) if any(e["event"]=="sample" for e in r["events"]) else first(r,"quiet_start").update(extra=1))
    def test_event_count_above_bound_rejected(self):
        self.check_bad(lambda r:r.update(events=r["events"]*16))
    def test_incomplete_target_geometry_rejected(self):
        self.check_bad(lambda r:first(r,"attack_before").pop("target_sx"))
    def test_fixture_forwards_real_ai_and_movement(self):
        s=(HERE/"scheduler_hostile_draft.dm").read_text(encoding="utf-8-sig")
        self.assertIn("/hostile/panther/scheduler_hostile/Life()",s)
        self.assertIn("/hostile/panther/scheduler_hostile/AttackingTarget()",s)
        self.assertGreaterEqual(s.count(". = ..()"),3)
        self.assertNotIn("A.Life()",s);self.assertNotIn("A.AttackTarget()",s)
        self.assertIn("A.npc_set_combat_target(null)",s)
    def test_fixture_event_schema_and_both_bounds_match_host(self):
        s=(HERE/"scheduler_hostile_draft.dm").read_text(encoding="utf-8")
        body=s.split("var/list/event_row = list(",1)[1].split('fixture_scheduler_assert(length(json_encode(event_row))',1)[0]
        names=re.findall(r'"([^"]+)"\s*=',body)
        self.assertEqual(len(names),len(set(names)))
        self.assertEqual(set(names),C.EVENT_FIELDS)
        self.assertIn('fixture_hostile_events.len < 2048',s)
        self.assertIn('length(json_encode(event_row)) <= 900',s)
        self.assertLess(2*2048*901+100000,4*1024*1024)
    def test_adapter_binds_fixture_and_headless_gate(self):
        original='\t\t\thuman_subtile_fixture_headless()\n"checks" = human_subtile_fixture_checks,\n"scope" = "actual human/codec; headless authority adapter"'
        self.assertIn("fixture_scheduler_hostile_main()",S.adapted_probe(original))
        dme='#include "tests\\human_subtile\\scheduler_core_draft.dm"'
        self.assertIn("scheduler_hostile_draft.dm",S.adapted_dme(dme))
        with self.assertRaises(ValueError): S.adapted_dme("")

if __name__=="__main__":unittest.main()
"""Source-only contracts for the unwired scheduler transition draft; no BYOND."""
from pathlib import Path
import unittest

HERE=Path(__file__).resolve().parent
SOURCE=HERE/'scheduler_core_draft.dm'

def section(source, start, end):
    return source.split(start,1)[1].split(end,1)[0]

def check_transition(source):
    observe=section(source,'/proc/fixture_scheduler_transition_observe(',
                    '// Called only by a future separately reviewed staging adapter.')
    for required in ('world.tick_lag == 0.5 && !clients.len && !processScheduler && !living_mob_list.len',
                     'S.processes.len == 1 && S.processes[1] == P',
                     'P.schedule_interval == 1 SECONDS && P.start_delay == 0.6 SECONDS',
                     'S.start()', 'S.stop()', 'P.ticks > 0 && !P.running && !P.queued && P.idle && !P.exceptions.len',
                     'fixture_scheduler_test_subjects = list(A)',
                     'A.npc_subtile_enabled = FALSE', 'A.npc_set_following(H)',
                     'A.npc_set_following(null)', 'A.behaviour = "scared"',
                     'A.npc_set_movement_target(M)', 'A.turns_since_scan = 5',
                     'fixture_transition_accepted["follow"] && fixture_transition_follow_moves > 0',
                     'fixture_transition_accepted["flee"] && fixture_transition_flee_moves > 0',
                     'fixture_transition_accepted["pet"] && fixture_transition_pet_moves > 0',
                     'fixture_transition_record("stimulus_before", A)',
                     'fixture_transition_record("stimulus_after", A)',
                     'fixture_transition_explicit_stop(A)',
                     'fixture_transition_move_entries == gap_moves',
                     'fixture_transition_move_entries == quiet_moves',
                     'fixture_transition_record("quiet_sample", A)',
                     'fixture_transition_record("quiet_end", A)',
                     'fixture_transition_record("end", A)'):
        if required not in observe: raise AssertionError(required)
    for forbidden in ('.Life(', '.do_behaviour(', '.npc_subtile_start_follow(',
                      '.npc_subtile_start_flee(', '.npc_subtile_start_pet_walk('):
        if forbidden in observe: raise AssertionError('manual AI call '+forbidden)
    record=section(source,'/proc/fixture_transition_record(',
                   '/mob/living/simple_animal/pet/cat/scheduler_transition\n')
    for required in ('fixture_transition_events.len < 4096',
                     'fixture_scheduler_assert(!A.npc_subtile_enabled && !A.npc_subtile_transaction && !A.npc_subtile_pulse && !A.npc_subtile_follow && !A.npc_subtile_flee && !A.npc_subtile_pet_walk && !A.npc_subtile_pursuit && !A.npc_subtile_wild_walk && !A.npc_subtile_recovery && !A.npc_subtile_pending_intent, \"transition_no_staged_owner\")',
                     '"x" = A.x', '"sx" = A.step_x', '"generation" = A.move_gen',
                     '"pending" = !!A.npc_subtile_pending_intent', '"recovery" = !!A.npc_subtile_recovery'):
        if required not in record: raise AssertionError(required)

class SchedulerTransitionSource(unittest.TestCase):
    def setUp(self): self.source=SOURCE.read_text(encoding='utf-8')
    def test_source_contract(self): check_transition(self.source)
    def test_only_observer_subtype_forwards_real_parent(self):
        for name,end in (('Life()', '/mob/living/simple_animal/pet/cat/scheduler_transition/Move()'),
                         ('Move()', '/mob/living/simple_animal/pet/cat/scheduler_transition/npc_subtile_continuous_legacy_ready(kind)'),
                         ('npc_subtile_continuous_legacy_ready(kind)', '// Explicit initial state')):
            start='/mob/living/simple_animal/pet/cat/scheduler_transition/'+name+'\n'
            body=section(self.source,start,end)
            self.assertEqual(body.count('. = ..()'),1,name)
    def test_old_main_does_not_invoke_new_draft(self):
        old=section(self.source,'/proc/fixture_scheduler_main()','// Source-only transition draft.')
        self.assertNotIn('fixture_scheduler_transition_',old)
    def test_two_modes_and_fresh_actor_cases(self):
        main=self.source.split('/proc/fixture_scheduler_transition_main()',1)[1]
        self.assertIn('world.params["scheduler_mode"]',main)
        self.assertIn('fixture_scheduler_transition_observe(mode, "follow_flee")',main)
        self.assertIn('fixture_scheduler_transition_observe(mode, "pet")',main)
        self.assertIn('mode in list("legacy", "mixed")',self.source)
        self.assertIn('scenario == "follow_flee" ? 100 : 12',self.source)
    def test_physical_movement_is_measured_after_ready_even_if_return_false(self):
        body=section(self.source,'/mob/living/simple_animal/pet/cat/scheduler_transition/Move()',
                     '/mob/living/simple_animal/pet/cat/scheduler_transition/npc_subtile_continuous_legacy_ready(kind)')
        self.assertIn('old_x != x * world.icon_size + step_x || old_y != y * world.icon_size + step_y',body)
        for kind in ('follow','flee','pet'):
            self.assertIn('fixture_transition_phase == "'+kind+'" && entry_kind == "'+kind+'"',body)
        self.assertIn('entry_command && entry_command == fixture_transition_command_id',body)
    def test_missing_process_and_owner_guards_fail_closed(self):
        for old in ('S.processes.len == 1 && S.processes[1] == P', '!A.npc_subtile_pulse',
                    'fixture_transition_accepted["flee"] && fixture_transition_flee_moves > 0',
                    'fixture_transition_move_entries == gap_moves',
                    'fixture_transition_move_entries == quiet_moves',
                    'fixture_transition_events.len < 4096'):
            with self.subTest(guard=old), self.assertRaises(AssertionError):
                prefix, draft=self.source.split('// Source-only transition draft.',1)
                check_transition(prefix+'// Source-only transition draft.'+draft.replace(old,'TRUE',1))
    def test_direct_ai_call_is_rejected(self):
        bad=self.source.replace('S.start()\n\twhile (world.time < started + (scenario == "follow_flee" ? 100 : 12))',
                                'S.start()\n\tA.Life()\n\twhile (world.time < started + (scenario == "follow_flee" ? 100 : 12))',1)
        with self.assertRaises(AssertionError): check_transition(bad)

if __name__ == '__main__': unittest.main()

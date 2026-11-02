"""Synthetic negative controls and exact source-stage reconstruction."""
import copy
import os
from pathlib import Path
import subprocess
import unittest

import pair_receipt as oracle
import pair_stage as stage

HERE = Path(__file__).resolve().parent
HEAD = 'a' * 40


def make_row(case, mode):
    state = dict(human_live=1, animal_live=1, human_tx=0, animal_tx=0,
                 admission_recorded=0, human_x=5, human_y=5, human_z=1, human_sx=0, human_sy=0,
                 animal_x=6, animal_y=5, animal_z=1, animal_sx=0, animal_sy=0)
    events = []
    def add(label, phase, detail=None, **updates):
        state.update(updates)
        events.append(dict(state, label=label, phase=phase, detail=detail,
                           ordinal=len(events)+1, at=(len(events)+1)*0.5,
                           case=case, mode=mode, human_lifetime=1, animal_lifetime=2))
    add('start', 'before_first')
    add('first_before', 'first_leg')
    add('turf_entered_before', 'first_leg', human_x=6)
    if mode == 'legacy':
        add('animal_crossed_before', 'first_leg', 'human')
        origin, phase = 'native_crossed', 'first_leg'
    else:
        add('first_after', 'first_leg')
        add('second_before', 'second_leg')
        add('second_after', 'second_leg', animal_x=5)
        add('fixture_injection_before', 'after_commit')
        origin, phase = 'fixture_post_commit', 'after_commit'
    add('action_before', phase, origin)
    action = dict(action=case, origin=origin, returned=1)
    error = None
    if case == 'owner':
        action.update(admission_recorded=1, current_at_return=1)
        add('owner_admission_return', phase, animal_tx=1, admission_recorded=1, admission_is_current=1)
    elif case == 'relocate':
        add('turf_entered_after', phase, human_x=8, human_y=8)
    elif case == 'delete':
        add('delete_requested', phase)
        add('turf_exited_after', phase, animal_live=0)
    elif case == 'yield':
        add('yield_before', phase)
        add('yield_after', phase)
    elif case == 'throw':
        add('throw_requested', phase)
        error = 'pair_fixture_callback_throw'
        action.pop('returned')
    if case != 'throw':
        add('action_after', phase, origin)
        if mode == 'legacy':
            add('animal_crossed_after', 'first_leg', 'human')
            add('first_after', 'first_leg')
            add('second_before', 'second_leg')
            if case == 'delete':
                add('second_skipped_deleted', 'second_leg')
            else:
                add('second_after', 'second_leg', animal_x=5)
    else:
        add('caught_exception', phase, error)
    add('terminal', 'settling', animal_tx=0, admission_finished=1 if case == 'owner' else None)
    return dict(case=case, mode=mode, error=error, action=action, events=events, overflow=0)


def make_receipt(mode):
    rows = [make_row(case, mode) for case in oracle.CASES]
    return dict(head=HEAD, error=None, byond_version=516, byond_build=1688, port=0,
                scope=oracle.SCOPE, pair_mode=mode, pair_rows=rows, pair_case=oracle.CASES[-1],
                pair_checks=30, pair_partial=rows[-1]['events'], pair_overflow=0)


class OracleControls(unittest.TestCase):
    def setUp(self):
        self.old = make_receipt('legacy')
        self.new = make_receipt('pair_first')

    def test_complete_pair_is_observation_not_parity(self):
        result = oracle.compare(oracle.receipt(self.old, HEAD, 'legacy'),
                                oracle.receipt(self.new, HEAD, 'pair_first'))
        self.assertTrue(result['observations_complete'])
        self.assertFalse(result['safety_or_gameplay_parity_established'])

    def test_missing_case_overflow_and_wrong_head_fail(self):
        for field, value in (('pair_rows', self.old['pair_rows'][:-1]),
                             ('pair_overflow', 1), ('head', 'b'*40), ('error', 'failed')):
            bad = copy.deepcopy(self.old); bad[field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                oracle.receipt(bad, HEAD, 'legacy')

    def test_false_native_and_early_injection_fail(self):
        bad = copy.deepcopy(self.old['pair_rows'][0])
        bad['action']['origin'] = 'fixture_post_commit'
        with self.assertRaises(ValueError):
            oracle.row(bad, 'legacy')
        bad = copy.deepcopy(self.new['pair_rows'][0])
        target = next(x for x in bad['events'] if x['label'] == 'second_after')
        target['label'] = 'missing'
        with self.assertRaises(ValueError):
            oracle.row(bad, 'pair_first')

    def test_unadmitted_or_unretired_owner_fails(self):
        for field in ('returned', 'admission_recorded', 'current_at_return'):
            bad = copy.deepcopy(self.old['pair_rows'][1]); bad['action'][field] = 0
            with self.subTest(field=field), self.assertRaises(ValueError):
                oracle.row(bad, 'legacy')
        bad = copy.deepcopy(self.old['pair_rows'][1]); bad['events'][-1]['animal_tx'] = 1
        with self.assertRaises(ValueError):
            oracle.row(bad, 'legacy')

    def test_relocation_deletion_yield_and_throw_need_witnesses(self):
        for index, label in ((2, 'action_after'), (3, 'delete_requested'),
                             (4, 'yield_after'), (5, 'throw_requested')):
            bad = copy.deepcopy(self.old['pair_rows'][index])
            next(e for e in bad['events'] if e['label'] == label)['label'] = 'missing'
            with self.subTest(label=label), self.assertRaises(ValueError):
                oracle.row(bad, 'legacy')

    def test_bad_actor_or_time_or_terminal_fails(self):
        for mutate in ('lifetime', 'time', 'terminal', 'unknown_label', 'bad_phase'):
            bad = copy.deepcopy(self.new['pair_rows'][0])
            if mutate == 'lifetime':
                bad['events'][0]['human_lifetime'] = True
            elif mutate == 'time':
                bad['events'][2]['at'] = -1
            elif mutate == 'terminal':
                bad['events'][-1]['label'] = 'missing'
            elif mutate == 'unknown_label':
                bad['events'][1]['label'] = 'unreviewed_event'
            else:
                bad['events'][1]['phase'] = 'unreviewed_phase'
            with self.subTest(mutation=mutate), self.assertRaises(ValueError):
                oracle.row(bad, 'pair_first')


class StageControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        checkout = HERE.parents[1]
        override = os.environ.get('PAIR_BASE_GITDIR')
        if (checkout / 'civ13.dme').is_file():
            git = ['git', '-C', str(checkout)]
        elif override:
            git = ['git', '--git-dir', override]
        else:
            raise RuntimeError('local source verification needs PAIR_BASE_GITDIR')
        cls.inputs = {p: subprocess.check_output(git + ['show', stage.BASE + ':' + p], timeout=10)
                      for p in stage.BLOBS}
        cls.fixture = (HERE / 'pair_measure.dm').read_bytes()

    def test_exact_stage_and_no_real_map(self):
        output = stage.reconstruct(self.inputs, self.fixture)
        probe, dme = output['tests/human_subtile/probe.dm'], output['human_subtile.dme']
        self.assertEqual(probe.count(b'pair_run()'), 1)
        self.assertIn(b'"pair_partial" = pair_events', probe)
        self.assertIn(b'tests\\human_subtile\\pair_measure.dm', dme)
        self.assertFalse(any(x.startswith(b'#include ') and b'.dmm' in x for x in dme.splitlines()))

    def test_changed_or_missing_inputs_and_fixture_fail(self):
        for kind in ('missing', 'changed', 'fixture'):
            sources = dict(self.inputs)
            fixture = self.fixture
            if kind == 'missing':
                del sources['civ13.dme']
            elif kind == 'changed':
                sources['civ13.dme'] += b'\\n'
            else:
                fixture += b'\\n'
            with self.subTest(kind=kind), self.assertRaises(ValueError):
                stage.reconstruct(sources, fixture)

    def test_fixture_preserves_raw_and_synthetic_attribution(self):
        text = self.fixture.decode()
        self.assertIn('pair_apply_action("native_crossed")', text)
        self.assertIn('pair_apply_action("fixture_post_commit")', text)
        self.assertIn('pair_record("delete_requested")', text)
        self.assertIn('pair_record("yield_before")', text)
        self.assertIn('pair_record("throw_requested")', text)
        self.assertIn('pair_admission = receipt["transaction"]', text)


if __name__ == '__main__':
    unittest.main()

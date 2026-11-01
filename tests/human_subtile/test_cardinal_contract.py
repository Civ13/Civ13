import copy
import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('cardinal_contract', Path(__file__).with_name('cardinal_contract.py'))
c = importlib.util.module_from_spec(spec)
spec.loader.exec_module(c)


def receipt(mode='smooth', tick=.5, lag=4):
    events, x = [], 12*32
    enabled = mode == 'smooth'
    def add(label, at, **values):
        event = {'event': label, 'at': at, 'x': x//32, 'y': 32, 'z': 1, 'sx': x%32, 'sy': 0,
                 'enabled': enabled, 'tick_usage': 1, 'life_depth': 0, 'transaction': 0, 'pulse': 0,
                 'owner': None, 'pending': None, 'active_tx': None, 'step_size': 32}
        event.update(values)
        events.append(event)
    add('phase_start', 0)
    add('command_before', 0, detail={'mode': 'direction', 'lag': lag, 'speed_argument': 0, 'direction': 4})
    add('command_after', 0, detail=1 if enabled else None, owner='owner' if enabled else None)
    for cycle, at in enumerate((2, 6, 10), 1):
        tx = f'tx{cycle}'
        if enabled:
            add('tx_admitted', at, tx=tx, active_tx=tx, transaction=1, tx_dir=4, remaining_x=32, remaining_y=0)
            for pulse in range(16):
                pulse_at = at + (pulse//8)*tick
                add('move_enter', pulse_at, active_tx=tx, transaction=1)
                x += 2
                add('move_exit', pulse_at, active_tx=tx, transaction=1)
            add('final_pulse', at+2, tx=tx, active_tx=tx, transaction=1, remaining_x=0, remaining_y=0)
            add('tx_actor_released', at+2, tx=tx, tx_finished=0, tx_actor_present=1, arrived=1)
            add('tx_finished', at+2, tx=tx, tx_finished=1, arrived=1, tx_actor_present=0,
                tx_target_present=0, tx_combat_present=0, tx_following_present=0, tx_intent_present=0)
        else:
            add('move_enter', at)
            x += 32
            add('move_exit', at)
    add('observation_end', 16)
    add('phase_end', 16)
    return {'enabled': enabled, 'lag_ticks': lag, 'tick_lag_ds': tick, 'converted_ds': lag,
            'started': 0, 'ended': 16, 'observation_ds': 16, 'event_count': len(events), 'events': events,
            'step_size': 32, 'life_count': 0, 'tx_count': 3 if enabled else 0,
            'move_enter_count': 48 if enabled else 3, 'move_exit_count': 48 if enabled else 3}


class CardinalContractTests(unittest.TestCase):
    def test_source_binding_rejects_extra_missing_wrong_tree_and_unrelated_head(self):
        head='a'*40
        paths=b'\0'.join(x.encode() for x in sorted(c.ALLOWED_DELTA))+b'\0'
        def check(cmd,**_):
            if cmd[1]=='rev-parse': return (c.BASE_TREE+'\n').encode()
            self.assertEqual(cmd[1:5],['diff','--no-ext-diff','--no-renames','--name-only'])
            return paths
        with patch.object(c.subprocess,'check_output',side_effect=check), \
             patch.object(c.subprocess,'run',return_value=type('Result',(),{'returncode':0})()):
            self.assertTrue(c.validate_source(['git'],{},head))
            original=paths
            for bad in (paths+b'unrelated\0', b'\0'.join(paths.split(b'\0')[:-2])+b'\0',
                        paths+next(iter(c.ALLOWED_DELTA)).encode()+b'\0', paths[:-1]):
                paths=bad
                with self.assertRaises(ValueError): c.validate_source(['git'],{},head)
            paths=original
        with patch.object(c.subprocess,'check_output',return_value=b'0'*40), \
             patch.object(c.subprocess,'run',return_value=type('Result',(),{'returncode':0})()):
            with self.assertRaises(ValueError): c.validate_source(['git'],{},head)
        with patch.object(c.subprocess,'check_output',return_value=(c.BASE_TREE+'\n').encode()), \
             patch.object(c.subprocess,'run',return_value=type('Result',(),{'returncode':1})()):
            with self.assertRaises(ValueError): c.validate_source(['git'],{},head)

    def test_positive_variants_and_timings(self):
        for mode in c.MODES:
            for tick in c.TICKS:
                for lag in c.LAGS:
                    result = c.validate_case(receipt(mode, tick, lag), mode, tick, lag)
                    self.assertEqual(result['start_intervals'], [4, 4])
                    self.assertEqual(result['first_start_delay'],2)
                    self.assertEqual(result['first_physical_delay'],2)
                    self.assertEqual(len(result['final_pulses']),3 if mode=='smooth' else 0)

    def test_empty_forged_or_wrong_direction_cannot_pass(self):
        row = receipt()
        for mutate in (
            lambda r: r.update(events=[], event_count=0),
            lambda r: r['events'][1]['detail'].update(direction=8),
            lambda r: r['events'][5].update(sy=2),
            lambda r: r.update(converted_ds=2),
        ):
            bad = copy.deepcopy(row); mutate(bad)
            with self.assertRaises(ValueError): c.validate_case(bad, 'smooth', .5, 4)

    def test_missing_cleanup_and_overlapping_transaction_fail(self):
        row = receipt()
        for label in ('tx_finished', 'final_pulse'):
            bad = copy.deepcopy(row)
            del bad['events'][next(i for i, e in enumerate(bad['events']) if e['event'] == label)]
            bad['event_count'] -= 1
            with self.assertRaises(ValueError): c.validate_case(bad, 'smooth', .5, 4)
        bad=copy.deepcopy(row)
        del bad['events'][next(i for i,e in enumerate(bad['events']) if e['event']=='observation_end')]
        bad['event_count']-=1
        with self.assertRaises(ValueError): c.validate_case(bad, 'smooth', .5, 4)
        bad=copy.deepcopy(row)
        next(e for e in bad['events'] if e['event']=='tx_actor_released')['arrived']=0
        with self.assertRaises(ValueError): c.validate_case(bad, 'smooth', .5, 4)
        bad = copy.deepcopy(row)
        index = next(i for i, e in enumerate(bad['events']) if e['event'] == 'tx_admitted')
        bad['events'].insert(index+1, copy.deepcopy(bad['events'][index])); bad['event_count'] += 1
        with self.assertRaises(ValueError): c.validate_case(bad, 'smooth', .5, 4)

    def test_no_life_or_suppressed_command_or_overflow(self):
        for label, value in [('phase_start', ('life_depth', 1)), ('command_after', ('event', 'command_suppressed'))]:
            row = receipt(); next(e for e in row['events'] if e['event'] == label)[value[0]] = value[1]
            with self.assertRaises(ValueError): c.validate_case(row, 'smooth', .5, 4)
        row = receipt(); row['event_count'] = c.MAX_EVENTS + 1
        with self.assertRaises(ValueError): c.validate_case(row, 'smooth', .5, 4)

    def test_pair_rejects_wrong_source_missing_or_duplicate_case(self):
        head = 'a'*40
        def whole(mode):
            # Fixture starts after one common readiness tick.
            rows = [receipt(mode, .5, lag) for lag in c.LAGS]
            for row in rows:
                row['started'] += 1; row['ended'] += 1
                for event in row['events']: event['at'] += 1
            return {'head': head, 'error': None, 'port': 0, 'byond_version': 516, 'byond_build': 1688,
                    'scope': c.SCOPE, 'mode': mode, 'tick': .5, 'overflow': False,
                    'movement_blob': c.SOURCE_MOVEMENT_BLOB,
                    'setup': {'requested_tick': .5, 'actual_tick': .5, 'startup_time': 0, 'ready_time': .5,
                              'startup_usage': 10000, 'ready_usage': 1}, 'rows': rows}
        pair = {mode: whole(mode) for mode in c.MODES}
        self.assertFalse(c.compare(pair, head, .5)['parity_established'])
        for mutate in (lambda p: p['smooth'].update(movement_blob='b'*40),
                       lambda p: p['smooth']['rows'].pop(),
                       lambda p: p['smooth']['rows'][1].update(lag_ticks=3),
                       lambda p: p.pop('legacy')):
            bad = copy.deepcopy(pair); mutate(bad)
            with self.assertRaises(ValueError): c.compare(bad, head, .5)


if __name__ == '__main__':
    unittest.main()

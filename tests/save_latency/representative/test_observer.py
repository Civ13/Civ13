"""Actual phase observer with an injected clock, transport and stop event."""
import json
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parent))
import execute


class ObserverTests(unittest.TestCase):
    def setUp(self):
        self.enterContext(patch.object(subprocess, 'Popen', side_effect=AssertionError('process forbidden')))
        self.enterContext(patch.object(socket, 'socket', side_effect=AssertionError('socket forbidden')))
        self.temporary = self.enterContext(tempfile.TemporaryDirectory())
        self.game = Path(self.temporary)
        self.now, self.sent, self.resource_calls = 0., [], []

    def observe(self, cadence, count, *, transport=None, resource_delay=0, stop_at=None, deadline=1000,
                clock_jitter=0, early_wake_seconds=None):
        owner = self
        class Stop:
            def is_set(self):
                return len(owner.sent) >= count or (stop_at is not None and owner.now >= stop_at)
            def wait(self, seconds):
                if early_wake_seconds is not None:
                    seconds = min(seconds, early_wake_seconds)
                owner.now = min(owner.now+seconds, stop_at) if stop_at is not None else owner.now+seconds
                return self.is_set()
        def request(action, session, budget):
            self.assertEqual((action, session), ('status', 'observe'))
            self.sent.append(self.now)
            if transport:
                transport(len(self.sent), budget)
            return {'representative': {'heartbeat': 7, 'phase': 'saving' if len(self.sent)>2 else 'idle'},
                    'world_time': len(self.sent)}
        def resources(pid):
            self.resource_calls.append((pid, self.now))
            self.now += resource_delay
            return {'started_utc': 'owned', 'private_bytes': 1, 'working_bytes': 1, 'cpu_seconds': 0}
        def clock():
            self.now += clock_jitter
            return self.now
        packet = {'sampler_cadence_seconds': cadence, 'resource_cadence_seconds': 1000,
                  'output': str(self.game), 'maximum_private_bytes': 1000, 'maximum_output_bytes': 100000}
        execute.observe(SimpleNamespace(clock=clock, resources=resources),
                        SimpleNamespace(query=request), self.game, packet, SimpleNamespace(pid=42),
                        {'started_utc': 'owned'}, deadline, Stop())
        path = self.game / 'latency.jsonl'
        return [json.loads(line) for line in path.read_text().splitlines()] if path.exists() else []

    def test_quick_responses_keep_one_schedule_across_old_window_boundaries(self):
        for cadence, count in ((1, 5), (.5, 4), (1.5, 4)):
            with self.subTest(cadence=cadence):
                self.now, self.sent, self.resource_calls = 0., [], []
                (self.game / 'latency.jsonl').unlink(missing_ok=True)
                rows = self.observe(cadence, count)
                self.assertEqual(self.sent, [cadence*index for index in range(count)])
                self.assertEqual([row['sent'] for row in rows], self.sent)
                self.assertTrue(all(row['heartbeat'] == 7 for row in rows))

    def test_timeout_and_stall_retain_gaps_without_catchup_requests(self):
        def transport(number, budget):
            if number == 2:
                self.now += budget
                raise TimeoutError('injected bounded timeout')
            if number == 3:
                self.now += 1.3
        rows = self.observe(.5, 5, transport=transport)
        self.assertEqual(self.sent, [0., .5, 1.5, 3., 3.5])
        self.assertEqual(rows[1]['status'], 'timeout')
        self.assertNotIn('heartbeat', rows[1])
        self.assertEqual(rows[2]['status'], 'transport_exceeded_timeout')
        self.assertGreaterEqual(rows[2]['skipped_after'], 2)
        self.assertEqual(rows[-1]['server_phase_at_response'], 'saving')

    def test_clock_read_overhead_keeps_initial_slot_and_minimum_spacing(self):
        self.observe(.5, 3, clock_jitter=.001)
        self.assertLess(self.sent[0], .5)
        self.assertTrue(all(right-left >= .5 for left, right in zip(self.sent, self.sent[1:])))

    def test_resource_gap_does_not_reset_schedule_or_inflate_query_latency(self):
        rows = self.observe(.5, 4, resource_delay=1.2)
        self.assertEqual(self.sent, [0., 1.5, 2., 2.5])
        self.assertEqual(rows[0]['latency'], 0)
        self.assertEqual(rows[1]['deadline_misses'], 2)
        self.assertTrue(all(right-left >= .5 for left, right in zip(self.sent, self.sent[1:])))

    def test_phase_completion_interrupts_wait_and_already_stopped_phase_does_nothing(self):
        rows = self.observe(1, 100, stop_at=1.25)
        self.assertEqual(self.sent, [0., 1.])
        self.assertEqual(len(rows), 2)
        self.assertEqual(self.now, 1.25)
        self.sent, self.resource_calls = [], []
        (self.game / 'latency.jsonl').unlink()
        self.assertEqual(self.observe(1, 0), [])
        self.assertEqual(self.resource_calls, [])

    def test_fixed_deadline_expires_without_additional_requests_or_extension(self):
        with self.assertRaisesRegex(TimeoutError, 'aggregate budget'):
            self.observe(1, 100, deadline=40)
        self.assertEqual(self.sent, list(range(40)))
        self.assertEqual(self.now, 40)
        self.assertEqual(len((self.game / 'latency.jsonl').read_text().splitlines()), 40)

    def test_early_wakes_preserve_query_spacing_and_final_deadline_wait(self):
        with self.assertRaisesRegex(TimeoutError, 'aggregate budget'):
            self.observe(1, 100, deadline=31.25, early_wake_seconds=.2)
        self.assertEqual(self.sent, list(range(32)))
        self.assertEqual(self.now, 31.25)
        rows = [json.loads(line) for line in (self.game / 'latency.jsonl').read_text().splitlines()]
        self.assertEqual([row['sent'] for row in rows], self.sent)

    def test_early_wakes_remain_interruptible_in_final_deadline_wait(self):
        rows = self.observe(1, 100, deadline=31.75, early_wake_seconds=.2, stop_at=31.3)
        self.assertEqual(self.sent, list(range(32)))
        self.assertEqual(len(rows), 32)
        self.assertEqual(self.now, 31.3)

    def test_actual_host_query_caps_caller_budget_by_allocation_and_phase_remainder(self):
        (self.game / 'config').mkdir()
        (self.game / 'config/full-map-probe-token.txt').write_text('f'*64)
        effect = SimpleNamespace(clock=lambda: self.now, connect=lambda *args: self.fail('transport ran'))
        packet = {'port': 18563, 'query_timeout_seconds': 1}
        host = execute.Host(effect, self.game, SimpleNamespace(poll=lambda: None), 'a'*40,
                            packet, b'injected helper boundary', 10, None)
        status = {'source': 'a'*40, 'session': 'owned', 'clients': 0, 'representative': {'phase': 'idle'}}
        for caller, now, expected in ((2, 0, 1), (.5, 0, .5), (2, 9.8, .2)):
            with self.subTest(caller=caller, now=now):
                self.now = now
                with patch.object(execute.helpers, 'query', return_value=status) as helper:
                    self.assertEqual(host.query('status', 'observe', caller), status)
                self.assertAlmostEqual(helper.call_args.args[-1], expected)


if __name__ == '__main__':
    unittest.main()

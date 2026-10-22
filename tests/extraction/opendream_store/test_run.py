"""Offline causal tests: injected backend, memory-only stages; no native processes."""
import copy
import json
import unittest
from unittest.mock import patch
import run as r

PROBE = '''#include "../../code/modules/1713/extraction/account_store.dm"
/world
\tfps = 10
/world/OpenPort(port)
\tif (port == "none") return ..()
\treturn FALSE
var/store_failures = 0
/proc/store_assert(condition, message)
\tif (!condition)
\t\tstore_failures++
\t\tworld.log << "FAIL: [message]"
/world/New()
\tworld.OpenPort("none")
\ttransaction_probe()
\ttext2file(store_failures ? "FAIL: [store_failures] journal assertions" : "PASS", "result.txt")
\tshutdown()
/proc/transaction_probe()
\tvar/datum/extraction_session/S
\tfor (var/invalid in list("malformed", 17))
\t\tvar/list/bad_entries = list()
\t\tstore_assert(!S.valid_entries(bad_entries, 16), "scalar account root rejected [invalid]")
\t\tstore_assert(!S.checkpoint_home(bad_entries), "checkpoint roots")
\t\tvar/list/bad_nodes = list()
\t\tstore_assert(!S.valid_entries(bad_nodes, 16), "scalar equipment node rejected [invalid]")
\t\tstore_assert(!S.checkpoint_home(bad_nodes), "checkpoint nodes")
\tvar/list/budget_entries = list()
'''.encode()
TRANSACTIONS = b'\tfor (var/entry_index in 1 to entries.len)\n\t\tvar/list/entry = entries[entry_index]\n\t\t\tfor (var/node_index in 1 to nodes.len)\n\t\t\t\tvar/list/node = nodes[node_index]\n'


def sample(**changes):
    result = dict(owned=True, clients=0, outbound=0, unexpected_listener=False,
                  bytes=0, files=1, depth=1, rss=100, effective_cvars=copy.deepcopy(r.CVARS))
    result.update(changes)
    return result


def inputs():
    data = {p: b'// inert synthetic test input\n' for p in r.INPUTS}
    data[r.PROBE] = PROBE
    data[r.BASE+'transactions.dm'] = TRANSACTIONS
    return data


def admission():
    a = dict(enabled=True, allocated=True, game=r.GAME, engine=r.ENGINE,
             engine_tree=r.ENGINE_TREE, robust=r.ROBUST, allocation_id='TEST-ONLY', owner='injected',
             expires_utc=3400, cvars=copy.deepcopy(r.CVARS), resource_envelope={
                 'runner_class':'standard-public-ubuntu', 'runner_memory_bytes':8*1024**3,
                 'runner_cpus':2, 'sample_interval_seconds':0.25},
             monitor_review='1'*64, build_contract={'sdk':'10.0.401', 'configuration':'Release',
                 'platform':'linux-x64', 'commands_sha256':'1'*64,
                 'effective_source_manifest_sha256':'1'*64, 'robust_transform_sha256':'1'*64,
                 'backend_bundle_sha256':'1'*64})
    for key in ('executor_review_sha256', 'startup_sha256', 'profile_sha256', 'archive_sha256',
                'compiler_sha256', 'runtime_sha256', 'installed_manifest_sha256'):
        a[key] = r.sha(b'startup')
    return a


class Clock:
    now = 0
    def __call__(self): return self.now


class Backend:
    def __init__(self, a, clock):
        self.a, self.clock = a, clock
        self.calls = []
        self.cleaned = False
        self.fault = None
    def reserve(self, a):
        self.calls.append('reserve')
        self.anchors = r.anchors_for(a, inputs())
        return 'OWNED-TEST-TOKEN'
    def setup(self, a, token, deadline, guard, boundary):
        self.calls.append('setup')
        boundary('launch',self.anchors)
        guard(sample(outbound=1))  # build-only dependency transport allowed
        boundary('final',self.anchors)
        receipt = dict(a)
        receipt.update(exited=True, descendants_empty=True)
        if self.fault == 'package': receipt['runtime_sha256'] = '0'*64
        return receipt
    def vacant(self, token, port): return self.fault != 'busy-port'
    def step(self, phase, case, files, token, deadline, guard, boundary):
        self.calls.append((phase, case))
        if self.fault == 'timeout': self.clock.now = 2401
        self.expected = dict(self.anchors)
        self.expected.update({'stage:'+p:r.sha(raw) for p,raw in files.items()})
        if phase == 'runtime': self.expected['artifact:probe.json'] = r.sha(b'{}')
        boundary('launch',self.expected)
        if self.fault != 'unmonitored':
            changes = {'outbound': 1} if self.fault == 'outbound' else {}
            guard(sample(**changes))
        if self.fault == 'raise': raise r.Rejected('injected transport failure')
        expected = []
        if case.endswith('old-loops'):
            name = 'scalar account root rejected ' if case.startswith('roots') else 'scalar equipment node rejected '
            expected = [name+'malformed', name+'17']
        marker = 'FAIL: 2 journal assertions' if expected else r.PASS
        logs = ['\n'.join('FAIL: '+x for x in expected)]
        if self.fault == 'unexpected-failure': logs.append('FAIL: wrong target')
        if self.fault == 'account': logs.append('Logging in...')
        if self.fault == 'runtime-error': logs.append('Runtime error: bad thing')
        boundary('final',self.expected)
        return dict(exited=True, descendants_empty=self.fault != 'survivor', observations=1,startup_verified=True,
                    exit=0, streams=logs, result=(marker+'\n').encode())
    def cleanup(self, token, deadline):
        self.cleaned = True
        return self.fault != 'cleanup'
    def artifacts(self, token, case): return {'probe.json':b'{}'}
    def seals(self, token, case): return dict(self.expected, **{'artifact:probe.json':r.sha(b'{}')})
    def final_seals(self, token): return self.anchors
    def retain(self, token, record): self.record = record


class Tests(unittest.TestCase):
    def perform(self, fault=None, a=None):
        a = admission() if a is None else a
        data = inputs()
        clock = Clock()
        backend = Backend(a, clock)
        backend.fault = fault
        self.backend = backend
        with patch.object(r, 'INPUTS', {p: r.sha(raw) for p, raw in data.items()}):
            digest = r.sha(json.dumps(a, sort_keys=True, separators=(',', ':')).encode())
            return r.orchestrate(a, data, b'startup', backend, clock, utc=lambda:1000, admission_sha256=digest)

    def test_actual_orchestration_runs_exact_five_cases(self):
        self.assertEqual(len(self.perform()), 5)
        self.assertEqual(self.backend.calls[2:], [(p, c) for c in r.CASES for p in ('compile', 'runtime')])
        self.assertTrue(self.backend.cleaned)

    def test_off_blocks_all_effects(self):
        a = admission(); a['enabled'] = False
        with self.assertRaisesRegex(r.Rejected, 'OFF'): self.perform(a=a)
        self.assertEqual(self.backend.calls, [])

    def test_unallocated_blocks_all_effects(self):
        a = admission(); a['allocated'] = False
        with self.assertRaises(r.Rejected): self.perform(a=a)
        self.assertEqual(self.backend.calls, [])

    def test_wrong_head_blocks_all_effects(self):
        a = admission(); a['game'] = 'b31'
        with self.assertRaises(r.Rejected): self.perform(a=a)
        self.assertEqual(self.backend.calls, [])

    def test_missing_profile_digest_refused(self):
        a = admission(); a['profile_sha256'] = None
        with self.assertRaises(r.Rejected): self.perform(a=a)
        self.assertEqual(self.backend.calls, [])

    def test_missing_resource_fields_refused(self):
        a = admission(); a['resource_envelope'] = {'test': True}
        with self.assertRaises(r.Rejected): self.perform(a=a)
        self.assertEqual(self.backend.calls, [])

    def test_missing_admission_digest_refused_before_effects(self):
        data = inputs(); a = admission(); backend = Backend(a, Clock())
        with self.assertRaisesRegex(r.Rejected, 'admission digest'):
            r.orchestrate(a, data, b'startup', backend, utc=lambda:1000)
        self.assertEqual(backend.calls, [])

    def test_failure_stops_and_cleans_no_retry(self):
        for fault in ('package', 'busy-port', 'timeout', 'unmonitored', 'outbound', 'raise',
                      'unexpected-failure', 'account', 'runtime-error', 'survivor', 'cleanup'):
            with self.subTest(fault=fault):
                with self.assertRaises(r.Rejected): self.perform(fault)
                self.assertTrue(self.backend.cleaned)
                self.assertEqual(self.backend.calls.count('reserve'), 1)
                if fault != 'cleanup': self.assertNotIn(('compile', 'roots-candidate'), self.backend.calls)

    def test_shared_deadline_not_reset_between_stages(self):
        clock = Clock(); budget = r.Budget(clock)
        clock.now = 2360
        self.assertEqual(budget.limit(90), 2370)
        clock.now = 2370
        with self.assertRaises(r.Rejected): budget.limit(60)

    def test_source_closure_and_digest_are_causal(self):
        data = inputs(); pins = {p: r.sha(v) for p,v in data.items()}
        r.verify_inputs(data, pins)
        data[r.PROBE] += b'changed'
        with self.assertRaises(r.Rejected): r.verify_inputs(data, pins)
        del data[r.PROBE]
        with self.assertRaises(r.Rejected): r.verify_inputs(data, pins)

    def test_exact_causal_scalar_oracles(self):
        for case in r.CASES[-2:]:
            prefix = 'scalar account root rejected ' if case.startswith('roots') else 'scalar equipment node rejected '
            good = ['FAIL: '+prefix+'malformed\nFAIL: '+prefix+'17']
            r.oracle(case, 0, b'FAIL: 2 journal assertions\n', good)
            for bad in ([], good+good, good+['FAIL: collateral'], good+['PASS: false positive']):
                with self.assertRaises(r.Rejected): r.oracle(case, 0, b'FAIL: 2 journal assertions\n', bad)

    def test_exact_positive_bytes_no_strip(self):
        for value in (r.PASS.encode(), (r.PASS+'\n\n').encode(), (r.PASS+'\r\n').encode()):
            with self.assertRaises(r.Rejected): r.oracle('full-candidate', 0, value, [])
        r.oracle('full-candidate', 0, (r.PASS+'\n').encode(), [])

    def test_monitor_gaps_and_thresholds(self):
        for changes in ({'owned':False}, {'clients':1}, {'unexpected_listener':True}, {'outbound':1},
                        {'rss':4*1024**3+1}, {'bytes':128*1024**2+1}, {'depth':17}, {'files':10001}):
            with self.assertRaises(r.Rejected): r.observe(sample(**changes), admission())
        incomplete = sample(); del incomplete['rss']
        with self.assertRaises(r.Rejected): r.observe(incomplete, admission())

    def test_stage_mutates_only_named_control_and_startup(self):
        data = inputs()
        positive = r.stage(data, 'roots-candidate', b'startup')
        negative = r.stage(data, 'roots-old-loops', b'startup')
        self.assertEqual(positive[r.PROBE], negative[r.PROBE])
        self.assertIn(b'for (var/list/entry in entries)', negative[r.BASE+'transactions.dm'])
        self.assertNotIn(b'for (var/list/entry in entries)', positive[r.BASE+'transactions.dm'])
        self.assertNotIn(b'checkpoint roots', positive[r.PROBE])
        self.assertNotIn(b'bad_nodes', positive[r.PROBE])
        self.assertIn(b'scalar account root rejected', positive[r.PROBE])
        full = r.stage(data, 'full-candidate', b'startup')
        self.assertEqual(full[r.BASE+'transactions.dm'], data[r.BASE+'transactions.dm'])
        self.assertNotIn(b'return ..()', full[r.PROBE])
        self.assertNotIn(b'/world/New()', full[r.PROBE])
        self.assertIn(b'/proc/store_fixture_body()', full[r.PROBE])
        nodes = r.stage(data, 'nodes-old-loops', b'startup')
        self.assertIn(b'for (var/list/node in nodes)', nodes[r.BASE+'transactions.dm'])
        self.assertNotIn(b'bad_entries', nodes[r.PROBE])
        self.assertIn(b'scalar equipment node rejected', nodes[r.PROBE])

    def test_drifted_seam_refused(self):
        data = inputs(); data[r.PROBE] = data[r.PROBE].replace(b'world.OpenPort', b'changed.OpenPort')
        with self.assertRaises(r.Rejected): r.stage(data, 'full-candidate', b'startup')


if __name__ == '__main__': unittest.main()

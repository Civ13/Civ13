"""Default-OFF orchestration with injected external effects.

All production inputs are immutable; external effects require an explicitly supplied,
independently reviewed backend. This module's CLI only reports the proposal;
entry.py is the separately gated source-first hosted execution entry.
"""
from pathlib import Path
import hashlib
import json
import re
import time

GAME = 'f5620b232b4fa159930b3b393c9794c05d4fb7b1'
ENGINE = '09f63000bab228a4bc792f3a2211e2d60a07de14'
ENGINE_TREE = '210207129ce01fce6daf87f3a3c8f48085184db6'
ROBUST = 'af2a7d0406b410c4d960f0f4b34513651c6dc742'
BASE = 'code/modules/1713/extraction/'
PROBE = 'tests/extraction/store_probe.dm'
INPUTS = {
    PROBE: '69bc96e2475ed76658749a003cffcabcaa792669968efa2300911fd6be09620b',
    'tests/extraction/journal_adapters.dm': 'acf4b93c8cba383bbab29aec7431bb63a09ebb11847a539b0a92d31279df7f56',
    BASE+'account_store.dm': '95e3bab184aab9e41f5da9154bc004fd95ab6bebd57cd438e7025ee23388efac',
    BASE+'transactions.dm': '23a18be4637881d77bcbaf70f41425293c0978c09b49c64a963ad77ac727876f',
    BASE+'settlement.dm': 'cd42b63f9da9b7ee733f110005781c6df6f89780efbcc1c501a8cf6ac834239b',
    BASE+'ipc_crypto.dm': '85e339c55e10379c92635a35514740de8a8d6766c19884d9eca09d01b89b2d26',
    BASE+'ipc_wire.dm': '3e3f308d7e244f1b4293ea7f8f02196a85c764468427e669227d269c89588f53',
    BASE+'ipc_request.dm': 'b911af76c106fff74dc083b2b3c69198a2304b7cb5a0d88d3d60baf5639e74f0',
    BASE+'insurance_mail.dm': '775c73d3c835e3a773522cc8671b53fce686cb2719231d7a050bdc6e9dfea55a',
}
CASES = ('full-candidate', 'roots-candidate', 'nodes-candidate', 'roots-old-loops', 'nodes-old-loops')
PASS = 'PASS: account journal restart, isolation, bounds, crash and corruption'
CVARS = {'opendream.world_params': 'phase=store', 'net.bindto': '127.0.0.1',
         'net.port': 19567, 'status.enabled': False, 'hub.advertise': False,
         'auth.mode': 2, 'opendream.require_native_identity': False,
         'opendream.topic_port': 0, 'opendream.enable_tracy': False,
         'opendream.debug_adapter_launched': 0}
DIAGNOSTIC = re.compile(r'runtime\s+error|bad\s+ref|##\s*error|unhandled\s+exception|'
                        r'cannot\s+execute\s+null|\bwarning\b|\bfatal\b|\berror\b|'
                        r'logging\s+in|logged\s+in|authenticated|client\s+connected', re.I)


class Rejected(RuntimeError):
    pass


def need(value, reason):
    if not value:
        raise Rejected(reason)


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def once(text, old, new):
    need(text.count(old) == 1, 'source seam drift')
    return text.replace(old, new, 1)


def verify_inputs(inputs, expected=None):
    expected = INPUTS if expected is None else expected
    need(set(inputs) == set(expected), 'source closure differs')
    for path, digest in expected.items():
        need(sha(inputs[path]) == digest, 'input digest differs: '+path)


def stage(inputs, case, startup):
    """Pure bytes transformation; caller verifies pinned inputs before use."""
    need(case in CASES, 'unknown case')
    files = dict(inputs)
    probe = inputs[PROBE].decode('utf-8').replace('\r\n', '\n')
    probe = once(probe, '/world/OpenPort(port)\n\tif (port == "none") return ..()\n\treturn FALSE\n', '')
    probe = once(probe, '\tworld.OpenPort("none")\n', '')
    probe = once(probe, '/world/New()', '/proc/store_fixture_body()')
    probe = once(probe, '\tshutdown()', '\tstore_startup_finish()')
    if case != 'full-candidate':
        header = probe.split('/proc/store_fixture_body()\n', 1)[0]
        transaction = probe.split('/proc/transaction_probe()\n', 1)[1]
        intro, scalar = transaction.split('\tfor (var/invalid in list("malformed", 17))\n', 1)
        scalar = scalar.split('\tvar/list/budget_entries = list()\n', 1)[0]
        roots, nodes = scalar.split('\t\tvar/list/bad_nodes = ', 1)
        selected = roots if case.startswith('roots') else '\t\tvar/list/bad_nodes = '+nodes
        # Remove only the checkpoint assertions whose downstream effects obscure
        # the two independent scalar-admission oracles. Candidate/control identical.
        selected = ''.join(line for line in selected.splitlines(True) if 'store_assert(!S.checkpoint_home(' not in line)
        probe = (header+'/proc/store_fixture_body()\n\ttransaction_probe()\n'
                 '\ttext2file(store_failures ? "FAIL: [store_failures] journal assertions" : "'+PASS+'", "result.txt")\n'
                 '\tstore_startup_finish()\n\n/proc/transaction_probe()\n'+intro+
                 '\tfor (var/invalid in list("malformed", 17))\n'+selected+'\tS.close()\n')
    files[PROBE] = probe.encode()
    if case.endswith('old-loops'):
        text = files[BASE+'transactions.dm'].decode().replace('\r\n', '\n')
        if case.startswith('roots'):
            text = once(text, '\tfor (var/entry_index in 1 to entries.len)\n\t\tvar/list/entry = entries[entry_index]',
                        '\tfor (var/list/entry in entries)')
        else:
            text = once(text, '\t\t\tfor (var/node_index in 1 to nodes.len)\n\t\t\t\tvar/list/node = nodes[node_index]',
                        '\t\t\tfor (var/list/node in nodes)')
        files[BASE+'transactions.dm'] = text.encode()
    files['startup.dm'] = startup
    paths = [PROBE, 'tests/extraction/journal_adapters.dm']+[BASE+n+'.dm' for n in ('ipc_crypto', 'ipc_wire', 'ipc_request', 'insurance_mail')]+['startup.dm']
    files['probe.dme'] = ''.join('#include "'+p+'"\n' for p in paths).encode()
    return files


def oracle(case, exit_code, result_bytes, streams):
    need(exit_code == 0, 'runtime exit failure')
    text = '\n'.join(streams)
    need(not DIAGNOSTIC.search(text), 'unexpected diagnostic/account activity')
    expected = []
    if case.endswith('old-loops'):
        label = 'scalar account root rejected ' if case.startswith('roots') else 'scalar equipment node rejected '
        expected = [label+'malformed', label+'17']
    labels = re.findall(r'FAIL: ([^\r\n]+)', text)
    need(sorted(labels) == sorted(expected), 'assertion multiset differs')
    need(not expected or 'PASS:' not in text, 'negative control has PASS')
    wanted = 'FAIL: 2 journal assertions' if expected else PASS
    # Native text2file writes exactly one LF. No stripping/alternate marker acceptance.
    need(result_bytes == (wanted+'\n').encode(), 'result bytes differ')
    return wanted


class Budget:
    def __init__(self, clock, utc=lambda: 0, expires=2400, *, entered=None, entered_utc=None):
        self.clock = clock
        self.utc = utc
        self.expires = expires
        # Anchor UTC once. Later wall-clock rollback cannot extend monotonic end.
        entered = clock() if entered is None else entered
        entered_utc = utc() if entered_utc is None else entered_utc
        remaining = min(2400, expires-entered_utc)
        need(remaining > 30, 'expired admission/no cleanup reserve')
        self.end = entered+remaining
        self.work_end = self.end-30
    def limit(self, seconds):
        self.check(self.work_end)
        return min(self.work_end, self.clock()+seconds)
    def check(self, deadline):
        need(self.clock() < deadline and self.clock() < self.work_end and self.utc() < self.expires, 'stage/shared deadline or expiry')


def admission_check(a):
    need(a.get('enabled') is True and a.get('allocated') is True, 'proposal is OFF/unallocated')
    need(a.get('game') == GAME and a.get('engine') == ENGINE and a.get('engine_tree') == ENGINE_TREE and a.get('robust') == ROBUST, 'wrong immutable identities')
    for key in ('allocation_id', 'owner', 'executor_review_sha256', 'startup_sha256', 'profile_sha256', 'archive_sha256', 'compiler_sha256', 'runtime_sha256', 'installed_manifest_sha256'):
        need(isinstance(a.get(key), str) and bool(a[key]), 'unbound '+key)
        if key.endswith('sha256'):
            need(re.fullmatch('[0-9a-f]{64}', a[key]) is not None, 'invalid digest '+key)
    need(a.get('cvars') == CVARS, 'effective CVar contract differs')
    need(type(a.get('expires_utc')) in (int, float) and 0 < a['expires_utc'] < float('inf'), 'unbound expiry')
    envelope = a.get('resource_envelope')
    need(isinstance(envelope, dict), 'missing concrete resource envelope')
    need(envelope.get('runner_class') == 'standard-public-ubuntu', 'wrong runner class')
    for key in ('runner_memory_bytes', 'runner_cpus', 'sample_interval_seconds'):
        value = envelope.get(key)
        need(type(value) in (int, float) and 0 < value < float('inf'), 'unbound resource '+key)
    need(envelope['sample_interval_seconds'] <= 0.25, 'sampling too sparse')
    need(isinstance(a.get('monitor_review'), str) and re.fullmatch('[0-9a-f]{64}', a['monitor_review']), 'unbound monitor review')
    build = a.get('build_contract')
    need(isinstance(build, dict) and build.get('sdk') == '10.0.401' and build.get('configuration') == 'Release' and build.get('platform') == 'linux-x64', 'unbound build contract')
    for key in ('commands_sha256', 'effective_source_manifest_sha256', 'robust_transform_sha256', 'backend_bundle_sha256'):
        need(isinstance(build.get(key), str) and re.fullmatch('[0-9a-f]{64}', build[key]), 'unbound build '+key)


def observe(sample, a, build=False):
    """Backend must report complete fields, including explicit vacancy/identity."""
    for key in ('owned', 'clients', 'outbound', 'unexpected_listener', 'bytes', 'files', 'depth', 'rss'):
        need(key in sample, 'missing monitor field '+key)
    need(sample['owned'] is True, 'process ownership lost')
    need(sample['clients'] == 0 and sample['unexpected_listener'] is False, 'unexpected client/listener')
    if not build:
        need(sample['outbound'] == 0, 'unexpected runtime outbound activity')
    cap = 8*1024**3 if build else 128*1024**2
    need(0 <= sample['bytes'] <= cap and 0 <= sample['files'] <= 10000 and 0 <= sample['depth'] <= 16, 'output threshold')
    need(0 <= sample['rss'] <= 4*1024**3, 'sampled RSS threshold')


def anchors_for(a, inputs):
    result = {k: a[k] for k in ('engine', 'engine_tree', 'robust', 'archive_sha256',
              'compiler_sha256', 'runtime_sha256', 'installed_manifest_sha256', 'profile_sha256')}
    result.update({'source:'+p:sha(raw) for p,raw in inputs.items()})
    result.update({'build:'+k:v for k,v in a['build_contract'].items()})
    return result


def orchestrate(a, inputs, startup, backend, clock=time.monotonic, *, utc=time.time, admission_sha256=None):
    """Backend owns side effects and retained receipt. No ambient/default backend.

    setup and compile/run must call guard(sample) during their operation, honor
    the supplied absolute monotonic deadline and return after descendants exit.
    cleanup receives only this packet's ownership token; failures are fatal.
    """
    # Start the shared budget at entry, before validation/source verification.
    entered = clock()
    entered_utc = utc()
    admission_check(a)
    budget = Budget(clock, utc, a['expires_utc'], entered=entered, entered_utc=entered_utc)
    need(sha(json.dumps(a, sort_keys=True, separators=(',', ':')).encode()) == admission_sha256,
         'frozen admission digest differs')
    verify_inputs(inputs)
    need(sha(startup) == a['startup_sha256'], 'startup digest drift')
    budget.check(budget.work_end)
    # Independent in-memory anchors. Never trust a backend's mutable manifest.
    anchors = anchors_for(a, inputs)
    token = backend.reserve(a)  # one-use, before any external work
    primary = None
    secondary = []
    results = []
    try:
        deadline = budget.limit(1500)
        guard_calls = 0
        last_sample = None
        monitor_epoch = None
        def guard(sample):
            nonlocal guard_calls, last_sample, monitor_epoch
            guard_calls += 1
            budget.check(deadline)
            now = clock()
            if sample.get('monitor_epoch') != monitor_epoch:
                last_sample = None
                monitor_epoch = sample.get('monitor_epoch')
            if last_sample is not None:
                interval = a['resource_envelope']['sample_interval_seconds']
                need(interval*0.5 <= now-last_sample <= interval*1.5, 'monitor cadence gap/burst')
            last_sample = now
            observe(sample, a, build=True)
        boundary_calls = 0
        boundary_kinds = []
        def boundary(kind, seals):
            nonlocal boundary_calls
            budget.check(deadline)
            need(kind in ('copy', 'launch', 'final'), 'unknown external boundary')
            expected = anchors if kind != 'copy' else {k:anchors[k] for k in seals if k in anchors}
            need(bool(seals) and seals == expected, 'independent setup seals differ')
            boundary_calls += 1
            boundary_kinds.append(kind)
        receipt = backend.setup(a, token, deadline, guard, boundary)
        budget.check(deadline)
        need(guard_calls > 0, 'setup did not monitor')
        if a.get('setup_mode') == 'sealed-first-build':
            need(receipt.get('prepared_install') is True and 'copy' in boundary_kinds and 'final' in boundary_kinds, 'sealed install skipped boundaries')
        else:
            need('launch' in boundary_kinds and 'final' in boundary_kinds, 'setup skipped independent boundary seals')
        need(receipt.get('exited') is True and receipt.get('descendants_empty') is True, 'setup processes still alive')
        for key in ('engine', 'engine_tree', 'robust', 'archive_sha256', 'compiler_sha256', 'runtime_sha256', 'installed_manifest_sha256', 'profile_sha256'):
            need(receipt.get(key) == a[key], 'provenance mismatch '+key)
        suite_end = budget.limit(720)
        for case in CASES:
            files = stage(inputs, case, startup)
            expected_seals = dict(anchors)
            expected_seals.update({'stage:'+p:sha(raw) for p,raw in files.items()})
            for phase, seconds in (('compile', 60), ('runtime', 90)):
                deadline = min(suite_end, budget.limit(seconds))
                guard_calls = 0
                boundary_calls = 0
                boundary_kinds = []
                last_sample = None
                def guard(sample):
                    nonlocal guard_calls, last_sample
                    guard_calls += 1
                    budget.check(deadline)
                    now = clock()
                    if last_sample is not None:
                        interval = a['resource_envelope']['sample_interval_seconds']
                        need(interval*0.5 <= now-last_sample <= interval*1.5, 'monitor cadence gap/burst')
                    last_sample = now
                    observe(sample, a)
                    if phase == 'runtime':
                        if sample.get('startup_pending') is True:
                            need(sample.get('effective_cvars') is None, 'ambiguous pending configuration')
                        else:
                            need(sample.get('effective_cvars') == CVARS, 'effective startup configuration differs')
                def boundary(kind, seals):
                    nonlocal boundary_calls
                    budget.check(deadline)
                    need(kind in ('copy', 'launch', 'final'), 'unknown external boundary')
                    expected = expected_seals if kind != 'copy' else {k:expected_seals[k] for k in seals if k in expected_seals}
                    need(bool(seals) and seals == expected, 'independent stage seals differ')
                    boundary_calls += 1
                    boundary_kinds.append(kind)
                if phase == 'runtime':
                    need(backend.vacant(token, 19567) is True, 'loopback port not vacant')
                report = backend.step(phase, case, files, token, deadline, guard, boundary)
                budget.check(deadline)
                need(guard_calls > 0, 'stage did not monitor')
                need('launch' in boundary_kinds and 'final' in boundary_kinds, 'stage skipped launch/final seals')
                if phase == 'compile':
                    artifacts = backend.artifacts(token, case)
                    need(isinstance(artifacts, dict) and 'probe.json' in artifacts and all(isinstance(v, bytes) for v in artifacts.values()), 'missing compiled closure')
                    expected_seals.update({'artifact:'+p:sha(raw) for p,raw in artifacts.items()})
                boundary('final', backend.seals(token, case))
                need(report.get('exited') is True and report.get('descendants_empty') is True, 'owned processes still alive')
                need(report.get('observations', 0) > 0, 'missing monitoring')
                need(report.get('exit') == 0, 'stage exit failure')
                need(not DIAGNOSTIC.search('\n'.join(report['streams'])), 'stage diagnostics')
                if phase == 'runtime':
                    need(report.get('startup_verified') is True, 'startup readback incomplete')
                    results.append(oracle(case, report['exit'], report['result'], report['streams']))
        budget.check(budget.work_end)
        need(backend.final_seals(token) == anchors, 'final independent seals differ')
    except BaseException as error:
        primary = error
    finally:
        # Cleanup reserve is part of the entry-anchored total 40 minutes.
        cleanup_end = min(budget.end, clock()+30)
        try:
            clean = backend.cleanup(token, cleanup_end)
            need(clock() <= cleanup_end and clean is True, 'owned cleanup failed')
        except BaseException as error:
            secondary.append(str(error)[:512])
        record = {'status':'FAIL' if primary or secondary else 'PASS',
                  'primary':str(primary)[:1024] if primary else None,
                  'secondary':secondary[:4], 'completed_cases':len(results)}
        try:
            backend.retain(token, record)
        except BaseException as error:
            secondary.append('receipt retention: '+str(error)[:400])
    if primary:
        if secondary:
            raise Rejected(str(primary)[:1024]+'; cleanup/receipt: '+'; '.join(secondary[:4])) from primary
        raise primary
    need(not secondary, '; '.join(secondary[:4]))
    return results


if __name__ == '__main__':
    print(json.dumps({'enabled': False, 'allocated': False, 'cases': CASES,
                      'game': GAME, 'engine': ENGINE,
                      'status': 'SOURCE_ONLY_PROPOSAL_NO_PROCESS_BACKEND'}, indent=2))

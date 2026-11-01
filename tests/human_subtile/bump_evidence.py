"""Independent host validation of the exact paired bump fixture archive."""
import hashlib
import importlib.util
import io
import json
from pathlib import Path, PurePosixPath
import re
import subprocess
import sys
import tarfile

HERE = Path(__file__).resolve().parent


def require(value, message):
    if not value:
        raise ValueError(message)


def modules():
    names = ('build_guard', 'source_binding', 'stage_observer', 'stage_bundle',
             'materialize_pair', 'receipt', 'runner_limits')
    result = {}
    for name in names:
        require(name not in sys.modules, 'Unexpected preloaded bump module: ' + name)
        spec = importlib.util.spec_from_file_location(name, HERE / (name + '.py'))
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        sys.modules[name] = module
        result[name] = module
    return result


def source(git, env, head, path, binding, deadline):
    return subprocess.check_output(git + ['show', head + ':' + path], env=env,
                                   timeout=binding.budget_timeout(10, deadline))


def metadata(raw):
    return {'bytes': len(raw), 'sha256': hashlib.sha256(raw).hexdigest()}


def valid_artifact(value, mode):
    return (isinstance(value, dict) and type(value.get('bytes')) is int and 0 < value['bytes'] <= 1024**3 and
            re.fullmatch('[0-9a-f]{64}', value.get('sha256') or '') is not None and value.get('mode') == mode)


def validate(data, head, suite, git, env, loaded=None, compile_validator=None, deadline=None):
    m = loaded if loaded is not None else modules()
    source_binding, stage, oracle, limits = (m[x] for x in ('source_binding', 'stage_bundle', 'receipt', 'runner_limits'))
    require(suite == limits.SUITE, 'bump suite')
    source_binding.budget_timeout(1, deadline)
    tree = source_binding.validate_head(git, head, env, deadline)
    inputs = source_binding.read_inputs(git, source_binding.BASE, env=env, deadline=deadline)
    guard = source(git, env, head, 'tests/human_subtile/bump_guard_preimage.dm', source_binding, deadline)
    observer = source(git, env, head, stage.OBSERVER, source_binding, deadline)
    scenario = source(git, env, head, stage.SCENARIO, source_binding, deadline)
    expected = {label: stage.reconstruct(inputs, guard, observer, scenario, label == 'candidate')
                for label in ('baseline', 'candidate')}
    allowed = {'harness-status.json', 'smoke-summary.json'}
    allowed.update(f'{prefix}/{name}' for prefix in ('npc-parent', 'npc-smoke')
                   for name in ('cloud-manifest.json', 'stage/compile-stdout.log', 'stage/compile-stderr.log'))
    allowed.update(f'{prefix}/runtime/{name}' for prefix in ('npc-parent', 'npc-smoke')
                   for name in ('receipt.json', 'result.txt', 'port-closed.txt', 'runtime.log',
                                'daemon-stdout.log', 'daemon-stderr.log'))
    allowed.update(f'abi/abi-{i}-{part}.log' for i in range(6) for part in ('stdout', 'stderr'))
    require(len(allowed) == 32, 'unexpected archive policy')
    with tarfile.open(fileobj=io.BytesIO(data), mode='r:') as archive:
        source_binding.budget_timeout(1, deadline)
        entries = archive.getmembers()
        names = [item.name for item in entries]
        require(len(names) == len(set(names)) == len(allowed) and set(names) == allowed and
                sum(item.size for item in entries) <= 16*1024**2 and
                all(item.isfile() and item.size <= 4*1024**2 and not PurePosixPath(item.name).is_absolute() and
                    '..' not in PurePosixPath(item.name).parts for item in entries), 'incomplete or unsafe bump archive')

        def read(name):
            return archive.extractfile(name).read()

        status = json.loads(read('harness-status.json'))
        summary = json.loads(read('smoke-summary.json'))
        require(status.get('head') == head and status.get('suite') == suite and status.get('phase') == 'complete' and
                status.get('outcome') == 'passed' and status.get('fixture_dme_only') is True and
                status.get('resource_copies_independent') is True and summary.get('head') == head and
                summary.get('tree') == tree and summary.get('base') == source_binding.BASE and summary.get('suite') == suite and
                summary.get('fixture_dme_only') is True and summary.get('observation_complete') is True and
                summary.get('parity_established') is False and summary.get('scope') == oracle.SCOPE and
                summary.get('tick') == 0.5 and summary.get('cases') == list(oracle.CASES) and
                summary.get('limits') == {'compile_seconds': 90, 'daemon_seconds': 60, 'setup_seconds': 60,
                                          'work_seconds': 490, 'whole_seconds': 600}, 'summary identity')
        states = summary.get('resource_states')
        artifacts = summary.get('artifacts')
        require(isinstance(states, dict) and set(states) == {'baseline', 'candidate'} and
                status.get('runtime_resources') == states and isinstance(artifacts, dict) and
                set(artifacts) == {'baseline', 'candidate'}, 'resource identities')
        limits.validate_accounting(summary.get('phases'), summary.get('comparison_elapsed'), summary.get('setup_seconds'))
        phases = summary['phases']
        for i, prefix in ((0, 'npc-parent'), (2, 'npc-smoke')):
            require(phases[i].get('command') == ['/opt/byond/bin/DreamMaker', '-max_errors', '0',
                    '/work/' + prefix + '/stage/human_subtile.dme'] and
                    phases[i + 1].get('command') == ['/opt/byond/bin/DreamDaemon',
                    '/work/' + prefix + '/runtime/human_subtile.dmb', '59474', '-ip', '127.0.0.1',
                    '-trusted', '-params', 'tested_commit=' + head, '-log', 'runtime.log'],
                    'unexpected process command')
        receipts = {}
        if compile_validator is None:
            spec = importlib.util.spec_from_file_location('bump_npc_fixture', HERE / 'run-npc.py')
            npc = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(npc)
            compile_validator = npc.current.legacy.validate_compile
        for label, prefix in (('baseline', 'npc-parent'), ('candidate', 'npc-smoke')):
            source_binding.budget_timeout(1, deadline)
            offset = 0 if label == 'baseline' else 2
            compile_phase = {key: value for key, value in phases[offset].items() if key != 'name'}
            daemon_phase = {key: value for key, value in phases[offset + 1].items() if key != 'name'}
            require(summary.get('compiles', {}).get(label) == compile_phase and
                    summary.get('results', {}).get(label, {}).get('daemon') == daemon_phase, 'phase receipt identity')
            manifest = json.loads(read(prefix + '/cloud-manifest.json'))
            require(manifest.get('head') == head and manifest.get('bump_variant') == label and
                    manifest.get('bump_base') == source_binding.BASE and manifest.get('bump_base_tree') == source_binding.TREE and
                    manifest.get('bump_experiment_tree') == tree, 'manifest identity')
            for path, raw in expected[label].items():
                require(manifest.get('stage_files', {}).get(path) == metadata(raw), 'fixture reconstruction: ' + path)
            require(isinstance(artifacts[label], dict) and set(artifacts[label]) == {'human_subtile.dmb', 'human_subtile.rsc'} and
                    valid_artifact(artifacts[label]['human_subtile.dmb'], 0o444), 'compiled binary identity')
            initial = artifacts[label]['human_subtile.rsc']
            state = states[label]
            require(valid_artifact(initial, 0o600) and isinstance(state, dict) and valid_artifact(state.get('before'), 0o600) and
                    valid_artifact(state.get('after'), 0o600) and state['before'] == initial and
                    type(state.get('changed')) is bool and state['changed'] == (state['before'] != state['after']) and
                    state.get('integrity_verified') is True and 'daemon_error' not in state and
                    'integrity_error' not in state, 'resource state: ' + label)
            require(read(prefix + '/runtime/port-closed.txt') == b'closed\n' and
                    read(prefix + '/runtime/result.txt') == b'PASS\n', 'runtime markers')
            compile_log = (read(prefix + '/stage/compile-stdout.log') + read(prefix + '/stage/compile-stderr.log')).decode(errors='replace')
            compile_validator(compile_log, 'human_subtile.dmb')
            raw = read(prefix + '/runtime/receipt.json')
            require(summary.get('results', {}).get(label, {}).get('receipt_sha256') == hashlib.sha256(raw).hexdigest(),
                    'runtime receipt hash')
            receipts[label] = json.loads(raw)
            oracle.validate_receipt(receipts[label], head, label == 'candidate')
        oracle.validate_pair(receipts['baseline']['bump_rows'], receipts['candidate']['bump_rows'])
        source_binding.budget_timeout(1, deadline)
    return True

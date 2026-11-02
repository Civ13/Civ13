"""Two-daemon callback-order measurement under the existing bounded controller."""
import json
import os
import sys
import time


def modules(shared):
    names = ('pair_stage', 'pair_binding', 'pair_receipt', 'pair_materialize', 'runner_limits')
    loaded = {}
    for name in names:
        shared.require(name not in sys.modules, 'Unexpected preloaded pair module: ' + name)
        module = shared.load_module(name, shared.HERE / (name + '.py'))
        sys.modules[name] = module
        loaded[name] = module
    return loaded


def run(shared, args, scratch, binary, archive, group, envelope, identity, abi, began, npc, runtime, legacy):
    m = modules(shared)
    limits, binding, stage, oracle = (m[x] for x in
                                     ('runner_limits', 'pair_binding', 'pair_materialize', 'pair_receipt'))
    shared.require(args.suite == 'pair05', 'Unexpected pair suite')
    limits.admission('bump05', time.monotonic(), args.work_deadline)
    git = ['git', '-c', 'core.fsmonitor=false', '-c', 'core.hooksPath=/dev/null', '-C', str(shared.ROOT)]
    tree = binding.validate_head(git, args.head)
    inputs = binding.read_inputs(git)
    limits.admission('bump05', time.monotonic(), args.work_deadline)
    fixture = (shared.HERE / 'pair_measure.dm').read_bytes()
    started = time.monotonic()
    child_elapsed = 0.0
    phases = []

    def check_setup():
        used = time.monotonic() - started - child_elapsed
        shared.require(0 <= used <= limits.SETUP_SECONDS, 'Pair setup allowance exceeded')
        return used

    shared.checkpoint('pair-staging', suite=args.suite, fixture_dme_only=True)
    out = scratch / 'npc-smoke'
    manifest = npc.prepare(out)
    shared.require(manifest['head'] == args.head, 'Pair staged head mismatch')
    parent, parent_manifest = stage.prepare_pair(out, manifest, inputs, fixture)
    variants = (('baseline', 'legacy', parent, parent_manifest),
                ('candidate', 'pair_first', out, manifest))
    for label, mode, folder, data in variants:
        data['pair_base'] = m['pair_stage'].BASE
        data['pair_base_tree'] = m['pair_stage'].BASE_TREE
        data['pair_experiment_tree'] = tree
        (folder / 'cloud-manifest.json').write_text(json.dumps(data, indent=2) + '\n')

    def check_inputs():
        for label, mode, folder, data in variants:
            for rel, expected in data['stage_files'].items():
                path = folder / 'stage' / rel
                shared.require(path.is_file() and not path.is_symlink() and path.stat().st_size == expected['bytes'] and
                               shared.file_hash(path) == expected['sha256'], 'Pair fixture input changed: ' + label + '/' + rel)

    builds, artifacts_by_variant, states, receipts, results = {}, {}, {}, {}, {}
    for label, mode, folder, data in variants:
        check_inputs()
        limits.remaining(len(phases), check_setup(), time.monotonic(), args.work_deadline)
        stage_path, dme = folder / 'stage', folder / data['dme']
        shared.checkpoint('pair-' + label + '-compile')
        runtime.verify_linux(binary, archive)
        build = shared.run_owned_phase(legacy, group, [str(binary / 'DreamMaker'), '-max_errors', '0', str(dme)],
                                       stage_path, 'compile', limits.COMPILE_SECONDS)
        shared.require(limits.finite(build.get('seconds')) and 0 <= build['seconds'] <= limits.COMPILE_SECONDS,
                       'Pair compile duration')
        child_elapsed += build['seconds']
        log = ''.join((stage_path / ('compile-' + part + '.log')).read_text(errors='replace')
                      for part in ('stdout', 'stderr'))
        legacy.validate_compile(log, dme.with_suffix('.dmb').name)
        builds[label] = build
        phases.append(dict(build, name=label + '_compile'))
        check_inputs(); check_setup()
        work, dmb, artifacts = shared.prepare_linked_runtime(folder, stage_path, dme, 'runtime')
        peer, peer_dmb, peer_artifacts = shared.prepare_linked_runtime(folder, stage_path, dme, 'runtime-wildlife')
        resource = dme.with_suffix('.rsc').name
        shared.require(artifacts == peer_artifacts and not os.path.samefile(dmb.with_suffix('.rsc'), peer_dmb.with_suffix('.rsc')),
                       'Pair runtime resources are not independent')
        artifacts_by_variant[label] = artifacts
        shared.checkpoint('pair-' + label + '-runtime-staged', resource_copies_independent=True)
        limits.remaining(len(phases), check_setup(), time.monotonic(), args.work_deadline)
        shared.require(not any(work.rglob('*.sav')), 'Pair daemon must start without saves')
        runtime.verify_linux(binary, archive)
        params = 'tested_commit=' + args.head + ';pair_mode=' + mode
        result = shared.run_checked_runtime(legacy, group,
            [str(binary / 'DreamDaemon'), str(dmb), '59474', '-ip', '127.0.0.1', '-trusted',
             '-params', params, '-log', 'runtime.log'],
            work, dme, peer, artifacts, dict(artifacts[resource]), label, states, timeout=limits.DAEMON_SECONDS)
        shared.require(limits.finite(result.get('seconds')) and 0 <= result['seconds'] <= limits.DAEMON_SECONDS,
                       'Pair daemon duration')
        child_elapsed += result['seconds']
        phases.append(dict(result, name=label + '_daemon'))
        legacy.inspect_logs(work)
        shared.require((work / 'port-closed.txt').read_bytes() == b'closed\n' and
                       (work / 'result.txt').read_bytes() == b'PASS\n', 'Pair fixture failed: ' + label)
        path = work / 'receipt.json'
        shared.require(path.stat().st_size <= 4 * 1024**2, 'Pair receipt byte bound')
        receipts[label] = json.loads(path.read_text())
        oracle.receipt(receipts[label], args.head, mode)
        results[label] = {'daemon': result, 'receipt_sha256': shared.file_hash(path)}
        check_inputs(); check_setup()
    comparison = oracle.compare(receipts['baseline']['pair_rows'], receipts['candidate']['pair_rows'])
    elapsed = time.monotonic() - started
    setup = elapsed - child_elapsed
    limits.validate_accounting(phases, elapsed, setup)
    summary = dict(head=args.head, tree=tree, base=m['pair_stage'].BASE, suite=args.suite,
        fixture_dme_only=True, observation_complete=True, parity_established=False,
        scope=oracle.SCOPE, tick=0.5, modes=['legacy', 'pair_first'], cases=list(oracle.CASES),
        comparison=comparison, compiles=builds, artifacts=artifacts_by_variant,
        resource_states=states, results=results, phases=phases,
        identity=identity, abi=abi, envelope=envelope,
        limits={'compile_seconds': limits.COMPILE_SECONDS, 'daemon_seconds': limits.DAEMON_SECONDS,
                'setup_seconds': limits.SETUP_SECONDS, 'work_seconds': limits.WORK_SECONDS,
                'whole_seconds': limits.OUTER_SECONDS},
        setup_seconds=setup, comparison_elapsed=elapsed, child_elapsed=child_elapsed,
        seconds=time.monotonic()-began)
    (scratch / 'smoke-summary.json').write_text(json.dumps(summary, indent=2) + '\n')
    shared.checkpoint('complete', outcome='passed', fixture_dme_only=True, suite=args.suite)

"""Exact-Git 516.1688 crawl fixture using the unchanged containment policy.

Preparation is offline. Compile-only launches no world. Local native runtime
remains held unless the existing no-socket profile is separately applicable.
Hosted Linux retains the existing bounded process-group profile, port closure,
client/Topic denial and diagnostic checks. No connected-client visual claim.
"""
import argparse
import importlib.util
import json
import os
from pathlib import Path

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('diagonal_runner', HERE / 'run-diagonal.py')
diagonal = importlib.util.module_from_spec(spec)
spec.loader.exec_module(diagonal)
legacy = diagonal.legacy
require = diagonal.require


def prepare(out, control='none'):
    manifest = legacy.prepare(diagonal.ROOT, out, 'human')
    manifest['target_engine'] = '516.1688'
    manifest['crawl_control'] = control
    diagonal.adapt(out, manifest, 'tests/human_subtile/probe.dm',
                   '\t\t\thuman_subtile_fixture_headless()',
                   '\t\t\thuman_subtile_fixture_headless()\n\t\t\thuman_subtile_fixture_crawl()')
    diagonal.adapt(out, manifest, 'tests/human_subtile/probe.dm',
                   '"checks" = human_subtile_fixture_checks,',
                   '"checks" = human_subtile_fixture_checks, "crawl_checks" = human_subtile_crawl_checks,')
    with (out / manifest['dme']).open('a', encoding='utf-8') as stream:
        stream.write('\n#include "tests\\human_subtile\\crawl.dm"\n')
    module = 'code/game/mob/living/carbon/human/subtile_movement.dm'
    if control == 'late-start':
        diagonal.adapt(out, manifest, module,
                       'due = start_time + i * duration / pulse_count',
                       'due = start_time + duration')
    if control == 'lost-lock':
        diagonal.adapt(out, manifest, module, 'while (world.time < end_time)',
                       'while (FALSE)')
    (out / 'crawl-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    return manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--byond-bin', type=Path)
    parser.add_argument('--prepare-only', action='store_true')
    parser.add_argument('--compile-only', action='store_true')
    parser.add_argument('--control', choices=('none', 'late-start', 'lost-lock'), default='none')
    args = parser.parse_args()
    require(args.prepare_only or args.byond_bin, 'Select --prepare-only or --byond-bin')
    out = args.output.resolve()
    manifest = prepare(out, args.control)
    if args.prepare_only:
        print('Prepared exact Git ' + manifest['head'] + '; no native execution')
        return
    byond = args.byond_bin.resolve()
    session = diagonal.Session(out / 'supervisor', manifest['head'], backend_factory=diagonal.current_backend) if os.name == 'nt' else None
    dme = out / manifest['dme']
    build = diagonal.run_phase(session, [str(byond / ('dm.exe' if os.name == 'nt' else 'DreamMaker')),
                                       '-max_errors', '0', str(dme)], cwd=out / 'stage',
                               phase='compile', timeout=120,
                               artifacts=[dme.with_suffix('.dmb'), dme.with_suffix('.rsc')])
    log = build.stdout + build.stderr
    (out / 'compile.log').write_text(log)
    require(build.returncode == 0, 'Current-engine compile failed')
    legacy.validate_compile(log, dme.with_suffix('.dmb').name)
    if args.compile_only:
        (out / 'compile-accepted.json').write_text(json.dumps(dict(head=manifest['head'], engine='516.1688',
            compile_passed=True, runtime_executed=False, control=args.control)) + '\n')
        print('PASS current-engine compile; no world launched: ' + manifest['head'])
        return
    work, binary, artifacts = legacy.prepare_runtime(out, manifest)
    result = diagonal.run_phase(session,
        [str(byond / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')), str(binary),
         *(['-invisible', '-close'] if os.name == 'nt' else ['59474']),
         *diagonal.no_port_args(), '-trusted', '-params', 'tested_commit=' + manifest['head'], '-log', 'runtime.log'],
        cwd=work, phase='crawl', timeout=90, state_directory=work)
    diagnostics = result.stdout + result.stderr
    if (work / 'runtime.log').exists():
        diagnostics += diagonal.read_bounded(work / 'runtime.log')
    (out / 'crawl-runtime.log').write_text(diagnostics)
    receipt = json.loads(diagonal.read_bounded(work / 'receipt.json'))
    (out / 'crawl-receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
    require(result.returncode == 0 and not legacy.DIAGNOSTICS.search(diagnostics), 'Native diagnostic/exit failure')
    require(receipt['head'] == manifest['head'] and receipt['port'] == 0 and (receipt['byond_version'], receipt['byond_build']) == (516, 1688), 'Wrong source/engine/port')
    ending = '\r\n' if os.name == 'nt' else '\n'
    require((work / 'port-closed.txt').read_bytes() == ('closed' + ending).encode(), 'No closed-port witness')
    expected = {'none': (None, 194), 'late-start': ('crawl_progress_during_wait_final_arrival_paid', 4),
                'lost-lock': ('crawl_cancel_retains_deadline_cleans_visuals', 150)}[args.control]
    require((receipt['error'], receipt['crawl_checks']) == expected and receipt['checks'] == 42,
            'Unexpected/incomplete native assertion: ' + str((receipt['error'], receipt['crawl_checks'], receipt['checks'])))
    require((work / 'result.txt').read_bytes() == (('FAIL ' + expected[0] if expected[0] else 'PASS') + ending).encode(), 'Wrong result marker')
    (out / 'accepted.json').write_text(json.dumps(dict(head=manifest['head'], engine='516.1688', control=args.control,
        accepted=True, artifacts=artifacts, checks=receipt['crawl_checks'], expected_error=expected[0],
        scope='full-source native fixture, explicit headless authority; no rendering/client acceptance'), indent=2) + '\n')
    print('PASS crawl/control: ' + manifest['head'])


if __name__ == '__main__':
    main()

"""Exact-Git 516.1688 diagonal/default fixture; bounded serial native phases.

Preserves the historical 1681 runner and its oracle. Explicitly records the
current-engine fixture migration and added diagonal entry as staging adapters.
Windows uses the unchanged native_fixture owned-Job and socket policy.
"""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts'))
from native_fixture import Session, WindowsBackend, no_port_args, read_bounded, run_native

spec = importlib.util.spec_from_file_location('historical_subtile', Path(__file__).with_name('run.py'))
legacy = importlib.util.module_from_spec(spec)
spec.loader.exec_module(legacy)


def require(ok, message):
    if not ok:
        raise RuntimeError(message)


def current_backend():
    # Separate current-engine allowlist; historical adapters remain unchanged.
    directory = Path(__file__).with_name('native_1688').resolve()
    sys.path.insert(0, str(directory))
    try:
        import windows
        import guard_config
        import owned_job
    finally:
        sys.path.pop(0)
    for module in (windows, guard_config, owned_job):
        require(Path(module.__file__).resolve() == directory / (module.__name__ + '.py'), 'Wrong current-engine native helper')
    for name in ('windows.py', 'owned_job.py'):
        require((directory / name).read_bytes() == (ROOT / 'tests/floor_decal_tracking' / name).read_bytes(), 'Containment adapter drift')
    return WindowsBackend(adapter=windows.Adapter(), windows=windows, owned=owned_job)


def adapt(out, manifest, relative, old, new):
    path = out / 'stage' / relative
    source = path.read_text(encoding='utf-8')
    require(source.count(old) == 1, 'Adapter anchor drift: ' + relative)
    path.write_text(source.replace(old, new), encoding='utf-8', newline='\n')
    manifest.setdefault('diagonal_adaptations', {})[relative] = hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--byond-bin', type=Path)
    parser.add_argument('--prepare-only', action='store_true')
    parser.add_argument('--control', choices=('none', 'legacy-split', 'cardinal-arithmetic'), default='none')
    args = parser.parse_args()
    require(args.prepare_only or args.byond_bin, 'Select --prepare-only or --byond-bin')
    out = args.output.resolve()
    manifest = legacy.prepare(ROOT, out, 'human')
    manifest['target_engine'] = '516.1688'
    manifest['diagonal_control'] = args.control
    adapt(out, manifest, 'tests/human_subtile/probe.dm',
          'world.byond_build == 1681', 'world.byond_build == 1688')
    adapt(out, manifest, 'tests/human_subtile/probe.dm',
          '\t\t\thuman_subtile_fixture_headless()',
          '\t\t\thuman_subtile_fixture_headless()\n\t\t\thuman_subtile_fixture_diagonal()')
    adapt(out, manifest, 'tests/human_subtile/probe.dm',
          '"checks" = human_subtile_fixture_checks,',
          '"checks" = human_subtile_fixture_checks, "diagonal_checks" = human_subtile_diagonal_checks,')
    dme = out / manifest['dme']
    with dme.open('a', encoding='utf-8') as stream:
        stream.write('\n#include "tests\\human_subtile\\diagonal.dm"\n')
    if args.control == 'legacy-split':
        adapt(out, manifest, 'code/game/mob/mob_movement.dm',
              'if (!subtile_pulse && (direct & (direct - 1)))', 'if (direct & (direct - 1))')
    if args.control == 'cardinal-arithmetic':
        adapt(out, manifest, 'code/game/mob/living/carbon/human/subtile_movement.dm',
              '(direction & EAST) ? 2 : (direction & WEST) ? -2 : 0',
              'direction == EAST ? 2 : direction == WEST ? -2 : 0')
    (out / 'diagonal-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    if args.prepare_only:
        print('Prepared exact Git ' + manifest['head'] + '; no native execution')
        return
    byond = args.byond_bin.resolve()
    session = Session(out / 'supervisor', manifest['head'], backend_factory=current_backend) if os.name == 'nt' else None
    build = run_native(session, [str(byond / ('dm.exe' if os.name == 'nt' else 'DreamMaker')),
                                 '-max_errors', '0', str(dme)], cwd=out / 'stage',
                       phase='compile', timeout=120, artifacts=[dme.with_suffix('.dmb'), dme.with_suffix('.rsc')])
    log = build.stdout + build.stderr
    (out / 'compile.log').write_text(log)
    require(build.returncode == 0 and log.count('DM compiler version 516.1688') == 1 and
            re.search(r'human_subtile.dmb - 0 errors, 0 warnings', log) and not legacy.DIAGNOSTICS.search(log),
            'Current-engine clean compile failed')
    work, binary, artifacts = legacy.prepare_runtime(out, manifest)
    rows = []
    for suite in (('diagonal',) if args.control != 'none' else ('diagonal', 'mining')):
        for filename in ('receipt.json', 'result.txt', 'port-closed.txt', 'runtime.log'):
            (work / filename).unlink(missing_ok=True)
        params = 'tested_commit=' + manifest['head']
        if suite == 'mining':
            params += ';mining_integration=1'
        result = run_native(session, [str(byond / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')),
                                     str(binary), *(['-invisible', '-close'] if os.name == 'nt' else []),
                                     *no_port_args(), '-trusted', '-params', params, '-log', 'runtime.log'],
                            cwd=work, phase=suite, timeout=90, state_directory=work)
        diagnostics = result.stdout + result.stderr
        if (work / 'runtime.log').exists():
            diagnostics += read_bounded(work / 'runtime.log')
        (out / (suite + '-runtime.log')).write_text(diagnostics)
        receipt = json.loads(read_bounded(work / 'receipt.json'))
        (out / (suite + '-receipt.json')).write_text(json.dumps(receipt, indent=2) + '\n')
        require(result.returncode == 0 and not legacy.DIAGNOSTICS.search(diagnostics), 'Native runtime diagnostic/exit failure')
        require(receipt['head'] == manifest['head'] and (receipt['byond_version'], receipt['byond_build']) == (516, 1688), 'Wrong native source/engine')
        require((work / 'port-closed.txt').read_bytes() == (b'closed\r\n' if os.name == 'nt' else b'closed\n'), 'No closed-port witness')
        expected_error = 'diagonal_32px_per_axis' if args.control != 'none' else None
        require(receipt['error'] == expected_error, 'Unexpected native assertion: ' + str(receipt['error']))
        expected_result = ('FAIL ' + expected_error if expected_error else 'PASS') + ('\r\n' if os.name == 'nt' else '\n')
        require((work / 'result.txt').read_bytes() == expected_result.encode(), 'Wrong native result marker')
        if suite == 'diagonal':
            require(receipt['checks'] == 42, 'Incomplete existing human regression checks')
            require(receipt['diagonal_checks'] == (4 if expected_error else 97), 'Incomplete diagonal checks')
        else:
            require(receipt['mining_checks'] == 52, 'Incomplete mining assertions')
            mining = receipt['mining_rows']
            require([(r['enabled'], r['sy']) for r in mining] == [(0, 0), (1, 0), (1, 4), (1, 28)], 'Missing mining cases')
            require(all(r['client'] == 0 and r['effects'] == 1 and r['bumps'] >= 3 for r in mining), 'Mining observations failed')
        rows.append(dict(suite=suite, checks=receipt['checks'], diagonal_checks=receipt['diagonal_checks'], mining_checks=receipt['mining_checks'], expected_error=expected_error))
    (out / 'accepted.json').write_text(json.dumps(dict(head=manifest['head'], engine='516.1688', control=args.control,
                                                     accepted=True, rows=rows, artifacts=artifacts,
                                                     scope='full-source native fixture; explicit headless authority; no client/rendering acceptance'), indent=2) + '\n')
    print(json.dumps(rows))


if __name__ == '__main__':
    main()

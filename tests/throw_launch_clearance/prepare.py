"""Prepare exact committed full-source throw probes; optional compile ONLY.

There is deliberately no daemon execution mode. Preserve the existing bounded
Windows compiler Session and current-engine allowlist without modification.
"""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('throw_current_runner', ROOT / 'tests/human_subtile/run-diagonal.py')
CURRENT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CURRENT)


def prepare(out):
    manifest = CURRENT.legacy.prepare(ROOT, out, 'human')
    # Keep the opt-in probe outside tests/human_subtile so source publication
    # does not implicitly select that directory's automatic native CI lane.
    relative = 'tests/throw_launch_clearance/throw_launch.dm'
    raw = CURRENT.legacy.git(ROOT, 'show', manifest['head'] + ':' + relative)
    fixture = out / 'stage' / relative
    fixture.parent.mkdir(parents=True, exist_ok=True)
    fixture.write_bytes(raw)
    manifest['launch_fixture_source'] = dict(path=relative, head=manifest['head'],
                                           sha256=hashlib.sha256(raw).hexdigest())
    CURRENT.adapt(out, manifest, 'tests/human_subtile/probe.dm',
                  '\t\t\thuman_subtile_fixture_headless()', '\t\t\tthrow_launch_fixture_run()')
    CURRENT.adapt(out, manifest, 'tests/human_subtile/probe.dm',
                  '"checks" = human_subtile_fixture_checks,',
                  '"checks" = human_subtile_fixture_checks, "launch_checks" = throw_launch_fixture_checks,')
    dme = out / manifest['dme']
    with dme.open('a', encoding='utf-8') as stream:
        stream.write('\n#include "tests\\throw_launch_clearance\\throw_launch.dm"\n')
    manifest['scope'] = '18x14x1 full-source throw launch probe; harmless human hitby adapter'
    manifest['native_executed'] = False
    manifest['target_engine'] = '516.1688'
    manifest['prepared_files'] = {
        p.relative_to(out / 'stage').as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
        for p in (out / 'stage').rglob('*') if p.is_file()}
    (out / 'launch-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    return manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True, type=Path)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--prepare-only', action='store_true')
    mode.add_argument('--compile-only', action='store_true')
    parser.add_argument('--byond-bin', type=Path)
    args = parser.parse_args()
    if args.compile_only and not args.byond_bin:
        parser.error('--compile-only requires --byond-bin')
    out = args.output.resolve()
    manifest = prepare(out)
    if args.prepare_only:
        print('Prepared only ' + manifest['head'] + '; no compiler or daemon launched')
        return
    dme = out / manifest['dme']
    byond = args.byond_bin.resolve()
    session = CURRENT.Session(out / 'supervisor', manifest['head'], backend_factory=CURRENT.current_backend) if os.name == 'nt' else None
    result = CURRENT.run_phase(session,
        [str(byond / ('dm.exe' if os.name == 'nt' else 'DreamMaker')), '-max_errors', '0', str(dme)],
        cwd=out / 'stage', phase='compile', timeout=120,
        artifacts=[dme.with_suffix('.dmb'), dme.with_suffix('.rsc')])
    log = result.stdout + result.stderr
    (out / 'compile.log').write_text(log)
    if result.returncode:
        raise RuntimeError('Compiler failed; complete log retained')
    CURRENT.legacy.validate_compile(log, dme.with_suffix('.dmb').name)
    receipt = dict(head=manifest['head'], engine='516.1688', compile_passed=True,
                   runtime_executed=False, dmb_sha256=hashlib.sha256(dme.with_suffix('.dmb').read_bytes()).hexdigest())
    (out / 'compile-accepted.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps(receipt))


if __name__ == '__main__':
    main()

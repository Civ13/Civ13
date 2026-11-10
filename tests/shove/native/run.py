"""Exact-commit full-source shove probe; unchanged Windows owned-Job envelope.

Uses the existing human fixture startup seams and constructors, not a mock
movement implementation. No native client, live server, or production data.
"""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[3]
spec = importlib.util.spec_from_file_location('shove_native_base', ROOT / 'tests/human_subtile/run-diagonal.py')
base = importlib.util.module_from_spec(spec)
spec.loader.exec_module(base)
legacy = base.legacy


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--byond-bin', required=True, type=Path)
    parser.add_argument('--compile-only', action='store_true')
    args = parser.parse_args()
    out = args.output.resolve()
    manifest = legacy.prepare(ROOT, out, 'human')
    relative = 'tests/shove/native/probe.dm'
    raw = legacy.git(ROOT, 'show', manifest['head'] + ':' + relative)
    target = out / 'stage' / relative
    target.parent.mkdir(parents=True)
    target.write_bytes(raw)
    manifest['shove_probe_sha256'] = legacy.digest(raw)
    base.adapt(out, manifest, 'tests/human_subtile/probe.dm',
               '\t\t\thuman_subtile_fixture_headless()', '\t\t\tshove_fixture()')
    base.adapt(out, manifest, 'tests/human_subtile/probe.dm',
               '"checks" = human_subtile_fixture_checks,',
               '"checks" = human_subtile_fixture_checks, "shove_checks" = shove_fixture_checks,')
    dme = out / manifest['dme']
    with dme.open('a', encoding='utf-8') as stream:
        stream.write('\n#include "tests\\shove\\native\\probe.dm"\n')
    (out / 'shove-manifest.json').write_text(json.dumps(manifest, indent=2))
    byond = args.byond_bin.resolve()
    session = base.Session(out / 'supervisor', manifest['head'], backend_factory=base.current_backend) if os.name == 'nt' else None
    build = base.run_phase(session, [str(byond / ('dm.exe' if os.name == 'nt' else 'DreamMaker')),
                           '-max_errors', '0', str(dme)], cwd=out / 'stage', phase='compile', timeout=120,
                           artifacts=[dme.with_suffix('.dmb'), dme.with_suffix('.rsc')])
    log = build.stdout + build.stderr
    (out / 'compile.log').write_text(log)
    base.require(build.returncode == 0, 'Compile failed')
    legacy.validate_compile(log, dme.with_suffix('.dmb').name)
    if args.compile_only:
        print('Compile passed; native runtime not run: ' + manifest['head'])
        return
    work, binary, artifacts = legacy.prepare_runtime(out, manifest)
    result = base.run_phase(session, [str(byond / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')),
                            str(binary), *(['-invisible', '-close'] if os.name == 'nt' else ['59474']),
                            *base.no_port_args(), '-trusted', '-params', 'tested_commit=' + manifest['head'],
                            '-log', 'runtime.log'], cwd=work, phase='shove', timeout=90, state_directory=work)
    diagnostics = result.stdout + result.stderr
    if (work / 'runtime.log').exists():
        diagnostics += base.read_bounded(work / 'runtime.log')
    (out / 'runtime.log').write_text(diagnostics)
    receipt = json.loads(base.read_bounded(work / 'receipt.json'))
    (out / 'receipt.json').write_text(json.dumps(receipt, indent=2))
    base.require(result.returncode == 0 and not legacy.DIAGNOSTICS.search(diagnostics), 'Runtime diagnostic/exit failure')
    base.require(receipt['head'] == manifest['head'] and receipt['port'] == 0 and
                 (receipt['byond_version'], receipt['byond_build']) == (516, 1688), 'Wrong source/engine or open port')
    base.require(receipt['error'] is None and receipt['shove_checks'] == 46, 'Incomplete/failed shove assertions')
    base.require((work / 'result.txt').read_text().strip() == 'PASS', 'No PASS marker')
    base.require((work / 'port-closed.txt').read_text().strip() == 'closed', 'No closed-port witness')
    legacy.inspect_logs(work)
    (out / 'accepted.json').write_text(json.dumps({'head': manifest['head'], 'checks': receipt['shove_checks'],
        'artifacts': artifacts, 'scope': 'headless real-helper/pulse probe; no visual or live-server acceptance'}, indent=2))
    print('PASS 46 shove checks at ' + manifest['head'])


if __name__ == '__main__':
    main()

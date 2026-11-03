"""Production-DM keybinding/text-save fixture with an injected client boundary.

Windows uses the reviewed current-pin owned-Job/no-socket facade. Import and
--prepare-only launch no native process. No full-game startup or real client.
"""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
SOURCE = 'code/modules/client/action_keybindings.dm'
SAVE = 'code/modules/client/preferencesSQLite/preferences_saving&loading&del.dm'


def prepare(output, control=False):
    output.mkdir(parents=True, exist_ok=False)
    stage = output / 'stage'
    stage.mkdir()
    (stage / 'SQL').mkdir()
    source = (ROOT / SOURCE).read_text(encoding='utf-8')
    source = source.split('/client/verb/configure_action_keybindings()')[0]
    if control:
        old = 'if (key in used)'
        assert source.count(old) == 1
        source = source.replace(old, 'if (FALSE)')
    source = source.replace('/client/proc/', '/datum/keybinding_client/proc/')
    source = source.replace('winset(src,', 'record_winset(src,')
    save = (ROOT / SAVE).read_text(encoding='utf-8')
    (stage / 'production.dm').write_text(source + '\n' + save, encoding='utf-8')
    (stage / 'fixture.dm').write_bytes(Path(__file__).with_name('fixture.dm').read_bytes())
    (stage / 'probe.dme').write_text('#include "fixture.dm"\n#include "production.dm"\n')
    manifest = {'head': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
                'control': control, 'map': '1x1x1 synthetic', 'scope': 'production policy/save IO, injected client winset',
                'source_hashes': {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in (SOURCE, SAVE)},
                'input_hashes': {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in stage.iterdir() if p.is_file()}}
    (output / 'prepared.json').write_text(json.dumps(manifest, indent=2) + '\n')
    return stage, manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--byond-bin', type=Path)
    parser.add_argument('--prepare-only', action='store_true')
    parser.add_argument('--compile-only', action='store_true')
    parser.add_argument('--conflict-control', action='store_true')
    args = parser.parse_args()
    stage, manifest = prepare(args.output.resolve(), args.conflict_control)
    if args.prepare_only:
        return
    if not args.byond_bin:
        parser.error('--byond-bin is required for native execution')
    sys.path.insert(0, str(ROOT / 'scripts'))
    from native_fixture import Session, no_port_args, run_native
    session = None
    if os.name == 'nt':
        spec = importlib.util.spec_from_file_location('keybinding_native_facade', ROOT / 'tests/human_subtile/run-diagonal.py')
        facade = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(facade)
        session = Session(args.output / 'containment', manifest['head'], backend_factory=facade.current_backend)
    compiler = args.byond_bin / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
    daemon = args.byond_bin / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
    build = run_native(session, [str(compiler), 'probe.dme'], cwd=stage, phase='compile', timeout=30,
                       artifacts=[stage / 'probe.dmb', stage / 'probe.rsc'], state_directory=stage)
    output = build.stdout + build.stderr
    (args.output / 'compile.log').write_text(output)
    print(output)
    pin = json.loads((ROOT / 'tools/byond/version.json').read_text())['version']
    if build.returncode or f'DM compiler version {pin}' not in output or '0 errors, 0 warnings' not in output:
        raise RuntimeError('Pinned fixture compilation failed')
    if args.compile_only:
        return
    if os.name == 'nt':
        raise RuntimeError('Windows runtime held: the initial probe logged a startup listener and hub login before world/New. Use --prepare-only or --compile-only; a no-socket startup envelope is required before another launch.')
    runtime = run_native(session, [str(daemon), 'probe.dmb', '-trusted', '-invisible', '-close',
                                  *no_port_args(), '-log', 'runtime.log'], cwd=stage, phase='runtime', timeout=20,
                         artifacts=[stage / 'probe.dmb', stage / 'probe.rsc'], state_directory=stage)
    log = (stage / 'runtime.log').read_text(errors='replace')
    print(log)
    if re.search(r'World opened on network port|Logging in|Logged in as', log, re.I):
        raise RuntimeError('Fixture startup violated the no-network contract')
    expected = 'FAIL action keybindings: conflict rejected' if args.conflict_control else 'PASS action keybindings:'
    if runtime.returncode or expected not in log or (not args.conflict_control and re.search(r'FAIL|runtime error', log, re.I)):
        raise RuntimeError('Keybinding native fixture failed')


if __name__ == '__main__':
    main()

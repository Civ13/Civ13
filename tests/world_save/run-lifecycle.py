"""Exercise production local lifecycle authentication and native shutdown guards."""
import argparse
import importlib.util
import json
from pathlib import Path
import os
import re
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--byond-bin', type=Path)
    parser.add_argument('--prepare-only', action='store_true')
    parser.add_argument('--negative-control', choices=('authentication', 'shutdown-generation'))
    args = parser.parse_args()
    if not args.prepare_only and not args.byond_bin:
        parser.error('--byond-bin required for native execution')
    root = Path(__file__).resolve().parents[2]
    output = Path(tempfile.mkdtemp(prefix='civ13-lifecycle-'))
    spec = importlib.util.spec_from_file_location('transaction', Path(__file__).with_name('run-restart-transaction.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    receipt = module.prepare(root, output)
    base = (output / 'probe.dm').read_text(encoding='utf-8').split('/world/New()')[0]
    probe = (root / 'tests/world_save/lifecycle_probe.dm').read_text(encoding='utf-8')
    (output / 'probe.dm').write_text(base + probe, encoding='utf-8')
    endpoint = (root / 'code/modules/persistence/nomads_lifecycle.dm').read_text(encoding='utf-8')
    if args.negative_control == 'authentication':
        anchor = 'if(peer[1] != "127.0.0.1" || '
        if endpoint.count(anchor) != 1:
            raise RuntimeError('Authentication anchor changed')
        endpoint = endpoint.replace(anchor, 'if(FALSE && peer[1] != "127.0.0.1" || ', 1)
    (output / 'endpoint.dm').write_text(endpoint, encoding='utf-8')
    transaction = (output / 'transaction.dm').read_text(encoding='utf-8')
    if args.negative_control == 'shutdown-generation':
        anchor = 'if(!matches(I, read_intent()) || trim(file2text("map_saves/save_complete.txt")) != expected_generation)'
        if transaction.count(anchor) != 1:
            raise RuntimeError('Final shutdown guard changed')
        transaction = transaction.replace(anchor, 'if(FALSE)', 1)
        (output / 'transaction.dm').write_text(transaction, encoding='utf-8')
    dme = (output / 'probe.dme').read_text(encoding='utf-8')
    # Adapt only the final native effect so rejected requests can be asserted in
    # one process; the final positive call invokes the actual native deletion.
    transaction = (output / 'transaction.dm').read_text(encoding='utf-8')
    if transaction.count('\tdel(world)\n') != 1:
        raise RuntimeError('Native shutdown effect changed')
    transaction = transaction.replace('\tdel(world)\n', '\tlifecycle_native_shutdown()\n', 1)
    (output / 'transaction.dm').write_text(transaction, encoding='utf-8')
    (output / 'probe.dme').write_text('#define GAME_STATE_PLAYING 3\n' + dme + '#include "endpoint.dm"\n', encoding='utf-8')
    receipt.update(negative_control=args.negative_control, prepared_only=args.prepare_only)
    print(f'Evidence: {output}', flush=True)
    if args.prepare_only:
        return
    byond = args.byond_bin.resolve(strict=True)
    compiler = byond / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
    daemon = byond / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
    build = subprocess.run([str(compiler), '-max_errors', '0', 'probe.dme'], cwd=output, capture_output=True, text=True, timeout=120)
    (output / 'compile.log').write_text(build.stdout + build.stderr, encoding='utf-8')
    if build.returncode or '0 errors, 0 warnings' not in build.stdout:
        raise RuntimeError('Lifecycle compile failed; see compile.log')
    run = subprocess.run([str(daemon), 'probe.dmb', '-invisible', '-close', '-safe', '-log', 'native.log'], cwd=output, capture_output=True, text=True, timeout=60)
    log = (output / 'native.log').read_text(encoding='utf-8', errors='replace')
    (output / 'daemon.log').write_text(run.stdout + run.stderr, encoding='utf-8')
    if run.returncode or re.search(r'runtime error:|bad ref|BUG:|##\s*ERROR\s*:|RUNTIME:|infinite loop|fatal error', log, re.I):
        raise RuntimeError('Unexpected native diagnostic')
    result = json.loads((output / 'result.json').read_text(encoding='utf-8'))
    failures = [line[6:] for line in log.splitlines() if line.startswith('FAIL: ')]
    expected = {'authentication': ['nonloopback accepted'], 'shutdown-generation': ['changed final generation reached shutdown']}.get(args.negative_control, [])
    if failures != expected or not result.get('done') or not result.get('intent_durable') or result.get('checks', 0) < 25 or result.get('failures') != len(expected):
        raise RuntimeError(f'Unexpected lifecycle assertions: {result}, {failures}')
    receipt['result'] = result
    (output / 'receipt.json').write_text(json.dumps(receipt, indent=2), encoding='utf-8')
    print(json.dumps(result))


if __name__ == '__main__':
    main()

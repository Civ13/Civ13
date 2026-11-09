"""Exercise production local lifecycle authentication and native shutdown guards."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import os
import re
import subprocess
import tempfile


ENDPOINT_ADAPTERS = """var/list/epoch_names = list("Stone Age")
/proc/log_admin(text)
	return
/proc/announce_restored_round_once()
	return
/datum/configuration/var/hub = null
/obj/map_metadata/var/ordinal_age = 0
/obj/map_metadata/var/age = "Stone Age"
/obj/map_metadata/proc/set_epoch(ordinal)
	return FALSE
"""


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
    anchor = 'return TRUE // Waiting-client integration uses production saver/loader/reclaim.'
    if base.count(anchor) != 1:
        raise RuntimeError('Reclaim completion adapter anchor changed')
    base = base.replace(anchor, 'return lifecycle_reclaim_ok', 1)
    probe = (root / 'tests/world_save/lifecycle_probe.dm').read_text(encoding='utf-8')
    (output / 'probe.dm').write_text(base + probe, encoding='utf-8')
    endpoint = (root / 'code/modules/persistence/nomads_lifecycle.dm').read_text(encoding='utf-8')
    if args.negative_control == 'authentication':
        anchor = 'if(peer[1] != "127.0.0.1" || '
        if endpoint.count(anchor) != 1:
            raise RuntimeError('Authentication anchor changed')
        endpoint = endpoint.replace(anchor, 'if(peer[1] == "disabled-negative-control" || ', 1)
    (output / 'endpoint.dm').write_text(endpoint, encoding='utf-8')
    # Collaborators the endpoint gained later (host epoch advance, standby handover,
    # hub visibility). The probe sends none of those requests; these only declare them.
    (output / 'endpoint_adapters.dm').write_text(ENDPOINT_ADAPTERS, encoding='utf-8')
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
    # The validated-shutdown deletion; the handover path has its own del(world).
    effect = 'replace the binary before the next startup.\n\tdel(world)\n'
    if transaction.count(effect) != 1:
        raise RuntimeError('Native shutdown effect changed')
    transaction = transaction.replace(effect, 'replace the binary before the next startup.\n\tlifecycle_native_shutdown()\n', 1)
    (output / 'transaction.dm').write_text(transaction, encoding='utf-8')
    (output / 'probe.dme').write_text('#define GAME_STATE_PLAYING 3\n' + dme + '#include "endpoint_adapters.dm"\n#include "endpoint.dm"\n', encoding='utf-8')
    receipt.update(negative_control=args.negative_control, prepared_only=args.prepare_only)
    receipt['production_hashes']['code/modules/persistence/nomads_lifecycle.dm'] = hashlib.sha256((root / 'code/modules/persistence/nomads_lifecycle.dm').read_bytes()).hexdigest()
    receipt['generated_hashes'] = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in output.iterdir() if p.suffix in ('.dm', '.dme')}
    (output / 'receipt.json').write_text(json.dumps(receipt, indent=2), encoding='utf-8')
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
    run = subprocess.run([str(daemon), 'probe.dmb', '-ip', '127.0.0.1', '-nowebclient', '-invisible', '-close', '-trusted', '-log', 'native.log'], cwd=output, capture_output=True, text=True, timeout=60)
    log = (output / 'native.log').read_text(encoding='utf-8', errors='replace')
    (output / 'daemon.log').write_text(run.stdout + run.stderr, encoding='utf-8')
    if run.returncode or re.search(r'runtime error:|bad ref|BUG:|##\s*ERROR\s*:|RUNTIME:|infinite loop|fatal error', log, re.I):
        raise RuntimeError('Unexpected native diagnostic')
    result = json.loads((output / 'result.json').read_text(encoding='utf-8'))
    failures = [line[6:] for line in log.splitlines() if line.startswith('FAIL: ')]
    expected = {'authentication': ['nonloopback accepted'], 'shutdown-generation': ['changed final generation reached shutdown']}.get(args.negative_control, [])
    if failures != expected or not result.get('done') or not result.get('intent_durable') or result.get('checks', 0) < 25 or result.get('failures') != len(expected):
        raise RuntimeError(f'Unexpected lifecycle assertions: {result}, {failures}')
    if not (output / 'map_saves/restart_intent.json').is_file():
        raise RuntimeError('Native shutdown consumed the published intent after its success receipt')
    receipt['result'] = result
    (output / 'receipt.json').write_text(json.dumps(receipt, indent=2), encoding='utf-8')
    print(json.dumps(result))


if __name__ == '__main__':
    main()

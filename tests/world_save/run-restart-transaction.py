"""Stage/run the production restart state machine with isolated side effects."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile


def prepare(root, output, control=None):
    relative = 'code/modules/persistence/restart_transaction.dm'
    source = (root / relative).read_text(encoding='utf-8')
    mutations = {
        'generation': ('if(!matches(I, current_identity())) throw EXCEPTION("Completed generation changed before restart")', '// Negative control: skip final validation.'),
        'consume': ('\t\tconsume(I)\n', '\t\t// Negative control: retain successful intent.\n'),
        'import': ('if(!load_generation(I)) throw EXCEPTION("Intended generation import failed: [map_storage.last_error]")', 'load_generation(I) // Negative control: ignore import failure.'),
    }
    if control and control != 'deferred-reboot':
        before, after = mutations[control]
        if source.count(before) != 1:
            raise RuntimeError('Mutation anchor changed')
        source = source.replace(before, after, 1)
    world = (root / 'code/world.dm').read_text(encoding='utf-8')
    start = world.index('/world/Reboot(var/reason, recovery_generation)')
    end = world.index('\n#define COLOR_LIGHT_SEPIA', start)
    reboot = world[start:end]
    if reboot.count('..(reason)') != 2 or reboot.count('spawn (150)') != 1:
        raise RuntimeError('Native reboot adapter anchor changed')
    reboot = reboot.replace('..(reason)', 'fixture_native_reboot(reason)')
    reboot = reboot.replace('spawn (150)', 'spawn (0)', 1)
    if control == 'deferred-reboot':
        anchor = '\t\tif(persistence_restart.busy || persistence_restart.startup_hold) return\n\t\tif (processScheduler)'
        if reboot.count(anchor) != 1:
            raise RuntimeError('Final deferred guard anchor changed')
        reboot = reboot.replace(anchor, '\t\tif (processScheduler)', 1)
    probe = root / 'tests/world_save/restart_transaction_probe.dm'
    (output / 'probe.dm').write_bytes(probe.read_bytes())
    (output / 'transaction.dm').write_text(source, encoding='utf-8', newline='\n')
    loading = (root / 'code/modules/persistence/loading.dm').read_text(encoding='utf-8')
    metadata_start = loading.index('/map_storage/proc/round_mode_metadata(')
    metadata_end = loading.index('\n/map_storage/proc/load_map_metadata()', metadata_start)
    (output / 'metadata.dm').write_text(loading[metadata_start:metadata_end] + '\n', encoding='utf-8')
    (output / 'reboot.dm').write_text(reboot, encoding='utf-8', newline='\n')
    macro = re.findall(r'^#define islist\(A\) .+$', (root / 'code/_macros.dm').read_text(encoding='utf-8'), re.M)
    if len(macro) != 1:
        raise RuntimeError('Production list macro changed')
    (output / 'probe.dme').write_text(macro[0] + '\n#define SPAN_DANGER(text) text\n#include "probe.dm"\n#include "metadata.dm"\n#define fdel(path) restart_delete_adapter(path)\n#include "transaction.dm"\n#define sleep(delay) restart_sleep_adapter(delay)\n#include "reboot.dm"\n', encoding='utf-8')
    return {'negative_control': control, 'production_hashes': {
        name: hashlib.sha256((root / name).read_bytes()).hexdigest()
        for name in (relative, 'code/world.dm', 'code/_macros.dm', 'code/modules/persistence/loading.dm')},
        'generated_hashes': {p.name: hashlib.sha256(p.read_bytes()).hexdigest()
                             for p in output.iterdir() if p.suffix in ('.dm', '.dme')}}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--byond-bin', type=Path)
    parser.add_argument('--prepare-only', action='store_true')
    parser.add_argument('--negative-control', choices=('generation', 'consume', 'import', 'deferred-reboot'))
    args = parser.parse_args()
    if not args.prepare_only and not args.byond_bin:
        parser.error('--byond-bin is required for native execution')
    root = Path(__file__).resolve().parents[2]
    output = Path(tempfile.mkdtemp(prefix='civ13-restart-transaction-'))
    receipt = prepare(root, output, args.negative_control)
    receipt['prepared_only'] = args.prepare_only
    (output / 'receipt.json').write_text(json.dumps(receipt, indent=2), encoding='utf-8')
    print(f'Evidence: {output}', flush=True)
    if args.prepare_only:
        return
    byond = args.byond_bin.resolve(strict=True)
    compiler = byond / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
    daemon = byond / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
    build = subprocess.run([str(compiler), '-max_errors', '0', 'probe.dme'], cwd=output,
                           capture_output=True, text=True, timeout=120)
    (output / 'compile.log').write_text(build.stdout + build.stderr, encoding='utf-8')
    if build.returncode or '0 errors, 0 warnings' not in build.stdout:
        raise RuntimeError('Native fixture compile failed; see compile.log')
    run = subprocess.run([str(daemon), 'probe.dmb', '-ip', '127.0.0.1', '-nowebclient', '-invisible', '-close', '-trusted', '-log', 'native.log'],
                         cwd=output, capture_output=True, text=True, timeout=60)
    log = (output / 'native.log').read_text(encoding='utf-8', errors='replace')
    (output / 'daemon.log').write_text(run.stdout + run.stderr, encoding='utf-8')
    if run.returncode or re.search(r'runtime error:|bad ref|BUG:|##\s*ERROR\s*:|RUNTIME:|infinite loop|fatal error', log, re.I):
        raise RuntimeError('Unexpected engine diagnostic')
    result = json.loads((output / 'result.json').read_text(encoding='utf-8'))
    if not result.get('done') or result.get('checks', 0) < 24:
        raise RuntimeError('Missing transaction assertions')
    failures = [line[6:] for line in log.splitlines() if line.startswith('FAIL: ')]
    expected = {
        'generation': ['stale completed generation restarted'],
        'consume': ['startup recovery failed to consume after successful load', 'failed consumption claimed completion', 'consumption retry reimported world'],
        'import': ['failed import discarded intent or released hold'],
        'deferred-reboot': ['ordinary reboot crossed final-yield transaction ownership'],
    }.get(args.negative_control, [])
    if failures != expected or result['failures'] != len(expected):
        raise RuntimeError(f'Unexpected assertion failures: {failures}')
    receipt['result'] = result
    (output / 'receipt.json').write_text(json.dumps(receipt, indent=2), encoding='utf-8')
    print(json.dumps(result))


if __name__ == '__main__':
    main()

"""Production save/load admission regression, with isolated storage adapters."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--byond-bin', type=Path)
    parser.add_argument('--prepare-only', action='store_true')
    parser.add_argument('--negative-control', choices=('admission', 'stale', 'recovery', 'player-ready'))
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    output = Path(tempfile.mkdtemp(prefix='civ13-world-operations-'))
    hashes = {}
    sources = [('code/predefines.dm', 'predefines.dm'),
               ('tests/world_save/stubs.dm', 'stubs.dm'),
               ('tests/world_save_operations/probe.dm', 'probe.dm')]
    sources += [(f'code/modules/persistence/{name}.dm', f'{name}.dm')
                for name in ('functions', 'player_reclaim', 'saving', 'loading')]
    for relative, target in sources:
        data = (root / relative).read_bytes()
        hashes[relative] = hashlib.sha256(data).hexdigest()
        source = data.decode('utf-8')
        if target == 'functions.dm' and args.negative_control:
            controls = {
                'admission': (' || persistence_active_operation ||', ' || FALSE ||'),
                'stale': ('if(persistence_active_operation != src) return FALSE', 'if(FALSE) return FALSE'),
                'recovery': ('if(!success && kind == "load" && mutation_started)', 'if(FALSE)'),
                'player-ready': ('operation.restoring_players = TRUE', 'operation.restoring_players = FALSE'),
            }
            before, after = controls[args.negative_control]
            if source.count(before) != 1:
                raise RuntimeError(f'Control anchor changed: {before}')
            source = source.replace(before, after)
            if args.negative_control == 'admission':
                # Remove both old and new admission gates; tests must catch overlap.
                source = source.replace('if(persistence_save_in_progress && !(restart_owner && persistence_restart.startup_hold)) return null', 'if(FALSE) return null')
        (output / target).write_text(source, encoding='utf-8')
    environment = '''#define TRUE 1
#define FALSE 0
#define TICK_CHECK fixture_tick_check()
#define TICK_LIMIT_TO_RUN 100
#define EXCEPTION(message) new /exception(message)
#include "predefines.dm"
#include "stubs.dm"
#define fdel(path) delete_file_adapter(path)
#include "functions.dm"
#include "player_reclaim.dm"
#include "saving.dm"
#include "loading.dm"
#include "probe.dm"
'''
    (output / 'probe.dme').write_text(environment, encoding='utf-8')
    receipt = {'sources_sha256': hashes, 'negative_control': args.negative_control,
               'generated_sha256': {p.name: hashlib.sha256(p.read_bytes()).hexdigest()
                                    for p in output.iterdir() if p.is_file()}}
    (output / 'sources.json').write_text(json.dumps(receipt, indent=2), encoding='utf-8')
    print(f'Retained evidence: {output}', flush=True)
    if args.prepare_only:
        print('PASS: sources prepared; native compile/runtime not run')
        return
    if not args.byond_bin:
        parser.error('--byond-bin required for native execution')
    byond = args.byond_bin.resolve(strict=True)
    compiler = byond / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
    daemon = byond / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
    for name, command in [('compile', [str(compiler), '-max_errors', '0', 'probe.dme']),
                          ('runtime', [str(daemon), 'probe.dmb', '-invisible', '-close', '-safe', '-log', 'runtime.log'])]:
        completed = subprocess.run(command, cwd=output, capture_output=True, text=True, timeout=90)
        log = completed.stdout + completed.stderr
        (output / f'{name}.log').write_text(log, encoding='utf-8')
        if completed.returncode:
            raise RuntimeError(f'{name} exit {completed.returncode}: {log}')
        if name == 'compile' and not re.search(r'0 errors, 0 warnings', log):
            raise RuntimeError(f'Compiler not clean: {log}')
    logs = '\n'.join(p.read_text(errors='replace') for p in output.glob('*.log'))
    if (output / 'unexpected.txt').exists() or re.search(r'runtime error:|bad ref|BUG:|##\s*ERROR|infinite loop|segmentation', logs, re.I):
        raise RuntimeError(f'Unexpected native diagnostic; inspect {output}')
    result = (output / 'result.txt').read_text().strip()
    failure = (output / 'failure.txt').read_text().strip() if (output / 'failure.txt').exists() else ''
    expected = {'admission': 'announcement sleep: wrapper save rejected',
                'stale': 'stale finish rejected',
                'recovery': 'mutating failure retains recovery hold',
                'player-ready': 'final callback restores players while operation held'}
    if args.negative_control:
        if result != 'FAIL' or failure != expected[args.negative_control]:
            raise RuntimeError(f'Wrong control outcome: {result}, {failure}')
    elif result != 'PASS':
        raise RuntimeError(f'Regression failed: {failure}')
    receipt.update(result=result, expected_failure=failure, checks=int((output / 'checks.txt').read_text()))
    (output / 'summary.json').write_text(json.dumps(receipt, indent=2), encoding='utf-8')
    print(f'PASS: {receipt["checks"]} assertions; ' + ('negative control detected' if args.negative_control else 'production admission'))


if __name__ == '__main__':
    main()

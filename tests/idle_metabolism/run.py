"""Extract production metabolism/action procedures into a tiny offline BYOND world."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import textwrap

ROOT = Path(__file__).resolve().parents[2]


def procedure(source, name):
    match = re.search(r'^' + re.escape(name) + r'\([^\n]*\)\n.*?(?=^/|\Z)', source, re.M | re.S)
    if not match:
        raise ValueError(f'Production procedure missing: {name}')
    return match[0].rstrip()


def production(control):
    paths = ['code/game/mob/living/carbon/human/human_life.dm',
             'code/_helpers/mobs.dm', 'code/modules/1713/active_training.dm']
    life, actions, training = [(ROOT / p).read_text(encoding='utf-8-sig') for p in paths]
    helpers = life[life.index('/mob/living/human/proc/survival_metabolism_time()'):
                   life.index('/mob/living/human/Life()')]
    fields = re.findall(r'^\tvar/tmp/survival_[^\n]+', life, re.M)
    if len(fields) != 2:
        raise ValueError('Runtime field extraction changed')
    start = life.index('\t\tvar/water_m = 1')
    end = life.index('\t\tif (find_trait("Extroverted"))', start)
    consumption = '/mob/living/human/proc/probe_consume()\n' + textwrap.indent(textwrap.dedent(life[start:end]), '\t')
    constant = re.search(r'^\s*#define HUNGER_THIRST_MULTIPLIER [^\n]+', life, re.M)[0].strip()
    action_procs = '\n\n'.join(procedure(actions, name) for name in (
        '/mob/proc/survival_action_started', '/mob/proc/survival_action_finished', '/proc/do_mob', '/proc/do_after'))
    source = constant + '\n/mob/living/human\n' + '\n'.join(fields) + '\n' + helpers + consumption + '\n' + action_procs + '\n' + procedure(training, '/mob/living/human/persistence_runtime_var')
    if control == 'idle':
        assert source.count('>= 600 ? 0.1 : 1') == 1
        source = source.replace('>= 600 ? 0.1 : 1', '>= 600 ? 1 : 1')
    elif control == 'action':
        source = source.replace('\tuser.survival_action_started()', '\t// omitted start')
        source = source.replace('survival_actions || !may_do_after || !may_do_mob || ', '')
    elif control == 'persistence':
        source = source.replace(', "survival_rest_since", "survival_actions"', '')
    return source, {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in paths}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--byond-bin', type=Path, required=True)
    parser.add_argument('--negative-control', choices=['idle', 'action', 'persistence'])
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=False)
    source, hashes = production(args.negative_control)
    metadata = {'head_sha': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
                'source_sha256': hashes, 'negative_control': args.negative_control,
                'scope': 'extracted production metabolism and timed actions, not full-game/client acceptance'}
    (args.output / 'metadata.json').write_text(json.dumps(metadata, indent=2), encoding='utf-8')
    (args.output / 'tested.patch').write_text(subprocess.check_output(['git', 'diff'], cwd=ROOT, text=True), encoding='utf-8')
    flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
    with tempfile.TemporaryDirectory(prefix='civ13-idle-') as temp:
        work = Path(temp)
        (work / 'production.dm').write_text(source, encoding='utf-8')
        (work / 'probe.dm').write_text((ROOT / 'tests/idle_metabolism/probe.dm').read_text(encoding='utf-8'), encoding='utf-8')
        (work / 'probe.dme').write_text('#include "probe.dm"\n#include "production.dm"\n', encoding='utf-8')
        compiler = args.byond_bin / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
        daemon = args.byond_bin / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
        build = subprocess.run([str(compiler), '-max_errors', '0', 'probe.dme'], cwd=work,
                               capture_output=True, text=True, timeout=45, creationflags=flags)
        log = build.stdout + build.stderr
        (args.output / 'compile.log').write_text(log, encoding='utf-8')
        print(log, flush=True)
        if build.returncode or '516.1681' not in log or '0 errors, 0 warnings' not in log:
            raise RuntimeError('Pinned compilation failed')
        result = subprocess.run([str(daemon), 'probe.dmb', '-close', '-safe', '-log', 'runtime.log']
                                + (['-invisible'] if os.name == 'nt' else []), cwd=work,
                                capture_output=True, text=True, timeout=25, creationflags=flags)
        runtime = (work / 'runtime.log').read_text(errors='replace') if (work / 'runtime.log').exists() else ''
        complete = (work / 'result.txt').read_text() if (work / 'result.txt').exists() else ''
        (args.output / 'runtime.log').write_text(runtime + result.stdout + result.stderr, encoding='utf-8')
        (args.output / 'result.txt').write_text(complete, encoding='utf-8')
        expected = {'idle': 'FAIL: idle ordinary food', 'action': 'FAIL: stationary unrestricted action',
                    'persistence': 'FAIL: runtime clock exclusion'}.get(args.negative_control, 'PASS: idle metabolism')
        diagnostics = runtime + result.stdout + result.stderr
        if result.returncode or not complete.startswith(expected) or any(x in diagnostics for x in ('runtime error:', 'Runtime error:', 'runtime:', 'BUG:')):
            raise RuntimeError(f'Fixture failed; expected {expected!r}, got {complete!r}')
        print(('PASS expected negative control: ' if args.negative_control else '') + complete.strip())


if __name__ == '__main__':
    main()

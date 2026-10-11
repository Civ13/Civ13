"""Bounded production disease fixture with normal world startup disabled."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import uuid


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--byond-bin', required=True, type=Path)
    parser.add_argument('--baseline', action='store_true')
    parser.add_argument('--negative-control', action='store_true')
    args = parser.parse_args()
    if args.baseline and args.negative_control:
        parser.error('Baseline and negative control are separate modes')
    root = Path(__file__).resolve().parents[2]
    prefix = '.survival_' + uuid.uuid4().hex
    generated = [root / (prefix + suffix) for suffix in
                 ('.dme', '_world.dm', '_disease.dm', '.dmb', '.rsc', '_globals.dm', '_medicine.dm')]
    logs = Path(tempfile.mkdtemp(prefix='civ13-survival-'))
    print(f'Artifacts: {logs}', flush=True)
    flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
    binary = args.byond_bin.resolve()
    try:
        world = (root / 'code/world.dm').read_text(encoding='utf-8')
        start = world.index('/world/New()')
        parent = world.index('\n\t..()', start)
        world = world[:parent] + world[parent:].replace('\n\t..()', '', 1)
        world = world.replace('/world/New()', '/world/proc/unused_survival_startup()', 1)
        generated[1].write_text(world, encoding='utf-8')
        source = (root / 'civ13.dme').read_text(encoding='utf-8')
        source = source.replace('code\\world.dm', generated[1].name)
        globals_source = (root / 'code/controllers/mc/globals.dm').read_text(encoding='utf-8')
        target = '\tgvars_datum_in_built_vars = exclude_these.vars + list('
        if globals_source.count(target) != 1:
            raise RuntimeError('Global variable snapshot isolation target changed')
        # Materialize the virtual vars list before union. BYOND 516.1681 logs
        # Bad ref during the original virtual-list union even on baseline.
        replacement = ('\tgvars_datum_in_built_vars = list()\n'
                       '\tfor(var/variable_name in exclude_these.vars)\n'
                       '\t\tgvars_datum_in_built_vars += variable_name\n'
                       '\tgvars_datum_in_built_vars += list(')
        generated[5].write_text(globals_source.replace(target, replacement), encoding='utf-8')
        source = source.replace('code\\controllers\\mc\\globals.dm', generated[5].name)
        if args.negative_control:
            medicine = (root / 'code/modules/reagents/Chemistry-Reagents/Chemistry-Reagents-Medicine.dm').read_text(encoding='utf-8')
            target = 'M.receive_disease_treatment(0.3)'
            if medicine.count(target) != 1:
                raise RuntimeError('Herbal negative control target changed')
            generated[6].write_text(medicine.replace(target, 'M.receive_disease_treatment(0)'), encoding='utf-8')
            source = source.replace('code\\modules\\reagents\\Chemistry-Reagents\\Chemistry-Reagents-Medicine.dm', generated[6].name)
        if args.baseline:
            life = subprocess.check_output(['git', 'show', 'e4967a4e0:code/game/mob/living/carbon/human/human_life.dm'], cwd=root, text=True)
            block = life[life.index('// disease stuff'):life.index('\n\t//shitcode to fix the movement bug')]
            generated[2].write_text('/mob/living/human/proc/survival_baseline_step()\n' + block, encoding='utf-8')
            source += f'\n#include "{generated[2].name}"\n#define SURVIVAL_BASELINE\n'
        generated[0].write_text(source + '\n#include "tests/survival/probe.dm"\n', encoding='utf-8')
        commit = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip()
        (logs / 'tested.patch').write_text(subprocess.check_output(['git', 'diff'], cwd=root, text=True), encoding='utf-8')
        compiler = binary / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
        daemon = binary / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
        build = subprocess.run([str(compiler), '-max_errors', '0', str(generated[0])], cwd=root,
                               capture_output=True, text=True, timeout=180, creationflags=flags)
        output = build.stdout + build.stderr
        (logs / 'compile.log').write_text(output, encoding='utf-8')
        print(output, flush=True)
        if build.returncode or '516.1681' not in output or '0 errors, 0 warnings' not in output:
            raise RuntimeError('Pinned compilation failed')
        for path in generated[3:5]:
            shutil.copy2(path, logs / path.name)
        shutil.copytree(root / 'config', logs / 'config')
        options = ['-invisible', '-close'] if os.name == 'nt' else []
        run = subprocess.run([str(daemon), str(logs / generated[3].name), *options, '-safe',
                              '-params', f'tested_commit={commit}', '-log', 'runtime.log'], cwd=logs,
                             capture_output=True, text=True, timeout=90, creationflags=flags)
        (logs / 'daemon.log').write_text(run.stdout + run.stderr, encoding='utf-8')
        runtime_log = (logs / 'runtime.log').read_text(encoding='utf-8', errors='replace')
        if 'BUG:' in runtime_log or 'Runtime error:' in runtime_log:
            print(runtime_log, flush=True)
            raise RuntimeError('Runtime diagnostics invalidate survival evidence')
        result = (logs / 'survival-result.txt').read_text(encoding='utf-8')
        print(result, flush=True)
        expected = ('FAIL: plague: three oral herbs complete course and reserve planting stock'
                    if args.negative_control else 'PASS:')
        if run.returncode or not result.startswith(expected):
            raise RuntimeError('Survival probe failed')
    finally:
        for path in generated:
            path.unlink(missing_ok=True)


if __name__ == '__main__':
    main()

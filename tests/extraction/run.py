"""Pinned BYOND production account journal checks in isolated temporary storage."""
import argparse
from pathlib import Path
import os
import shutil
import subprocess
import tempfile
import re
import uuid


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--byond-bin', required=True, type=Path)
    parser.add_argument('--probe', choices=('store', 'restart', 'settlement', 'equipment', 'mode', 'insurance'), default='store')
    parser.add_argument('--provenance-negative-control', action='store_true')
    parser.add_argument('--vote-negative-control', choices=('stale', 'cancel', 'reentry'))
    args = parser.parse_args()
    if args.provenance_negative_control and args.probe not in ('equipment', 'mode'):
        parser.error('Provenance control requires the equipment or mode probe')
    if args.vote_negative_control and (args.probe != 'mode' or args.provenance_negative_control):
        parser.error('Vote control requires the mode probe without another control')
    root = Path(__file__).resolve().parents[2]
    binary = args.byond_bin.resolve()
    compiler = binary / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
    daemon = binary / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
    flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
    if args.probe in ('equipment', 'mode', 'insurance'):
        return equipment(root, compiler, daemon, flags, args.probe, args.provenance_negative_control, args.vote_negative_control)
    with tempfile.TemporaryDirectory(prefix='civ13-extraction-') as temp:
        target = Path(temp)
        (target / 'tests/extraction').mkdir(parents=True)
        (target / 'code/modules/1713/extraction').mkdir(parents=True)
        probe_name = 'restart_probe.dm' if args.probe == 'restart' else ('settlement_probe.dm' if args.probe == 'settlement' else 'store_probe.dm')
        shutil.copy2(root / 'tests/extraction' / probe_name, target / 'tests/extraction' / probe_name)
        shutil.copy2(root / 'code/modules/1713/extraction/account_store.dm', target / 'code/modules/1713/extraction/account_store.dm')
        shutil.copy2(root / 'code/modules/1713/extraction/transactions.dm', target / 'code/modules/1713/extraction/transactions.dm')
        shutil.copy2(root / 'code/modules/1713/extraction/settlement.dm', target / 'code/modules/1713/extraction/settlement.dm')
        (target / 'probe.dme').write_text(f'#include "tests/extraction/{probe_name}"\n', encoding='utf-8')
        built = subprocess.run([str(compiler), '-max_errors', '0', 'probe.dme'], cwd=target,
                               capture_output=True, text=True, timeout=60, creationflags=flags)
        print(built.stdout + built.stderr)
        if built.returncode or '516.1681' not in built.stdout or '0 errors, 0 warnings' not in built.stdout:
            raise RuntimeError('Pinned compile failed')
        platform = ['-invisible', '-close'] if os.name == 'nt' else []
        phases = ('write', 'reload', 'recover') if args.probe == 'restart' else (('write', 'reload', 'replay') if args.probe == 'settlement' else ('store',))
        for phase in phases:
            (target / 'result.txt').unlink(missing_ok=True)
            ran = subprocess.run([str(daemon), 'probe.dmb', *platform, '-safe', '-params', f'phase={phase}', '-log', 'runtime.log'],
                             cwd=target, capture_output=True, text=True, timeout=45, creationflags=flags)
            result = (target / 'result.txt').read_text().strip() if (target / 'result.txt').exists() else 'MISSING'
            log = (target / 'runtime.log').read_text(errors='replace') if (target / 'runtime.log').exists() else ''
            print(result)
            if ran.returncode or not result.startswith('PASS:') or any(x in log.lower() for x in ('runtime error', 'bad ref', '## error')):
                print(log)
                raise RuntimeError('Account journal verification failed')


def equipment(root, compiler, daemon, flags, probe, provenance_control=False, vote_control=None):
    prefix = '.extraction_' + uuid.uuid4().hex
    generated = [root / (prefix + suffix) for suffix in ('.dme', '_world.dm', '_globals.dm', '.dmb', '.rsc')]
    try:
        source = (root / 'civ13.dme').read_text(encoding='utf-8')
        expected_vote_failure = None
        if vote_control:
            vote_source = (root / 'code/datums/vote.dm').read_text(encoding='utf-8')
            mutations = {
                'stale': (' && session_generation == generation', '', 'stale ballot and timer cannot touch replacement'),
                'cancel': ('H.state = "cancelled"', 'H.state = "pending"', 'cancel detaches callbacks and clears UI session'),
                'reentry': ('if (generation != H.generation || active_request) return .', 'reset()\n\t\tif (generation != H.generation || active_request) return .', 'reentrant callback replacement survives old completion'),
            }
            marker, replacement, expected_vote_failure = mutations[vote_control]
            if vote_source.count(marker) != 1:
                raise RuntimeError('Vote mutation marker changed')
            control = root / (prefix + '_vote.dm')
            generated.append(control)
            control.write_text(vote_source.replace(marker, replacement), encoding='utf-8')
            source = source.replace('code\\datums\\vote.dm', control.name)
        if provenance_control:
            codec = (root / 'code/modules/1713/extraction/equipment.dm').read_text(encoding='utf-8')
            marker = 'I.extraction_found_in_raid = record["schema"] == 2 ? node["found_in_raid"] : FALSE'
            if codec.count(marker) != 1:
                raise RuntimeError('Provenance control marker changed')
            control = root / (prefix + '_equipment.dm')
            generated.append(control)
            control.write_text(codec.replace(marker, 'I.extraction_found_in_raid = FALSE'), encoding='utf-8')
            source = source.replace('code\\modules\\1713\\extraction\\equipment.dm', control.name)
        world = (root / 'code/world.dm').read_text(encoding='utf-8')
        start = world.index('/world/New()')
        parent = world.index('\n\t..()', start)
        world = world[:parent] + world[parent:].replace('\n\t..()', '', 1)
        world = world.replace('/world/New()', '/world/proc/unused_extraction_startup()', 1)
        world = world.replace('/datum/global_init/New()\n', '/datum/global_init/New()\n\treturn\n', 1)
        generated[1].write_text(world, encoding='utf-8')
        globals_text = (root / 'code/controllers/mc/globals.dm').read_text(encoding='utf-8')
        marker = '/datum/controller/global_vars/New()\n'
        if globals_text.count(marker) != 1:
            raise RuntimeError('Global startup isolation marker changed')
        generated[2].write_text(globals_text.replace(marker, marker + '\treturn\n'), encoding='utf-8')
        source = source.replace('code\\world.dm', generated[1].name).replace('code\\controllers\\mc\\globals.dm', generated[2].name)
        source = re.sub(r'^#include ".*\.dmm"\s*$', '', source, flags=re.M)
        if probe == 'mode':
            source = '#define EXTRACTION_MODE_PROBE\n' + source
            source += '\n#include "tests/extraction/mode_probe.dm"\n#include "tests/extraction/vote_probe.dm"\n#include "tests/extraction/loot_probe.dm"\n#include "maps/extraction/industrial_district.dmm"\n'
        if probe == 'insurance':
            source = '#define EXTRACTION_RETURNS_PROCESS_PROBE\n' + source
            source += '\n#include "tests/extraction/insurance_process_probe.dm"\n'
        source += '\n#include "tests/extraction/equipment_probe.dm"\n'
        generated[0].write_text(source, encoding='utf-8')
        with tempfile.TemporaryDirectory(prefix='civ13-extraction-equipment-') as temp:
            target = Path(temp)
            built = subprocess.run([str(compiler), '-max_errors', '0', str(generated[0])], cwd=root,
                                   capture_output=True, text=True, timeout=90, creationflags=flags)
            print(built.stdout + built.stderr)
            if built.returncode or '516.1681' not in built.stdout or '0 errors, 0 warnings' not in built.stdout:
                raise RuntimeError('Pinned equipment compile failed')
            shutil.copy2(generated[3], target / 'probe.dmb')
            shutil.copy2(generated[4], target / 'probe.rsc')
            shutil.copytree(root / 'config/names', target / 'config/names')
            platform = ['-invisible', '-close'] if os.name == 'nt' else []
            phases = ('write', 'reload', 'replay') if probe == 'insurance' else ('equipment',)
            for phase in phases:
                (target / 'result.txt').unlink(missing_ok=True)
                ran = subprocess.run([str(daemon), 'probe.dmb', *platform, '-safe', '-params', f'phase={phase}', '-log', 'runtime.log'], cwd=target,
                                 capture_output=True, text=True, timeout=60, creationflags=flags)
                result = (target / 'result.txt').read_text().strip() if (target / 'result.txt').exists() else 'MISSING'
                log = (target / 'runtime.log').read_text(errors='replace') if (target / 'runtime.log').exists() else ''
                print(result)
                if vote_control:
                    if ran.returncode or not result.startswith('FAIL:') or expected_vote_failure not in log or any(x in log.lower() for x in ('runtime error', 'bad ref', '## error')):
                        print(log)
                        raise RuntimeError('Vote control did not fail at its intended assertion')
                    print('PASS: vote lifecycle control rejected: ' + vote_control)
                    return
                if provenance_control:
                    if ran.returncode or not result.startswith('FAIL:') or 'nested identities and raid provenance survive native disk reload' not in log or any(x in log.lower() for x in ('runtime error', 'bad ref', '## error')):
                        print(log)
                        raise RuntimeError('Provenance omission was not detected by the intended assertion')
                    print('PASS: generated provenance-loss control rejected at native disk reload')
                    return
                if ran.returncode or not result.startswith('PASS:') or any(x in log.lower() for x in ('runtime error', 'bad ref', '## error')):
                    print(log)
                    raise RuntimeError('Production equipment verification failed')
    finally:
        for path in generated:
            path.unlink(missing_ok=True)


if __name__ == '__main__':
    main()

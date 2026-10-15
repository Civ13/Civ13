"""Pinned mall compilation/native probe, offline temporary storage only."""
import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess
import uuid

from mall_run_support import OwnedRun


def main(argv=None, *, root=None, run_factory=OwnedRun):
    parser = argparse.ArgumentParser()
    parser.add_argument('--byond-bin', required=True, type=Path)
    parser.add_argument('--compile-only', action='store_true')
    parser.add_argument('--negative-control', choices=('mission', 'vehicle', 'key_charge', 'key_construction', 'stair_landing', 'stair_return', 'ordinary_replay'))
    args = parser.parse_args(argv)
    root = Path(root).resolve() if root is not None else Path(__file__).resolve().parents[2]
    prefix = '.mall_' + uuid.uuid4().hex
    files = [root / (prefix + suffix) for suffix in ('.dme', '_world.dm', '_globals.dm', '_metadata.dm', '.dmb', '.rsc', '_loot.dm', '_equipment.dm')]
    flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
    compiler = args.byond_bin / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
    daemon = args.byond_bin / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
    metadata = {'negative_control': args.negative_control, 'compile_only': args.compile_only}
    with run_factory(root, prefix, metadata, files) as owned:
        print('Fixture receipts: ' + str(owned.destination), flush=True)
        head = owned.run('git', ['git', 'rev-parse', 'HEAD'], root, 10, creationflags=flags)
        if head.returncode or not re.fullmatch(r'[0-9a-f]{40}', head.stdout.strip()):
            raise RuntimeError('Cannot establish fixture source HEAD: ' + head.stdout + head.stderr)
        owned.head_sha = head.stdout.strip()
        source = (root / 'civ13.dme').read_text(encoding='utf-8')
        world = (root / 'code/world.dm').read_text(encoding='utf-8')
        start = world.index('/world/New()')
        parent = world.index('\n\t..()', start)
        world = world[:parent] + world[parent:].replace('\n\t..()', '', 1)
        world = world.replace('/world/New()', '/world/proc/unused_mall_startup()', 1)
        world = world.replace('/datum/global_init/New()\n', '/datum/global_init/New()\n\treturn\n', 1)
        files[1].write_text(world, encoding='utf-8')
        globals_text = (root / 'code/controllers/mc/globals.dm').read_text(encoding='utf-8')
        marker = '/datum/controller/global_vars/New()\n'
        if globals_text.count(marker) != 1:
            raise RuntimeError('Global startup isolation marker changed')
        files[2].write_text(globals_text.replace(marker, marker+'\treturn\n', 1), encoding='utf-8')
        source = source.replace('code\\world.dm', files[1].name).replace('code\\controllers\\mc\\globals.dm', files[2].name)
        expected = None
        if args.negative_control in ('mission', 'vehicle', 'stair_landing', 'stair_return'):
            metadata = (root / 'code/modules/1713/extraction/mall.dm').read_text(encoding='utf-8')
            marker, replacement, expected = {
                'mission': ('return level in list(1, 4, 5)', 'return level in list(1, 2, 3, 4, 5)', 'secure floors excluded by mission policy'),
                'vehicle': ('return ..() && istype(E, /obj/effect/extraction_exit/highway) && E.z == 1', 'return ..()', 'only highway exits admit cars'),
                'stair_landing': ('if (A.density || isliving(A)) return FALSE', '// Negative control: ignore occupied landing', 'all cores reject dense destination occupancy without moving the actor'),
                'stair_return': ('if (!return_stairs || return_stairs.destination_z != z) return FALSE', '// Negative control: ignore return connection', 'all cores reject a missing return stair without moving the actor'),
            }[args.negative_control]
            if metadata.count(marker) != 1:
                raise RuntimeError('Mutation marker changed')
            files[3].write_text(metadata.replace(marker, replacement), encoding='utf-8')
            source = source.replace('code\\modules\\1713\\extraction\\mall.dm', files[3].name)
        elif args.negative_control == 'ordinary_replay':
            original = (root / 'code/modules/1713/extraction/loot.dm').read_text(encoding='utf-8')
            marker = 'stash -= list(entry)'
            if original.count(marker) != 1:
                raise RuntimeError('Ordinary claim mutation marker changed')
            files[6].write_text(original.replace(marker, '// Negative control: retain delivered entry'), encoding='utf-8')
            source = source.replace('code\\modules\\1713\\extraction\\loot.dm', files[6].name)
            expected = 'ordinary container claim is unique before reopening'
        elif args.negative_control:
            if args.negative_control == 'key_charge':
                relative, output = 'equipment.dm', files[7]
                marker = 'scalars[key] = value'
                replacement = 'scalars[key] = key == "uses_remaining" ? 3 : value'
                expected = 'successful extraction preserves remaining key uses'
            else:
                relative, output = 'loot.dm', files[6]
                marker = 'if (!isnull(test_fail_constructor_after) && constructed.len >= test_fail_constructor_after)'
                replacement = 'if (FALSE)'
                expected = 'keyed factory construction failure exposes no reward'
            original = (root / 'code/modules/1713/extraction' / relative).read_text(encoding='utf-8')
            if original.count(marker) != 1:
                raise RuntimeError('Key mutation marker changed')
            output.write_text(original.replace(marker, replacement), encoding='utf-8')
            source = source.replace('code\\modules\\1713\\extraction\\' + relative, output.name)
        source = re.sub(r'^#include ".*\.dmm"\s*$', '', source, flags=re.M)
        source += '\n#include "tests/extraction/container_keys_probe.dm"\n#include "tests/extraction/mall_probe.dm"\n#include "maps/extraction/interchange_mall.dmm"\n'
        files[0].write_text(source, encoding='utf-8')
        compiled = owned.run('compile', [str(compiler), '-max_errors', '0', files[0].name], root, 120, creationflags=flags)
        output = compiled.stdout + compiled.stderr
        if compiled.returncode or '516.1681' not in output or '0 errors, 0 warnings' not in output:
            raise RuntimeError('Pinned mall fixture compilation failed:\n' + output)
        if args.compile_only:
            accepted = 'PASS: pinned mall fixture compile'
        else:
            target = owned.create_runtime()
            shutil.copy2(files[4], target / 'probe.dmb')
            shutil.copy2(files[5], target / 'probe.rsc')
            shutil.copytree(root / 'config/names', target / 'config/names')
            platform = ['-invisible', '-close'] if os.name == 'nt' else []
            result = owned.run('daemon', [str(daemon), 'probe.dmb', '-port', 'none', *platform, '-safe', '-log', 'runtime.log'], target, 90, creationflags=flags)
            report = (target / 'result.txt').read_text(encoding='utf-8') if (target / 'result.txt').exists() else ''
            log = result.stdout + result.stderr + ((target / 'runtime.log').read_text(errors='replace') if (target / 'runtime.log').exists() else '')
            if result.returncode or any(value in log.lower() for value in ('runtime error', 'bad ref', '## error', 'opened on network port')):
                raise RuntimeError('Native mall fixture failed:\n' + log)
            if expected:
                if not report.startswith('FAIL:') or expected not in report:
                    raise RuntimeError('Negative control missed expected assertion: ' + report + '\n' + log)
                accepted = 'PASS: negative control rejected at ' + expected
            elif not report.startswith('PASS:'):
                raise RuntimeError(report + '\n' + log)
            else:
                accepted = report.strip()
    # Overall success is only emitted after receipt retention and owned cleanup.
    print(accepted, flush=True)


if __name__ == '__main__':
    main()

"""Pinned mall compilation/native probe, offline temporary storage only."""
import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess
import uuid

from mall_run_support import OwnedRun


PASS_RESULT = 'PASS: native mall floors, stairs, loot, highway policy and extraction'
NETWORK_STAGE = 'network closed and reopen refused'
DIAGNOSTICS = ('runtime error', 'bad ref', '## error', 'fatal error')
BINDING = re.compile(r'^World opened on network port [0-9]+ for address ([^\s]+)\.[ \t]*\r?$',
                     re.MULTILINE)
CLOSURE = re.compile(r'^World no longer opened to new users\.[ \t]*\r?$', re.MULTILINE)


def validate_native_result(report, stages, streams, expected=None):
    """Require the exact oracle and reject collateral failures in every stream.

    BYOND can mirror world.log to another stream. Each emitting stream may carry
    one identical expected assertion, but duplicate assertions within a stream
    are rejected. The retained runtime.log must itself contain that assertion.
    Native assertions can arrive through the catch or world/Error path. Only an
    exact expected negative result selects its corresponding log dialect.
    """
    if stages.splitlines().count(NETWORK_STAGE) != 1:
        raise RuntimeError('Native mall fixture did not establish closed/refused-reopen state')
    bindings = []
    for name, output in streams.items():
        matches = list(BINDING.finditer(output))
        closures = list(CLOSURE.finditer(output))
        if len(matches) > 1 or len(closures) > 1:
            raise RuntimeError('Duplicate native network diagnostic in ' + name)
        if matches and closures and matches[0].start() >= closures[0].start():
            raise RuntimeError('Native network closure preceded startup binding in ' + name)
        if name == 'runtime.log' and (len(matches) != 1 or len(closures) != 1):
            raise RuntimeError('Retained runtime log lacks its sole startup binding and closure')
        bindings.extend(match.group(1) for match in matches)
        if 'opened on network port' in BINDING.sub('', output).lower():
            raise RuntimeError('Unrecognized native bind diagnostic in ' + name)
    # world.address is not a reliable Linux bind witness. Check the native
    # startup diagnostic instead, alongside the fixture's closed-port assertion.
    if ('runtime.log' not in streams or not bindings
            or any(address != '127.0.0.1' for address in bindings)):
        raise RuntimeError('Native mall fixture did not establish IPv4 loopback binding')
    if expected is None:
        if report.splitlines() != [PASS_RESULT]:
            raise RuntimeError('Native mall fixture did not produce its sole exact positive result')
        if any(any(value in output.lower() for value in (*DIAGNOSTICS, 'fail:', 'pass:'))
               for output in streams.values()):
            raise RuntimeError('Unexpected native result record outside the positive receipt')
        return PASS_RESULT
    failure = (r'FAIL: (?P<runtime>runtime )?(?P<detail>' + re.escape(expected)
               + r' at tests[/\\]extraction[/\\]mall_probe\.dm:[0-9]+)')
    lines = report.splitlines()
    result = re.fullmatch(failure, lines[0]) if len(lines) == 1 else None
    if result is None:
        raise RuntimeError('Negative control did not produce its sole exact expected assertion')
    prefix = 'Runtime error: ' if result.group('runtime') else 'FAIL: '
    record = r'^' + re.escape(prefix + result.group('detail')) + r'[ \t]*$'
    for name, output in streams.items():
        # Normalize only native CRLF, not arbitrary whitespace or extra records.
        normalized = output.replace('\r\n', '\n')
        records = re.findall(record, normalized, flags=re.MULTILINE)
        if len(records) > 1 or (name == 'runtime.log' and len(records) != 1):
            raise RuntimeError('Negative control assertion count is invalid in ' + name)
        remainder = re.sub(record, '', normalized, flags=re.MULTILINE).lower()
        if any(value in remainder for value in (*DIAGNOSTICS, 'fail:', 'pass:')):
            raise RuntimeError('Collateral native diagnostic or result record in ' + name)
    return 'PASS: negative control rejected at ' + expected


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
                'stair_return': ('if (!return_stairs || return_stairs.destination_z != z) return FALSE', 'if (return_stairs && return_stairs.destination_z != z) return FALSE', 'all cores reject a missing return stair without moving the actor'),
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
            result = owned.run('daemon', [str(daemon), 'probe.dmb', '-ip', '127.0.0.1',
                                         '-invisible', '-close', '-trusted', '-nowebclient',
                                         '-log', 'runtime.log'], target, 90, creationflags=flags)
            report = (target / 'result.txt').read_text(encoding='utf-8') if (target / 'result.txt').exists() else ''
            stages = (target / 'stages.txt').read_text(encoding='utf-8') if (target / 'stages.txt').exists() else ''
            streams = {
                'stdout': result.stdout,
                'stderr': result.stderr,
                'runtime.log': ((target / 'runtime.log').read_text(errors='replace')
                                if (target / 'runtime.log').exists() else ''),
            }
            if result.returncode:
                raise RuntimeError('Native mall fixture exited unsuccessfully; inspect retained receipts')
            accepted = validate_native_result(report, stages, streams, expected)
    # Overall success is only emitted after receipt retention and owned cleanup.
    print(accepted, flush=True)


if __name__ == '__main__':
    main()

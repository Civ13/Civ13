"""Offline production-path flax regression. Never opens a client or server port."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import shutil
import subprocess
import sys
import threading
import time
import uuid

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts'))
import byond_runtime
import byond_toolchain
from native_fixture import no_port_args

CORE = 'code/modules/1713/flax_processing.dm'
ENTRY_SOURCES = ('code/game/mob/living/living.dm', 'code/game/mob/living/carbon/human/human.dm')
ENTRY_CONTRACTS = (
    'civ13.dme', 'code/world.dm', 'code/controllers/mc/globals.dm',
    'code/game/mob/inventory.dm', 'code/game/mob/living/carbon/human/inventory.dm',
    'code/game/mob/living/carbon/human/update_icons.dm',
    'code/game/objects/structures/table.dm', 'code/game/objects/items/weapons/defib.dm',
)
CONTROLS = {
    'payment': ('if (!use(2))', 'if (FALSE)', 'FAIL: bundle payment'),
    'replay': ('\tB.stage++', '\t// omitted stage advance', 'FAIL: comb stage advances'),
    'persistence': ('return key == "soaking" || ..()', 'return ..()', 'FAIL: soaking lock excluded'),
}
LOG_LIMIT = 16 * 1024 * 1024
INPUT_LIMIT = 2 * 1024 * 1024
ARTIFACT_LIMIT = 256 * 1024 * 1024
OUTPUT_LIMIT = 512 * 1024 * 1024
FILE_LIMIT = 128
GENERATED_SUFFIXES = ('.dme', '_world.dm', '_globals.dm', '_flax.dm', '.dmb', '.rsc',
                      '_living.dm', '_human.dm')


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n', encoding='utf-8')


def bounded_text(path, limit=LOG_LIMIT):
    with path.open('rb') as stream:
        data = stream.read(limit + 1)
    if len(data) > limit:
        raise RuntimeError('Evidence exceeds read bound: ' + str(path))
    return data.decode('utf-8', errors='replace')


def write_log(path, text):
    data = text.encode('utf-8')
    path.write_bytes(data[:LOG_LIMIT])
    if len(data) > LOG_LIMIT:
        raise RuntimeError('Combined diagnostic exceeded bound; bounded prefix retained: ' + str(path))


def check_output_budget(directory):
    """Detect live-file overruns; an admitted filesystem quota is still required.

    Stream capture below has a hard byte cap. Native direct file writes can
    overshoot between observations; never equate this check with a disk quota.
    """
    count = total = 0
    for path in directory.rglob('*'):
        if path.is_file():
            count += 1
            total += path.stat().st_size
            if count > FILE_LIMIT or total > OUTPUT_LIMIT:
                raise RuntimeError('Task-owned output budget exceeded')
            if path.suffix in ('.log', '.txt', '.json') and path.stat().st_size > LOG_LIMIT:
                raise RuntimeError('Native diagnostic file exceeds bound: ' + str(path))
    return count, total


def run_phase(command, *, cwd, output, phase, timeout, creationflags=0):
    """Retain bounded stdout/stderr even on timeout or interruption.

    Only the direct child is stopped here. Descendant ownership and actual
    socket closure remain the admitted supervisor's separate responsibility.
    """
    receipt = {'phase': phase, 'argv': command, 'cwd': str(cwd),
               'timeout_seconds': timeout, 'status': 'starting',
               'descendant_cleanup': 'unverified', 'streams': {}}
    receipt_path = output / (phase + '-phase.json')
    write_json(receipt_path, receipt)
    exceeded = threading.Event()
    readers = []
    child = None
    failure = None
    previous_sigterm = None

    def interrupted(signum, frame):
        raise InterruptedError('Native phase interrupted by signal ' + str(signum))

    def capture(stream, name):
        info = receipt['streams'][name]
        try:
            with (output / (phase + '.' + name + '.log')).open('xb') as target:
                while True:
                    data = getattr(stream, 'read1', stream.read)(16384)
                    if not data:
                        break
                    info['observed_bytes'] += len(data)
                    keep = data[:max(0, LOG_LIMIT - info['retained_bytes'])]
                    target.write(keep)
                    target.flush()
                    info['retained_bytes'] += len(keep)
                    if len(keep) != len(data):
                        info['truncated'] = True
                        exceeded.set()
            info['status'] = 'closed'
        except BaseException as error:
            info.update(status='error', error=repr(error))
            exceeded.set()

    try:
        if threading.current_thread() is threading.main_thread():
            previous_sigterm = signal.signal(signal.SIGTERM, interrupted)
        child = subprocess.Popen(command, cwd=cwd, stdout=subprocess.PIPE,
                                 stderr=subprocess.PIPE, creationflags=creationflags)
        receipt.update(status='running', pid=child.pid)
        for name in ('stdout', 'stderr'):
            receipt['streams'][name] = {'status': 'reading', 'observed_bytes': 0,
                                        'retained_bytes': 0, 'truncated': False, 'error': None}
            reader = threading.Thread(target=capture, args=(getattr(child, name), name), daemon=True)
            readers.append(reader)
            reader.start()
        write_json(receipt_path, receipt)
        deadline = time.monotonic() + timeout
        while child.poll() is None:
            if exceeded.is_set():
                raise RuntimeError('Native stream capture exceeded its bound or failed')
            check_output_budget(output)
            if time.monotonic() >= deadline:
                raise subprocess.TimeoutExpired(command, timeout)
            time.sleep(0.05)
        receipt['returncode'] = child.returncode
        receipt['status'] = 'exited'
    except BaseException as error:
        failure = error
        receipt.update(status='interrupted' if isinstance(error, KeyboardInterrupt) else 'failed',
                       error_type=type(error).__name__, error=repr(error))
        if child is not None:
            try:
                if child.poll() is None:
                    child.kill()
                child.wait(timeout=5)
            except BaseException as cleanup_error:
                receipt['direct_child_stop_error'] = repr(cleanup_error)
    finally:
        for reader in readers:
            if reader.ident is not None:
                reader.join(timeout=1)
        receipt['stream_writers_closed'] = all(not reader.is_alive() for reader in readers)
        receipt['direct_child_exited'] = child is not None and child.poll() is not None
        receipt['retention_complete'] = (receipt['stream_writers_closed'] and not exceeded.is_set()
                                         and len(receipt['streams']) == 2
                                         and all(info['status'] == 'closed' for info in receipt['streams'].values()))
        if receipt['stream_writers_closed'] and child is not None:
            child.stdout.close()
            child.stderr.close()
        if previous_sigterm is not None:
            signal.signal(signal.SIGTERM, previous_sigterm)
        try:
            write_json(receipt_path, receipt)
        except BaseException as retention_error:
            if failure is None:
                raise
            print('Phase receipt finalization failed: ' + repr(retention_error), file=sys.stderr)
    if failure is not None:
        raise failure
    stdout = bounded_text(output / (phase + '.stdout.log')) if (output / (phase + '.stdout.log')).exists() else ''
    stderr = bounded_text(output / (phase + '.stderr.log')) if (output / (phase + '.stderr.log')).exists() else ''
    if exceeded.is_set() or not receipt['stream_writers_closed']:
        raise RuntimeError('Native stream retention incomplete or over limit; see phase receipt')
    check_output_budget(output)
    return subprocess.CompletedProcess(command, child.returncode, stdout, stderr)


def bounded_digest(path, limit):
    digest = hashlib.sha256()
    size = 0
    with path.open('rb') as stream:
        while chunk := stream.read(65536):
            size += len(chunk)
            if size > limit:
                raise RuntimeError('Generated evidence exceeds alias bound: ' + str(path))
            digest.update(chunk)
    return size, digest.hexdigest()


def retain_upload_aliases(output, generated, manifest):
    """Copy only this flax run's enumerated files to nonhidden artifact paths."""
    if len(generated) not in (6, 8):
        raise RuntimeError('Upload aliases require the enumerated owned flax files')
    prefix = generated[0].name.removesuffix('.dme')
    if (not re.fullmatch(r'\.flax_probe_[0-9a-f]{32}', prefix)
            or [path.name for path in generated] != [prefix + suffix for suffix in GENERATED_SUFFIXES[:len(generated)]]
            or any(path.parent.resolve() != ROOT.resolve() for path in generated)):
        raise RuntimeError('Upload aliases require the enumerated owned flax files')
    manifest['upload_aliases'] = []
    manifest['upload_alias_status'] = 'retaining'
    for index, original in enumerate(generated):
        binary = original.suffix in ('.dmb', '.rsc')
        limit = ARTIFACT_LIMIT if binary else INPUT_LIMIT
        alias = Path('generated-artifacts' if binary else 'generated-inputs') / ('generated-' + str(index) + original.suffix)
        record = {'original_path': str(original), 'alias_path': alias.as_posix(),
                  'limit_bytes': limit, 'status': 'missing'}
        manifest['upload_aliases'].append(record)
        if original.is_symlink():
            raise RuntimeError('Generated evidence must not be a symlink: ' + str(original))
        if not original.exists():
            continue  # Compiled outputs are absent during prelaunch source retention.
        if not original.is_file() or original.stat().st_size > limit:
            raise RuntimeError('Generated evidence exceeds alias bound: ' + str(original))
        destination = output / alias
        if destination.parent.is_symlink() or destination.is_symlink():
            raise RuntimeError('Upload alias must not follow a symlink: ' + str(destination))
        size, digest = bounded_digest(original, limit)
        record.update(bytes=size, sha256=digest)
        if not destination.exists():
            count, total = check_output_budget(output)
            if count + 1 > FILE_LIMIT or total + size > OUTPUT_LIMIT:
                raise RuntimeError('Upload alias exceeds task-owned output budget')
            destination.parent.mkdir(exist_ok=True)
            record['status'] = 'copying'
            with original.open('rb') as source, destination.open('xb') as target:
                copied = 0
                while chunk := source.read(65536):
                    copied += len(chunk)
                    if copied > size:
                        raise RuntimeError('Generated evidence changed while aliasing: ' + str(original))
                    target.write(chunk)
        if bounded_digest(destination, limit) != (size, digest):
            raise RuntimeError('Preserve mismatched upload alias: ' + str(destination))
        record['status'] = 'retained'
    manifest['upload_alias_status'] = 'complete_for_existing_generated_files'


def retain_manifest(output, generated, manifest, *, finalized=False):
    """Inventory known generated files and stable diagnostic paths; never delete.

    Source snapshots are written before native launch, so an uncatchable process
    exit still leaves inputs and live logs in their persistent owned locations.
    """
    alias_error = None
    if 'upload_aliases' in manifest:  # Flax opt-in only; shared harvest retention is unchanged.
        try:
            retain_upload_aliases(output, generated, manifest)
        except BaseException as error:
            alias_error = error
            manifest.update(upload_alias_status='failed', upload_alias_error=repr(error))
    records = []
    for path in generated:
        record = {'path': str(path), 'exists': path.exists()}
        if path.exists():
            size = path.stat().st_size
            record.update(bytes=size, within_bound=size <= (ARTIFACT_LIMIT if path.suffix in ('.dmb', '.rsc') else INPUT_LIMIT))
            if path.suffix not in ('.dmb', '.rsc') and size <= INPUT_LIMIT:
                with path.open('rb') as stream:
                    data = stream.read(INPUT_LIMIT + 1)
                if len(data) <= INPUT_LIMIT:
                    record.update(sha256=hashlib.sha256(data).hexdigest(), bytes_hashed=len(data))
        records.append(record)
    manifest['generated'] = records
    manifest['finalized'] = finalized
    manifest['retained_outputs'] = []
    for index, path in enumerate(sorted(output.rglob('*'))):
        if index >= FILE_LIMIT:
            manifest['inventory_truncated'] = True
            break
        if path.is_file() and path.name != 'evidence-manifest.json':
            size = path.stat().st_size
            record = {'path': path.relative_to(output).as_posix(), 'bytes': size}
            if size <= LOG_LIMIT and path.suffix not in ('.dmb', '.rsc', '.sav'):
                with path.open('rb') as stream:
                    data = stream.read(LOG_LIMIT + 1)
                if len(data) <= LOG_LIMIT:
                    record.update(sha256=hashlib.sha256(data).hexdigest(), bytes_hashed=len(data))
            manifest['retained_outputs'].append(record)
    write_json(output / 'evidence-manifest.json', manifest)
    if alias_error is not None:
        raise alias_error
    if 'upload_aliases' in manifest:
        check_output_budget(output)


def entry_sources(control=None):
    """Whole production files, original same-path definitions and include order.

    The sole causal control restores both historical terminal calls in generated
    copies. It does not substitute a tester drop override or invoke soak directly.
    """
    if control not in (None, 'legacy-return'):
        raise ValueError('Unreviewed human-entry control')
    result = {}
    for path, guard in zip(ENTRY_SOURCES, ('internal_organs', 'organs')):
        source = (ROOT / path).read_text(encoding='utf-8')
        current = ('/mob/living/human/drop_from_inventory(var/obj/item/W, var/atom/Target = null)\n'
                   f'\tif (W in {guard})\n\t\treturn\n\treturn ..()')
        if source.count(current) != 1:
            raise RuntimeError('Production human drop definition missing or ambiguous: ' + path)
        result[path] = source.replace(current, current.removesuffix('return ..()') + '..()', 1) if control else source
    return result


def entry_dme(source, names):
    if len(names) != len(ENTRY_SOURCES):
        raise ValueError('Both production human definitions must be staged')
    for path, name in zip(ENTRY_SOURCES, names):
        include = '#include "' + path.replace('/', '\\') + '"'
        if source.count(include) != 1:
            raise RuntimeError('Production human include missing or ambiguous: ' + path)
        source = source.replace(include, '#include "' + name + '"', 1)
    return source


def runtime_identity(binary, archive):
    if sys.platform == 'linux':
        if archive is None:
            raise ValueError('--byond-archive is required for Linux fixture identity')
        return byond_runtime.verify_linux(binary, archive)
    # Existing Windows launch path is not archive/member verification evidence.
    return None


def check_compile(build, expected_version):
    output = build.stdout + build.stderr
    if build.returncode:
        raise RuntimeError('Fixture compiler exited nonzero: ' + output[-4000:])
    try:
        byond_toolchain.compiler_log(output, expected_version)
    except ValueError as error:
        raise RuntimeError('Fixture compiler version/result contract rejected: ' + output[-4000:]) from error


def source_for(control):
    source = (ROOT / CORE).read_text(encoding='utf-8')
    if control:
        old, new, _ = CONTROLS[control]
        if source.count(old) != 1:
            raise RuntimeError('Mutation target missing or ambiguous')
        source = source.replace(old, new, 1)
    return source


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument('--byond-bin', type=Path)
    parser.add_argument('--byond-archive', type=Path)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--negative-control', choices=CONTROLS)
    parser.add_argument('--human-entry', action='store_true')
    parser.add_argument('--entry-control', choices=('legacy-return',))
    parser.add_argument('--expected-head')
    parser.add_argument('--source-check', action='store_true')
    args = parser.parse_args()
    if (args.entry_control and not args.human_entry) or (args.human_entry and args.negative_control):
        parser.error('Human entry and processing controls must be selected separately')
    if args.source_check:
        for control in (None, *CONTROLS):
            source_for(control)
        entry_sources()
        entry_sources('legacy-return')
        print('PASS: source and unique mutation targets; no compiler/runtime launched')
        return
    if args.human_entry and sys.platform != 'linux':
        parser.error('Prepared human-entry lane requires the separately reviewed Linux run plan')
    if not args.byond_bin or not args.output:
        parser.error('--byond-bin and --output are required for native verification')
    if sys.platform == 'linux' and args.byond_archive is None:
        parser.error('--byond-archive is required for Linux fixture identity')
    requirement = byond_toolchain.load()
    args.output = args.output.resolve()
    args.output.mkdir(parents=True, exist_ok=True)
    if any(args.output.iterdir()):
        parser.error('Preserve existing evidence; use an empty output directory')
    binary = args.byond_bin.absolute()  # Preserve links/traversal for identity rejection.
    compiler = binary / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
    daemon = binary / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
    flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
    prefix = '.flax_probe_' + uuid.uuid4().hex
    generated = [ROOT / (prefix + suffix) for suffix in
                 ('.dme', '_world.dm', '_globals.dm', '_flax.dm', '.dmb', '.rsc')]
    if args.human_entry:
        generated.extend(ROOT / (prefix + suffix) for suffix in ('_living.dm', '_human.dm'))
    manifest = {'schema_version': 1, 'status': 'preparing', 'upload_aliases': [],
                'generated_prefix': prefix, 'runtime_directory': str(args.output / 'runtime'),
                'automatic_deletion': False, 'descendant_cleanup': 'unverified',
                'expected_diagnostics': ['compile.stdout.log', 'compile.stderr.log', 'compile-phase.json',
                                         'daemon.stdout.log', 'daemon.stderr.log', 'daemon-phase.json',
                                         'runtime/runtime.log', 'runtime/errors.txt', 'runtime/result.txt',
                                         'runtime/fixture.json', 'runtime/port-closed.txt'],
                'limits': {'stream_bytes': LOG_LIMIT, 'input_bytes': INPUT_LIMIT,
                           'artifact_bytes': ARTIFACT_LIMIT, 'observed_output_bytes': OUTPUT_LIMIT,
                           'inventory_files': FILE_LIMIT},
                'hard_live_file_quota': 'requires admitted external filesystem quota'}
    write_json(args.output / 'evidence-manifest.json', manifest)
    try:
        commit = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
        manifest['head_sha'] = commit
        if args.human_entry and args.expected_head != commit:
            raise RuntimeError('Human-entry run requires the exact reviewed --expected-head')
        if args.human_entry and subprocess.check_output(['git', 'status', '--porcelain', '--untracked-files=no'], cwd=ROOT, text=True, timeout=10).strip():
            raise RuntimeError('Human-entry run requires clean reviewed tracked inputs')
        probe = 'tests/flax_processing/human_entry_probe.dm' if args.human_entry else 'tests/flax_processing/probe.dm'
        paths = [CORE, 'code/modules/persistence/saving.dm',
                 'code/modules/persistence/loading.dm', 'code/modules/persistence/functions.dm',
                 'config/crafting/material_recipes_global.txt', 'code/modules/research_tree/research_node.dm',
                 probe, 'tests/flax_processing/run.py',
                 'scripts/byond_runtime.py', 'scripts/byond_toolchain.py', 'scripts/native_fixture.py',
                 'tools/byond/version.json']
        if args.human_entry:
            paths.extend(ENTRY_SOURCES)
            paths.extend(ENTRY_CONTRACTS)
        metadata = {'head_sha': commit, 'control': args.negative_control,
                    'probe': probe, 'entry_control': args.entry_control,
                    'expected_byond_version': requirement['version'],
                    'source_sha256': {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in paths}}
        write_json(args.output / 'metadata.json', metadata)
        patch_bytes = subprocess.check_output(['git', 'diff', 'HEAD'], cwd=ROOT)
        if len(patch_bytes) > INPUT_LIMIT:
            raise RuntimeError('Source patch exceeds evidence bound')
        (args.output / 'tested.patch').write_bytes(patch_bytes)
        world = (ROOT / 'code/world.dm').read_text(encoding='utf-8')
        start = world.index('/world/New()')
        parent = world.index('\n\t..()', start)
        world = world[:parent] + world[parent:].replace('\n\t..()', '', 1)
        world = world.replace('/world/New()', '/world/proc/unused_flax_startup()', 1)
        marker = '/datum/global_init/New()\n'
        if world.count(marker) != 1:
            raise RuntimeError('World isolation marker changed')
        generated[1].write_text(world.replace(marker, marker + '\treturn\n', 1), encoding='utf-8')
        globals_source = (ROOT / 'code/controllers/mc/globals.dm').read_text(encoding='utf-8')
        marker = '/datum/controller/global_vars/New()\n'
        if globals_source.count(marker) != 1:
            raise RuntimeError('Controller isolation marker changed')
        generated[2].write_text(globals_source.replace(marker, marker + '\treturn\n', 1), encoding='utf-8')
        generated[3].write_text(source_for(args.negative_control), encoding='utf-8')
        source = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
        source = source.replace('code\\world.dm', generated[1].name)
        source = source.replace('code\\controllers\\mc\\globals.dm', generated[2].name)
        if args.human_entry:
            staged = entry_sources(args.entry_control)
            for path, destination in zip(ENTRY_SOURCES, generated[6:]):
                destination.write_text(staged[path], encoding='utf-8')
            source = entry_dme(source, [path.name for path in generated[6:]])
        include = '#include "code\\modules\\1713\\flax_processing.dm"'
        if include in source:
            source = source.replace(include, '#include "' + generated[3].name + '"')
        else:
            source += '\n#include "' + generated[3].name + '"\n'
        source = re.sub(r'^#include ".*\.dmm".*$', '', source, flags=re.M)
        generated[0].write_text(source + '\n#include "' + probe + '"\n', encoding='utf-8')
        snapshots = args.output / 'generated-inputs'
        snapshots.mkdir()
        for path in generated:
            if path.suffix not in ('.dmb', '.rsc'):
                if path.stat().st_size > INPUT_LIMIT:
                    raise RuntimeError('Generated input exceeds evidence bound: ' + str(path))
                shutil.copy2(path, snapshots / path.name)
        # Persist inputs/ownership before either native launch. Even SIGKILL or
        # a failed finalizer cannot remove these snapshots or live runtime logs.
        retain_manifest(args.output, generated, manifest)
        identity = runtime_identity(binary, args.byond_archive)
        (args.output / 'compiler-runtime.json').write_text(json.dumps(identity, indent=2), encoding='utf-8')
        build = run_phase([str(compiler), '-max_errors', '0', str(generated[0])],
                          cwd=ROOT, output=args.output, phase='compile', timeout=180, creationflags=flags)
        output = build.stdout + build.stderr
        write_log(args.output / 'compile.log', output)
        check_compile(build, requirement['version'])
        # Retain nonhidden compiled evidence before starting the daemon too.
        retain_manifest(args.output, generated, manifest)
        work = args.output / 'runtime'
        work.mkdir()
        for path in generated[4:6]:
            if path.stat().st_size > ARTIFACT_LIMIT:
                raise RuntimeError('Compiled artifact exceeds retained bound: ' + str(path))
            shutil.copy2(path, work / path.name)
        shutil.copytree(ROOT / 'config/names', work / 'config/names')
        (work / 'config/crafting').mkdir(parents=True)
        shutil.copy2(ROOT / 'config/crafting/material_recipes_global.txt', work / 'config/crafting/material_recipes_global.txt')
        identity = runtime_identity(binary, args.byond_archive)
        (args.output / 'daemon-runtime.json').write_text(json.dumps(identity, indent=2), encoding='utf-8')
        result = run_phase([str(daemon), str(work / generated[4].name),
                                 *(['-invisible', '-close'] if os.name == 'nt' else []),
                                 *(no_port_args() if args.human_entry else []),
                                 '-trusted', '-params', f'tested_commit={commit}', '-log', 'runtime.log'], cwd=work,
                           output=args.output, phase='daemon', timeout=45, creationflags=flags)
        diagnostics = result.stdout + result.stderr
        for filename in ('runtime.log', 'errors.txt', 'result.txt', 'fixture.json', 'port-closed.txt'):
            path = work / filename
            if path.exists():
                bounded_text(path)
                shutil.copy2(path, args.output / filename)
                if filename in ('runtime.log', 'errors.txt'):
                    diagnostics += bounded_text(path)
        write_log(args.output / 'daemon.log', result.stdout + result.stderr)
        actual = bounded_text(work / 'result.txt').strip() if (work / 'result.txt').exists() else ''
        expected = CONTROLS[args.negative_control][2] if args.negative_control else 'PASS: flax processing and native disk round trips'
        if args.human_entry:
            expected = ('FAIL: human afterattack enters production wait' if args.entry_control
                        else 'PASS: production human flax afterattack entry and caller contracts')
            if not (work / 'port-closed.txt').exists() or bounded_text(work / 'port-closed.txt').strip() != 'closed':
                raise RuntimeError('Human-entry no-port assertion did not complete')
            if args.entry_control and 'ENTRY PASS: afterattack physically places the paid bundle before the entry oracle' not in diagnostics:
                raise RuntimeError('Legacy entry control lacks physical-placement evidence')
        if result.returncode or actual != expected or any(marker in diagnostics.lower() for marker in ('runtime error:', 'bug:', '## error:')):
            raise RuntimeError(f'Expected {expected!r}, got {actual!r}; diagnostics: {diagnostics[-2500:]}')
        print(('PASS expected mutation: ' if args.negative_control or args.entry_control else '') + actual)
        manifest['status'] = 'passed_expected_control' if args.negative_control or args.entry_control else 'passed'
    except BaseException as error:
        manifest.update(status='interrupted' if isinstance(error, KeyboardInterrupt) else 'failed',
                        error_type=type(error).__name__, error=repr(error))
        raise
    finally:
        original_error = sys.exc_info()[1]
        try:
            retain_manifest(args.output, generated, manifest, finalized=True)
        except BaseException as retention_error:
            if original_error is None:
                raise
            # Keep the original failure; persistent files are not removed even
            # when an inventory write fails (for example, a full filesystem).
            print('Evidence manifest finalization failed: ' + repr(retention_error), file=sys.stderr)


if __name__ == '__main__':
    main()

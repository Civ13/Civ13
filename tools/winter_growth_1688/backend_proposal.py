"""Linux516.1688 controller; explicit opt-in plus exact actual-checkout admission.
No acquisition; bounded synthetic worlds only.
"""
import io
import json
import os
import re
import stat
import time
import zipfile
from pathlib import Path
from prepare import (ADAPTER, VERSION, HEAD, TREE, bounded_file, candidate_manifest, digest,
                     dump, canonical, safe_root, verify_prepared, generated_files)
from plan import (PHASES, PROFILES, OUTPUT_LIMITS, RESTART_FILES, PRIVATE_HOME,
                  CLEANUP_RESERVE_SECONDS, copy_restart, activation_gate)
from receipts import LifecycleModel
from oracle import verify_result, verify_compile, diagnostics, strict_json
from header_preflight import validate_saved_headers

ARCHIVE = "16278f318cdeb4b77c57868dd7135032fde717ea6226269d22b2a1a50968e7f9"
OWNED_CONTROLLER = "b247b308ff088b832417466218b1b96f11be2f1a622e710749e92c77b451b1ea"
MEMBERS = ("DreamMaker", "DreamDaemon", "libbyond.so", "libext.so")
CONTROLLER_FILES = ("run.py", "prepare.py", "plan.py", "receipts.py", "oracle.py",
                    "backend_proposal.py", "owned_process_1688.py", "admission.py", "source-manifest.json", "source-equivalence.json", "check_checkout.py", "header_preflight.py", "probe.dm", "food-save.dm", "wrapper.dm", "grant.py")
DIRECTORY_FLAGS = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW


def read(path, limit=4 * 1024**2):
    return bounded_file(path, limit).decode("utf-8-sig", errors="strict")


def binaries(directory, archive):
    archive_data = bounded_file(archive, 64 * 1024**2)
    if digest(archive_data) != ARCHIVE:
        raise ValueError("Unreviewed BYOND archive bytes")
    rows = {}
    with zipfile.ZipFile(io.BytesIO(archive_data)) as content:
        if len(content.namelist()) != len(set(content.namelist())):
            raise ValueError("Duplicate archive members")
        for name in MEMBERS:
            item = content.getinfo("byond/bin/" + name)
            if item.file_size > 64 * 1024**2:
                raise ValueError("Unexpected runtime member size")
            expected = digest(content.read(item))
            data = bounded_file(directory / name, 64 * 1024**2)
            if len(data) != item.file_size or digest(data) != expected:
                raise ValueError("Runtime member bytes differ: " + name)
            rows[name] = expected
    return rows


def directory_fd(path):
    """Anchor a task path without following any symlink component."""
    path = path.absolute()
    if ".." in path.parts:
        raise ValueError("Inventory path contains parent traversal")
    fd = os.open(path.anchor, DIRECTORY_FLAGS)
    try:
        for part in path.parts[1:]:
            child = os.open(part, DIRECTORY_FLAGS, dir_fd=fd)
            os.close(fd)
            fd = child
        return fd
    except BaseException:
        os.close(fd)
        raise


def child_directory_fd(parent, name, observed):
    fd = os.open(name, DIRECTORY_FLAGS, dir_fd=parent)
    try:
        current = os.fstat(fd)
        if (not stat.S_ISDIR(current.st_mode) or
                (current.st_dev, current.st_ino) != (observed.st_dev, observed.st_ino)):
            raise ValueError("Inventory directory identity changed")
        return fd
    except BaseException:
        os.close(fd)
        raise


def private_home_inventory(work):
    """Inspect metadata only in fresh task HOME; never follow links or retain data."""
    totals = {"files": 0, "bytes": 0, "directories": 0}

    def visit(fd, depth):
        with os.scandir(fd) as entries:
            for entry in entries:
                if not re.fullmatch(r"[A-Za-z0-9_.-]{1,80}", entry.name):
                    raise ValueError("Unexpected private HOME entry name")
                if depth == 0 and entry.name != ".byond":
                    raise ValueError("Only .byond is permitted under private HOME")
                if depth + 1 > PRIVATE_HOME["depth"]:
                    raise ValueError("Private HOME depth exceeds bound")
                info = os.stat(entry.name, dir_fd=fd, follow_symlinks=False)
                if stat.S_ISDIR(info.st_mode):
                    totals["directories"] += 1
                    if totals["directories"] > PRIVATE_HOME["directories"]:
                        raise ValueError("Private HOME directory count exceeds bound")
                    child = child_directory_fd(fd, entry.name, info)
                    try:
                        visit(child, depth + 1)
                    finally:
                        os.close(child)
                elif stat.S_ISREG(info.st_mode) and depth > 0:
                    if info.st_nlink != 1:
                        raise ValueError("Private HOME hard links are not permitted")
                    totals["files"] += 1
                    totals["bytes"] += info.st_size
                    if (totals["files"] > PRIVATE_HOME["files"] or
                            info.st_size > PRIVATE_HOME["file_bytes"] or
                            totals["bytes"] > PRIVATE_HOME["total_bytes"]):
                        raise ValueError("Private HOME file count or size exceeds bound")
                else:
                    raise ValueError("Private HOME contains a link or non-regular entry")
    try:
        root = directory_fd(work)
        try:
            try:
                info = os.stat("home", dir_fd=root, follow_symlinks=False)
            except FileNotFoundError:
                return totals
            if not stat.S_ISDIR(info.st_mode):
                raise ValueError("Private HOME must be a real task directory")
            home = child_directory_fd(root, "home", info)
            try:
                visit(home, 0)
            finally:
                os.close(home)
        finally:
            os.close(root)
    except OSError as error:
        raise ValueError("Private HOME metadata inspection failed") from error
    return totals


def outside_home_entries(work):
    """Stream no-follow metadata; reject each directory before traversal resumes."""
    def visit(fd, prefix):
        with os.scandir(fd) as entries:
            for entry in entries:
                relative = prefix + entry.name
                info = os.stat(entry.name, dir_fd=fd, follow_symlinks=False)
                yield relative, info
                if stat.S_ISDIR(info.st_mode) and relative != "home":
                    child = child_directory_fd(fd, entry.name, info)
                    try:
                        yield from visit(child, relative + "/")
                    finally:
                        os.close(child)
    try:
        root = directory_fd(work)
        try:
            yield from visit(root, "")
        finally:
            os.close(root)
    except OSError as error:
        raise ValueError("Output metadata inspection failed") from error


def controller_hashes():
    root = Path(__file__).absolute().parent
    rows = {name: digest(bounded_file(root / name)) for name in CONTROLLER_FILES}
    if rows['owned_process_1688.py'] != OWNED_CONTROLLER:
        raise ValueError('Reviewed retained-leader controller changed')
    return rows


def output_inventory(work, inputs):
    """Bound sampled metadata without reading private HOME contents.

    This is sampled containment, not a disk quota or proof of no transient file.
    Full source/input hashes are checked before and after every invocation.
    """
    private = private_home_inventory(work)
    extras = total = directories = 0
    for name, info in outside_home_entries(work):
        if stat.S_ISDIR(info.st_mode):
            directories += 1
            if directories > 12000:
                raise ValueError('Output directory bound exceeded')
            continue
        if not stat.S_ISREG(info.st_mode) or info.st_nlink != 1:
            raise ValueError('Linked or nonregular output: ' + name)
        if name in inputs:
            if info.st_size != inputs[name]['bytes']:
                raise ValueError('Input size changed')
            continue
        extras += 1
        total += info.st_size
        cap = OUTPUT_LIMITS['individual_log_bytes'] if name.endswith('.log') else 16 * 1024**2
        if name in ('winter1688.dmb', 'winter1688.rsc'):
            cap = OUTPUT_LIMITS['compiled_pair_bytes']
        if info.st_size > cap or extras > OUTPUT_LIMITS['runtime_extra_files']:
            raise ValueError('Output count or individual size exceeded')
    compiled = sum((work / name).stat().st_size for name in ('winter1688.dmb', 'winter1688.rsc')
                   if (work / name).exists() and name not in inputs)
    if compiled > OUTPUT_LIMITS['compiled_pair_bytes'] or total - compiled > OUTPUT_LIMITS['runtime_extra_bytes']:
        raise ValueError('Output aggregate exceeded')
    return {'extra_files': extras, 'extra_bytes': total, 'private_home_metadata': private}


def auxiliary_logs(work, inputs):
    """Read every generated log after owned cleanup, never private HOME/input logs."""
    logs = {}
    for name, info in outside_home_entries(work):
        if name not in inputs and name.endswith('.log') and not stat.S_ISDIR(info.st_mode):
            content = read(work / name, OUTPUT_LIMITS['individual_log_bytes'])
            diagnostics(content)
            logs[name] = content
    return logs


def aggregate_inventory(root):
    total = count = 0
    # Metadata only; do not read BYOND private HOME data or follow any link.
    for folder, dirs, files in os.walk(root, followlinks=False):
        for name in dirs:
            if (Path(folder) / name).is_symlink():
                raise ValueError('Linked evidence directory')
        for name in files:
            info = (Path(folder) / name).stat(follow_symlinks=False)
            if not stat.S_ISREG(info.st_mode) or info.st_nlink != 1:
                raise ValueError('Linked or nonregular evidence')
            count += 1
            total += info.st_size
            if count > 100000 or total > OUTPUT_LIMITS['aggregate_evidence_bytes']:
                raise ValueError('Aggregate evidence bound exceeded')
    return {'bytes': total, 'files': count}


def verify_inputs(work, rows):
    for name, row in rows.items():
        data = bounded_file(work / name, max(row['bytes'], 1))
        if {'bytes': len(data), 'sha256': digest(data)} != row:
            raise ValueError('Phase input changed: ' + name)


def write_input(work, name, data, rows):
    target = work / name
    target.parent.mkdir(parents=True, exist_ok=True)
    with target.open('xb') as stream:
        stream.write(data)
    rows[name] = {'bytes': len(data), 'sha256': digest(data)}


def stage_runtime_names(source, manifest, work, inputs):
    """Stage only candidate-bound name tables required by full-source globals.

    Production uses double-quoted file2list paths, not compiled RSC resources.
    Enumerate the manifest, never copy an unbounded/unverified source directory.
    All copies join immutable inputs verified before and after each daemon.
    """
    declaration = bounded_file(source / 'code/names.dm')
    row = manifest['code/names.dm']
    if len(declaration) != row['size'] or digest(declaration) != row['sha256']:
        raise ValueError('Name declarations differ from candidate')
    required = set(re.findall(r'file2list\s*\(\s*"(config/names/[^"\n]+)"', declaration.decode('utf-8')))
    names = sorted(name for name in manifest if name.startswith('config/names/'))
    if not required or not required.issubset(names):
        raise ValueError('Required runtime name table absent from candidate')
    for name in names:
        if len(Path(name).parts) != 3 or Path(name).name in ('.', '..'):
            raise ValueError('Unexpected runtime name path')
        data = bounded_file(source / name)
        row = manifest[name]
        if len(data) != row['size'] or digest(data) != row['sha256']:
            raise ValueError('Runtime name table differs from candidate: ' + name)
        write_input(work, name, data, inputs)
    verify_inputs(work, {name: inputs[name] for name in names})
    return names


def retire_reproducible_inputs(work, phase_receipt, manifest, inputs):
    """Retire only verified task copies after successful oracle and owned cleanup.

    Compile originals (DMB/RSC), generated overlays, hashes, logs and saves stay.
    A partial failure retains a precise deletion ledger and stops the run.
    """
    work = safe_root(work)
    if phase_receipt.get('phase') != work.name:
        raise ValueError('Retirement phase/work identity mismatch')
    fixed = {phase: (role, variant, mode) for phase, role, variant, mode in PHASES}
    if work.name not in fixed:
        raise ValueError('Unknown retirement phase')
    role, variant, mode = fixed[work.name]
    if phase_receipt.get('role') != role:
        raise ValueError('Retirement role mismatch')
    for flag in ('started', 'terminated', 'process_completed', 'cleanup_verified', 'validated'):
        if phase_receipt.get(flag) is not True:
            raise ValueError('Retirement requires successful validated owned cleanup')
    if phase_receipt.get('verdict') != ('causal-control-detected' if role == 'daemon' and variant != 'baseline' else 'passed'):
        raise ValueError('Retirement requires exact successful oracle verdict')
    ledger_path = work / 'retired-inputs.json'
    if ledger_path.exists() or ledger_path.is_symlink():
        raise ValueError('Retirement ledger already exists')
    process = phase_receipt.get('process_receipt', {})
    if (process.get('process_started') is not True or type(phase_receipt.get('pid')) is not int
            or phase_receipt['pid'] <= 0 or process.get('pid') != phase_receipt['pid']):
        raise ValueError('Retirement process identity not bound')
    required = ('termination_observed', 'leader_reaped', 'cleanup_verified',
                'cleanup_no_observed_live_descendants', 'cleanup_process_group_absent',
                'owned_child_listing_available', 'owned_observation_trusted', 'signal_handlers_restored')
    if (any(process.get(k) is not True for k in required) or process.get('cleanup_errors') != []
            or process.get('stop_reason') is not None or type(process.get('exit_code')) is not int
            or process['exit_code'] != 0 or process.get('log_truncated') is not False):
        raise ValueError('Retirement cleanup evidence incomplete')
    names = sorted(manifest) if role == 'compiler' else ['winter1688.dmb', 'winter1688.rsc']
    expected = {}
    for name in names:
        if Path(name).is_absolute() or '..' in Path(name).parts or '.git' in Path(name).parts:
            raise ValueError('Invalid retirement path')
        row = inputs[name]
        if role == 'compiler' and row != {'bytes': manifest[name]['size'], 'sha256': manifest[name]['sha256']}:
            raise ValueError('Retirement source copy differs from immutable manifest')
        expected[name] = row
    # Check all targets first: a known mismatch causes zero deletions.
    verify_inputs(work, expected)
    ledger = {'phase': work.name, 'status': 'in-progress', 'files': expected,
              'retired': [], 'unique_evidence_retired': False,
              'reconstruct_from': 'exact production checkout' if role == 'compiler' else variant + '-compile sealed DMB/RSC'}
    with ledger_path.open('xb') as stream:
        stream.write(canonical(ledger))
    try:
        for name in names:
            verify_inputs(work, {name: expected[name]})
            (work / name).unlink()
            ledger['retired'].append(name)
        ledger['status'] = 'completed'
        dump(work / 'retired-inputs.json', ledger)
    except BaseException as error:
        ledger['status'] = 'failed'
        ledger['error'] = str(error)
        dump(work / 'retired-inputs.json', ledger)
        raise
    return ledger


def listener_ack(work, binding, variant, mode, sample_inventory, proc_identity):
    state = {'acknowledged': False}
    expected = {'schema': 1, 'adapter': ADAPTER, 'candidate_manifest_sha256': binding,
                'version': VERSION, 'variant': variant, 'phase': mode, 'port': 0, 'head': HEAD, 'tree': TREE}

    def sample(pid, identity, observed):
        sample_inventory()
        if state['acknowledged']:
            return
        ready = work / 'winter-native-ready.json'
        if not ready.exists():
            return
        ack = work / 'winter-native-go.txt'
        if ack.exists() or ack.is_symlink():
            raise ValueError('Preexisting closure acknowledgement')
        value = strict_json(read(ready, 16384))
        if value != expected or type(value.get('port')) is not int or type(value.get('schema')) is not int:
            raise ValueError('Unbound closure readiness')
        current = proc_identity(pid)
        if current is None or current['start_ticks'] != identity['start_ticks'] or current['state'] in ('Z', 'X'):
            raise ValueError('Leader not alive at closure census')
        sockets = set()
        seen = []
        for child, old in observed.items():
            current = proc_identity(child)
            if current is None or current['start_ticks'] != old['start_ticks']:
                raise ValueError('Owned identity disappeared during census')
            if current['state'] in ('Z', 'X'):
                continue
            for fd in Path(f'/proc/{child}/fd').iterdir():
                try:
                    link = os.readlink(fd)
                except FileNotFoundError as error:
                    raise ValueError('FD inventory raced during census') from error
                if link.startswith('socket:['):
                    sockets.add(link[8:-1])
            seen.append(current)
        listeners = []
        for table in ('tcp', 'tcp6'):
            for line in Path(f'/proc/{pid}/net/{table}').read_text().splitlines()[1:]:
                fields = line.split()
                if fields[3] == '0A' and fields[9] in sockets:
                    listeners.append({'table': table, 'local': fields[1], 'inode': fields[9]})
        if listeners:
            raise ValueError('Owned listening socket at closure census')
        current = proc_identity(pid)
        if current is None or current['start_ticks'] != identity['start_ticks'] or current['state'] in ('Z', 'X'):
            raise ValueError('Leader exited during closure census')
        dump(work / 'listener-census.json', {'leader': identity, 'owned': seen, 'listeners': [], 'port': 0})
        with ack.open('x') as stream:
            stream.write(binding + ':' + variant + ':' + mode)
        state['acknowledged'] = True

    return sample, state


def run_native(source, manifest_path, prepared, output, binary, archive, *, reviewed_native=False, grant_path=None):
    """Explicit native invocation after exact real-checkout and source admission."""
    activation_gate(reviewed_native)  # Must precede native-controller import and IO.
    if grant_path is None:
        raise ValueError("Exact one-shot grant path required")
    from owned_process_1688 import BoundedProcessError, run_bounded, proc_identity

    source, prepared, binary = map(safe_root, (source, prepared, binary))
    output = output.absolute()
    if output.exists() or any(p.is_symlink() for p in output.parents):
        raise ValueError('Execution output must be a fresh unlinked directory')
    if any(output == p or p in output.parents or output in p.parents for p in (source, prepared, binary)):
        raise ValueError('Execution output must be separate from inputs')
    preparation = json.loads(read(prepared / 'preparation.json', 4 * 1024**2))
    verify_prepared(prepared, preparation)
    if preparation['git_head'] != HEAD or preparation['git_tree'] != TREE:
        raise ValueError('Native preparation must come from actual exact checkout')
    raw, manifest = candidate_manifest(source, manifest_path)
    binding = digest(raw)
    if preparation['candidate_manifest_sha256'] != binding:
        raise ValueError('Preparation source differs')
    for name, row in preparation['inputs'].items():
        expected = manifest.get(name)
        if expected is None or row != {'bytes': expected['size'], 'sha256': expected['sha256']}:
            raise ValueError('Prepared input is not bound to candidate manifest')
    controller = controller_hashes()
    runtime = binaries(binary, archive)
    from grant import consume_grant
    grant_receipt = consume_grant(grant_path, controller, binding)
    model = LifecycleModel(binding, time.monotonic())
    model.state['evidence_kind'] = 'native-owned-process-execution'
    model.state.update(head=HEAD, tree=TREE, grant=grant_receipt)
    output.mkdir(parents=True)
    dump(output / 'controller-binding.json', controller)
    dump(output / 'runtime-binding.json', runtime)
    compiled = {}
    restart_receipt = None
    results = {}

    def checkpoint():
        verify_prepared(prepared, preparation)
        if candidate_manifest(source, manifest_path) != (raw, manifest):
            raise ValueError('Source checkout changed')
        if controller_hashes() != controller or binaries(binary, archive) != runtime:
            raise ValueError('Controller or runtime changed')
        aggregate_inventory(output)
        if time.monotonic() >= model.deadline - CLEANUP_RESERVE_SECONDS:
            raise ValueError('Aggregate deadline exhausted during preflight')

    try:
        for phase, role, variant, mode in PHASES:
            checkpoint()
            work = output / phase
            inputs = {}
            if role == 'compiler':
                work.mkdir()
                for name, row in manifest.items():
                    data = bounded_file(source / name)
                    if digest(data) != row['sha256']:
                        raise ValueError('Source changed during copy')
                    write_input(work, name, data, inputs)
                overlay = {name: bounded_file(prepared / 'inputs' / name)
                           for name in preparation['inputs']}
                for name, data in generated_files(overlay, binding, variant).items():
                    retained = bounded_file(prepared / 'generated' / variant / name)
                    if retained != data:
                        raise ValueError('Generated overlay differs from sealed preparation')
                    write_input(work, name, data, inputs)
                command = [str(binary / 'DreamMaker'), '-max_errors', '0', 'winter1688.dme']
            else:
                if mode == 'reader':
                    copy_restart(output / 'baseline-writer', work, restart_receipt, binding)
                    dump(work / 'header-preflight.json', validate_saved_headers(work, expected_files=restart_receipt['restart_files']))
                    for name in RESTART_FILES:
                        data = bounded_file(work / name, RESTART_FILES[name])
                        inputs[name] = {'bytes': len(data), 'sha256': digest(data)}
                else:
                    work.mkdir()
                for name, row in compiled[variant].items():
                    data = bounded_file(output / (variant + '-compile') / name, OUTPUT_LIMITS['compiled_pair_bytes'])
                    if digest(data) != row['sha256'] or len(data) != row['bytes']:
                        raise ValueError('Compiled input changed')
                    write_input(work, name, data, inputs)
                stage_runtime_names(source, manifest, work, inputs)
                command = [str(binary / 'DreamDaemon'), 'winter1688.dmb', '-ip', '127.0.0.1',
                           '-invisible', '-close', '-trusted', '-nowebclient', '-params',
                           'winter_phase=' + mode, '-log', 'runtime.log']
            checkpoint()
            verify_inputs(work, inputs)
            for folder in ('home', 'tmp'):
                (work / folder).mkdir()
            environment = {'HOME': str(work / 'home'), 'TMPDIR': str(work / 'tmp'),
                           'LANG': 'C', 'LC_ALL': 'C', 'TZ': 'UTC',
                           'BYOND_SYSTEM': str(binary.parent), 'LD_LIBRARY_PATH': str(binary)}
            profile = PROFILES[role]
            limits = {'cpu': profile['cpu_seconds'], 'as': profile['address_space_bytes'],
                      'file': profile['file_bytes'], 'fds': profile['file_descriptors']}
            wall = model.attempt(phase, time.monotonic())
            dump(work / 'input-hashes.json', inputs)
            dump(work / 'start.json', {'phase': phase, 'command': command, 'limits': limits,
                                     'wall_seconds': wall, 'candidate_manifest_sha256': binding})
            dump(output / 'result.json', model.state)

            def inventory_sample():
                output_inventory(work, inputs)
                aggregate_inventory(output)

            closure = {'acknowledged': False}
            if role == 'daemon':
                sample, closure = listener_ack(work, binding, variant, mode, inventory_sample, proc_identity)
            else:
                sample = lambda pid, identity, observed: inventory_sample()

            def started(pid, identity):
                model.started(pid)  # in-memory start fact before IO or /proc
                dump(work / 'started.json', {'pid': pid, 'phase': phase, 'identity': identity})
                dump(output / 'result.json', model.state)

            try:
                wall = min(wall, model.deadline - time.monotonic() - CLEANUP_RESERVE_SECONDS)
                if wall <= 0:
                    raise ValueError('Aggregate deadline exhausted before spawn')
                process = run_bounded(command, work, work / 'process.log', wall,
                                      profile['stdout_bytes'], environment, limits, sample, started)
            except BaseException as error:
                receipt = error.receipt if isinstance(error, BoundedProcessError) else None
                model.fail(str(error), receipt)
                if receipt is not None:
                    dump(work / 'process.json', receipt)
                dump(output / 'result.json', model.state)
                raise
            dump(work / 'process.json', process)
            model.process_returned(process)
            inventory_sample()
            verify_inputs(work, inputs)
            checkpoint()
            logs = auxiliary_logs(work, inputs)
            log = read(work / 'process.log')
            if role == 'compiler':
                verdict = verify_compile(log)
                compiled[variant] = {}
                for name in ('winter1688.dmb', 'winter1688.rsc'):
                    data = bounded_file(work / name, OUTPUT_LIMITS['compiled_pair_bytes'])
                    if not data:
                        raise ValueError('Empty compiled file')
                    compiled[variant][name] = {'bytes': len(data), 'sha256': digest(data)}
                if sum(row['bytes'] for row in compiled[variant].values()) > OUTPUT_LIMITS['compiled_pair_bytes']:
                    raise ValueError('Compiled pair bound exceeded')
                dump(work / 'compiled.json', compiled[variant])
            else:
                if not closure['acknowledged']:
                    raise ValueError('Missing owned closure acknowledgement')
                result = strict_json(read(work / 'winter-native-result.json'))
                native_log = read(work / 'runtime.log')
                # BYOND may put the complete transcript in runtime.log rather
                # than stdout. Only a complete exact oracle log can satisfy it.
                primary = native_log if 'GROWTH1688_RESULT ' in native_log else log
                auxiliary = logs
                expected_writer = None
                if mode == 'reader':
                    expected_writer = strict_json(read(work / 'winter-growth-writer.json', 1024**2))
                verdict = verify_result(binding, variant, mode, result, primary, auxiliary,
                                        expected_writer=expected_writer, process_receipt=process,
                                        expected_save_files=restart_receipt['restart_files'] if mode == 'reader' else None)
                if verdict['status'] == 'inconclusive':
                    model.inconclusive(verdict.get('reason', 'Stochastic growth inconclusive'), time.monotonic())
                    results[phase] = verdict
                    dump(output / 'phase-results.json', results)
                    dump(output / 'result.json', model.state)
                    # No passed receipt, retirement, reader admission or retry.
                    return results
            model.validate(verdict['status'], time.monotonic())
            results[phase] = verdict
            if phase == 'baseline-writer':
                restart_receipt = dict(model.state['phases'][-1])
                restart_receipt['restart_files'] = {}
                for name, limit in RESTART_FILES.items():
                    data = bounded_file(work / name, limit)
                    restart_receipt['restart_files'][name] = {'bytes': len(data), 'sha256': digest(data)}
                dump(work / 'restart-receipt.json', restart_receipt)
                dump(work / 'header-preflight.json', validate_saved_headers(work, expected_files=restart_receipt['restart_files']))
            dump(output / 'phase-results.json', results)
            dump(output / 'result.json', model.state)
            retire_reproducible_inputs(work, model.state['phases'][-1], manifest, inputs)
            aggregate_inventory(output)
        checkpoint()
        return results
    except BaseException as error:
        if model.state['status'] != 'failed':
            model.fail(str(error))
        dump(output / 'result.json', model.state)
        raise

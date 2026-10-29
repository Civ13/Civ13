"""Bounded, guest-only native renderer feasibility; never composition acceptance."""
import argparse
import ctypes as c
from ctypes import wintypes as w
import json
import os
from pathlib import Path
import re
import shutil
import socket
import subprocess
import sys
import time
import urllib.request
import uuid
import zipfile
import PIL
from PIL import Image, ImageGrab
from guard_config import VENDOR, LIMITS, digest
from entry_budget import Budget

ROOT = Path(__file__).resolve().parent
INSTALLED_MANIFEST_SHA256 = None  # Fresh 1688 installed-runtime review is pending.
INSTALLED_MANIFEST_SHAPE = None
LOCAL_RUNTIME_DLLS = ('mfc140u.dll', 'msvcp140.dll', 'vcruntime140.dll')
DIRECTX = {
    'd3dx9_43.dll': (1998168, '0b28546be22c71834501f7d7185ede5d79742457331c7ee09efc14490dd64f5f'),
    'D3DCompiler_43.dll': (2106216, '2f23182ec6f4889397ac4bf03d62536136c5bdba825c7d2c4ef08c827f3a8a1c'),
}
SHARED_EFFECTS = ['existing authentication may be used', 'registry/preferences may be shared',
                  'cache/recent connections may be written', 'shared screenshots may be written']



def source_identity():
    return {p.name: digest(p) for p in ROOT.iterdir() if p.is_file()}


def pillow_identity():
    return {str(Path(module.__file__).resolve()): digest(module.__file__)
            for module in (PIL, Image, ImageGrab, Image.core)}


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def exit_observations(roles):
    """Failure-time samples from retained handles, before cleanup Job termination."""
    rows = []
    for phase, adapter, process in roles:
        row = dict(phase=phase, observed_monotonic=None,
                   exited=None, exit_code=None, identity=None)
        for field, read in (
                ('observed_monotonic', time.monotonic),
                ('exited', lambda: adapter.exited(process)),
                ('identity', lambda: adapter.identity(process)),
                ('exit_code', lambda: adapter.finish(process)['exit_code'] if row['exited'] else None)):
            try:
                row[field] = read()
            except Exception as error:
                row.setdefault('diagnostic_errors', []).append(f'{field}: {error}'[:1024])
        rows.append(row)
    return rows


def read_json(path):
    require(path.is_file() and not path.is_symlink() and path.stat().st_size <= 65536,
            'Admission/manifest must be a bounded regular file')
    def unique(pairs):
        value = {}
        for key, item in pairs:
            require(key not in value, 'Duplicate admission/manifest key')
            value[key] = item
        return value
    return json.loads(path.read_text(), object_pairs_hook=unique)


def load_local(admission, reviewed_sha256, output, budget=None):
    # The digest must come from an independent review. JSON assertions are not
    # proof of isolation, consent, resource availability or reviewer identity.
    budget = budget if budget is not None else Budget()
    require(sys.platform == 'win32', 'Local-installed mode requires Windows')
    require(isinstance(reviewed_sha256, str) and re.fullmatch('[0-9a-f]{64}', reviewed_sha256),
            'An independently reviewed admission digest is required')
    packet = read_json(admission)
    budget.check()
    require(digest(admission) == reviewed_sha256, 'Admission differs from reviewed packet')
    require(type(packet['expires_unix']) in (int, float), 'Invalid grant expiry')
    budget.bind(packet['expires_unix'])
    from local_runtime import verify_runtime
    verify_runtime(packet['runtime'], budget.check)
    budget.check()
    require(packet['schema'] == 1 and packet['scope'] == 'dreamseeker-smoke-local-installed',
            'Wrong local admission scope')
    require(str(uuid.UUID(packet['one_use_id'])) == packet['one_use_id'], 'Noncanonical one-use ID')
    require(packet['output'] == str(output.resolve()) and not output.exists(),
            'Admission must bind fresh exact output')
    task_root = Path(packet['task_root']).resolve(strict=True)
    require(output.resolve().is_relative_to(task_root) and output.resolve() != task_root,
            'Output escapes admitted task directory')
    ledger = Path(packet['ledger']).resolve(strict=True)
    require(ledger.is_dir() and ledger.is_relative_to(task_root)
            and not ledger.is_relative_to(output.resolve()), 'Invalid durable one-use ledger')
    require(packet['host'] == os.environ.get('COMPUTERNAME')
            and packet['account'] == os.environ.get('USERDOMAIN', '') + '\\' + os.environ.get('USERNAME', ''),
            'Host/account differ from admission')
    require(packet['source_sha256'] == source_identity(), 'Reviewed source changed')
    budget.check()
    require(packet['python'] == {'path': str(Path(sys.executable).resolve()), 'sha256': digest(sys.executable)},
            'Python identity changed')
    budget.check()
    require(packet['pillow_version'] == PIL.__version__ and packet['pillow_sha256'] == pillow_identity(),
            'Pillow identity changed')
    budget.check()
    require(packet['limits'] == {'run_seconds': 150, 'cleanup_seconds_per_job': 5,
                               'cpu_seconds_per_process': 60, **LIMITS}, 'Unsupported limits')
    review = packet['review']
    require(all(isinstance(review.get(key), str) and review[key].strip()
                for key in ('reference', 'reviewer', 'resource_owner', 'executor', 'desktop_owner')),
            'Named independent review and resource/desktop ownership required')
    require(review['native_execution_approved'] is True and review['exclusive_desktop_approved'] is True
            and review['socket_polling_limitation_accepted'] is True, 'Execution/desktop/network admission absent')
    profile = packet['profile']
    require(isinstance(profile.get('evidence_reference'), str) and profile['evidence_reference'].strip(),
            'Profile decision evidence required')
    require((profile['decision'] == 'isolated_verified' and profile['accepted_effects'] == [])
            or (profile['decision'] == 'shared_effects_explicitly_accepted'
                and profile['accepted_effects'] == SHARED_EFFECTS), 'Unresolved profile/account decision')
    manifest_path = Path(packet['installed_manifest'])
    require(INSTALLED_MANIFEST_SHA256 is not None and INSTALLED_MANIFEST_SHAPE is not None,
            '516.1688 installed runtime has not been reviewed; native hold remains')
    manifest = read_json(manifest_path)
    budget.check()
    require(digest(manifest_path) == INSTALLED_MANIFEST_SHA256, 'Unknown installed identity record')
    budget.check()
    binary = Path(manifest['bin']).resolve(strict=True)
    rows = manifest['files']
    names = [row['name'] for row in rows]
    require((len(names), sum(row['bytes'] for row in rows)) == INSTALLED_MANIFEST_SHAPE
            and len(names) == len(set(names)),
            'Installed manifest shape changed')
    require({p.name for p in binary.iterdir()} == set(names), 'Unexpected installed bin entries')
    budget.check()
    for row in rows:
        path = binary / row['name']
        require(path.is_file() and not path.is_symlink() and path.stat().st_size == row['bytes']
                and digest(path) == row['sha256'], 'Installed bytes changed: ' + row['name'])
        budget.check()
    hashes = {row['name']: row['sha256'] for row in rows}
    require(all(hashes.get(name) == expected for name, expected in VENDOR['binaries'].items()),
            'Installed vendor pins differ')
    context = dict(packet=packet, packet_sha256=reviewed_sha256, binary=binary,
                   hashes={name: hashes[name] for name in (*VENDOR['binaries'], *LOCAL_RUNTIME_DLLS)},
                   receipt=ledger / (packet['one_use_id'] + '.json'), consumed=False, budget=budget)
    # Runtime/source identity was checked above in this admission boundary.
    # Retain deadline/resource validation without duplicating the full tree scan.
    local_deadline(context)
    context['monotonic_expiry'] = budget.full_end
    require(not context['receipt'].exists(), 'One-use admission already consumed')
    return context


def local_fresh(context):
    local_deadline(context)
    packet = context['packet']
    require(packet['source_sha256'] == source_identity(), 'Source changed before native launch')
    from local_runtime import verify_runtime
    verify_runtime(packet['runtime'], context['budget'].check)
    context['budget'].check()
    require(packet['python'] == {'path': str(Path(sys.executable).resolve()), 'sha256': digest(sys.executable)}
            and packet['pillow_version'] == PIL.__version__
            and packet['pillow_sha256'] == pillow_identity(), 'Interpreter/dependency identity changed')
    local_deadline(context)


def local_deadline(context):
    context['budget'].check()
    packet, now = context['packet'], time.time()
    issued, expires = packet['issued_unix'], packet['expires_unix']
    require(all(type(value) in (int, float) for value in (issued, expires))
            and issued <= now < expires and 0 < expires - issued <= 300,
            'Admission expired, future-dated or overlong')
    resources = packet['resources']
    require(type(resources['measured_unix']) in (int, float)
            and 0 <= now - resources['measured_unix'] <= 60
            and resources['free_ram_bytes'] >= 2 * 1024**3
            and resources['free_disk_bytes'] >= 1024**3
            and resources['cpu_headroom_accepted'] is True, 'Fresh admitted resources unavailable')
    context['budget'].check()


def stage_local(context, work):
    destination = work / 'byond' / 'bin'
    destination.mkdir(parents=True, exist_ok=False)
    for name, expected in context['hashes'].items():
        local_deadline(context)
        source = context['binary'] / name
        require(source.is_file() and not source.is_symlink() and digest(source) == expected,
                'Installed file changed before copy: ' + name)
        shutil.copyfile(source, destination / name)
        require(digest(destination / name) == expected, 'Staged binary differs: ' + name)
        local_deadline(context)
    return destination


def admit_local_launch(context, binary, adapter, output):
    local_fresh(context)
    require(adapter.free() >= 2 * 1024**3, 'Current RAM headroom unavailable')
    local_deadline(context)
    require(shutil.disk_usage(output).free >= 1024**3, 'Current disk headroom unavailable')
    local_deadline(context)
    require({p.name for p in binary.iterdir()} == set(context['hashes']), 'Unexpected staged bin entry')
    for name, expected in context['hashes'].items():
        path = binary / name
        require(path.is_file() and not path.is_symlink() and digest(path) == expected,
                'Staged bytes changed before launch')
        local_deadline(context)
    if not context['consumed']:
        # Exclusive final name is durable across task failures. Never delete or
        # recreate this receipt, even if no process starts after consumption.
        with context['receipt'].open('x', encoding='utf-8') as receipt:
            receipt.write(json.dumps({'one_use_id': context['packet']['one_use_id'],
                                      'admission_sha256': context['packet_sha256'],
                                      'consumed_unix': time.time(), 'output': str(output)}))
            receipt.flush()
            os.fsync(receipt.fileno())
        context['consumed'] = True
        context['receipt_sha256'] = digest(context['receipt'])
    else:
        require(context['receipt'].is_file() and digest(context['receipt']) == context['receipt_sha256'],
                'Consumed one-use receipt missing or changed')
    local_deadline(context)


def server_arguments(port):
    return ['fixture.dmb', str(port), '-ip', '127.0.0.1', '-invisible', '-trusted', '-nowebclient']


def pixel_contract(image, phase):
    if phase not in ('red', 'blue') or image.size != (224, 224):
        return False
    if image.mode == 'RGBA' and image.getchannel('A').getextrema() != (255, 255):
        return False
    wanted = (255, 0, 0) if phase == 'red' else (0, 0, 255)
    expected = Image.new('RGB', (224, 224), wanted)
    expected.paste((0, 255, 0), (96, 96, 128, 128))
    return image.convert('RGB').tobytes() == expected.tobytes()


def windows_directory():
    kernel = c.WinDLL('kernel32', use_last_error=True)
    kernel.GetWindowsDirectoryW.argtypes = [w.LPWSTR, w.UINT]
    kernel.GetWindowsDirectoryW.restype = w.UINT
    value = c.create_unicode_buffer(32768)
    length = kernel.GetWindowsDirectoryW(value, len(value))
    require(0 < length < len(value), 'Windows directory unavailable')
    return Path(value.value)


def graphics_prerequisites():
    """Read existing x86 system DLLs only; never install or substitute a DLL."""
    system = windows_directory() / 'SysWOW64'
    for parent in (system, *system.parents):
        require(parent.is_dir() and not parent.is_symlink()
                and not getattr(parent.stat(), 'st_file_attributes', 0) & 0x400,
                'Reviewed x86 system directory unavailable')
    rows = {}
    for name, (size, expected) in DIRECTX.items():
        path = system / name
        require(path.is_file() and not path.is_symlink()
                and not getattr(path.stat(), 'st_file_attributes', 0) & 0x400
                and path.stat().st_size == size and digest(path) == expected,
                'Reviewed x86 DirectX prerequisite missing or changed: ' + name)
        rows[name] = dict(bytes=size, sha256=expected, location='windows-x86-system')
    return rows


def socket_contract(rows, server=False, port=None):
    for row in rows:
        if row['protocol'] != 'tcp' or row['address'] != '127.0.0.1':
            raise RuntimeError('Unexpected owned socket: ' + str(row))
        if row['remote'] not in ('0.0.0.0', '127.0.0.1'):
            raise RuntimeError('Non-loopback peer: ' + str(row))
        if row['state'] == 'listen' and (not server or row['port'] != port):
            raise RuntimeError('Unexpected owned listener: ' + str(row))


def install(destination):
    archive = destination / 'vendor.zip'
    # Exact reference-observed mirror bytes; no alternate source or redirect.
    class NoRedirect(urllib.request.HTTPRedirectHandler):
        def redirect_request(self, *args, **kwargs):
            raise RuntimeError('Unexpected vendor redirect')
    with urllib.request.build_opener(NoRedirect()).open(VENDOR['url'], timeout=30) as response:
        if response.url != VENDOR['url']:
            raise RuntimeError('Unexpected vendor redirect')
        data = response.read(16 * 1024**2 + 1)
    if len(data) != VENDOR['bytes']:
        raise RuntimeError('Vendor archive exceeds bound')
    archive.write_bytes(data)
    if digest(archive) != VENDOR['sha256']:
        raise RuntimeError('Vendor archive hash mismatch')
    with zipfile.ZipFile(archive) as z:
        for entry in z.infolist():
            target = (destination / entry.filename).resolve()
            if not target.is_relative_to(destination.resolve()):
                raise RuntimeError('Unsafe vendor archive path')
        z.extractall(destination)
    binary = destination / 'byond' / 'bin'
    for name, expected in VENDOR['binaries'].items():
        if digest(binary / name) != expected:
            raise RuntimeError('Vendor binary hash mismatch: ' + name)
    return binary


def desktop_capture(adapter, process):
    require(not adapter.exited(process), 'Retained client exited before capture')
    identity = adapter.identity(process)
    require(identity['pid'] == process.pid, 'Retained client identity mismatch')
    pid = process.pid
    u = c.WinDLL('user32', use_last_error=True)
    u.GetForegroundWindow.restype = w.HWND
    u.GetWindowThreadProcessId.argtypes = [w.HWND, c.POINTER(w.DWORD)]
    u.IsWindowVisible.argtypes = [w.HWND]
    u.IsIconic.argtypes = [w.HWND]
    u.GetDpiForWindow.argtypes = [w.HWND]
    u.GetDpiForWindow.restype = w.UINT
    u.GetSystemMetrics.argtypes = [c.c_int]
    u.WindowFromPoint.argtypes = [w.POINT]
    u.WindowFromPoint.restype = w.HWND
    u.GetAncestor.argtypes = [w.HWND, w.UINT]
    u.GetAncestor.restype = w.HWND
    u.GetWindowTextLengthW.argtypes = [w.HWND]
    u.GetWindowTextW.argtypes = [w.HWND, w.LPWSTR, c.c_int]
    u.SetForegroundWindow.argtypes = [w.HWND]
    u.GetClientRect.argtypes = [w.HWND, c.POINTER(w.RECT)]
    u.ClientToScreen.argtypes = [w.HWND, c.POINTER(w.POINT)]
    callback_type = c.WINFUNCTYPE(w.BOOL, w.HWND, w.LPARAM)
    u.EnumWindows.argtypes = [callback_type, w.LPARAM]
    owned, visited = [], 0
    @callback_type
    def visit(hwnd, _):
        nonlocal visited
        visited += 1
        if visited > 512:
            return False
        owner = w.DWORD()
        u.GetWindowThreadProcessId(hwnd, c.byref(owner))
        if owner.value == pid and u.IsWindowVisible(hwnd):
            title = c.create_unicode_buffer(min(256, u.GetWindowTextLengthW(hwnd)) + 1)
            u.GetWindowTextW(hwnd, title, len(title))
            owned.append((hwnd, title.value))
        return True
    u.EnumWindows(visit, 0)
    require(visited <= 512, 'Window enumeration bound exceeded')
    if not owned:
        return None
    if len(owned) != 1 or owned[0][1] != 'Civ13 DreamSeeker smoke':
        raise RuntimeError('Unexpected client window/prompt; no interaction attempted: ' + repr(owned))
    hwnd = owned[0][0]
    u.SetForegroundWindow(hwnd)
    if u.GetForegroundWindow() != hwnd:
        raise RuntimeError('Owned window cannot acquire foreground on this runner')
    def rectangle():
        owner = w.DWORD()
        u.GetWindowThreadProcessId(hwnd, c.byref(owner))
        require(owner.value == pid, 'Owned client window identity changed')
        require(u.IsWindowVisible(hwnd) and not u.IsIconic(hwnd)
                and u.GetForegroundWindow() == hwnd and u.GetDpiForWindow(hwnd) == 96,
                'Owned visible foreground window at96DPI required')
        rect, point = w.RECT(), w.POINT()
        require(u.GetClientRect(hwnd, c.byref(rect)) and u.ClientToScreen(hwnd, c.byref(point)),
                'Owned client geometry unavailable')
        require((rect.left, rect.top, rect.right, rect.bottom) == (0, 0, 224, 224),
                'Exact224x224 client rectangle required')
        x, y, width, height = (u.GetSystemMetrics(n) for n in (76, 77, 78, 79))
        require(x <= point.x and y <= point.y
                and point.x + 224 <= x + width and point.y + 224 <= y + height,
                'Owned client rectangle is offscreen')
        for row in range(9):
            for column in range(9):
                hit = u.WindowFromPoint(w.POINT(point.x + column * 223 // 8,
                                              point.y + row * 223 // 8))
                require(hit and u.GetAncestor(hit, 2) == hwnd, 'Owned client rectangle is obscured')
        return (point.x, point.y, point.x + 224, point.y + 224)
    before = rectangle()
    image = ImageGrab.grab(before)
    require(rectangle() == before and not adapter.exited(process)
            and adapter.identity(process) == identity and image.size == (224, 224),
            'Owned client identity or geometry changed during capture')
    return image


def run(output, local_admission=None, reviewed_admission_sha256=None, *, budget=None):
    budget = budget if budget is not None else Budget()
    require(type(budget) is Budget, 'Original entry Budget required')
    budget.check()
    require(local_admission is not None or reviewed_admission_sha256 is None,
            'Reviewed digest requires explicit local admission mode')
    local = load_local(local_admission, reviewed_admission_sha256, output, budget) if local_admission is not None else None
    if local is None and (os.name != 'nt' or os.environ.get('GITHUB_ACTIONS') != 'true'):
        raise RuntimeError('This smoke runner is restricted to disposable Windows GitHub CI')
    from windows import Adapter
    output.mkdir(parents=True, exist_ok=False)
    work = output.parent / (output.name + '-private-work')
    evidence = {'scope': 'DreamSeeker feasibility only; no production composition acceptance',
                'vendor': VENDOR, 'captures': {}, 'cleanup': [], 'secondary_errors': []}
    if local is not None:
        evidence['local_admission'] = {'sha256': local['packet_sha256'],
                                     'one_use_id': local['packet']['one_use_id'],
                                     'consumption_receipt': str(local['receipt'])}
    adapters = []
    primary = None

    def check_work():
        budget.check()
        if local is not None:
            local_deadline(local)

    try:
        check_work()
        work.mkdir(exist_ok=False)
        evidence['head'] = subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip()
        check_work()
        evidence['source_sha256'] = source_identity()
        check_work()
        binary = install(work) if local is None else stage_local(local, work)
        check_work()
        evidence['graphics_prerequisites'] = graphics_prerequisites()
        check_work()
        fixture = work / 'fixture'
        fixture.mkdir()
        for name in ('fixture.dme', 'fixture.dm', 'fixture.dmf'):
            shutil.copyfile(ROOT / name, fixture / name)
        # An input sprite, not a screenshot or an acceptance reference.
        Image.new('RGBA', (32, 32), (255, 255, 255, 255)).save(fixture / 'tile.png')
        evidence['input_sprite_sha256'] = digest(fixture / 'tile.png')
        check_work()

        def launch(name, args, phase, visible=False):
            check_work()
            adapter = Adapter()
            # open() can retain a Job before configuration fails.
            adapters.append((adapter, None, phase))
            adapter.preflight(LIMITS)
            check_work()
            if local is not None:
                admit_local_launch(local, binary, adapter, output)
            check_work()
            adapter.open(creation_guard=check_work)
            check_work()
            process = adapter.launch([str(binary / name)] + args, fixture, output, phase, visible,
                                     creation_guard=check_work)
            adapters[-1] = (adapter, process, phase)
            return adapter, process

        def watch():
            check_work()
            for adapter, process, phase in adapters:
                check_work()
                if process is None or adapter.exited(process):
                    check_work()
                    continue
                check_work()
                if adapter.memory(process.process) > LIMITS['process_private_bytes']:
                    raise RuntimeError('Owned process memory bound exceeded')
                check_work()
                if adapter.times(process)[1] > 60:
                    raise RuntimeError('Owned process CPU bound exceeded')
                check_work()
                if adapter.accounting().total != 1:
                    raise RuntimeError('Unexpected child process')
                check_work()
                rows = adapter.sockets(process)
                check_work()
                socket_contract(rows, phase == 'server', port if phase == 'server' else None)
            for path in output.glob('*.log'):
                if path.stat().st_size > 1024**2:
                    raise RuntimeError('Log bound exceeded')
            check_work()
            time.sleep(min(.1, budget.remaining(work=True)))
            check_work()

        port = None
        compiler, compiled = launch('dm.exe', ['-max_errors', '0', 'fixture.dme'], 'compile')
        while True:
            check_work()
            exited = compiler.exited(compiled)
            check_work()
            if exited:
                break
            watch()
        logs = ''.join(p.read_text(errors='replace') for p in output.glob('compile.*.log'))
        if (compiler.finish(compiled)['exit_code'] != 0 or '0 errors, 0 warnings' not in logs
                or logs.count('DM compiler version 516.1688') != 1 or not (fixture/'fixture.dmb').is_file()):
            raise RuntimeError('Fixture compilation failed')
        check_work()
        with socket.socket() as probe:
            check_work()
            probe.bind(('127.0.0.1', 0))
            check_work()
            port = probe.getsockname()[1]
        check_work()
        server, serving = launch('dd.exe', server_arguments(port), 'server')
        while not (fixture/'ready.txt').exists():
            check_work()
            if server.exited(serving):
                raise RuntimeError('Server exited before readiness')
            watch()
        check_work()
        rows = server.sockets(serving)
        check_work()
        socket_contract(rows, True, port)
        if not any(r['state'] == 'listen' and r['port'] == port for r in rows):
            raise RuntimeError('Loopback-only server listener not proven')
        evidence['server_listener'] = rows
        client, playing = launch('dreamseeker.exe', [f'byond://127.0.0.1:{port}##guest'], 'client', True)
        for phase in ('red', 'blue'):
            previous = None
            while True:
                watch()
                if client.exited(playing) or server.exited(serving):
                    evidence['pre_cleanup_exits'] = exit_observations((
                        ('client', client, playing), ('server', server, serving)))
                    raise RuntimeError('Client/server exited before capture')
                check_work()
                image = desktop_capture(client, playing)
                check_work()
                if not (fixture/'client.txt').exists():
                    continue
                receipt = (fixture/'client.txt').read_text().strip()
                if receipt != 'guest=1;version=516;build=1688':
                    raise RuntimeError('Non-guest or wrong-build client')
                if not (fixture/'phase.txt').exists() or (fixture/'phase.txt').read_text().strip() != phase:
                    continue
                if image is None or not pixel_contract(image, phase):
                    continue
                pixels = image.tobytes()
                check_work()
                if pixels == previous:
                    target = output / (phase + '.png')
                    image.save(target)
                    check_work()
                    evidence['captures'][phase] = {'sha256': digest(target), 'size': image.size}
                    check_work()
                    (fixture/(phase+'-captured.txt')).write_text('captured')
                    check_work()
                    break
                previous = pixels
        evidence['client'] = receipt
        check_work()
        evidence['result'] = 'PASS native guest renderer smoke, composition UNTESTED'
    except BaseException as error:
        primary = error
        evidence['error'] = str(error)[:1024]
    finally:
        secondary = evidence['secondary_errors']
        for adapter, process, phase in reversed(adapters):
            wait = budget.cleanup_wait()
            row = {'phase': phase, 'wait_seconds': wait, 'all_exited': False}
            try:
                result = adapter.cleanup(process, wait)
                require(isinstance(result, dict), 'Invalid owned cleanup result')
                require(len(json.dumps(result)) <= 16384, 'Owned cleanup detail exceeds receipt bound')
                row.update(result)
                require(row.get('all_exited') is True, 'Owned process cleanup not confirmed')
            except BaseException as error:
                row['error'] = str(error)[:1024]
                secondary.append({'phase': phase, 'error': str(error)[:1024]})
            evidence['cleanup'].append(row)
        try:
            budget.check(work=False)
        except BaseException as error:
            secondary.append({'phase': 'finalization', 'error': str(error)[:1024]})
        if primary is not None or secondary:
            evidence['result'] = 'FAIL; no native acceptance'
        try:
            (output/'receipt.json').write_text(json.dumps(evidence, indent=2))
            budget.check(work=False)
        except BaseException as error:
            secondary.append({'phase': 'receipt', 'error': str(error)[:1024]})
            evidence['result'] = 'FAIL; receipt finalization unconfirmed'
            # One bounded corrective diagnostic write, no process or run retry.
            try:
                (output/'receipt.json').write_text(json.dumps(evidence, indent=2))
            except BaseException as receipt_error:
                secondary.append({'phase': 'receipt-write', 'error': str(receipt_error)[:1024]})
        if primary is not None:
            for row in secondary:
                primary.add_note(str(row)[:1200])
            raise primary
        require(not secondary, 'Owned cleanup/receipt finalization not confirmed: ' + str(secondary)[:4096])
    print(evidence['result'])


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--local-admission', type=Path)
    parser.add_argument('--reviewed-admission-sha256')
    args = parser.parse_args()
    run(args.output.resolve(), args.local_admission, args.reviewed_admission_sha256)

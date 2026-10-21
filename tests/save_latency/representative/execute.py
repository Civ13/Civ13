"""Explicit bounded native executor. Default CLI prints a plan and runs nothing."""
import argparse
from contextlib import contextmanager
from datetime import datetime, timedelta, timezone
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import secrets
import shutil
import socket
import stat
import subprocess
import threading
import time
import zipfile

import files
import helpers
import protocol
import sampler
import source

PROTECTED_PORTS = {1714, 1715, 18459, 18460, 18461, 18462}
CORE_SECONDS = 9810


def write(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n', encoding='utf-8')


def require_time(clock, deadline):
    if clock() >= deadline:
        raise TimeoutError('Frozen aggregate deadline exhausted')


def resource_packet(packet, now):
    """This is trusted operator allocation data, not an authorization signature."""
    if packet.get('schema') != 1 or packet.get('authorized') is not True or not packet.get('allocation_id'):
        raise ValueError('A current explicit resource allocation is required')
    expires = datetime.fromisoformat(packet['expires_utc'].replace('Z', '+00:00'))
    if expires.tzinfo is None or expires <= now:
        raise ValueError('Resource allocation expired')
    if packet.get('commits') != [source.REFERENCE, source.CANDIDATE]:
        raise ValueError('Resource allocation source pair changed')
    if (type(packet.get('port')) is not int or packet['port'] in PROTECTED_PORTS
            or not 1024 <= packet['port'] <= 65535):
        raise ValueError('Allocated port is protected or invalid')
    for name in ('setup_seconds', 'minimum_free_bytes', 'maximum_output_bytes', 'maximum_private_bytes',
                 'sampler_cadence_seconds', 'query_timeout_seconds', 'resource_cadence_seconds', 'no_save_seconds'):
        value = packet.get(name)
        if type(value) not in (int, float) or not 0 < value < float('inf'):
            raise ValueError('Missing finite allocated bound: ' + name)
    if packet.get('core_seconds') != CORE_SECONDS or packet['resource_cadence_seconds'] < 10:
        raise ValueError('Frozen core bound or minimum resource sampling spacing changed')
    if expires < now + timedelta(seconds=packet['setup_seconds'] + CORE_SECONDS):
        raise ValueError('Allocation does not cover the complete frozen envelope')
    if not isinstance(packet.get('listener_addresses'), list) or not packet['listener_addresses']:
        raise ValueError('Expected listener addresses must be frozen by the runtime owner')
    if not Path(packet['output']).is_absolute():
        raise ValueError('Allocated output must be absolute')
    root = files.unlinked(packet['output'])
    if root.exists() or not root.parent.is_dir():
        raise ValueError('Allocated output must be a new absolute unlinked directory')
    return root


def copy_tree(original, destination, clock, deadline):
    original, destination = files.unlinked(original), files.unlinked(destination)
    if destination.exists() or destination.is_relative_to(original):
        raise ValueError('Refusing existing or recursively nested output tree')
    destination.mkdir(parents=True)
    for path in original.rglob('*'):
        require_time(clock, deadline)
        files.unlinked(path)
        target = destination / path.relative_to(original)
        if path.is_dir():
            target.mkdir()
        elif path.is_file():
            with path.open('rb') as src, target.open('xb') as dst:
                for chunk in iter(lambda: src.read(1024 * 1024), b''):
                    require_time(clock, deadline)
                    dst.write(chunk)
        else:
            raise ValueError('Unsupported archive file kind')


def export(repository, commit, destination, effect, deadline, maximum_bytes):
    destination.mkdir(parents=True, exist_ok=False)
    archive = destination / 'source.zip'
    effect.run(['git', '-C', str(repository), 'archive', '--format=zip', '--output=' + str(archive), commit],
               cwd=destination, timeout=min(300, deadline-effect.clock()))
    game = destination / 'game'
    game.mkdir()
    with zipfile.ZipFile(archive) as zipped:
        if archive.stat().st_size + sum(member.file_size for member in zipped.infolist()) > maximum_bytes:
            raise ValueError('Archive exceeds allocated output ceiling')
        seen = set()
        for member in zipped.infolist():
            require_time(effect.clock, deadline)
            name = PurePosixPath(member.filename)
            if (name.is_absolute() or '..' in name.parts or ':' in member.filename or '\\' in member.filename
                    or member.filename.casefold() in seen or stat.S_ISLNK(member.external_attr >> 16)):
                raise ValueError('Unsafe or duplicate Git archive member')
            seen.add(member.filename.casefold())
            target = game.joinpath(*name.parts)
            if member.is_dir():
                target.mkdir(parents=True, exist_ok=True)
            else:
                target.parent.mkdir(parents=True, exist_ok=True)
                with zipped.open(member) as src, target.open('xb') as dst:
                    while chunk := src.read(1024 * 1024):
                        require_time(effect.clock, deadline)
                        dst.write(chunk)
    return game


def overlay(game, packet, manifest):
    for name, expected in manifest['source_sha256'].items():
        if files.file_sha(game / name) != expected:
            raise ValueError('Archive source differs: ' + name)
    generated = game / 'representative'
    generated.mkdir(exist_ok=False)
    for name, expected in manifest['generated_sha256'].items():
        if files.file_sha(packet / name) != expected:
            raise ValueError('Generated observer changed')
        shutil.copy2(packet / name, game / name if name == 'representative.dme' else generated / name)
    if files.file_sha(packet / 'probe.dm') != manifest['adapter_sha256']:
        raise ValueError('Test adapter changed')
    shutil.copy2(packet / 'probe.dm', generated / 'probe.dm')
    config = game / 'config/config.txt'
    blocked = {'HUB', 'SERVER', 'ALLOW_WEBCLIENT', 'WEBHOOK_CAN_FIRE', 'WEBHOOK_ADDRESS', 'WEBHOOK_KEY',
               'TORBAN', 'IPINTEL_EMAIL'}
    config.write_text('\n'.join(line for line in config.read_text(encoding='utf-8').splitlines()
                               if not line.strip() or line.strip().split()[0].upper() not in blocked) + '\n', encoding='utf-8')
    manifest['isolated_config_sha256'] = files.file_sha(config)
    token = secrets.token_hex(32)
    (game / 'config/full-map-probe-token.txt').write_text(token, encoding='ascii')
    for path in source.PRODUCTION:
        if files.file_sha(game / path) != manifest['source_sha256'][path]:
            raise ValueError('Production source changed while applying overlay')
    return token


class SystemEffects:
    clock = staticmethod(time.monotonic)
    sleep = staticmethod(time.sleep)
    utcnow = staticmethod(lambda: datetime.now(timezone.utc))

    @staticmethod
    def run(command, cwd, timeout):
        if timeout <= 0:
            raise TimeoutError('Subprocess budget exhausted')
        completed = subprocess.run(command, cwd=cwd, capture_output=True, timeout=timeout,
                                   creationflags=subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0)
        if completed.returncode:
            raise subprocess.CalledProcessError(completed.returncode, command,
                                                output=completed.stdout, stderr=completed.stderr)
        return completed.stdout + completed.stderr

    @staticmethod
    def launch(command, cwd, stdout, stderr):
        return subprocess.Popen(command, cwd=cwd, stdin=subprocess.DEVNULL, stdout=stdout, stderr=stderr,
                                creationflags=subprocess.CREATE_NO_WINDOW)

    @staticmethod
    def connect(address, timeout):
        return socket.create_connection(address, timeout=timeout)

    @staticmethod
    def available(port):
        with socket.socket() as probe:
            probe.bind(('127.0.0.1', port))

    @staticmethod
    def resources(pid):
        # Observation only; never rediscover a process for a stop operation.
        result = subprocess.run(['powershell', '-NoProfile', '-NonInteractive', '-Command',
            f'$p=Get-Process -Id {int(pid)} -ErrorAction Stop; '
            '[ordered]@{private_bytes=$p.PrivateMemorySize64;working_bytes=$p.WorkingSet64;'
            'cpu_seconds=$p.CPU;started_utc=$p.StartTime.ToUniversalTime().ToString("o")} | ConvertTo-Json -Compress'],
            capture_output=True, text=True, check=True, timeout=30,
            creationflags=subprocess.CREATE_NO_WINDOW)
        return json.loads(result.stdout)


@contextmanager
def owned_process(effect, command, directory, cleanup_seconds=30):
    """Only the returned process handle can be stopped; no disk/PID takeover."""
    with (directory / 'daemon.stdout.log').open('wb') as out, (directory / 'daemon.stderr.log').open('wb') as err:
        process = effect.launch(command, directory, out, err)
        try:
            yield process
        finally:
            try:
                if process.poll() is None:
                    process.terminate()
                    try:
                        process.wait(timeout=cleanup_seconds / 2)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait(timeout=cleanup_seconds / 2)
                if process.poll() is None:
                    raise RuntimeError('Owned exit unconfirmed; preserve all inputs and outputs')
                write(directory / 'exit.json', {'pid': process.pid, 'exit_code': process.poll(), 'owned_exit': True})
            except BaseException:
                write(directory / 'exit.json', {'pid': process.pid, 'owned_exit': False, 'preserve': True})
                raise


class Host:
    def __init__(self, effect, game, process, commit, packet, query_source, clock_deadline, listener):
        self.effect, self.game, self.process, self.commit = effect, game, process, commit
        self.packet, self.query_source, self.deadline, self.listener = packet, query_source, clock_deadline, listener
        self.monitor_failures = []
        self.dispatch_times = {}
        self.token = (game / 'config/full-map-probe-token.txt').read_text(encoding='ascii')

    def query(self, action, session, timeout=None):
        if self.monitor_failures:
            raise self.monitor_failures[0]
        require_time(self.effect.clock, self.deadline)
        if self.process.poll() is not None:
            raise RuntimeError('Owned daemon exited')
        if action != 'status':
            self.dispatch_times[action] = self.effect.clock()
            with (self.game / 'phase-events.jsonl').open('a') as stream:
                stream.write(json.dumps({'action': action, 'monotonic': self.effect.clock(), 'stage': 'dispatch'}) + '\n')
        result = helpers.query(self.query_source, self.effect.connect, self.effect.clock,
                               self.packet['port'], self.token, action, session,
                               min(timeout or self.packet['query_timeout_seconds'], self.deadline-self.effect.clock()))
        protocol.checked_status(result, self.commit, None if session == 'observe' else session)
        if action != 'status':
            with (self.game / 'phase-events.jsonl').open('a') as stream:
                stream.write(json.dumps({'action': action, 'monotonic': self.effect.clock(), 'stage': 'acknowledgment'}) + '\n')
        return result

    def baseline(self):
        deadline = min(self.deadline, self.effect.clock()+self.packet['no_save_seconds'])
        while self.effect.clock() < deadline:
            self.status()
            self.effect.sleep(min(.25, deadline-self.effect.clock()))

    def status(self):
        return self.query('status', 'observe')

    def until(self, predicate):
        while self.effect.clock() < self.deadline:
            if self.process.poll() is not None:
                raise RuntimeError('Owned process exited during phase')
            try:
                row = self.status()
                if predicate(row):
                    return row
            except (OSError, TimeoutError):
                pass
            self.effect.sleep(min(.25, max(0, self.deadline-self.effect.clock())))
        raise TimeoutError('Host phase exceeded frozen allocation')

    def poll(self, phase, session, deadline):
        result = self.until(lambda row: row['representative']['phase'] == phase)
        protocol.checked_status(result, self.commit, session)
        action = {'first_complete': 'first', 'second_complete': 'second', 'census_complete': 'census'}[phase]
        write(self.game / (phase + '-receipt.json'), {'monotonic': self.effect.clock(),
              'dispatch_monotonic': self.dispatch_times[action], 'elapsed_seconds': self.effect.clock()-self.dispatch_times[action],
              'status': result})
        return result


def generated_bytes(game):
    return sum(path.stat().st_size for path in game.rglob('*') if path.is_file())


def validate_resource(observation, owned, packet):
    if observation.get('started_utc') != owned['started_utc']:
        raise ValueError('Resource observation PID was replaced')
    for key in ('private_bytes', 'working_bytes', 'cpu_seconds', 'output_bytes'):
        value = observation.get(key)
        if type(value) not in (int, float) or not 0 <= value < float('inf'):
            raise ValueError('Resource metric unavailable: ' + key)
    if observation['private_bytes'] > packet['maximum_private_bytes'] or observation['output_bytes'] > packet['maximum_output_bytes']:
        raise RuntimeError('Allocated resource ceiling exceeded')


def run_phase(effect, game, commit, packet, helper_data, deadline, body, role):
    """Actual owned daemon + source-bound transport, with continuous limits."""
    selected = helpers.functions(helper_data['run.py'], ('daemon_arguments', 'listener_identity', 'diagnostic_failures'), BASE=commit)
    binary = game / 'representative.dmb'
    command = selected['daemon_arguments'](Path(packet['byond_bin']), binary, packet['port'])
    command[command.index('-params') + 1] += '&representative_role=' + role
    with owned_process(effect, command, game) as process:
        # A query is only observation until the sole listener owner is verified.
        host = Host(effect, game, process, commit, packet, helper_data['query.py'], deadline, None)
        initial = host.until(lambda row: row.get('state') == 1 or row.get('import_complete'))
        if deadline-effect.clock() < 120:
            raise TimeoutError('Insufficient bounded listener query reserve')
        listener = effect.listener(packet['port'], process.pid, selected['listener_identity'])
        if set(listener['owners']) != {process.pid} or set(listener['addresses']) != set(packet['listener_addresses']):
            raise ValueError('Listener ownership/address allocation mismatch')
        host.listener = listener
        process_receipt = {'pid': process.pid, 'started_utc': listener['process_start_utc'],
                           'binary_sha256': files.file_sha(binary)}
        write(game / 'owned-process.json', process_receipt)
        # Preserve existing refusal oracles before any mutating command.
        for token, action, session in (('0'*64 if host.token != '0'*64 else '1'*64, 'status', 'observe'),
                                       (host.token, 'first', 'stale-session')):
            try:
                helpers.query(helper_data['query.py'], effect.connect, effect.clock, packet['port'], token,
                              action, session, min(packet['query_timeout_seconds'], deadline-effect.clock()))
            except PermissionError:
                continue
            raise ValueError('Authentication/session refusal control failed')
        stop = threading.Event()
        failures = []
        host.monitor_failures = failures
        def observe():
            last_resource = -float('inf')
            try:
                while not stop.is_set():
                    remaining = deadline-effect.clock()
                    if remaining <= 0:
                        raise TimeoutError('Independent observer exhausted aggregate budget')
                    def observation(budget):
                        status = host.query('status', 'observe', budget)
                        return {'heartbeat': status['representative']['heartbeat'],
                                'phase': status['representative']['phase'], 'world_time': status['world_time']}
                    rows = sampler.sample(observation,
                                          effect.clock, effect.sleep, duration=min(1, remaining),
                                          cadence=packet['sampler_cadence_seconds'],
                                          max_samples=100000)
                    with (game / 'latency.jsonl').open('a', encoding='utf-8') as stream:
                        for row in rows:
                            stream.write(json.dumps(row) + '\n')
                    if effect.clock()-last_resource >= packet['resource_cadence_seconds']:
                        if deadline-effect.clock() < 30:
                            raise TimeoutError('Insufficient resource query reserve')
                        observation = effect.resources(process.pid)
                        observation['monotonic'] = effect.clock()
                        observation['output_bytes'] = generated_bytes(Path(packet['output']))
                        with (game / 'resources.jsonl').open('a') as stream:
                            stream.write(json.dumps(observation) + '\n')
                        validate_resource(observation, process_receipt, packet)
                        last_resource = effect.clock()
            except BaseException as error:
                failures.append(error)
        monitor = threading.Thread(target=observe, name='representative-independent-observer', daemon=True)
        monitor.start()
        try:
            result = body(host, initial, process_receipt)
        finally:
            stop.set()
            monitor.join(timeout=min(30, max(0, deadline-effect.clock())))
            if monitor.is_alive():
                raise RuntimeError('Observer exit unconfirmed')
        if failures:
            raise failures[0]
    # Inspect complete output after owned exit, including shutdown diagnostics.
    for name in ('daemon.stdout.log', 'daemon.stderr.log'):
        shutil.copy2(game / name, game.parent / name)
    diagnostic = selected['diagnostic_failures'](game.parent)
    if diagnostic:
        write(game / 'diagnostics.json', diagnostic)
        raise RuntimeError('Strict native diagnostics invalidate acceptance')
    return result


def execute(repository, packet, effect=None):
    effect = effect or SystemEffects()
    root = resource_packet(packet, effect.utcnow())
    if os.name != 'nt' and isinstance(effect, SystemEffects):
        raise ValueError('Existing native ownership helpers support Windows only')
    setup_deadline = effect.clock() + packet['setup_seconds']
    toolchain = Path(packet['byond_bin'])
    if not toolchain.is_absolute():
        raise ValueError('Allocated toolchain path must be absolute')
    for name in ('dm.exe', 'dd.exe'):
        if files.file_sha(files.unlinked(toolchain / name)) != packet['toolchain_sha256'][name]:
            raise ValueError('Toolchain differs from allocated exact bytes')
    if effect.free_bytes(root.parent) < packet['minimum_free_bytes']:
        raise RuntimeError('Allocated storage headroom unavailable')
    effect.available(packet['port'])
    root.mkdir(parents=True, exist_ok=False)
    write(root / 'allocation.json', packet)
    prepared = {}
    try:
        def bounded_source(repository, commit, path):
            if setup_deadline-effect.clock() < 30:
                raise TimeoutError('Insufficient setup reserve for a bounded Git read')
            data = effect.source(repository, commit, path)
            require_time(effect.clock, setup_deadline)
            return data
        helper_data = {name: bounded_source(repository, source.HELPERS, 'tests/world_save/full_map_lifecycle/' + name)
                       for name in ('query.py', 'run.py')}
        for label, commit in (('A', source.REFERENCE), ('B', source.CANDIDATE)):
            require_time(effect.clock, setup_deadline)
            game = effect.export(repository, commit, root / label, setup_deadline, packet['maximum_output_bytes'])
            manifest = source.prepare(repository, commit, root / (label + '-overlay'), reader=bounded_source)
            overlay(game, root / (label + '-overlay'), manifest)
            write(root / (label + '-manifest.json'), manifest)
            prepared[label] = (commit, game)
            if generated_bytes(root) > packet['maximum_output_bytes']:
                raise RuntimeError('Prepared inputs exceed allocated output ceiling')
        require_time(effect.clock, setup_deadline)
        core_deadline = effect.clock() + CORE_SECONDS
        binaries = {}
        for label, (commit, game) in prepared.items():
            require_time(effect.clock, core_deadline)
            try:
                log = effect.run([str(toolchain / 'dm.exe'), '-max_errors', '0', 'representative.dme'],
                                 cwd=game, timeout=min(300, core_deadline-effect.clock()))
            except (subprocess.CalledProcessError, subprocess.TimeoutExpired) as error:
                (game / 'compile.log').write_bytes((error.output or b'') + (error.stderr or b''))
                raise
            (game / 'compile.log').write_bytes(log)
            if b'516.1681' not in log or b'0 errors, 0 warnings' not in log:
                raise RuntimeError('Pinned compiler did not return clean build')
            binaries[label] = {suffix: files.file_sha(game / ('representative.' + suffix)) for suffix in ('dmb', 'rsc')}
        seed_game = root / 'seed/game'
        copy_tree(prepared['A'][1], seed_game, effect.clock, core_deadline)
        def seed(host, initial, owned):
            host.query('start', initial['session'])
            ready = host.until(lambda row: row.get('ready') and row.get('fixture', {}).get('seeded'))
            host.query('first', ready['session'])
            complete = host.poll('first_complete', ready['session'], host.deadline)
            I = protocol.saved_receipt(complete, source.REFERENCE, ready['session'], 'first_complete', 0)
            return files.freeze_generation(seed_game / 'map_saves', root / 'seed-generation', I)
        seed_receipt = effect.phase(seed_game, source.REFERENCE, packet, helper_data,
                                    min(core_deadline, effect.clock()+1800), seed, 'seed')
        shutil.copy2(seed_game / 'full-map-fixture.json', root / 'seed-fixture.json')
        write(root / 'seed-receipt.json', seed_receipt)
        arms = {}
        for label, (commit, template) in prepared.items():
            arm_deadline = min(core_deadline, effect.clock()+3600)
            writer = root / (label + '-writer/game')
            copy_tree(template, writer, effect.clock, arm_deadline)
            files.stage_reader(root / 'seed-generation', writer / 'map_saves', seed_receipt)
            shutil.copy2(root / 'seed-fixture.json', writer / 'full-map-fixture.json')
            def save_pair(host, initial, owned):
                ready = host.until(lambda row: row.get('import_complete') and row.get('ready'))
                host.query('census', ready['session'])
                host.poll('census_complete', ready['session'], arm_deadline)
                census = json.loads((writer / 'representative-census.json').read_text(encoding='utf-8'))
                if census.get('source') != commit or census.get('session') != ready['session'] or not isinstance(census.get('counts'), dict):
                    raise ValueError('Census source or boot binding differs')
                if (not census['counts'] or any(type(value) is not int or value <= 0 for value in census['counts'].values())
                        or sum(census['counts'].values()) != census.get('total')
                        or any(census.get(key) != ready.get(key) for key in ('maxx', 'maxy', 'maxz'))):
                    raise ValueError('Census count or dimensions malformed')
                host.baseline()
                if files.inventory(writer / 'map_saves') != seed_receipt['files_sha256']:
                    raise ValueError('Imported seed bytes changed')
                retained = writer.parent / 'imported-seed'
                (writer / 'map_saves').rename(retained)
                (writer / 'map_saves').mkdir()
                host.query('first', ready['session'])
                first = host.poll('first_complete', ready['session'], arm_deadline)
                I1 = protocol.saved_receipt(first, commit, ready['session'], 'first_complete', 1)
                first_copy = root / (label + '-first')
                first_receipt = files.freeze_generation(writer / 'map_saves', first_copy, I1)
                host.query('second', ready['session'])
                second = host.poll('second_complete', ready['session'], arm_deadline)
                I2 = protocol.saved_receipt(second, commit, ready['session'], 'second_complete', 2)
                if I1['generation'] == I2['generation']:
                    raise ValueError('Second save reused generation')
                backup = files.freeze_generation(writer / 'map_backups', root / (label + '-backup'), I1)
                if backup['files_sha256'] != first_receipt['files_sha256']:
                    raise ValueError('Completed backup differs from completed first generation')
                active = files.freeze_generation(writer / 'map_saves', root / (label + '-active'), I2)
                if not isinstance(active['saved_environment'], dict) or not isinstance(backup['saved_environment'], dict):
                    raise ValueError('Durable saved environment receipt missing')
                return {'writer': owned, 'status': second, 'first_status': first,
                        'active': active, 'backup': backup, 'census': census}
            arm = effect.phase(writer, commit, packet, helper_data, arm_deadline, save_pair, 'writer')
            readers = {}
            for kind, marker in (('active', 2), ('backup', 1)):
                reader = root / (label + '-' + kind + '-reader/game')
                copy_tree(template, reader, effect.clock, arm_deadline)
                files.stage_reader(root / (label + '-' + kind), reader / 'map_saves', arm[kind])
                shutil.copy2(root / 'seed-fixture.json', reader / 'full-map-fixture.json')
                def restored(host, initial, owned, kind=kind, marker=marker):
                    after = host.until(lambda row: row.get('import_complete') and not row.get('restart_hold'))
                    protocol.compare_reader(arm['status'] if kind == 'active' else arm['first_status'], after,
                                            commit, arm[kind]['identity'], marker, arm['writer'], owned,
                                            arm[kind]['saved_environment'])
                    return {'owned': owned, 'status': after}
                readers[kind] = effect.phase(reader, commit, packet, helper_data, arm_deadline, restored, 'reader')
                if files.inventory(reader / 'map_saves') != arm[kind]['files_sha256']:
                    raise ValueError('Reader changed completed generation bytes')
            if protocol.process_identity(readers['active']['owned']) == protocol.process_identity(readers['backup']['owned']):
                raise ValueError('Active and backup reused one reader process')
            arms[label] = {'writer': arm, 'readers': readers}
            if label == 'B':
                reference_census = arms['A']['writer']['census']
                for key in ('counts', 'total', 'maxx', 'maxy', 'maxz'):
                    if reference_census.get(key) != census_value(arm['census'], key):
                        raise ValueError('Public cohort differs between A and B: ' + key)
            write(root / (label + '-result.json'), arms[label])
        require_time(effect.clock, core_deadline)
        result = {'correctness_phases_completed': isinstance(effect, SystemEffects),
                  'execution_mode': 'native' if isinstance(effect, SystemEffects) else 'injected', 'performance_acceptance': False,
                  'representative_acceptance': False, 'reason': 'Raw matched performance and population/resource comparison still requires independent review.',
                  'binaries': binaries, 'arms': arms}
        write(root / 'result.json', result)
        return result
    except BaseException as error:
        write(root / 'failure.json', {'type': type(error).__name__, 'message': str(error), 'preserve': True, 'acceptance': False})
        raise


def census_value(census, key):
    if key not in census:
        raise ValueError('Missing actual cohort field: ' + key)
    return census[key]


# Bind actual effects only when explicitly called, never during import or tests.
SystemEffects.export = lambda self, repository, commit, destination, deadline, maximum_bytes: export(repository, commit, destination, self, deadline, maximum_bytes)
SystemEffects.phase = lambda self, game, commit, packet, helper_data, deadline, body, role: run_phase(self, game, commit, packet, helper_data, deadline, body, role)
SystemEffects.free_bytes = staticmethod(lambda path: shutil.disk_usage(path).free)
SystemEffects.listener = staticmethod(lambda port, pid, existing: existing(port, pid))
SystemEffects.source = staticmethod(source.git_source)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--execute', action='store_true')
    parser.add_argument('--resource-packet', type=Path)
    parser.add_argument('--repository', type=Path)
    args = parser.parse_args(argv)
    if not args.execute:
        print(json.dumps({'plan_only': True, 'commits': [source.REFERENCE, source.CANDIDATE],
                          'core_seconds': CORE_SECONDS, 'native_executed': False}))
        return
    if not args.resource_packet or not args.repository:
        parser.error('Execution requires an explicit current resource packet and source repository')
    execute(args.repository, json.loads(args.resource_packet.read_text(encoding='utf-8')))


if __name__ == '__main__':
    main()

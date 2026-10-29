"""Explicit, default-off save -> exit -> master update -> canonical build -> load.

Importing this module performs no I/O. Native execution requires reviewed local
configuration and the normal compiler/runtime admission; this is not a scheduler.
"""
from pathlib import Path
import argparse
import hashlib
import json
import os
import re
import shutil
import time
import uuid
import zipfile

import master_guard
import supervisor as core

MAPS = {'NOMADS_GAIA': 'nomads_gaia.dmm', 'NOMADS_EUROPE': 'nomads_europe.dmm'}


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def archive_matches(archive, artifacts):
    names = archive.namelist()
    if len(names) != len(artifacts) or set(names) != set(artifacts):
        return False
    for name, expected in artifacts.items():
        digest = hashlib.sha256()
        with archive.open(name) as stream:
            for block in iter(lambda: stream.read(1024 * 1024), b''):
                digest.update(block)
        if digest.hexdigest() != expected:
            return False
    return True


def configuration(config):
    require(all(Path(config[key]).is_absolute() for key in
                ('canonical_game_directory', 'repository', 'root', 'config_directory')),
            'Canonical paths must be absolute')
    game = Path(config['canonical_game_directory']).resolve(strict=True)
    root = Path(config['root']).resolve(strict=True)
    require(Path(config['repository']).resolve(strict=True) == game and
            root == game / 'data/desktop-supervisor' and
            Path(config['config_directory']).resolve(strict=True) == game / 'config',
            'Canonical game, repository, config and supervisor root must agree')
    require(config.get('branch') == 'master' and config.get('map') in MAPS,
            'Expected named master and an explicit supported map')
    require(config.get('bind') in ('127.0.0.1', '0.0.0.0') and
            type(config.get('port')) is int and 1 <= config['port'] <= 65535,
            'Expected explicit native bind and port')
    return game, root


def native_quiet(game, host, port):
    """Read-only admission: no owned/foreign native process or conflicting port.

    An unknown idle GUI is not silently adopted or terminated. The operator must
    reconcile it through normal admission before this explicit updater can run.
    """
    if os.name != 'nt':
        raise RuntimeError('Live canonical updating supports Windows only')
    require(core.process_identity(host['pid']) is None,
            'Previous owned PID is still alive or was reused')
    import psutil
    for process in psutil.process_iter(['name']):
        name = (process.info.get('name') or '').lower()
        require(name not in ('dd.exe', 'dm.exe', 'dreamdaemon.exe', 'dreammaker.exe'),
                'Another native process requires ownership reconciliation')
    require(not any(c.status == psutil.CONN_LISTEN and c.laddr.port == port
                    for c in psutil.net_connections(kind='tcp')),
            'Conflicting listener; no process action permitted')


class CanonicalUpdater:
    def __init__(self, config, *, supervisor=None, guard=master_guard.verified_master,
                 quiet=native_quiet):
        self.config = config
        self.game, self.root = configuration(config)
        self.sup = supervisor
        self.guard, self.quiet = guard, quiet
        self.transaction = None

    def verify_source(self, *, inspect_only=False, update=False):
        options = {'inspect_only': inspect_only, 'update': update,
                   'mutation_guard': None if inspect_only else self.stopped,
                   'approved_host_sha256': self.config.get('approved_host_sha256')}
        if update:
            options['before_fast_forward'] = self.protect_config_update
        return self.guard(self.game, self.config['git'], **options)

    def protect_config_update(self, before, target):
        self.stopped()
        changed = self.sup.command([self.config['git'], '--no-optional-locks', 'diff', '--name-only',
                                    '-z', before, target, '--', 'config', 'SQL/admins.txt'], self.game)
        require(not changed, 'Upstream configuration changes require operator reconciliation before update')

    def protected_config(self):
        paths = list((self.game / 'config').rglob('*'))
        paths += [self.game / 'SQL/admins.txt']
        result = {}
        for path in paths:
            require(not path.is_symlink(), 'Linked local configuration requires review')
            if path.is_file() and path.name != 'lifecycle-revision.txt':
                result[path.relative_to(self.game).as_posix()] = core.digest(path)
        return result

    def phase(self, name, **values):
        self.transaction.update(phase=name, **values)
        core.write_json(self.root / 'update-state.json', self.transaction)
        core.write_json(self.root / 'updates' / (self.transaction['operation'] + '.json'), self.transaction)

    def stopped(self, *, rehash=False):
        require(self.transaction is not None and self.transaction.get('generation'),
                'No completed save/exit transaction')
        host = self.transaction['previous_host']
        self.quiet(self.game, host, self.config['port'])
        state = json.loads(self.sup.state_path.read_text(encoding='utf-8-sig'))
        require(state.get('phase') == 'stopped' and state.get('host') is None and
                state.get('stopped_host') == host and
                state.get('operation') == self.transaction['operation'],
                'Stopped ownership state changed')
        backup = Path(self.transaction['backup'])
        require(core.digest(backup / 'receipt.json') == self.transaction['receipt_sha256'],
                'Recovery receipt changed')
        saved, names = core.validate_generation(backup, expected_map=self.config['map'])
        receipt = json.loads((backup / 'receipt.json').read_text())
        require(saved['generation'] == self.transaction['generation'] == receipt['generation'] and
                set(receipt['files']) == set(names), 'Recovery generation changed')
        stamps = {name: [(backup / name).stat().st_size, (backup / name).stat().st_mtime_ns,
                         (backup / name).stat().st_ino] for name in names}
        require(stamps == self.transaction['backup_stamps'], 'Recovery backup changed')
        if rehash:
            require(all(core.digest(backup / name) == receipt['files'][name] for name in names),
                    'Recovery backup bytes changed')
        require(self.protected_config() == self.transaction['configuration'],
                'Local configuration changed; preserve it and stop')

    def archive_artifacts(self):
        self.stopped()
        old = self.transaction['previous_binaries']
        require(set(old) == {'civ13.dmb', 'civ13.rsc'} and
                all(core.digest(self.game / name) == digest for name, digest in old.items()),
                'Previous canonical artifacts changed')
        path = self.root / 'updates' / (self.transaction['operation'] + '-artifacts.zip')
        with zipfile.ZipFile(path, 'x', compression=zipfile.ZIP_DEFLATED) as archive:
            for name in old:
                archive.write(self.game / name, name)
        with zipfile.ZipFile(path) as archive:
            require(archive_matches(archive, old), 'Previous artifact archive failed readback')
        self.phase('archived', previous_artifacts=str(path), previous_artifacts_sha256=core.digest(path))

    def verify_previous_artifacts(self):
        path = Path(self.transaction['previous_artifacts'])
        old = self.transaction['previous_binaries']
        require(path.is_file() and not path.is_symlink() and
                core.digest(path) == self.transaction['previous_artifacts_sha256'],
                'Previous artifact archive changed')
        with zipfile.ZipFile(path) as archive:
            require(archive_matches(archive, old), 'Previous artifact archive contents changed')

    def build(self, revision):
        self.stopped()
        require(core.digest(self.config['compiler']) == self.config['compiler_sha256'],
                'Reviewed compiler identity changed')
        stage = self.root / 'updates' / (self.transaction['operation'] + '-stage')
        require(not stage.exists(), 'Staged build already exists; do not replay')
        self.sup.command([self.config['git'], 'clone', '--shared', '--no-checkout', '--single-branch',
                          '--branch', 'master', str(self.game), str(stage)],
                         log=self.root / 'updates' / (self.transaction['operation'] + '-clone.log'), timeout=300)
        self.sup.command([self.config['git'], 'checkout', '--detach', revision], stage, timeout=300)
        self.verify_stage_source(stage, allowed=set())
        text = (stage / 'civ13.dme').read_text(encoding='utf-8')
        includes = re.findall(r'(?m)^#include "[^"\r\n]*\.dmm"[ \t]*\r?$', text)
        require(len(includes) == 1, 'Expected exactly one source map include')
        selected = stage / 'maps/nomads' / MAPS[self.config['map']]
        require(selected.is_file(), 'Selected map is missing')
        replacement = '#include "maps\\nomads\\' + MAPS[self.config['map']] + '"'
        expected_dme = text.replace(includes[0], replacement).replace('\n', os.linesep).encode('utf-8')
        (stage / 'civ13.dme').write_bytes(expected_dme)
        raw = self.sup.command([self.config['git'], '--no-optional-locks', 'ls-files', '-z'], stage)
        before_atlas = {name: core.digest(stage / name) for name in raw.split('\0') if name}
        atlas_output = self.root / 'updates' / (self.transaction['operation'] + '-atlas-output.json')
        with atlas_output.open('xb'):
            pass
        atlas_identity = atlas_output.stat()
        self.sup.command([self.config['python'], 'scripts/build-crafting-atlas.py',
                          '--catalog-only', '--game-catalog', str(atlas_output)],
                         stage, self.root / 'updates' / (self.transaction['operation'] + '-atlas.log'))
        self.stopped()
        require((stage / 'civ13.dme').read_bytes() == expected_dme, 'Staged DME changed during atlas generation')
        self.verify_stage_source(stage, allowed={'civ13.dme'})
        require(all(core.digest(stage / name) == digest for name, digest in before_atlas.items()),
                'Staged inputs changed during atlas generation')
        require(atlas_output.is_file() and not atlas_output.is_symlink() and
                (atlas_output.stat().st_dev, atlas_output.stat().st_ino) ==
                (atlas_identity.st_dev, atlas_identity.st_ino), 'Atlas output identity changed')
        atlas_bytes = atlas_output.read_bytes()
        try:
            atlas = json.loads(atlas_bytes)
        except (ValueError, UnicodeDecodeError) as error:
            raise RuntimeError('Generated atlas is not valid JSON') from error
        require(isinstance(atlas, dict) and isinstance(atlas.get('acquisition'), dict) and
                isinstance(atlas.get('recipes'), list) and isinstance(atlas.get('resources'), dict),
                'Generated atlas has an invalid catalog shape')
        (stage / 'UI/crafting-atlas.json').write_bytes(atlas_bytes)
        require((stage / 'UI/crafting-atlas.json').read_bytes() == atlas_bytes and
                (stage / 'civ13.dme').read_bytes() == expected_dme,
                'Staged DME or atlas changed before freeze')
        self.verify_stage_source(stage, allowed={'civ13.dme', 'UI/crafting-atlas.json'})
        inputs = {name: core.digest(stage / name) for name in raw.split('\0') if name}
        output = self.sup.command([self.config['compiler'], '-max_errors', '0', 'civ13.dme'],
                                  stage, self.root / 'updates' / (self.transaction['operation'] + '-compile.log'), timeout=180)
        require(re.search(r'(?<![0-9])0 errors,\s+0 warnings\b', output),
                'Compiler did not confirm zero errors/warnings')
        self.stopped()
        require(self.sup.command([self.config['git'], 'rev-parse', 'HEAD'], stage) == revision,
                'Staged checkout revision changed')
        self.verify_stage_source(stage, allowed={'civ13.dme', 'UI/crafting-atlas.json'})
        require(all(core.digest(stage / name) == digest for name, digest in inputs.items()),
                'Frozen staged source changed during compilation')
        require(all((stage / name).is_file() and (stage / name).stat().st_size > 0
                    for name in ('civ13.dmb', 'civ13.rsc')), 'Compiler outputs are absent or empty')
        manifest = {'revision': revision, 'map': self.config['map'],
                    'binaries': {name: core.digest(stage / name) for name in ('civ13.dmb', 'civ13.rsc')},
                    'selected_map': selected.relative_to(stage).as_posix(),
                    'selected_map_sha256': core.digest(selected),
                    'compiler_sha256': core.digest(self.config['compiler']), 'source': inputs}
        require(self.verify_source(inspect_only=True)['commit'] == revision,
                'Canonical source changed during staging')
        core.verify_binaries(stage, manifest, revision, self.config['map'])
        core.write_json(stage / 'build.json', manifest)
        return stage, manifest

    def verify_stage_source(self, stage, *, allowed):
        git = self.config['git']
        changed = self.sup.command([git, '--no-optional-locks', 'diff', '--name-only', '-z', 'HEAD'], stage)
        untracked = self.sup.command([git, '--no-optional-locks', 'ls-files', '--others', '--exclude-standard', '-z'], stage)
        require(not untracked and set(filter(None, changed.split('\0'))) <= allowed,
                'Staged source has unexpected edits or untracked files')

    def switch_build(self, stage, manifest):
        self.stopped(rehash=True)
        core.verify_binaries(stage, manifest, manifest['revision'], self.config['map'])
        old = self.transaction['previous_binaries']
        require(all(core.digest(self.game / name) == digest for name, digest in old.items()),
                'Previous canonical artifacts changed before switch')
        pending = {}
        for name, expected in manifest['binaries'].items():
            temporary = self.root / 'updates' / (self.transaction['operation'] + '-' + name + '.new')
            with (stage / name).open('rb') as source, temporary.open('xb') as target:
                shutil.copyfileobj(source, target)
                target.flush()
                os.fsync(target.fileno())
            require(core.digest(temporary) == expected, 'Staged artifact copy differs')
            pending[name] = temporary
        self.phase('switching', staged_build=str(stage), binaries=manifest['binaries'])
        for name, temporary in pending.items():
            self.stopped()
            self.verify_previous_artifacts()
            require(core.digest(self.game / name) == old[name], 'Canonical artifact changed during switch')
            os.replace(temporary, self.game / name)
        core.verify_binaries(self.game, manifest, manifest['revision'], self.config['map'])

    def isolate_nonpersistent_save(self, backup):
        self.stopped(rehash=True)
        working = self.game / 'map_saves'
        require(working.is_dir() and not working.is_symlink(), 'Working save directory is unavailable or linked')
        receipt = json.loads((Path(backup) / 'receipt.json').read_text())
        require(all(not (working / name).is_symlink() and core.digest(working / name) == digest
                    for name, digest in receipt['files'].items()),
                'Working save differs from backup')
        retained = self.root / 'updates' / (self.transaction['operation'] + '-working-save')
        require(not retained.exists(), 'Retained working save already exists')
        self.phase('isolating-save', retained_working_save=str(retained))
        self.stopped(rehash=True)
        require(all(not (working / name).is_symlink() and core.digest(working / name) == digest
                    for name, digest in receipt['files'].items()), 'Working save changed before isolation')
        working.rename(retained)
        require(all(not (retained / name).is_symlink() and core.digest(retained / name) == digest
                    for name, digest in receipt['files'].items()), 'Retained working save changed during isolation')
        working.mkdir()
        self.phase('save-isolated')

    def run(self, *, admin_operation=None, expected_session=None):
        require(self.config.get('canonical_update_enabled') is True,
                'Canonical save/load updating is disabled; activation is separate')
        require(not (self.root / 'HALTED.json').exists(), 'Supervisor is halted; no automatic recovery')
        current = self.root / 'update-state.json'
        require(not current.exists() or json.loads(current.read_text()).get('phase') == 'complete',
                'An earlier update is incomplete; reconcile it without replay')
        for name in ('compiler', 'daemon'):
            path = Path(self.config[name])
            require(path.is_absolute() and path.is_file() and
                    core.digest(path) == self.config[name + '_sha256'],
                    'Reviewed native tool identity changed')
        self.sup = self.sup or core.Supervisor(self.config)
        sup = self.sup
        old = dict(sup.state)
        require(old.get('phase') == 'ready' and old.get('host') and sup.alive() and
                Path(old['host']['workdir']).resolve(strict=True) == self.game and
                old.get('map') == self.config['map'], 'Expected exact owned canonical ready world')
        initial = sup.status()
        sup.accept_ready(initial, None)
        require(not initial.get('restart_intent'), 'Unconsumed restart intent')
        mode = initial.get('persistence_mode')
        require(type(mode) is int and mode in (0, 1),
                'Running world does not supply a valid persistence mode; no save requested')
        if admin_operation is not None:
            require(re.fullmatch(r'[0-9a-f]{32}', admin_operation) is not None and
                    initial.get('maintenance_operation') == admin_operation and
                    core.startup_session(initial) == expected_session,
                    'Admin request or process session changed')
        elif initial.get('clients'):
            return {'deferred': 'connected clients', 'source_changed': False}
        session = core.startup_session(initial)
        require(self.verify_source(inspect_only=True)['commit'] == old['revision'],
                'Running revision differs from local named master')
        self.transaction = {'operation': admin_operation or uuid.uuid4().hex, 'previous_host': old['host'],
                            'previous_revision': old['revision'], 'previous_binaries': old['binaries'],
                            'configuration': self.protected_config(), 'map': self.config['map'],
                            'persistence_mode': mode}
        (self.root / 'updates').mkdir(exist_ok=True)
        self.phase('saving')
        try:
            if admin_operation:
                backup, generation = sup.stop_saved(self.transaction['operation'], expected_session=session, admin_operation=True, expected_persistence=mode)
            else:
                backup, generation = sup.stop_saved(self.transaction['operation'], expected_session=session, expected_persistence=mode)
            # stop_saved is not treated as proof by itself: independently recheck
            # exact exit and the acknowledged same-map generation before Git.
            self.quiet(self.game, old['host'], self.config['port'])
            saved, names = core.validate_generation(backup, self.transaction['operation'], session, self.config['map'])
            require(saved['generation'] == generation, 'Acknowledged saved generation differs')
            sup.state = dict(old, phase='stopped', host=None, stopped_host=old['host'],
                             backup=str(backup), generation=generation, operation=self.transaction['operation'])
            core.write_json(sup.state_path, sup.state)
            self.phase('saved', backup=str(backup), generation=generation,
                       receipt_sha256=core.digest(Path(backup) / 'receipt.json'),
                       backup_stamps={name: [(Path(backup) / name).stat().st_size,
                                            (Path(backup) / name).stat().st_mtime_ns,
                                            (Path(backup) / name).stat().st_ino] for name in names})
            self.stopped(rehash=True)
            self.archive_artifacts()
            revision = self.verify_source(update=True)['commit']
            self.phase('updating', revision=revision)
            stage, manifest = self.build(revision)
            # A newer advertised master after compile refuses load, no chase loop.
            require(self.verify_source()['commit'] == revision, 'Remote master advanced before load')
            self.stopped()
            self.phase('compiled', staged_build=str(stage), binaries=manifest['binaries'])
            self.switch_build(stage, manifest)
            (self.game / 'config/lifecycle-revision.txt').write_text(revision, encoding='ascii')
            # Save stays at the canonical path; no copytree, clone or new run.
            saved, _ = core.validate_generation(self.game / 'map_saves', expected_map=self.config['map'])
            require(saved['generation'] == generation, 'Working generation changed before load')
            receipt = json.loads((Path(backup) / 'receipt.json').read_text())
            require(all(core.digest(self.game / 'map_saves' / name) == digest
                        for name, digest in receipt['files'].items()), 'Working save differs from backup')
            if not mode:
                self.isolate_nonpersistent_save(backup)
            self.stopped(rehash=True)
            self.phase('loading')
            require(core.digest(self.config['daemon']) == self.config['daemon_sha256'],
                    'Reviewed daemon identity changed before load')
            def accept_continuity(first):
                # Keep state STARTING until the saved world and heartbeat pass.
                first_tick = first.get('debug', {}).get('tick')
                require(type(first_tick) in (int, float), 'Startup has no observable heartbeat')
                timeout = self.config.get('continuity_timeout_seconds', 60)
                require(type(timeout) in (int, float) and 1 <= timeout <= 300, 'Invalid continuity timeout')
                deadline = sup.clock() + timeout
                while True:
                    require(sup.alive(), 'Owned startup process exited during continuity check')
                    loaded = sup.status()
                    sup.accept_ready(loaded, generation if mode else None)
                    require(core.startup_session(first) == core.startup_session(loaded) and
                            type(loaded.get('persistence_mode')) is int and loaded['persistence_mode'] == mode and
                            (not mode or all(loaded.get(axis) == saved[axis] for axis in ('maxx', 'maxy', 'maxz'))) and
                            loaded.get('debug', {}).get('runtime', {}).get('total') == 0,
                            'Loaded world continuity, mode or runtime checks failed')
                    tick = loaded.get('debug', {}).get('tick')
                    require(type(tick) in (int, float), 'Startup has no observable heartbeat')
                    if tick > first_tick:
                        return loaded
                    require(sup.clock() < deadline, 'Startup heartbeat did not advance before timeout')
                    sup.sleep(min(1, max(0, deadline - sup.clock())))

            sup.launch_prepared(self.game, manifest, generation if mode else None, self.transaction['operation'], backup,
                                readiness_check=accept_continuity)
            self.phase('complete', host=sup.state['host'])
            return {'revision': revision, 'generation': generation, 'restored': bool(mode), 'canonical_dmb': str(self.game / 'civ13.dmb'),
                    'phase': 'ready'}
        except Exception as error:
            self.phase('failed', failed_phase=self.transaction.get('phase'), error_class=type(error).__name__)
            core.write_json(self.root / 'HALTED.json', {'error_class': type(error).__name__,
                            'operation': self.transaction['operation'],
                            'recovery': 'Retain owned process, exact saved generation and artifacts; no retry or forced kill'})
            raise


def consume_admin_once(config, supervisor=None, updater_factory=CanonicalUpdater):
    """Consume one typed request while holding the existing supervisor lock.

    The exclusive receipt is durable before any lifecycle mutation. A crash or
    ambiguous response therefore cannot cause this identity to be replayed.
    """
    game, root = configuration(config)
    require(config.get('canonical_update_enabled') is True, 'Canonical updater is disabled')
    with core.exclusive_lock(root / 'supervisor.lock'):
        sup = supervisor or core.Supervisor(config)
        require(not (root / 'HALTED.json').exists(), 'Supervisor is halted')
        require(sup.state.get('phase') == 'ready' and sup.alive(), 'No owned ready world')
        status = sup.status()
        operation = status.get('maintenance_operation')
        if operation is None:
            return None
        require(isinstance(operation, str) and re.fullmatch(r'[0-9a-f]{32}', operation), 'Invalid maintenance identity')
        session = core.startup_session(status)
        folder = root / 'admin-maintenance'
        folder.mkdir(exist_ok=True)
        receipt = folder / (operation + '.json')
        with receipt.open('x', encoding='utf-8') as stream:
            json.dump({'operation': operation, 'phase': 'accepted'}, stream)
            stream.flush()
            os.fsync(stream.fileno())
        try:
            result = updater_factory(config, supervisor=sup).run(admin_operation=operation, expected_session=session)
            core.write_json(receipt, {'operation': operation, 'phase': 'complete', 'result': result})
            return result
        except Exception as error:
            core.write_json(receipt, {'operation': operation, 'phase': 'failed', 'error': str(error)})
            # If the old world still exists, send only a fixed failure signal;
            # no exception text, path or command is sent into the game.
            try:
                if sup.alive():
                    core.query(config['port'], sup.token, 'maintenance_failed', operation, session)
            except Exception:
                pass
            raise


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('check', 'dry-run', 'update-once', 'watch-admin'))
    parser.add_argument('--config', type=Path, required=True)
    args = parser.parse_args()
    config = json.loads(args.config.read_text(encoding='utf-8-sig'))
    game, root = configuration(config)
    if args.action in ('check', 'dry-run'):
        print(json.dumps({'canonical_dmb': str(game / 'civ13.dmb'),
                          'enabled': config.get('canonical_update_enabled') is True,
                          'mode': 'metadata only; no token, process, network or update',
                          'persistence_mode': 'unknown until authenticated live status',
                          'plan': ['verify owner and mode', 'save and verify exit', 'retain save and old binaries',
                                   'stage and validate build', 'switch binaries', 'restore if persistent',
                                   'verify mode, readiness and heartbeat']}))
        return
    require(config.get('canonical_update_enabled') is True, 'Canonical updater is disabled')
    if args.action == 'watch-admin':
        while True:
            consume_admin_once(config)
            time.sleep(5)
    with core.exclusive_lock(root / 'supervisor.lock'):
        print(json.dumps(CanonicalUpdater(config).run()))


if __name__ == '__main__':
    main()

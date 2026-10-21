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
import uuid
import zipfile

import master_guard
import supervisor as core

MAPS = {'NOMADS_GAIA': 'nomads_gaia.dmm', 'NOMADS_EUROPE': 'nomads_europe.dmm'}


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


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
        return self.guard(self.game, self.config['git'], inspect_only=inspect_only,
                          update=update, mutation_guard=None if inspect_only else self.stopped,
                          approved_host_sha256=self.config.get('approved_host_sha256'))

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
            require(set(archive.namelist()) == set(old) and
                    all(hashlib.sha256(archive.read(name)).hexdigest() == digest
                        for name, digest in old.items()), 'Previous artifact archive failed readback')
        self.phase('archived', previous_artifacts=str(path), previous_artifacts_sha256=core.digest(path))

    def build(self, revision):
        self.stopped()
        require(core.digest(self.config['compiler']) == self.config['compiler_sha256'],
                'Reviewed compiler identity changed')
        paths = [self.game / 'civ13.dme', self.game / 'UI/crafting-atlas.json']
        originals = {path: path.read_bytes() for path in paths}
        recovery = self.root / 'updates' / (self.transaction['operation'] + '-inputs')
        recovery.mkdir(exist_ok=False)
        for index, path in enumerate(paths):
            (recovery / str(index)).write_bytes(originals[path])
        expected = dict(originals)
        try:
            # Only after the verified archive and stopped gate: one raw DMB path.
            for name in ('civ13.dmb', 'civ13.rsc'):
                self.stopped()
                (self.game / name).unlink()
            text = originals[paths[0]].decode('utf-8')
            includes = re.findall(r'(?m)^#include "[^"\r\n]*\.dmm"[ \t]*\r?$', text)
            require(len(includes) == 1, 'Expected exactly one source map include')
            selected = self.game / 'maps/nomads' / MAPS[self.config['map']]
            require(selected.is_file(), 'Selected map is missing')
            replacement = '#include "maps\\nomads\\' + MAPS[self.config['map']] + '"'
            expected[paths[0]] = text.replace(includes[0], replacement).encode('utf-8')
            self.stopped()
            paths[0].write_bytes(expected[paths[0]])
            self.sup.command([self.config['python'], 'scripts/build-crafting-atlas.py',
                              '--catalog-only', '--game-catalog', 'UI/crafting-atlas.json'],
                             self.game, recovery / 'atlas.log')
            expected[paths[1]] = paths[1].read_bytes()
            raw = self.sup.command([self.config['git'], '--no-optional-locks', 'ls-files', '-z'], self.game)
            names = raw.split('\0')
            inputs = {name: core.digest(self.game / name) for name in names if name}
            self.stopped()
            output = self.sup.command([self.config['compiler'], '-max_errors', '0', 'civ13.dme'],
                                      self.game, recovery / 'compile.log', timeout=180)
            require(re.search(r'(?<![0-9])0 errors,\s+0 warnings\b', output),
                    'Compiler did not confirm zero errors/warnings')
            self.stopped()
            require(all(core.digest(self.game / name) == digest for name, digest in inputs.items()),
                    'Frozen source changed during compilation')
            require(all((self.game / name).is_file() and (self.game / name).stat().st_size > 0
                        for name in ('civ13.dmb', 'civ13.rsc')), 'Compiler outputs are absent or empty')
            manifest = {'revision': revision, 'map': self.config['map'],
                        'binaries': {name: core.digest(self.game / name) for name in ('civ13.dmb', 'civ13.rsc')},
                        'selected_map': selected.relative_to(self.game).as_posix(),
                        'selected_map_sha256': core.digest(selected),
                        'compiler_sha256': core.digest(self.config['compiler']), 'source': inputs}
        finally:
            for path in paths:
                self.stopped()
                require(path.read_bytes() == expected[path],
                        'Derived file changed unexpectedly; original retained in input recovery')
                path.write_bytes(originals[path])
        require(self.verify_source(inspect_only=True)['commit'] == revision,
                'Source identity changed after derived-input restoration')
        core.verify_binaries(self.game, manifest, revision, self.config['map'])
        core.write_json(recovery / 'build.json', manifest)
        return manifest

    def run(self):
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
        if initial.get('clients'):
            return {'deferred': 'connected clients', 'source_changed': False}
        session = core.startup_session(initial)
        require(self.verify_source(inspect_only=True)['commit'] == old['revision'],
                'Running revision differs from local named master')
        self.transaction = {'operation': uuid.uuid4().hex, 'previous_host': old['host'],
                            'previous_revision': old['revision'], 'previous_binaries': old['binaries'],
                            'configuration': self.protected_config(), 'map': self.config['map']}
        (self.root / 'updates').mkdir(exist_ok=True)
        self.phase('saving')
        try:
            backup, generation = sup.stop_saved(self.transaction['operation'], expected_session=session)
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
            manifest = self.build(revision)
            # A newer advertised master after compile refuses load, no chase loop.
            require(self.verify_source()['commit'] == revision, 'Remote master advanced before load')
            self.stopped()
            self.phase('compiled', binaries=manifest['binaries'])
            (self.game / 'config/lifecycle-revision.txt').write_text(revision, encoding='ascii')
            # Save stays at the canonical path; no copytree, clone or new run.
            saved, _ = core.validate_generation(self.game / 'map_saves', expected_map=self.config['map'])
            require(saved['generation'] == generation, 'Working generation changed before load')
            receipt = json.loads((Path(backup) / 'receipt.json').read_text())
            require(all(core.digest(self.game / 'map_saves' / name) == digest
                        for name, digest in receipt['files'].items()), 'Working save differs from backup')
            self.stopped(rehash=True)
            self.phase('loading')
            require(core.digest(self.config['daemon']) == self.config['daemon_sha256'],
                    'Reviewed daemon identity changed before load')
            def accept_continuity(first):
                # Keep state STARTING until the saved world and heartbeat pass.
                sup.sleep(1)
                loaded = sup.status()
                sup.accept_ready(loaded, generation)
                require(sup.alive() and core.startup_session(first) == core.startup_session(loaded) and
                        all(loaded.get(axis) == saved[axis] for axis in ('maxx', 'maxy', 'maxz')) and
                        loaded.get('debug', {}).get('runtime', {}).get('total') == 0 and
                        type(first.get('debug', {}).get('tick')) in (int, float) and
                        type(loaded.get('debug', {}).get('tick')) in (int, float) and
                        loaded['debug']['tick'] > first['debug']['tick'],
                        'Loaded world continuity, heartbeat or runtime checks failed')
                return loaded

            sup.launch_prepared(self.game, manifest, generation, self.transaction['operation'], backup,
                                readiness_check=accept_continuity)
            self.phase('complete', host=sup.state['host'])
            return {'revision': revision, 'generation': generation, 'canonical_dmb': str(self.game / 'civ13.dmb'),
                    'phase': 'ready'}
        except Exception as error:
            self.phase('failed', error_class=type(error).__name__)
            core.write_json(self.root / 'HALTED.json', {'error_class': type(error).__name__,
                            'operation': self.transaction['operation'],
                            'recovery': 'Retain owned process, exact saved generation and artifacts; no retry or forced kill'})
            raise


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('check', 'update-once'))
    parser.add_argument('--config', type=Path, required=True)
    args = parser.parse_args()
    config = json.loads(args.config.read_text(encoding='utf-8-sig'))
    game, root = configuration(config)
    if args.action == 'check':
        print(json.dumps({'canonical_dmb': str(game / 'civ13.dmb'),
                          'enabled': config.get('canonical_update_enabled') is True,
                          'mode': 'metadata only; no token, process, network or update'}))
        return
    require(config.get('canonical_update_enabled') is True, 'Canonical updater is disabled')
    with core.exclusive_lock(root / 'supervisor.lock'):
        print(json.dumps(CanonicalUpdater(config).run()))


if __name__ == '__main__':
    main()

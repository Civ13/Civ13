"""Group-wide fresh world: archive every region's world and the group's transfer state.

For a connected region group, where the single-region fresh world (fresh_world.py)
refuses. Every region must be saved and stopped. The command holds every region's
action lock, pauses the transfer helpers (the supervisor skips them while the group
journal exists), stops the agents and the coordinator, and moves, never deletes:

- each region's map_saves, map_backups and map_rollback (every saved body goes with them);
- each region's transfers.sqlite (in-flight travellers and account homes);
- the group's coordinator.sqlite (account homes and decided transfers).

into <root>/fresh-world-archives/<operation>/. Each region's own fresh-world-pending.json
is written first, so its host refuses start, wake and the watchdog until every move
has succeeded. The regions then start fresh; the supervisor starts new helpers, which
create empty stores and enrol every region. Accounts (data/player_saves), bans and
settings stay. Recovery after an interruption is manual: see docs/launcher-fresh-world.md.
"""
import json
import os
from pathlib import Path
import secrets

from gaia_host import Refused
import fresh_world

STORE_SUFFIXES = ('', '-wal', '-shm', '-journal')


def journal(group):
    return Path(group['root']) / 'fresh-world-group.json'


def paused(group):
    """True while a group fresh world runs or awaits recovery: helpers stay stopped."""
    return journal(group).exists()


def store_files(path):
    return [path.with_name(path.name + suffix) for suffix in STORE_SUFFIXES if path.with_name(path.name + suffix).exists()]


def write_json(path, value):
    temporary = path.with_name(path.name + '.tmp')
    temporary.write_text(json.dumps(value, indent=2), encoding='utf-8')
    os.replace(temporary, path)


def stop_helpers(group, pairs, coordinator_pid, terminate):
    """Ends the coordinator and every region's agent; refuses if any still runs."""
    pid = coordinator_pid(group)
    if pid:
        terminate(pid)
    for _region, host in pairs:
        port = host.config.get('transfer_port')
        if port:
            for agent in host.platform.listener_pids(port):
                terminate(agent)
    if coordinator_pid(group):
        raise Refused('the transfer coordinator did not stop; try again')
    for region, host in pairs:
        port = host.config.get('transfer_port')
        if port and host.platform.listening(port):
            raise Refused('the transfer agent of %s did not stop; try again' % region['id'])


def request(group, pairs, confirmation, coordinator_pid, terminate):
    """Archives the whole group's world and transfer state, then asks each region to start.

    pairs is [(region, host)] for every region of the group. Returns the launcher's
    usual {"accepted": ..., "refused": ...} answer plus the archive folder."""
    if confirmation != group['group']:
        raise Refused('the group fresh world needs --confirm-group with the exact group id')
    if len(pairs) != len(group['regions']):
        raise Refused('the group fresh world acts on every region; leave out --region')
    if paused(group):
        raise Refused('an interrupted group fresh world needs manual recovery; see fresh-world-group.json')
    operation = secrets.token_hex(16)
    taken = []
    try:
        for region, host in pairs:
            host.state_dir.mkdir(parents=True, exist_ok=True)
            try:
                with host.lock.open('x', encoding='utf-8') as stream:
                    stream.write(operation)
            except FileExistsError:
                raise Refused('%s is still running an action' % region['id'])
            taken.append(host)
        for region, host in pairs:
            fresh_world.check(host, linked=True)
        root = Path(group['root'])
        archive = root / 'fresh-world-archives' / operation
        for parent in (root, *root.parents):
            if parent.is_symlink() or getattr(parent.lstat(), 'st_file_attributes', 0) & 0x400:
                raise Refused('fresh world refuses linked parent paths')
        manifest = {'version': 1, 'operation': operation, 'group': group['group'], 'archive': str(archive),
                    'regions': [region['id'] for region, _host in pairs], 'moved': [], 'phase': 'stopping helpers'}
        write_json(journal(group), manifest)
        try:
            stop_helpers(group, pairs, coordinator_pid, terminate)
        except BaseException:
            journal(group).unlink()  # nothing moved yet: the group is unchanged
            raise
        # From here a failure leaves the journals in place for manual recovery.
        archive.mkdir(parents=True, exist_ok=False)
        for region, host in pairs:
            write_json(fresh_world.pending(host), dict(manifest, region=region['id'], phase='group archiving'))
        manifest['phase'] = 'archiving'
        write_json(journal(group), manifest)
        for region, host in pairs:
            target = archive / region['id']
            target.mkdir()
            moves = [host.repo / name for name in fresh_world.WORLD_PATHS if (host.repo / name).exists()]
            moves += store_files(host.state_dir / 'transfers.sqlite')
            for source in moves:
                fresh_world.safe_tree(source)
                os.rename(source, target / source.name)  # same filesystem: no copy, no delete
                manifest['moved'].append('%s/%s' % (region['id'], source.name))
                write_json(journal(group), manifest)
            (host.repo / 'map_saves').mkdir()  # check_save accepts an empty directory as fresh
        for source in store_files(root / 'coordinator.sqlite'):
            os.rename(source, archive / source.name)
            manifest['moved'].append(source.name)
            write_json(journal(group), manifest)
        manifest['phase'] = 'archived'
        (archive / 'manifest.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
        for _region, host in pairs:
            fresh_world.pending(host).unlink()
        journal(group).unlink()  # helpers may start again, on empty stores
    finally:
        for host in taken:
            host.lock.unlink(missing_ok=True)
    accepted, refused = {}, {}
    for region, host in pairs:
        try:
            accepted[region['id']] = host.request('start')
        except Refused as error:
            refused[region['id']] = str(error)
    return {'accepted': accepted, 'refused': refused, 'archive': str(archive), 'operation': operation}

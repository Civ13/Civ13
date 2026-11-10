"""Recoverable fresh-world transaction for stopped, unlinked region hosts.

Never delete data. A pending journal is a process-interruption start/watchdog interlock.
Connected regions need the coordinated protocol in docs/launcher-fresh-world.md.
"""
import json
import os
from pathlib import Path
import secrets

from gaia_host import Refused

WORLD_PATHS = ('map_saves', 'map_backups', 'map_rollback')
SEPARATE_DOMAINS = ('extraction_accounts', 'extraction_world', 'extraction_surface',
                    'extraction_loot', 'vehicle_key_service', 'safehouse_spool')


def pending(host):
    return host.state_dir / 'fresh-world-pending.json'


def safe_tree(path):
    """Reject links/junctions rather than moving data with ambiguous ownership."""
    if path.is_symlink() or getattr(path, 'is_junction', lambda: False)():
        raise Refused('fresh world refuses linked paths: ' + str(path))
    # Windows junction detection also on Python versions without Path.is_junction.
    if path.exists() and getattr(path.lstat(), 'st_file_attributes', 0) & 0x400:
        raise Refused('fresh world refuses reparse points: ' + str(path))
    if path.is_dir():
        for child in path.iterdir():
            safe_tree(child)


def check(host, linked=False):
    """Refuse unless the region is stopped and safe to archive. linked=True is the
    group-wide reset (group_fresh_world.py), which archives the transfer stores too."""
    if pending(host).exists():
        raise Refused('an interrupted fresh-world archive needs manual recovery; see fresh-world-pending.json')
    group = json.loads(Path(host.config['group_config']).read_text(encoding='utf-8'))
    if not linked and any(r.get('transfer_port') is not None for r in group['regions']):
        raise Refused('connected regions require a coordinated transit/transfer reset; use the group fresh world')
    if not linked and ((host.repo / 'config/transfer_agent.json').exists() or (host.state_dir / 'transfers.sqlite').exists()):
        raise Refused('transfer state exists; use the group fresh world')
    if any((host.repo / 'data' / name).exists() for name in SEPARATE_DOMAINS):
        raise Refused('separate extraction/vehicle persistence exists; a coordinated reset is required')
    if not (host.repo / '.git').exists() or not (host.repo / host.live_dmb_name()).is_file():
        raise Refused('set up and build the region first')
    if host.platform.listening(host.config['port']) or host.platform.listening(host.standby_port()):
        raise Refused('Save and stop the region first; fresh world never force-stops players')
    for marker in (host.freeze_file, host.cold_file, host.running_file):
        if marker.exists():
            raise Refused('region is not explicitly stopped (running/sleep/wake marker remains); Save and stop first')
    if host.stage_lock.exists():
        raise Refused('wait for the staged build to finish')
    if not host.byond_signed_in() or not host.task_ready_for_start():
        raise Refused('BYOND must be signed in and the region ready to start')
    # Validate parents as well as each moved tree (symlinked repository/state is not safe).
    for target in (host.repo, host.state_dir):
        for parent in (target, *target.parents):
            if parent.is_symlink() or getattr(parent.lstat(), 'st_file_attributes', 0) & 0x400:
                raise Refused('fresh world refuses linked parent paths')
    archive_root = host.state_dir / 'fresh-world-archives'
    if archive_root.is_symlink() or (archive_root.exists() and getattr(archive_root.lstat(), 'st_file_attributes', 0) & 0x400):
        raise Refused('fresh world refuses a linked archive folder')
    for name in WORLD_PATHS:
        safe_tree(host.repo / name)


def request(host, confirmation):
    if confirmation != host.config['region']:
        raise Refused('fresh world needs --region and --confirm-region with the same exact region id')
    host.state_dir.mkdir(parents=True, exist_ok=True)
    operation = secrets.token_hex(16)
    try:
        with host.lock.open('x', encoding='utf-8') as stream:
            stream.write(operation)
    except FileExistsError:
        raise Refused('another action is still running')
    try:
        check(host)
        host.state_file.unlink(missing_ok=True)  # as Host.request: no fields left over from the previous action
        host.record(action='fresh-world', operation=operation, phase='accepted', error=None, archive=None, validation=None)
        host.platform.detach([host.config['python'], '-I', '-B', str(host.script), '--config',
                              host.config['_path'], '--worker', 'fresh-world', operation])
    except Exception:
        host.lock.unlink(missing_ok=True)
        raise
    return {'accepted': True, 'operation': operation, 'action': 'fresh-world'}


def work(host, operation):
    if not host.lock.exists() or host.lock.read_text().strip() != operation:
        return
    try:
        check(host)  # Recheck after the detached worker starts, before changing anything.
        archive = host.state_dir / 'fresh-world-archives' / operation
        archive.mkdir(parents=True, exist_ok=False)
        manifest = {'version': 1, 'operation': operation, 'region': host.config['region'],
                    'repository': str(host.repo), 'archive': str(archive),
                    'paths': [name for name in WORLD_PATHS if (host.repo / name).exists()],
                    'moved': [], 'phase': 'archiving'}
        host.write_json(pending(host), manifest)
        host.record(phase='archiving old world', archive=str(archive))
        for name in manifest['paths']:
            # Same filesystem rename: no copy-then-delete and no archive retention pruning.
            os.rename(host.repo / name, archive / name)
            manifest['moved'].append(name)
            host.write_json(pending(host), manifest)
        (host.repo / 'map_saves').mkdir()  # check_save accepts an existing empty directory as fresh.
        manifest['phase'] = 'archived'
        (archive / 'manifest.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
        pending(host).unlink()  # All generations removed together; ordinary start is safe now.
        host.record(phase='starting fresh world', archive=str(archive))
        host.do_start(operation)  # Deliberately no pull, compile, auto-merge or build-slot rotation.
        host.record(phase='done', error=None, archive=str(archive),
                    validation='port open only; native gameplay and character behavior not verified')
    except Exception as error:
        host.record(phase='failed', error=str(error)[:500])
    finally:
        host.lock.unlink(missing_ok=True)

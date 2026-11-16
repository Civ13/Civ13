"""One-off migration of a stopped region's save to the unformed underground level.

Gaia, Desert, Jungle, Barren and the Moon used to ship a filled cave level at z 1
(docs/underground-level.md). `shard_group.py migrate-underground --region ID` turns a
stopped region's save over to the new level:

1. refuse unless the region is stopped (or cold), idle, built and has a completed save;
2. back the save up to <state_dir>/underground-migration/<stamp> (never pruned);
3. copy the build, helpers, config and save into <group root>/.migration/<ID> and boot
   it with -params migrate_underground=1: the world lifts people, loose objects and
   crates to the surface, turns the old level into unformed rock, saves and ends
   (code/modules/multiz/underground_migration.dm);
4. boot the same copy with -params validate_save=1 (the outside save validator);
5. only when both report ok, swap the migrated save (with its validated.json) into the
   region. The old save stays in the backup.

Run it after Update has built the region on the latest master, and start the region
afterwards as usual.
"""
import json
import os
import shutil
import subprocess
import time
from pathlib import Path

from gaia_host import Refused, copy_save

MIGRATION_DIR = '.migration'
MIGRATION_TIMEOUT_SECONDS = 3 * 3600  # Gaia: load, migrate and save, on a slow disk


def migration_argv(this, group, dmb, params):
    argv = this.validator_argv(group, dmb)
    argv[argv.index('validate_save=1')] = params
    argv[argv.index('validator.log')] = params.split('=')[0] + '.log'
    return argv


def run_world(argv, folder, timeout):
    """Run DreamDaemon in folder until the world ends. Returns its exit code."""
    with open(folder / (Path(argv[-1]).stem + '.out'), 'ab') as out:
        process = subprocess.Popen(argv, cwd=str(folder), stdout=out, stderr=subprocess.STDOUT)
        try:
            return process.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()
            raise Refused('the world in %s did not finish within %d s' % (folder, timeout))


def check_stopped(host):
    status = host.status()
    if status.get('state') not in ('stopped', 'cold') or status.get('listening'):
        raise Refused('Save and stop the region first (it is %s)' % status.get('state'))
    if status.get('busy') or host.stage_lock.exists():
        raise Refused('the region is busy; wait for its operation to finish')
    if host.platform.listening(host.standby_port()):
        raise Refused('the handover standby is still running')


def prepare(this, group, region_id, folder):
    """Copy region_id's save, build and config into folder. Returns (generation, dmb)."""
    path = this.region_dir(group, region_id)
    saves = path / 'map_saves'
    generation = this.save_generation(saves)
    if not generation:
        raise Refused('the region has no completed save to migrate')
    region = next(r for r in group['regions'] if r['id'] == region_id)
    config = this.region_config(group, region)
    live = this.read_record(Path(config['state_dir']) / 'build.json').get('file')
    live = live if live in this.DMB_SLOTS else this.DMB_SLOTS[0]
    if not (path / live).exists():
        raise Refused('the region has no build; run Update first')
    if folder.exists():
        shutil.rmtree(folder)
    (folder / 'map_saves').mkdir(parents=True)
    for item in saves.iterdir():
        if item.is_file() and item.name not in this.VALIDATOR_SKIPPED_SAVES:
            shutil.copy2(item, folder / 'map_saves' / item.name)
    for name in this.VALIDATOR_BUILD_FILES + this.VALIDATOR_HELPERS + (live[:-4] + '.rsc',):
        if (path / name).exists():
            shutil.copy2(path / name, folder / name)
    if (path / 'config').is_dir():
        shutil.copytree(path / 'config', folder / 'config', ignore=shutil.ignore_patterns('*token*'))
    return generation, live


def swap_in(saves, migrated, generation):
    """Replace saves with migrated, keeping the old files beside it until the swap is done."""
    old = saves.with_name('map_saves.pre-underground')
    if old.exists():
        shutil.rmtree(old)
    staged = saves.with_name('map_saves.underground')
    if staged.exists():
        shutil.rmtree(staged)
    shutil.copytree(migrated, staged)
    os.replace(saves, old)
    os.replace(staged, saves)
    shutil.rmtree(old)


def migrate(this, group, host, region_id, run=run_world, now=time.time):
    """The whole migration for one stopped region. Returns its report."""
    check_stopped(host)
    folder = Path(group['root']) / MIGRATION_DIR / region_id
    generation, dmb = prepare(this, group, region_id, folder)
    stamp = time.strftime('%Y%m%d-%H%M%S', time.gmtime(now()))
    backup = host.state_dir / 'underground-migration' / stamp
    copy_save(this.region_dir(group, region_id) / 'map_saves', backup)
    report = {'region': region_id, 'from_generation': generation, 'backup': str(backup)}

    run(migration_argv(this, group, dmb, 'migrate_underground=1'), folder, MIGRATION_TIMEOUT_SECONDS)
    migrated = this.read_record(folder / 'underground_migration.json')
    report['migration'] = migrated
    if not migrated.get('ok'):
        raise Refused('migration failed, region left as it was: %s' % (migrated.get('error') or 'no report'))

    (folder / 'map_saves' / 'validated.json').unlink(missing_ok=True)
    run(this.validator_argv(group, dmb), folder, this.VALIDATOR_TIMEOUT_SECONDS)
    result = this.read_record(folder / 'validation_result.json')
    report['validation'] = {key: result.get(key) for key in ('ok', 'full', 'error') if key in result}
    record = this.read_record(folder / 'map_saves' / 'validated.json')
    new_generation = this.save_generation(folder / 'map_saves')
    if not result.get('ok') or not result.get('full') or not record \
            or not this.record_matches_saves(record, folder / 'map_saves', new_generation):
        raise Refused('the migrated save did not validate, region left as it was: %s'
                      % (result.get('error') or 'no full record'))

    saves = this.region_dir(group, region_id) / 'map_saves'
    if this.save_generation(saves) != generation:
        raise Refused('the region saved again during the migration; run it again')
    swap_in(saves, folder / 'map_saves', generation)
    report['generation'] = new_generation
    report['ok'] = True
    shutil.rmtree(folder, ignore_errors=True)
    return report

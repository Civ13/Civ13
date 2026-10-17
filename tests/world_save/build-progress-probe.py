"""Generate hash-bound save-progress diagnostics; never edit production inputs."""
import argparse
import hashlib
import json
from pathlib import Path


def digest(data):
    return hashlib.sha256(data).hexdigest()


def replace_once(source, before, after):
    if source.count(before) != 1:
        raise ValueError(f'Expected one diagnostic insertion anchor: {before!r}')
    return source.replace(before, after, 1)


def instrument(saving, functions, phase_profile=False):
    if saving.count('\tTICK_CHECK\n') != 2:
        raise ValueError('Expected the two production serializer tick checks')
    saving = saving.replace('TICK_CHECK', 'WORLD_SAVE_PROGRESS_TICK_CHECK')
    saving = ('#ifndef WORLD_SAVE_PROGRESS_TICK_CHECK\n'
              '#define WORLD_SAVE_PROGRESS_TICK_CHECK ( world.tick_usage > TICK_LIMIT_RUNNING ? world_save_progress_stoplag() : 0 )\n'
              '#endif\n'
              + saving)
    saving = replace_once(saving, '/map_storage/proc/Save_World()\n',
                          '/map_storage/proc/Save_World()\n'
                          '\tworld_save_progress_begin()\n'
                          '\ttry\n\t\treturn world_save_progress_original_Save_World()\n'
                          '\tcatch(var/exception/E)\n'
                          '\t\tworld_save_progress_active = FALSE\n\t\tthrow E\n\n'
                          '/map_storage/proc/world_save_progress_original_Save_World()\n')
    saving = replace_once(saving, '\tfor(var/A = 1, A <= world.maxz, A++)\n',
                          '\tworld_save_progress_emit("metadata", 0, 0, TRUE)\n'
                          '\tfor(var/A = 1, A <= world.maxz, A++)\n'
                          '\t\tvar/progress_completed_turfs = 0\n')
    saving = replace_once(saving, '\t\tvar/savefile/savefile = new("map_saves/[A].sav")\n',
                          '\t\tworld_save_progress_emit("level_start", A, 0, TRUE)\n'
                          '\t\tvar/savefile/savefile = new("map_saves/[A].sav")\n')
    saving = replace_once(saving, '\t\t\t\tsavefile["[turf.x]"] << ref\n\t\t\t\tWORLD_SAVE_PROGRESS_TICK_CHECK\n',
                          '\t\t\t\tsavefile["[turf.x]"] << ref\n'
                          '\t\t\t\tprogress_completed_turfs++\n'
                          '\t\t\t\tif(progress_completed_turfs % 1024 == 0)\n'
                          '\t\t\t\t\tworld_save_progress_emit("turfs", A, progress_completed_turfs)\n'
                          '\t\t\t\tWORLD_SAVE_PROGRESS_TICK_CHECK\n')
    saving = replace_once(saving, '\t\tlog_startup_progress("\tSaved z-level [A].")\n',
                          '\t\tworld_save_progress_emit("level_serialized", A, progress_completed_turfs, TRUE)\n'
                          '\t\tlog_startup_progress("\tSaved z-level [A].")\n')
    saving = replace_once(saving, '\tlog_startup_progress("Finished saving.")\n',
                          '\tworld_save_progress_emit("completion_marker", world.maxz, world.maxx * world.maxy, TRUE)\n'
                          '\tworld_save_progress_active = FALSE\n'
                          '\tlog_startup_progress("Finished saving.")\n')
    # Original stoplag body is unchanged. Only the two saver checks call a
    # scoped wrapper with the same production threshold and return value.
    if phase_profile:
        saving = instrument_phases(saving)
    return saving, functions


def instrument_phases(saving):
    saving = replace_once(saving, '\t\tfor(var/turf/turf in world)\n',
                          '\t\tworld_save_profile_phase("traversal")\n'
                          '\t\tfor(var/turf/turf in world)\n'
                          '\t\t\tworld_save_profile_visited++\n')
    saving = replace_once(saving, '\t\t\tif (turf.z == A)\n',
                          '\t\t\tif (turf.z == A)\n\t\t\t\tworld_save_profile_selected++\n')
    saving = replace_once(saving, '\t\t\t\tsavefile.cd = "/map/[turf.z]/[turf.y]"\n',
                          '\t\t\t\tworld_save_profile_phase("index")\n'
                          '\t\t\t\tsavefile.cd = "/map/[turf.z]/[turf.y]"\n')
    tick_anchor = '\t\t\t\t\tworld_save_progress_emit("turfs", A, progress_completed_turfs)\n\t\t\t\tWORLD_SAVE_PROGRESS_TICK_CHECK\n'
    saving = replace_once(saving, tick_anchor, tick_anchor +
                          '\t\t\t\tworld_save_profile_phase("traversal")\n')
    saving = replace_once(saving, '\t\tworld_save_progress_emit("level_serialized",',
                          '\t\tworld_save_profile_phase("other")\n'
                          '\t\tworld_save_progress_emit("level_serialized",')
    for name, signature, arguments, phase, counter in (
        ('BuildVarDirectory', 'savefile/savefile, datum/A, var/contents = 0', 'savefile, A, contents', 'object', 'objects'),
        ('encode_saved_value', 'savefile/F, value', 'F, value', 'value', 'values'),
    ):
        before = f'/map_storage/proc/{name}({signature})\n'
        wrapper = (before + '\tif(!world_save_progress_active || !world_save_profile_totals)\n'
                   f'\t\treturn world_save_profile_original_{name}({arguments})\n'
                   f'\tworld_save_profile_{counter}++\n'
                   f'\tvar/previous_phase = world_save_profile_phase("{phase}")\n'
                   '\ttry\n'
                   f'\t\t. = world_save_profile_original_{name}({arguments})\n'
                   '\tcatch(var/exception/E)\n'
                   '\t\tworld_save_profile_phase(previous_phase)\n\t\tthrow E\n'
                   '\tworld_save_profile_phase(previous_phase)\n\treturn .\n\n'
                   f'/map_storage/proc/world_save_profile_original_{name}({signature})\n')
        saving = replace_once(saving, before, wrapper)
    return saving


def profile_helper(helper):
    begin_anchor = '\tworld_save_progress_last_write = world_save_progress_started\n'
    helper = replace_once(helper, begin_anchor,
                          begin_anchor + '\tworld_save_profile_begin(world_save_progress_started)\n')
    helper = replace_once(helper, '\t. = stoplag()\n',
                          '\tvar/previous_phase = world_save_profile_phase("yield")\n'
                          '\t. = stoplag()\n\tworld_save_profile_phase(previous_phase)\n')
    return replace_once(helper, '\t\tvar/path = "world_save_progress.json"\n',
                        '\t\tworld_save_profile_row(row)\n\t\tvar/path = "world_save_progress.json"\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--saving-source', required=True, type=Path)
    parser.add_argument('--functions-source', required=True, type=Path)
    parser.add_argument('--tick-source', required=True, type=Path)
    parser.add_argument('--expected-saving-sha256', required=True)
    parser.add_argument('--expected-functions-sha256', required=True)
    parser.add_argument('--expected-tick-sha256', required=True)
    parser.add_argument('--output-dir', required=True, type=Path)
    parser.add_argument('--phase-profile', action='store_true')
    args = parser.parse_args()
    sources = {}
    for name in ('saving', 'functions', 'tick'):
        path = getattr(args, name + '_source').resolve(strict=True)
        if path.stat().st_size > 512 * 1024:
            raise ValueError('Source exceeds bounded input size')
        data = path.read_bytes()
        expected = getattr(args, 'expected_' + name + '_sha256').lower()
        if digest(data) != expected:
            raise ValueError(f'{name} source hash mismatch')
        sources[name] = dict(path=str(path), sha256=expected, data=data)
    tick = sources['tick']['data'].decode('utf-8').replace('\r\n', '\n')
    if tick.count('#define TICK_CHECK ( world.tick_usage > TICK_LIMIT_RUNNING ? stoplag() : 0 )\n') != 1:
        raise ValueError('Unsupported production TICK_CHECK definition')
    # Resolve every anchor before creating outputs; existing output is rejected.
    saving, functions = instrument(*(sources[n]['data'].decode('utf-8').replace('\r\n', '\n')
                                     for n in ('saving', 'functions')), phase_profile=args.phase_profile)
    helper_path = Path(__file__).with_name('progress-probe.dm')
    helper_data = helper_path.read_bytes()
    if args.phase_profile:
        helper_data = profile_helper(helper_data.decode('utf-8').replace('\r\n', '\n')).encode()
    outputs = {'saving.dm': saving.encode(), 'functions.dm': sources['functions']['data'],
               'progress-probe.dm': helper_data}
    if args.phase_profile:
        outputs['phase-profile.dm'] = Path(__file__).with_name('phase-profile.dm').read_bytes()
    args.output_dir.mkdir(parents=True, exist_ok=False)
    for name, data in outputs.items():
        (args.output_dir / name).write_bytes(data)
    manifest = dict(scope='test-only generated-copy serialization progress; no save acceptance',
                    generator_sha256=digest(Path(__file__).read_bytes()),
                    sources={n: {k: v for k, v in entry.items() if k != 'data'}
                             for n, entry in sources.items()},
                    generated={n: digest(data) for n, data in outputs.items()},
                    phase_profile=args.phase_profile,
                    integration='Replace only saving.dm in isolated copy; append progress-probe.dm and, when phase_profile is true, phase-profile.dm to isolated DME. functions.dm is unchanged',
                    cadence='Check each 1024 completed turfs; overwrite latest JSON at most once per 10 wall-clock seconds except phase boundaries',
                    limits='world.timeofday with midnight wrap for runs under 24 hours is not monotonic; counts describe active level; elapsed includes yields and engine flushes; level_serialized is not durable completion')
    (args.output_dir / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(manifest, indent=2))


if __name__ == '__main__':
    main()

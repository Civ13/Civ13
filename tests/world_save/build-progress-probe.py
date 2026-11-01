"""Generate hash-bound save-progress diagnostics; never edit production inputs."""
import argparse
import hashlib
import json
import re
from pathlib import Path


def digest(data):
    return hashlib.sha256(data).hexdigest()


def replace_once(source, before, after):
    if source.count(before) != 1:
        raise ValueError(f'Expected one diagnostic insertion anchor: {before!r}')
    return source.replace(before, after, 1)


def instrument(saving, functions, phase_profile=False):
    bounded = '/map_storage/proc/save_work_check()\n' in saving
    spatial = bounded and 'CIV13_HUMAN_SPATIAL_EXPERIMENTAL' in saving
    expected_ticks = 4 if spatial else (1 if bounded else 2)
    if saving.count('\tTICK_CHECK\n') != expected_ticks:
        raise ValueError('Expected the production serializer tick checks')
    if spatial:
        start = '/map_storage/proc/build_human_obstruction_index('
        end = '/map_storage/proc/validate_human_saved_geometry('
        if saving.count(start) != 1 or saving.count(end) != 1:
            raise ValueError('Expected one human obstruction index boundary')
        index = saving.split(start, 1)[1].split(end, 1)[0]
        if index.count('\tTICK_CHECK\n') != 3:
            raise ValueError('Expected three human obstruction index tick checks')
    saving = saving.replace('TICK_CHECK', 'WORLD_SAVE_PROGRESS_TICK_CHECK')
    if bounded:
        # The root-admission wait is outside synchronous capture. Instrument
        # this exact named seam separately; arbitrary extra sleeps still reject.
        capture = '/map_storage/proc/capture_moving_save_root(savefile/destination, list/record)\n'
        edge = '/map_storage/proc/moving_save_root_edge('
        if capture in saving:
            if saving.count(capture) != 1 or saving.count(edge) != 1:
                raise ValueError('Expected one moving capture boundary')
            prefix, body = saving.split(capture)
            body, suffix = body.split(edge)
            headroom = '\tif(world.tick_usage >= 80)\n\t\tsleep(world.tick_lag)\n'
            body = replace_once(body, headroom,
                                '\tif(world.tick_usage >= 80)\n\t\tworld_save_progress_sleep(world.tick_lag)\n')
            saving = prefix + capture + body + edge + suffix
        if spatial:
            # Instrument the saver-side late enrollment and group wait. Actors
            # never wait in these seams; reject missing or duplicated anchors.
            boundaries = (
                ('/map_storage/proc/classify_human_save_entry(', '/map_storage/proc/capture_human_save_roster_positions('),
                ('/map_storage/proc/capture_human_save_roster_positions(', '/map_storage/proc/capture_human_save_root('),
            )
            for start, end in boundaries:
                if saving.count(start) != 1 or saving.count(end) != 1:
                    raise ValueError('Expected one human handoff boundary')
                prefix, body = saving.split(start)
                body, suffix = body.split(end)
                handoff = '\t\tsleep(world.tick_lag)\n'
                body = replace_once(body, handoff, '\t\tworld_save_progress_sleep(world.tick_lag)\n')
                saving = prefix + start + body + end + suffix
        # Preserve the bounded policy's thresholds, counters and wait delays.
        saving, sleeps = re.subn(r'(?m)^(\s*)sleep\((world.tick_lag|0)\)$',
                                 r'\1world_save_progress_sleep(\2)', saving)
        if sleeps != 3:
            raise ValueError('Expected the three bounded serializer sleep sites')
    saving = ('#ifndef WORLD_SAVE_PROGRESS_TICK_CHECK\n'
              '#define WORLD_SAVE_PROGRESS_TICK_CHECK ( world.tick_usage > TICK_LIMIT_RUNNING ? world_save_progress_stoplag() : 0 )\n'
              '#endif\n'
              + saving)
    # Current admission owns the operation before entering the serializer. Do not
    # start profiling at Save_World: rejected/reentrant requests must not reset
    # an active sample, and transaction/validation time is outside this scope.
    admission = '\tif(!operation || !operation.enter_contents(src, "save")) return FALSE\n'
    if '/map_storage/proc/save_world_contents(' in saving:
        entry = '/map_storage/proc/Save_World()\n\treturn run_world_operation("save")\n'
        if saving.count(entry) != 1 or saving.count('/map_storage/proc/Save_World()\n') != 1:
            raise ValueError('Expected one unchanged operation-admission entry')
        signature = 'save_world_contents(datum/persistence_world_operation/operation)'
        arguments = 'operation'
        saving = replace_once(saving, admission, admission + '\tworld_save_progress_begin()\n')
        begin = ''
    else:
        # Explicitly hash-bound legacy packet sources retain their old entry.
        signature = 'Save_World()'
        arguments = ''
        begin = '\tworld_save_progress_begin()\n'
    original = 'world_save_progress_original_' + signature
    saving = replace_once(saving, '/map_storage/proc/' + signature + '\n',
                          '/map_storage/proc/' + signature + '\n' + begin +
                          '\ttry\n\t\treturn world_save_progress_original_' + signature.split('(')[0] + '(' + arguments + ')\n'
                          '\tcatch(var/exception/E)\n'
                          '\t\tworld_save_progress_active = FALSE\n\t\tthrow E\n\n'
                          '/map_storage/proc/' + original + '\n')
    saving = replace_once(saving, '\tfor(var/A = 1, A <= world.maxz, A++)\n',
                          '\tworld_save_progress_emit("metadata", 0, 0, TRUE)\n'
                          '\tfor(var/A = 1, A <= world.maxz, A++)\n'
                          '\t\tvar/progress_completed_turfs = 0\n')
    saving = replace_once(saving, '\t\tvar/savefile/savefile = new("map_saves/[A].sav")\n',
                          '\t\tworld_save_progress_emit("level_start", A, 0, TRUE)\n'
                          '\t\tvar/savefile/savefile = new("map_saves/[A].sav")\n')
    index_write = ('\t\t\t\tsavefile["/map/[A]/[y]/[x]"] << ref\n' if bounded
                   else '\t\t\t\tsavefile["[turf.x]"] << ref\n')
    checkpoint = ('\t\t\t\tsave_work_check()\n' if bounded
                  else '\t\t\t\tWORLD_SAVE_PROGRESS_TICK_CHECK\n')
    saving = replace_once(saving, index_write + checkpoint,
                          index_write + '\t\t\t\tprogress_completed_turfs++\n'
                          '\t\t\t\tif(progress_completed_turfs % 1024 == 0)\n'
                          '\t\t\t\t\tworld_save_progress_emit("turfs", A, progress_completed_turfs)\n'
                          + checkpoint)
    saving = replace_once(saving, '\t\tlog_startup_progress("\tSaved z-level [A].")\n',
                          '\t\tworld_save_progress_emit("level_serialized", A, progress_completed_turfs, TRUE)\n'
                          '\t\tlog_startup_progress("\tSaved z-level [A].")\n')
    saving = replace_once(saving, '\tlog_startup_progress("Finished saving.")\n',
                          '\tworld_save_progress_emit("completion_marker", world.maxz, world.maxx * world.maxy, TRUE)\n'
                          '\tworld_save_progress_active = FALSE\n'
                          '\tlog_startup_progress("Finished saving.")\n')
    # Original stoplag and bounded-work policy bodies retain their thresholds,
    # wait delays and return values through scoped diagnostic wrappers.
    if phase_profile:
        saving = instrument_phases(saving, bounded=bounded)
    return saving, functions


def instrument_phases(saving, bounded=False):
    if bounded:
        anchor = '\t\tfor(var/y = 1, y <= world.maxy, y++)\n'
        saving = replace_once(saving, anchor,
                              '\t\tworld_save_profile_phase("traversal")\n' + anchor)
        anchor = '\t\t\t\tvar/turf/T = locate(x, y, A)\n'
        saving = replace_once(saving, anchor, anchor +
                              '\t\t\t\tworld_save_profile_visited++\n'
                              '\t\t\t\tworld_save_profile_selected++\n')
        anchor = '\t\t\t\tsavefile["/map/[A]/[y]/[x]"] << ref\n'
        saving = replace_once(saving, anchor,
                              '\t\t\t\tworld_save_profile_phase("index")\n' + anchor)
    else:
        saving = replace_once(saving, '\t\tfor(var/turf/turf in world)\n',
                              '\t\tworld_save_profile_phase("traversal")\n'
                              '\t\tfor(var/turf/turf in world)\n'
                              '\t\t\tworld_save_profile_visited++\n')
        saving = replace_once(saving, '\t\t\tif (turf.z == A)\n',
                              '\t\t\tif (turf.z == A)\n\t\t\t\tworld_save_profile_selected++\n')
        saving = replace_once(saving, '\t\t\t\tsavefile.cd = "/map/[turf.z]/[turf.y]"\n',
                              '\t\t\t\tworld_save_profile_phase("index")\n'
                              '\t\t\t\tsavefile.cd = "/map/[turf.z]/[turf.y]"\n')
    checkpoint = 'save_work_check()' if bounded else 'WORLD_SAVE_PROGRESS_TICK_CHECK'
    tick_anchor = '\t\t\t\t\tworld_save_progress_emit("turfs", A, progress_completed_turfs)\n\t\t\t\t' + checkpoint + '\n'
    saving = replace_once(saving, tick_anchor, tick_anchor +
                          '\t\t\t\tworld_save_profile_phase("traversal")\n')
    saving = replace_once(saving, '\t\tworld_save_progress_emit("level_serialized",',
                          '\t\tworld_save_profile_phase("other")\n'
                          '\t\tworld_save_progress_emit("level_serialized",')
    build_signature = 'savefile/savefile, datum/A, var/contents = 0'
    build_arguments = 'savefile, A, contents'
    if bounded:
        build_signature += ', traversal = FALSE'
        build_arguments += ', traversal'
        if 'CIV13_HUMAN_SPATIAL_EXPERIMENTAL' in saving:
            build_signature += ', datum/human_request = null'
            build_arguments += ', human_request'
    for name, signature, arguments, phase, counter in (
        ('BuildVarDirectory', build_signature, build_arguments, 'object', 'objects'),
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
    helper = replace_once(helper, '\tworld_save_progress_sleeps++\n\tsleep(delay)\n',
                          '\tworld_save_progress_sleeps++\n'
                          '\tvar/previous_phase = world_save_profile_phase("yield")\n'
                          '\tsleep(delay)\n\tworld_save_profile_phase(previous_phase)\n')
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

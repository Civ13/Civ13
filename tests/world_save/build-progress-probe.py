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


def instrument(saving, functions):
    if saving.count('\tTICK_CHECK\n') != 1:
        raise ValueError('Expected the production list serializer tick check')
    saving = saving.replace('TICK_CHECK', 'WORLD_SAVE_PROGRESS_TICK_CHECK')
    # Observe the bounded saver's explicit waits without altering their delay,
    # threshold, work counter or relative-slice policy.
    saving, sleeps = re.subn(r'(?m)^(\s*)sleep\((world.tick_lag|0)\)$',
                             r'\1world_save_progress_sleep(\2)', saving)
    if sleeps != 3:
        raise ValueError('Expected the three bounded serializer sleep sites')
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
    saving = replace_once(saving, '\t\t\t\tsavefile["/map/[A]/[y]/[x]"] << ref\n\t\t\t\tsave_work_check()\n',
                          '\t\t\t\tsavefile["/map/[A]/[y]/[x]"] << ref\n'
                          '\t\t\t\tprogress_completed_turfs++\n'
                          '\t\t\t\tif(progress_completed_turfs % 1024 == 0)\n'
                          '\t\t\t\t\tworld_save_progress_emit("turfs", A, progress_completed_turfs)\n'
                          '\t\t\t\tsave_work_check()\n')
    saving = replace_once(saving, '\t\tlog_startup_progress("\tSaved z-level [A].")\n',
                          '\t\tworld_save_progress_emit("level_serialized", A, progress_completed_turfs, TRUE)\n'
                          '\t\tlog_startup_progress("\tSaved z-level [A].")\n')
    saving = replace_once(saving, '\tlog_startup_progress("Finished saving.")\n',
                          '\tworld_save_progress_emit("completion_marker", world.maxz, world.maxx * world.maxy, TRUE)\n'
                          '\tworld_save_progress_active = FALSE\n'
                          '\tlog_startup_progress("Finished saving.")\n')
    # Original stoplag and bounded-work policy bodies are unchanged. Scoped
    # wrappers preserve their thresholds, wait delays and return values.
    return saving, functions


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--saving-source', required=True, type=Path)
    parser.add_argument('--functions-source', required=True, type=Path)
    parser.add_argument('--tick-source', required=True, type=Path)
    parser.add_argument('--expected-saving-sha256', required=True)
    parser.add_argument('--expected-functions-sha256', required=True)
    parser.add_argument('--expected-tick-sha256', required=True)
    parser.add_argument('--output-dir', required=True, type=Path)
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
                                     for n in ('saving', 'functions')))
    helper_path = Path(__file__).with_name('progress-probe.dm')
    helper_data = helper_path.read_bytes()
    outputs = {'saving.dm': saving.encode(), 'functions.dm': sources['functions']['data'],
               'progress-probe.dm': helper_data}
    args.output_dir.mkdir(parents=True, exist_ok=False)
    for name, data in outputs.items():
        (args.output_dir / name).write_bytes(data)
    manifest = dict(scope='test-only generated-copy serialization progress; no save acceptance',
                    generator_sha256=digest(Path(__file__).read_bytes()),
                    sources={n: {k: v for k, v in entry.items() if k != 'data'}
                             for n, entry in sources.items()},
                    generated={n: digest(data) for n, data in outputs.items()},
                    integration='Replace only saving.dm in the isolated source copy; append progress-probe.dm to the isolated DME. functions.dm is an unchanged inventory copy',
                    cadence='Check each 1024 completed turfs; overwrite latest JSON at most once per 10 wall-clock seconds except phase boundaries',
                    limits='world.timeofday with midnight wrap for runs under 24 hours is not monotonic; counts describe active level; elapsed includes yields and engine flushes; level_serialized is not durable completion')
    (args.output_dir / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(manifest, indent=2))


if __name__ == '__main__':
    main()

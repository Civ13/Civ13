"""Extract actual fresh-round setup; isolate only its external effects."""
import hashlib
import re


def generate(root, control=None):
    path = root / 'code/game/gameticker.dm'
    source = path.read_text(encoding='utf-8')
    marker = '/datum/controller/gameticker/proc/setup()'
    if source.count(marker) != 1:
        raise RuntimeError('Round setup marker changed')
    start = source.index(marker)
    end = source.index('\n/datum/controller/gameticker/proc/close_jobs()', start)
    body = source[start:end]
    # Count entry calls in both modes; cap a deliberately restored unsafe spin
    # so its negative control fails an assertion rather than hanging the engine.
    body = body.replace(marker + '\n', marker + '\n'
                        '\tfixture_round_setup_visits++\n'
                        '\tif(fixture_round_setup_visits > 5)\n'
                        '\t\tfixture_round_busy_spin = TRUE\n'
                        '\t\treturn TRUE\n', 1)
    if control == 'setup':
        marker = '\tif(map_storage.round_restored) return TRUE\n'
        if body.count(marker) != 4:
            raise RuntimeError('Round resume guard changed')
        body = re.sub(r'^\t+if\(map_storage.round_restored\) return TRUE\n', '', body, flags=re.M)
    if control == 'busy':
        marker = ('\tif(persistence_save_in_progress)\n\t\tsleep(1)\n'
                  '\t\tif(map_storage.round_restored) return TRUE\n'
                  '\t\tcurrent_state = GAME_STATE_PREGAME\n\t\treturn FALSE\n')
        if body.count(marker) != 2:
            raise RuntimeError('Busy yield mutation target changed')
        body = body.replace(marker, '\tif(persistence_save_in_progress) return FALSE\n')
    start = source.index('/datum/controller/gameticker/proc/pregame()')
    end = source.index('\n/datum/controller/gameticker/proc/setup()', start)
    pregame = source[start:end]
    hashes = {path.relative_to(root).as_posix(): hashlib.sha256(path.read_bytes()).hexdigest()}
    time_path = root / 'code/_helpers/time.dm'
    time_source = time_path.read_text(encoding='utf-8')
    hashes[time_path.relative_to(root).as_posix()] = hashlib.sha256(time_path.read_bytes()).hexdigest()
    macro = next(line for line in time_source.splitlines() if line.startswith('#define roundduration2text_in_ticks '))
    start = time_source.index('/proc/roundduration2text()')
    end = time_source.index('//Returns the world time in english', start)
    formatting = time_source[start:end]
    units_path = root / 'code/__defines/time.dm'
    hashes[units_path.relative_to(root).as_posix()] = hashlib.sha256(units_path.read_bytes()).hexdigest()
    units = units_path.read_text(encoding='utf-8')
    tod_path = root / 'code/__defines/time_of_day.dm'
    hashes[tod_path.relative_to(root).as_posix()] = hashlib.sha256(tod_path.read_bytes()).hexdigest()
    tod_source = tod_path.read_text(encoding='utf-8')
    start = tod_source.index('var/TOD_loop_started = FALSE')
    end = tod_source.index('/proc/clock_time()', start)
    tod = tod_source[start:end]
    if control == 'tod':
        tod = tod.replace('\tif(TOD_loop_started) return\n', '', 1)
    return ('#define GAMETICKER_PREGAME_TIME 1\n#define SPAN_NOTICE(text) text\n'
            + units + '\n' + macro + '\n' + pregame + '\n' + body + '\n' + formatting + '\n' + tod), hashes

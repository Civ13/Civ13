"""Check production turf registration, repeated constructors and replacement offline."""
import argparse
import pathlib
import subprocess
import tempfile

p = argparse.ArgumentParser()
p.add_argument('--byond-bin', type=pathlib.Path, required=True)
a = p.parse_args()
root = pathlib.Path(__file__).resolve().parents[2]
source = (root / 'code/game/turfs/turf.dm').read_text()
body = source.split('/turf/New()\n', 1)[1].split('\n/turf/proc/initialize()', 1)[0]
with tempfile.TemporaryDirectory(prefix='civ13-turf-registration-') as folder:
    work = pathlib.Path(folder)
    dme = work / 'probe.dme'
    dme.write_text('''#define FALSE 0
#define TRUE 1
#define GAME_STATE_PLAYING 3
var/global/list/turfs = list()
var/global/list/new_turfs = list()
var/global/list/turf_registry_members = list()
var/global/datum/ticker
/datum/var/current_state = 0
/turf/proc/levelupdate()
/turf/proc/calculate_window_coeff()
/turf/var/tmp/turf_registration_done = FALSE
/turf/New()
''' + body + '''
/turf/alternate
/world/OpenPort(port)
    if (port == "none") return ..(port)
    return 0
/world
    maxx = 32
    maxy = 32
/world/New()
    OpenPort("none")
    var/turf/T = locate(1,1,1)
    var/expected = world.maxx * world.maxy
    if (turfs.len != expected) CRASH("initial count")
    T.New()
    if (turfs.len != expected) CRASH("duplicate constructor")
    new /turf/alternate(T)
    if (turfs.len != expected) CRASH("replacement count")
    T = locate(1,1,1)
    if (!(T in turfs) || !turf_registry_members[T]) CRASH("replacement membership")
    text2file("PASS", "result.txt")
    shutdown()
''')
    result = subprocess.run([str(a.byond_bin / 'dm.exe'), str(dme)], cwd=work, capture_output=True, text=True)
    print(result.stdout)
    if result.returncode: raise SystemExit(result.returncode)
    try:
        result = subprocess.run([str(a.byond_bin / 'dd.exe'), 'probe.dmb', '-safe', '-invisible', '-close', '-log', 'runtime.log'], cwd=work, capture_output=True, text=True, timeout=30)
    except subprocess.TimeoutExpired:
        print((work / 'runtime.log').read_text() if (work / 'runtime.log').exists() else 'No runtime log', flush=True)
        raise
    print((work / 'runtime.log').read_text() if (work / 'runtime.log').exists() else result.stdout)
    if not (work / 'result.txt').exists(): raise SystemExit('No passing runtime result')
    print((work / 'result.txt').read_text())

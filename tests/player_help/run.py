"""Compile actual DM help service with minimal offline adapters; no game startup."""
import argparse
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
PRELUDE = '''
#define TRUE 1
#define FALSE 0
#define SECONDS * 10
#define GAME_STATE_PREGAME 1
#define GAME_STATE_SETTING_UP 2
#define GAME_STATE_PLAYING 3
#define GAME_STATE_FINISHED 4
#define PROCESS_PRIORITY_LOW 1
var/list/clients = list()
var/datum/probe_map/map = new
/datum/probe_map
    var/title = "Nomads (Gaia)"
    var/ID = "NOMADS_GAIA"
    var/gamemode = "Classic (Stone Age Start)"
    var/age = "5000 B.C."
    var/ordinal_age = 0
    var/civilizations = TRUE
var/datum/probe_processes/processes = new
/datum/probe_processes
    var/process/player_help/player_help
/process
    var/name
    var/schedule_interval
    var/list/fires_at_gamestates
    var/priority
    proc/setup()
    proc/fire()
'''
PROBE = '''
/proc/check(condition, label)
    if (!condition)
        world.log << "FAIL: [label]"
        failures++
var/failures = 0
/world/New()
    world.OpenPort("none")
    world.log << "BEGIN"
    var/datum/player_help_service/H = player_help_service
    H.root = "spool/"
    var/list/context = H.game_context()
    check(context["map"] == "Nomads (Gaia)" && context["gamemode"] == map.gamemode, "actual map and mode snapshot")
    map = null
    check(H.game_context()["map"] == "Unknown", "unavailable map snapshot")
    map = new
    check(!H.available(), "unconfigured")
    text2file(json_encode(list("enabled"=TRUE,"sequence"="old")), "spool/health.json")
    check(!H.available(), "first heartbeat is not proof of running worker")
    fdel("spool/health.json")
    text2file(json_encode(list("enabled"=TRUE,"sequence"="new")), "spool/health.json")
    check(H.available(), "changed heartbeat ready")
    sleep(101)
    check(!H.available(), "stale heartbeat")
    fdel("spool/health.json")
    text2file(json_encode(list("enabled"=FALSE,"sequence"="disabled")), "spool/health.json")
    check(!H.available(), "disabled")
    text2file("not json", "spool/bad.json")
    check(isnull(H.read_json("spool/bad.json", 100)), "malformed")
    check(isnull(H.read_json("spool/bad.json", 2)), "oversized")
    var/rendered = H.render_answer("<script>alert('x')</script>")
    check(!findtext(rendered, "<script>"), "escaped HTML")
    check(findtext(rendered, "&lt;script&gt;"), "text retained")
    text2file(json_encode(list("id"="old", "status"="ok", "answer"="old answer")), "spool/1.response.json")
    check(isnull(H.matching_response(1, "new")), "wrong response identity rejected")
    check(islist(H.matching_response(1, "old")), "matching response accepted")
    fdel("spool/1.response.json")
    for(var/i=1,i<=8,i++)
        H.pending["[i]"] = list("id"="1-2-3", "client"=null, "deadline"=0)
        text2file("request", "spool/[i].request.json")
        text2file("1-2-3", "spool/[i].ready")
        text2file("answer", "spool/[i].response.json")
    H.poll()
    check(!H.pending.len, "disconnected clients release all slots")
    for(var/i=1,i<=8,i++)
        check(!fexists("spool/[i].ready") && !fexists("spool/[i].request.json") && !fexists("spool/[i].response.json"), "spool cleanup")
    world.log << "RESULT: [failures]"
    del(world)
'''


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--byond-bin', type=Path, required=True)
    parser.add_argument('--negative-control', choices=['escaping', 'heartbeat', 'identity'])
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix='civ13-player-help-') as directory:
        temp = Path(directory)
        (temp / 'spool').mkdir()
        production = (ROOT / 'code/game/mob/player_help.dm').read_text()
        if args.negative_control == 'escaping':
            production = production.replace('html_encode(answer)', 'answer')
        elif args.negative_control == 'heartbeat':
            production = production.replace('return heartbeat_confirmed && world.time - heartbeat_time < 100', 'return TRUE')
        elif args.negative_control == 'identity':
            production = production.replace('islist(response) && response["id"] == id', 'islist(response)')
        (temp / 'production.dm').write_text(production)
        (temp / 'probe.dme').write_text(PRELUDE + '\n#include "production.dm"\n' + PROBE)
        compiler = args.byond_bin / ('dm.exe' if (args.byond_bin / 'dm.exe').exists() else 'DreamMaker')
        daemon = args.byond_bin / ('dd.exe' if (args.byond_bin / 'dd.exe').exists() else 'DreamDaemon')
        built = subprocess.run([str(compiler), 'probe.dme'], cwd=temp, capture_output=True, text=True, timeout=90)
        print(built.stdout)
        if built.returncode or '0 errors, 0 warnings' not in built.stdout:
            raise SystemExit('Fixture compilation failed')
        ran = subprocess.run([str(daemon), 'probe.dmb', '-invisible', '-trusted', '-close', '-log', 'probe.log'], cwd=temp, capture_output=True, text=True, timeout=40)
        output = ran.stdout + ran.stderr + (temp / 'probe.log').read_text(errors='replace')
        if args.negative_control:
            if 'FAIL:' not in output:
                raise SystemExit('Negative control not detected')
            print('Expected negative control detected:', args.negative_control)
        elif 'RESULT: 0' not in output or 'FAIL:' in output or any(error in output.lower() for error in ('runtime error:', 'bad ref', 'unhandled exception')):
            print(output)
            raise SystemExit('Native help probe failed')
        else:
            print('Native help probe PASS')


if __name__ == '__main__':
    main()

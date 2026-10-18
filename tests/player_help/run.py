"""Compile actual DM help service with minimal offline adapters; no game startup."""
import argparse
import contextlib
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile

from render_contract import validate as validate_render

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
#define AREA_OUTSIDE 1
#define WEATHER_NONE 1
#define WEATHER_WET 2
#define WEATHER_EXTREME 3
#define WEATHER_SMOG 4
/world
    hub = ""
    visibility = 0
/world/OpenPort(port)
    return ..("none")
/client/New()
    del(src)
    return null
var/season = "WINTER"
var/time_of_day = "Night"
/proc/IsGuestKey(key)
    return findtext(key, "guest") == 1
/area
    var/location = AREA_OUTSIDE
    var/weather = WEATHER_WET
/mob
    var/probe_connected = TRUE
    var/probe_prompts = 0
    var/probe_submits = 0
    var/probe_question
    var/probe_result
    var/probe_disconnect_on_prompt = FALSE
    proc/probe_submit(question)
        probe_submits++
        probe_result = player_help_service.enqueue(md5("injected authenticated client"), question, null)
/mob/probe_help/player_help_prompt()
    probe_prompts++
    if (probe_disconnect_on_prompt)
        probe_connected = FALSE
    return probe_question
/datum/player_help_service/probe_limits
    var/clock = 1000
    limit_time()
        return clock
/datum/player_help_service/probe_backend
    var/online = TRUE
    var/fail_write = FALSE
    available()
        return online
    write_request(slot, list/request)
        if (fail_write)
            return FALSE
        return ..()
/proc/get_area(mob/M)
    return M.loc
/mob/living/human
    var/obj/item/l_hand
    var/obj/item/r_hand
    var/obj/item/back
    var/obj/item/wear_mask
    var/obj/item/wear_suit
    var/obj/item/w_uniform
    var/obj/item/shoes
    var/obj/item/belt
    var/obj/item/gloves
    var/obj/item/head
    var/obj/item/l_ear
    var/obj/item/r_ear
    var/obj/item/wear_id
    var/obj/item/l_store
    var/obj/item/r_store
    var/health = 45
    var/maxHealth = 100
    var/nutrition = 200
    var/max_nutrition = 400
    var/water = 175
    var/max_water = 350
    var/bodytemperature = 300
    var/cold_wetness = 0.5
    var/on_fire = TRUE
    var/stunned = FALSE
    var/weakened = FALSE
/obj/item/stack
    var/amount = 5
/obj/item/weapon/storage
var/list/clients = list()
var/probe_inspections = 0
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
    check(!world.port && !world.visibility, "fixture starts offline")
    world.OpenPort(59474)
    check(!world.port, "fixture refuses reopening")
    world.log << "BEGIN"
    var/datum/player_help_service/H = player_help_service
    H.root = "spool/"
    var/mob/probe_help/asker = new
    asker.ask_player_help()
    check(asker.probe_prompts == 1 && !asker.probe_submits && !H.accounts.len, "unavailable service still prompts and cancellation consumes no allowance")
    asker.probe_question = "How do I play?"
    asker.ask_player_help()
    check(asker.probe_prompts == 2 && asker.probe_submits == 1, "actual verb submits only after prompt")
    check(findtext(asker.probe_result, "unavailable"), "verb submission returns unavailable after prompt")
    var/datum/player_help_service/probe_limits/L = new
    var/account = md5("same authenticated account across reconnect")
    check(L.reserve(account) == 1, "first account admission")
    check(findtext(L.reserve(account), "pending"), "one outstanding across reconnect")
    L.clear_slot(1)
    check(findtext(L.reserve(account), "wait"), "rapid repeats retain account cooldown")
    L.clock += 300
    check(L.reserve(account) == 1, "cooldown expiry")
    L.clear_slot(1)
    L.clock += 300
    check(L.reserve(account) == 1, "third burst admission")
    L.clear_slot(1)
    L.clock += 300
    check(findtext(L.reserve(account), "wait"), "burst quota after cooldown")
    L.clock += 300
    check(L.reserve(account) == 1, "burst expiry")
    L.clear_slot(1)
    L.accounts = list()
    L.global_times = list()
    L.limits["window_requests"] = 2
    for(var/i=1,i<=2,i++)
        check(L.reserve(account) == 1, "window setup admission")
        L.clear_slot(1)
        L.clock += 300
    check(findtext(L.reserve(account), "wait"), "long window quota")
    L.accounts = list()
    L.global_times = list()
    L.limits["global_requests"] = 1
    check(L.reserve(md5("global one")) == 1, "global first")
    L.clear_slot(1)
    check(findtext(L.reserve(md5("global two")), "busy"), "global quota rejects distinct accounts")
    L.global_times = list()
    L.accounts = list()
    L.limits["global_requests"] = 30
    L.limits["max_accounts"] = 1
    check(L.reserve(md5("bounded one")) == 1, "state capacity setup")
    L.clear_slot(1)
    check(findtext(L.reserve(md5("bounded two")), "busy") && L.accounts.len == 1, "bounded account state rejects without evicting cooldown")
    L.clock += 6000
    check(L.reserve(md5("bounded two")) == 1, "expired account state reclaimed")
    L.clear_slot(1)
    L.accounts = list()
    L.global_times = list()
    L.limits["max_accounts"] = 2048
    for(var/i=1,i<=8,i++)
        check(L.reserve(md5("queue [i]")) == i, "bounded queue admission")
    check(findtext(L.reserve(md5("queue overflow")), "busy"), "global queue saturation")
    // Disconnected recipients still reserve their accounts until completion/timeout.
    H.pending["1"] = list("id"="disconnected", "account"=account, "deadline"=world.time + 100)
    H.poll()
    check(H.pending.len == 1, "disconnect does not release pending account")
    if (H.pending["1"])
        H.pending["1"]["deadline"] = 0
    H.poll()
    check(!H.pending.len, "timeout releases disconnected request")
    var/datum/player_help_service/probe_backend/B = new
    B.root = "spool/"
    B.online = FALSE
    check(findtext(B.enqueue(account, "Question", null), "unavailable") && !B.accounts.len, "unavailable submission spends no allowance")
    B.online = TRUE
    player_help_service = B
    asker.ask_player_help()
    check(asker.probe_result == TRUE && B.pending.len == 1, "actual verb prompt submission publishes ready backend request")
    asker.ask_player_help()
    check(findtext(asker.probe_result, "pending") && B.pending.len == 1, "repeated adapter submission retains pending account")
    var/mob/probe_help/reconnected = new
    reconnected.probe_question = "Second question"
    reconnected.ask_player_help()
    check(findtext(reconnected.probe_result, "pending") && B.pending.len == 1, "second adapter with same account cannot duplicate dispatch")
    var/mob/probe_help/leaving = new
    leaving.probe_question = "Disconnected during input"
    leaving.probe_disconnect_on_prompt = TRUE
    leaving.ask_player_help()
    check(leaving.probe_prompts == 1 && !leaving.probe_submits, "disconnect during prompt cannot submit")
    B.clear_slot(1)
    B.accounts = list()
    B.global_times = list()
    player_help_service = H
    var/long_question = ""
    for(var/i=1,i<=501,i++)
        long_question += "x"
    check(findtext(B.enqueue(account, long_question, null), "500") && !B.accounts.len, "oversized submission spends no allowance")
    B.fail_write = TRUE
    check(findtext(B.enqueue(account, "Question", null), "could not send") && !B.pending.len, "write failure releases pending lock")
    check(findtext(B.enqueue(account, "Question", null), "wait"), "write failure retains cooldown against retry flood")
    B.fail_write = FALSE
    check(B.enqueue(md5("backend success"), "Question", null) == TRUE, "actual queue publishes request")
    var/list/sent = B.read_json("spool/1.request.json", 16384)
    check(sent["account"] == md5("backend success") && sent["question"] == "Question", "server request includes bounded account and question")
    text2file(json_encode(list("id"=sent["id"], "status"="unavailable")), "spool/1.response.json")
    B.poll()
    check(!B.pending.len && !fexists("spool/1.ready"), "failed response releases queue and removes dispatch marker")
    var/list/context = H.game_context()
    check(context["map"] == "Nomads (Gaia)" && context["gamemode"] == map.gamemode, "actual map and mode snapshot")
    var/area/local_area = new
    var/mob/living/human/player = new(local_area)
    player.back = new /obj/item/weapon/storage(player)
    player.back.name = "backpack"
    var/obj/item/stack/material = new(player.back)
    material.name = "iron"
    var/obj/item/hidden = new(player)
    hidden.name = "not an equipment slot"
    var/list/inventory = H.inventory_context(player)
    var/list/rows = inventory["items"]
    check(rows.len == 2 && rows[2]["quantity"] == 5 && rows[2]["place"] == "backpack", "carried storage and stack quantities only")
    for(var/i=1,i<=30,i++)
        new /obj/item(player.back)
    inventory = H.inventory_context(player)
    check(inventory["items"].len == 24 && inventory["truncated"], "bounded inventory flagged incomplete")
    var/mob/living/human/budget_player = new(local_area)
    budget_player.back = new /obj/item/weapon/storage(budget_player)
    for(var/i=1,i<=70,i++)
        new /obj(budget_player.back)
    probe_inspections = 0
    var/list/budget_inventory = H.inventory_context(budget_player)
    check(probe_inspections == 64 && budget_inventory["truncated"], "combined entry and child inspection budget reaches exactly 64")
    var/list/snapshot = H.game_context(player)
    var/list/condition = snapshot["player"]
    check(condition["health_percent"] == 45 && condition["wetness_percent"] == 50, "asking player condition")
    check(snapshot["season"] == "WINTER" && snapshot["time_of_day"] == "Night", "public environment")
    check("On fire" in condition["active_effects"], "active public effect")
    player.health = 80
    check(H.game_context(player)["player"]["health_percent"] == 80 && condition["health_percent"] == 45, "fresh detached snapshot")
    check(!context["player"], "no player condition without asking human")
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
    var/list/render_cases = json_decode(file2text("render-cases.json"))
    var/list/render_results = list()
    for (var/list/render_case in render_cases)
        var/html = H.render_answer(render_case["markdown"])
        for (var/expected in render_case["contains"])
            check(findtextEx(html, expected), "Markdown required text: [render_case["name"]]")
        for (var/forbidden in render_case["absent"])
            check(!findtextEx(html, forbidden), "Markdown forbidden text: [render_case["name"]]")
        render_results += list(list("name" = render_case["name"], "html" = html))
    text2file(json_encode(render_results), "render-results.json")
    var/oversized_answer = ""
    for (var/i = 1, i <= 4001, i++)
        oversized_answer += "x"
    check(findtext(H.render_answer(oversized_answer), "usable response"), "renderer enforces answer bound")
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
    parser.add_argument('--output', type=Path, help='Retain isolated sources, logs and hashes in a new directory')
    parser.add_argument('--prepare-only', action='store_true', help='Write the exact isolated fixture without launching any process; requires --output')
    parser.add_argument('--negative-control', choices=['escaping', 'heartbeat', 'identity', 'player-context', 'inventory-budget', 'rate-limit', 'prompt-first', 'disconnect'])
    args = parser.parse_args()
    if args.prepare_only and not args.output:
        parser.error('--prepare-only requires --output')
    if args.output:
        args.output.mkdir(parents=True, exist_ok=False)
    storage = contextlib.nullcontext(str(args.output)) if args.output else tempfile.TemporaryDirectory(prefix='civ13-player-help-')
    with storage as directory:
        temp = Path(directory)
        (temp / 'spool').mkdir()
        production = (ROOT / 'code/game/mob/player_help.dm').read_text()
        (temp / 'render-cases.json').write_bytes((ROOT / 'tests/player_help/render-cases.json').read_bytes())
        if production.count('/client/verb/ask_player_help()') != 1 or '/mob/verb/ask_player_help()' in production:
            raise SystemExit('Help must have one client-owned verb, matching Adminhelp ownership')
        # Inject only the unavailable native client/input boundary. The actual
        # verb body runs; reserve/poll below are unmodified production paths.
        production = production.replace('/client/verb/ask_player_help()', '/mob/verb/ask_player_help()')
        production = production.replace('/client/proc/player_help_prompt()', '/mob/proc/player_help_prompt()')
        production = production.replace('if (question && (src in clients))', 'if (question && probe_connected)')
        production = production.replace('player_help_service.submit(src, question)', 'probe_submit(question)')
        if args.negative_control == 'rate-limit':
            production = production.replace('if (retry)', 'if (FALSE && retry)')
        elif args.negative_control == 'prompt-first':
            production = production.replace('var/question = player_help_prompt()', 'if (!player_help_service.available())\n\t\treturn\n\tvar/question = player_help_prompt()')
        elif args.negative_control == 'disconnect':
            production = production.replace('if (C && !(C in clients))', 'if (!C)\n\t\t\tclear_slot(i)\n\t\t\tcontinue\n\t\tif (C && !(C in clients))')
        production = production.replace('inspected++', 'inspected++; probe_inspections++')
        if args.negative_control == 'inventory-budget':
            production = production.replace('queue.len >= 64 || inspected + children_inspected >= 64', 'queue.len >= 64 || children_inspected + children_inspected >= 64')
        elif args.negative_control == 'player-context':
            production = production.replace('round(100 * H.health / max(1, H.maxHealth))', '100')
        elif args.negative_control == 'escaping':
            target = '/datum/player_help_service/proc/markdown_text(value)\n\treturn html_encode(value)'
            if production.count(target) != 1:
                raise SystemExit('Escaping control target changed')
            production = production.replace(target, '/datum/player_help_service/proc/markdown_text(value)\n\treturn value')
        elif args.negative_control == 'heartbeat':
            production = production.replace('return heartbeat_confirmed && world.time - heartbeat_time < 100', 'return TRUE')
        elif args.negative_control == 'identity':
            production = production.replace('islist(response) && response["id"] == id', 'islist(response)')
        (temp / 'production.dm').write_text(production)
        (temp / 'probe.dme').write_text(PRELUDE + '\n#include "production.dm"\n' + PROBE)
        if args.prepare_only:
            (temp / 'prepared.json').write_text(json.dumps({
                'control': args.negative_control,
                'production_sha256': hashlib.sha256((ROOT / 'code/game/mob/player_help.dm').read_bytes()).hexdigest(),
                'files': {name: hashlib.sha256((temp / name).read_bytes()).hexdigest()
                          for name in ('production.dm', 'probe.dme', 'render-cases.json')},
                'no_processes_launched': True,
            }, indent=2))
            print('Help fixture prepared without compilation or runtime')
            return
        compiler = args.byond_bin / ('dm.exe' if (args.byond_bin / 'dm.exe').exists() else 'DreamMaker')
        daemon = args.byond_bin / ('dd.exe' if (args.byond_bin / 'dd.exe').exists() else 'DreamDaemon')
        built = subprocess.run([str(compiler), 'probe.dme'], cwd=temp, capture_output=True, text=True, timeout=90)
        (temp / 'compile.log').write_text(built.stdout + built.stderr)
        print(built.stdout)
        if (built.returncode or '0 errors, 0 warnings' not in built.stdout or '516.1681' not in built.stdout
                or 'invalid file' in (built.stdout + built.stderr).lower()):
            raise SystemExit('Fixture compilation failed')
        ran = subprocess.run([str(daemon), 'probe.dmb', '-invisible', '-trusted', '-close', '-log', 'probe.log'], cwd=temp, capture_output=True, text=True, timeout=40)
        output = ran.stdout + ran.stderr + (temp / 'probe.log').read_text(errors='replace')
        (temp / 'runtime.log').write_text(output)
        (temp / 'receipt.json').write_text(json.dumps({
            'control': args.negative_control, 'compiler_exit': built.returncode,
            'daemon_exit': ran.returncode, 'production_sha256': hashlib.sha256((ROOT / 'code/game/mob/player_help.dm').read_bytes()).hexdigest(),
            'generated_sha256': hashlib.sha256(production.encode()).hexdigest(),
            'scope': 'Actual verb with injected client/input boundary; actual queue/admission/poll with isolated storage, no live client or LLM'
        }, indent=2))
        if ran.returncode:
            raise SystemExit('Native daemon exited unexpectedly')
        if args.negative_control:
            expected = {'escaping': 'escaped HTML', 'heartbeat': 'first heartbeat is not proof of running worker',
                        'identity': 'wrong response identity rejected',
                        'player-context': 'asking player condition',
                        'inventory-budget': 'combined entry and child inspection budget reaches exactly 64',
                        'rate-limit': 'rapid repeats retain account cooldown',
                        'prompt-first': 'unavailable service still prompts and cancellation consumes no allowance',
                        'disconnect': 'disconnect does not release pending account'}[args.negative_control]
            if ('FAIL: ' + expected) not in output or any(error in output.lower() for error in ('runtime error:', 'bad ref', 'unhandled exception')):
                print(output)
                raise SystemExit('Negative control not detected')
            print('Expected negative control detected:', args.negative_control)
        elif 'RESULT: 0' not in output or 'FAIL:' in output or any(error in output.lower() for error in ('runtime error:', 'bad ref', 'unhandled exception')):
            print(output)
            raise SystemExit('Native help probe failed')
        else:
            cases = json.loads((temp / 'render-cases.json').read_text())
            results = json.loads((temp / 'render-results.json').read_text())
            if [row['name'] for row in results] != [case['name'] for case in cases]:
                raise SystemExit('Native render cases missing or reordered')
            for case, result in zip(cases, results):
                validate_render(case, result['html'])
            print('Native help probe PASS')


if __name__ == '__main__':
    main()

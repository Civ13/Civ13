"""Pure guards for the normal-startup, real-client gather candidate.

No process, network, game action or authorization occurs in this module.
"""
import re

from prepare_native import without_comments

BASE = "tests/gameplay_bridge/native/client_gather/"
MAP = BASE + "fixture.dmm"
ORACLE = BASE + "oracle.dm"
MODULE = "code/modules/gameplay_bridge/bridge.dm"
PREFIX = "#define CIV13_GAMEPLAY_BRIDGE\n"
SUFFIX = '\n#include "' + MODULE + '"\n#include "' + ORACLE + '"\n'
IDENTITIES = (
    "civ13.dme", "code/world.dm", "code/controllers/mc/globals.dm",
    "code/modules/client/client_procs.dm", "code/modules/client/movement.dm",
    "code/game/mob/login.dm", "code/game/mob/living/carbon/human/human.dm",
    "code/game/mob/living/carbon/human/human_life.dm",
    "code/game/mob/living/carbon/human/update_icons.dm",
    "code/game/objects/map_metadata/testing.dm", "code/game/jobs/job_controller.dm",
    "code/modules/1713/jobs/nomads.dm", "code/modules/1713/modern_items.dm",
    "code/modules/gameplay_bridge/bridge.dm", "code/modules/gameplay_bridge/mechanics.dm",
    "code/_helpers/mobs.dm", "code/game/turfs/floor_attackby.dm")


def normal_dme(original):
    if "CIV13_GAMEPLAY_BRIDGE" in original or MODULE in original or BASE in original:
        raise ValueError("production bridge/profile activation drift")
    matches = list(re.finditer(r'^#include "([^"\n]+\.dmm)"[^\S\n]*$', original, re.M))
    if len(matches) != 1:
        raise ValueError("exactly one production map include required")
    match = matches[0]
    result = PREFIX + original[:match.start()] + '#include "' + MAP + '"' + original[match.end():] + SUFFIX
    verify_dme(original, result)
    return result


def verify_dme(original, generated):
    maps = re.findall(r'^#include "([^"\n]+\.dmm)"[^\S\n]*$', original, re.M)
    if len(maps) != 1 or not generated.startswith(PREFIX) or not generated.endswith(SUFFIX):
        raise ValueError("normal startup DME boundary changed")
    restored = generated[len(PREFIX):-len(SUFFIX)]
    anchor = '#include "' + MAP + '"'
    if restored.count(anchor) != 1:
        raise ValueError("fixture map binding changed")
    restored = restored.replace(anchor, '#include "' + maps[0] + '"', 1)
    if restored != original:
        raise ValueError("production include/function projection changed")


def verify_map(source):
    # Deliberately restricted DMM, not a permissive DMM parser.
    definitions = re.findall(r'^"([a-z])" = (.+)$', source, re.M)
    expected = {
        "a": "(/turf/floor/dirt,/area/caribbean/dark)",
        "g": "(/turf/floor/grass,/area/caribbean/dark)",
        "l": "(/obj/structure/lamp/lamp_small/alwayson/white,/turf/floor/dirt,/area/caribbean/dark)",
        "m": "(/obj/map_metadata/testing,/turf/floor/dirt,/area/caribbean/dark)",
        "s": '(/obj/effect/landmark{name = "start"},/obj/effect/landmark{name = "JoinLateCiv"},/obj/item/weapon/flint/sharpened,/turf/floor/dirt,/area/caribbean/dark)'}
    grid = re.search(r'\(1,1,1\) = \{"\n([a-z\n]+)"\}\s*\Z', source)
    if len(definitions) != 5 or dict(definitions) != expected or not grid:
        raise ValueError("fixed public resource map changed")
    rows = grid[1].strip().splitlines()
    expected_rows = ["aaaaaaaaa", "aaaaaaaaa", "aaaalaaaa", "aaaaaaaaa", "aaagsgaaa",
                     "aaaaaaaaa", "aaaaaaaaa", "aaaaaaaaa", "maaaaaaaa"]
    if rows != expected_rows or source.count('(1,1,1)') != 1:
        raise ValueError("fixed 9x9 single-level geometry changed")
    remainder = re.sub(r'^"[a-z]" = .+\n', '', source, flags=re.M).strip()
    if remainder != grid[0].strip():
        raise ValueError("extra map block/source")


def verify_oracle(source):
    code = without_comments(source)
    declarations = re.findall(r'^(/[^\n]+)', code, re.M)
    allowed = {
        '/hook/startup/proc/client_gather_fixture_start()',
        '/datum/gameplay_client_gather_observer',
        '/datum/gameplay_client_gather_observer/proc/advertised(turf/T)',
        '/datum/gameplay_client_gather_observer/proc/cuttings()',
        '/datum/gameplay_client_gather_observer/proc/emit(final = FALSE)',
        '/datum/gameplay_client_gather_observer/proc/monitor()'}
    if len(declarations) != len(allowed) or set(declarations) != allowed:
        raise ValueError("oracle must not replace production entrypoints")
    if re.search(r'\.(?:[A-Za-z_]\w*)\s*(?:=(?!=)|\+\+|--|\+=|-=)', code):
        raise ValueError("oracle may not mutate external state")
    if re.search(r'\b(?:assign|execute|observe|visible|active|ready|Life|forceMove|attack_hand|gather_grass_cuttings|do_after|text2path|call|input|alert|Export|OpenPort|Reboot|shutdown|qdel|del)\s*\(', code):
        raise ValueError("oracle may not drive gameplay/authority")
    if len(re.findall(r'\bnew\b', code)) != 1 or 'var/datum/gameplay_client_gather_observer/probe = new' not in code:
        raise ValueError("oracle may construct only its own observer")
    if re.search(r'\bin\s+(?:world|clients|player_list)\b', code):
        raise ValueError("oracle must remain own actor/fixed-cell bounded")
    required = (
        'world.maxx != 9 || world.maxy != 9 || world.maxz != 1',
        '!config.skip_persistence_saving', 'bootstrap_deadline = world.time + 9000',
        'observation_deadline = bound_tick + 1200', 'world.time <= observation_deadline',
        'session.holder', 'session.gameplay_bridge_consent_mob != body',
        'body.type != /mob/living/human', 'body.life_tick < 1',
        '!istype(body.original_job, /datum/job/civilian/civnomad)',
        '!istype(map, /obj/map_metadata/testing)', 'ticker.current_state != GAME_STATE_PLAYING',
        'tool = A', 'supplied_tool_missing', 'duplicate_supplied_tool',
        'if (++visited > 128)', 'if (++visited > 64)',
        'left.get_lumcount() >= 0.5', 'right.get_lumcount() >= 0.5',
        'L.body != body || L.owner != B || L.run_generation != generation',
        'requests.len >= 2', 'world.time - returned_tick < 35',
        'body.life_tick <= first_life', 'body = null', 'session = null',
        'tool = null', 'captured = null', 'emit(TRUE)',
        '"client-gather-result.json" : "client-gather-status.json"')
    if any(anchor not in code for anchor in required):
        raise ValueError("oracle isolation/horizon/cleanup guard omitted")
    external_calls = set(re.findall(r'\b[A-Za-z_]\w*\.([A-Za-z_]\w*)\s*\(', code))
    if external_calls != {'get_active_hand', 'get_lumcount', 'monitor'}:
        raise ValueError("unreviewed external method in passive oracle")

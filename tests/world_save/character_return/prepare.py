"""Hash-bound character-return source preparation only; never compile or launch."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import re

HERE = Path(__file__).resolve().parent
COMMIT = 'f065e129e2b3c422236869218353db29c2bf62de'
CASES = ('disk', 'repeat-return', 'failed-handoff', 'occupied-bed', 'destroyed-bed',
         'refused-move', 'redirected-move', 'reserved', 'recovery-hold', 'dead', 'tdm')
CONTROLS = {
    'omit-claim-consume': ('repeat-return', 'FAIL: repeated return moved back to bed'),
    'omit-reservation': ('reserved', 'FAIL: reserved return was admitted'),
    'omit-bed-owner': ('disk', 'FAIL: disk bed ownership lost'),
}
DISABLED_STUBS = (
    '/proc/persistence_bed_return_enabled', '/map_storage/proc/prepare_character_return',
    '/map_storage/proc/finish_character_return', '/map_storage/proc/character_recovery_unready',
    '/map_storage/proc/local_character_bodies', '/map_storage/proc/return_player_eligible',
)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def verify_inputs(root):
    manifest = json.loads((HERE / 'inputs.json').read_text())
    if manifest['source_commit'] != COMMIT:
        raise ValueError('Unexpected immutable source commit')
    for path, expected in manifest['sha256'].items():
        if digest((root / path).read_bytes()) != expected:
            raise ValueError('Pinned source mismatch: ' + path)
    return manifest


def load_helpers(root):
    # This pinned module defines preparation/native functions but launches nothing on import.
    spec = importlib.util.spec_from_file_location('character_return_cross_helpers', root / 'tests/world_save/run-cross-level.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def adapt_reclaim(source, base):
    original = base.extract_proc(source, '/map_storage/proc/reclaim_saved_player')
    adapted = original
    for before, after, count in (
        ('lobby.client', 'lobby.claim_client', 5),
        ('var/client/C', 'var/datum/character_return_client/C', 1),
        ('H.key = C.key', 'character_return_transfer(C, H)', 1),
    ):
        if adapted.count(before) != count:
            raise ValueError('Exact reclaim IO anchor changed: ' + before)
        adapted = adapted.replace(before, after)
    return base.replace_once(source, original, adapted, 'dedicated reclaim IO'), original, adapted


def adapt_bed(source, base):
    # All bed policy/procedures remain production text. Only the fresh-admission
    # lobby IO accesses need the same inert client boundary as reclaim.
    original = base.extract_proc(source, '/map_storage/proc/allow_new_character')
    if original.count('lobby.client') != 5:
        raise ValueError('Exact fresh-admission IO anchor changed')
    adapted = original.replace('lobby.client', 'lobby.claim_client')
    return base.replace_once(source, original, adapted, 'dedicated fresh-admission IO'), original, adapted


def prepare(root, output, control=None):
    root, output = Path(root).resolve(), Path(output).resolve()
    if control is not None and control not in CONTROLS:
        raise ValueError('Unknown omission control')
    if output.exists():
        raise ValueError('Output must not already exist')
    manifest = verify_inputs(root)  # Before importing helpers or producing any output.
    base = load_helpers(root)
    generated = {}
    for relative in base.PRODUCTION:
        generated[Path(relative).name] = (root / relative).read_text(encoding='utf-8-sig')
    stubs = base.adapt_stubs((root / 'tests/world_save/stubs.dm').read_text())
    for name in DISABLED_STUBS:
        stubs = base.replace_once(stubs, base.extract_proc(stubs, name), '', 'dedicated disabled stub removal')
    generated['stubs.dm'] = stubs
    generated['player_reclaim.dm'], reclaim_before, reclaim_after = adapt_reclaim(generated['player_reclaim.dm'], base)
    generated['bed_return.dm'], bed_before, bed_after = adapt_bed((root / 'code/modules/persistence/bed_return.dm').read_text(), base)
    if control == 'omit-claim-consume':
        generated['player_reclaim.dm'] = base.replace_once(generated['player_reclaim.dm'],
            '\t\tpersistence_restored_bodies.Remove(C.ckey)\n', '\t\t// Generated omission: retained first-return claim.\n', 'claim consumption omission')
    elif control == 'omit-reservation':
        generated['player_reclaim.dm'] = base.replace_once(generated['player_reclaim.dm'],
            'persistence_player_claims[C.ckey] || character_recovery_unready()', 'character_recovery_unready()', 'reservation omission')
    generated['list_macro.dm'] = '\n'.join(re.findall(r'^#define islist\(A\) .+$', (root / 'code/_macros.dm').read_text(), re.M)) + '\n'
    if len(generated['list_macro.dm'].splitlines()) != 1:
        raise ValueError('Expected one islist macro')
    macros = (root / 'code/_macros.dm').read_text()
    for name in ('SPAN', 'SPAN_WARNING'):
        matches = re.findall(r'^#define ' + name + r'\([^\n]+$', macros, re.M)
        if len(matches) != 1:
            raise ValueError('Expected one production message macro: ' + name)
        generated['list_macro.dm'] += matches[0] + '\n'
    generated['reachability.dm'] = base.extract_proc((root / 'code/modules/persistence/durable_world.dm').read_text(), '/map_storage/proc/validate_durable_reachability')
    cross = (root / 'tests/world_save/cross_level_probe.dm').read_text()
    if cross.count('/world/New()\n') != 1:
        raise ValueError('Expected one original startup adapter')
    cross = cross[:cross.index('/world/New()\n')]
    cross = base.replace_once(cross, '\tturf = /turf/cross_level\n', '\tturf = /turf/floor/character_return\n', 'dedicated floor world')
    generated['cross_level_probe.dm'] = cross
    sleep = (root / 'tests/world_save/sleep_transfer_probe.dm').read_text()
    anchor = '/map_storage/cross_level/sleep_transfer/capture_durable_world()\n'
    if sleep.count(anchor) != 1:
        raise ValueError('Expected one sleep adapter boundary')
    generated['sleep_adapters.dm'] = sleep[:sleep.index(anchor)]
    for relative, target, procedures in (
        ('code/game/mob/living/carbon/human/human_helpers.dm', 'sleep_helpers.dm',
         ('/proc/is_protected_sleep_location', '/mob/living/human/proc/release_protected_sleep_buckle')),
        ('code/game/objects/buckling.dm', 'buckling.dm',
         ('/obj/proc/buckle_mob', '/obj/proc/unbuckle_mob', '/obj/proc/post_buckle_mob')),
        ('code/game/atoms_movable.dm', 'force_move.dm',
         ('/proc/persistence_live_contents', '/proc/persistence_movement_allowed', '/atom/movable/proc/forceMove')),
    ):
        text = (root / relative).read_text(encoding='utf-8-sig')
        generated[target] = '\n'.join(base.extract_proc(text, name) for name in procedures)
    fixture = (HERE / 'fixture.dm').read_text()
    if control == 'omit-bed-owner':
        fixture += '\n/obj/structure/bed/persistence_runtime_var(key)\n\treturn key == "persistence_bed_owner_ckey" || ..()\n'
    generated['character_return_fixture.dm'] = fixture
    dme = (root / 'tests/world_save/cross_level.dme').read_text()
    dme += '\n' + '\n'.join('#include "' + name + '"' for name in (
        'sleep_adapters.dm', 'sleep_helpers.dm', 'buckling.dm', 'force_move.dm',
        'bed_return.dm', 'character_return_fixture.dm')) + '\n'
    generated['probe.dme'] = dme
    receipt = {
        'source_commit': COMMIT, 'source_sha256': manifest['sha256'],
        'prepared_only': True, 'native_executed': False, 'compiled': False,
        'engine_profile': '516.1688 (execution/provenance caller separately reviewed)',
        'cases': [CONTROLS[control][0]] if control else list(CASES),
        'negative_control': control,
        'expected_result': CONTROLS[control][1] if control else 'PASS',
        'client_io_adapters': {'reclaim_lobby_accesses': 5, 'fresh_admission_lobby_accesses': 5,
                               'native_key_handoffs': 1, 'native_client_declarations': 1},
        'adapted_procedures': {
            'reclaim': {'before': digest(reclaim_before.encode()), 'after': digest(reclaim_after.encode())},
            'allow_new_character': {'before': digest(bed_before.encode()), 'after': digest(bed_after.encode())},
        },
        'generated_sha256': {name: digest(text.encode()) for name, text in generated.items()},
        'preparation_sha256': {name: digest((HERE / name).read_bytes()) for name in ('prepare.py', 'inputs.json', 'fixture.dm')},
        'limits': ['No compiler, daemon, client, process discovery or runtime launcher',
                   'Real serializer and bed/reclaim policy; constructed human physiology/medical datum and client handoff are adapters',
                   'Synthetic cross-level metadata schema; fixture-only zone-export adapter, not Nomads topology acceptance',
                   'Disk case is a same-world export/import, not fresh-process recovery',
                   'No real Login/HUD, timed sleep verb, game activation, original saves or OpenDream acceptance'],
    }
    output.mkdir(parents=True)
    for name, text in generated.items():
        (output / name).write_text(text, encoding='utf-8', newline='\n')
    (output / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
    return receipt


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--prepare-only', action='store_true', required=True)
    parser.add_argument('--source-root', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--negative-control', choices=tuple(CONTROLS))
    args = parser.parse_args()
    print(json.dumps(prepare(args.source_root, args.output, args.negative_control), indent=2))


if __name__ == '__main__':
    main()

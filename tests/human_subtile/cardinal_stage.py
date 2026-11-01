"""Fixture-only transformations for a future immutable cardinal worker stage."""
import hashlib
from pathlib import Path

MOVEMENT = 'code/game/mob/living/simple_animal/subtile_movement.dm'
PROBE = 'tests/human_subtile/probe.dm'
RANDOM_FIXTURE = 'tests/human_subtile/random_cadence_fixture.dm'
CORE = 'tests/human_subtile/scheduler_core_draft.dm'
CARDINAL_FIXTURE = 'tests/human_subtile/cardinal_probe.dm'
EXPECTED_MOVEMENT_BLOB = 'c658aa260cd486f5c8a82dc796e048c321362d54'
EXPECTED_SPECIES_BLOBS = {
    'code/game/mob/living/simple_animal/hostile/mosquitoes.dm': '9bea59584d822537d5fbeb446d95d7f9fb6b12d4',
    'code/game/mob/living/simple_animal/hostile/vampirebat.dm': '5cb84fe68311d5095a8369feabccdb00f7c745d8',
}


def git_blob(raw):
    return hashlib.sha1(b'blob ' + str(len(raw)).encode('ascii') + b'\0' + raw).hexdigest()


def adapt(out, manifest, current, random_contract, scope):
    """Adapt only a private stage built from the independently verified HEAD."""
    out = Path(out)
    stage = out / 'stage'
    for path, expected in {MOVEMENT: EXPECTED_MOVEMENT_BLOB, **EXPECTED_SPECIES_BLOBS}.items():
        if git_blob((stage/path).read_bytes()) != expected:
            raise ValueError('unexpected immutable production blob: ' + path)
    if not (stage/CARDINAL_FIXTURE).is_file():
        raise ValueError('missing cardinal fixture')
    changes = [
        (PROBE, '\tmaxx = 18\n\tmaxy = 14', '\tmaxx = 65\n\tmaxy = 65'),
        (PROBE, '\t\t\tnpc_subtile_fixture()', '\t\t\tfixture_interval_cardinal_main()'),
        (PROBE, '"scope" = "actual human/codec; headless authority adapter"',
         '"scope" = "' + scope + '", "mode" = fixture_cardinal_mode, "tick" = fixture_cardinal_tick, '
         '"movement_blob" = "' + EXPECTED_MOVEMENT_BLOB + '", "setup" = fixture_cardinal_setup, '
         '"rows" = fixture_cardinal_rows, "overflow" = fixture_random_overflow'),
    ]
    changes += [(MOVEMENT, old, new) for old, new in random_contract.movement_replacements('candidate')]
    # Both test probe wrappers have this exact field list. Update each occurrence
    # in one checked transformation; actual production source remains untouched.
    old = 'list("mode" = mode, "lag" = lag, "speed_argument" = 0)'
    new = 'list("mode" = mode, "lag" = lag, "speed_argument" = 0, "direction" = direction)'
    raw = (stage/RANDOM_FIXTURE).read_text(encoding='utf-8')
    if raw.count(old) != 2:
        raise ValueError('unexpected command observation preimage')
    for relative, before, after in changes:
        current.adapt(out, manifest, relative, before, after)
    path = stage/RANDOM_FIXTURE
    path.write_text(raw.replace(old, new), encoding='utf-8', newline='\n')
    dme = out / manifest['dme']
    with dme.open('a', encoding='utf-8', newline='\n') as stream:
        for include in (CORE, RANDOM_FIXTURE, CARDINAL_FIXTURE):
            stream.write('\n#include "' + include.replace('/', '\\') + '"')
        stream.write('\n')
    touched = {x[0] for x in changes} | {RANDOM_FIXTURE, dme.relative_to(stage).as_posix()}
    for relative in touched:
        data = (stage/relative).read_bytes()
        manifest['stage_files'][relative] = {'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()}
    manifest['cardinal_scope'] = scope
    manifest['cardinal_movement_blob'] = EXPECTED_MOVEMENT_BLOB

"""Pure staging reconstruction for the source-only bump fixture draft.

The calling job must still bind its own exact commit, worker, archive, bounds,
inputs and teardown; this file does not create or launch a job.
"""
import re
import build_guard
import source_binding
import stage_observer

LIVING = 'code/game/mob/living/living.dm'
PROBE = 'tests/human_subtile/probe.dm'
OBSERVER = 'tests/human_subtile/bump_fixture_observer.dm'
SCENARIO = 'tests/human_subtile/bump_fixture_probe.dm'
FIXTURE_BLOBS = {
    OBSERVER: 'd133a83d4dc40fd372aa0c2e5a204e05d826900e',
    SCENARIO: '27c69dd0c9de5015eb13157d186ffc1e10fbbea6',
}


def once(text, before, after):
    if text.count(before) != 1:
        raise ValueError('fixture staging preimage mismatch')
    return text.replace(before, after, 1)


def prepare_probe(raw):
    probe = raw.decode('utf-8')
    probe = once(probe, '\t\t\thuman_subtile_fixture_headless()', '\t\t\tnpc_subtile_fixture()')
    probe = once(probe, '"checks" = human_subtile_fixture_checks,',
                 '"checks" = human_subtile_fixture_checks, "npc_checks" = npc_subtile_checks, "npc_rows" = npc_subtile_rows,')
    return probe.encode()


def reconstruct(inputs, old_guard, observer, scenario, candidate):
    if set(inputs) != set(source_binding.BLOBS):
        raise ValueError('incomplete baseline input set')
    for path, expected in source_binding.BLOBS.items():
        if build_guard.blob(inputs[path]) != expected:
            raise ValueError('baseline source changed: ' + path)
    for path, raw in ((OBSERVER, observer), (SCENARIO, scenario)):
        if build_guard.blob(raw.replace(b'\r\n', b'\n')) != FIXTURE_BLOBS[path]:
            raise ValueError('fixture source changed: ' + path)
    observer = observer.replace(b'\r\n', b'\n')
    scenario = scenario.replace(b'\r\n', b'\n')
    guard = build_guard.build(old_guard,
                              inputs['code/game/mob/living/simple_animal/subtile_movement.dm'],
                              inputs['code/game/mob/living/simple_animal/hostile/tactical_ai.dm'])
    living = guard if candidate else inputs[LIVING]
    probe = prepare_probe(inputs[PROBE])
    dme = inputs['civ13.dme'].decode('utf-8')
    dme = re.sub(r'^#include ".*\.dmm"\s*$', '', dme, flags=re.M)
    dme += '\n#include "tests\\human_subtile\\mining.dm"\n#include "tests\\human_subtile\\probe.dm"\n'
    dme += '\n#include "tests\\human_subtile\\npc.dm"\n'
    dme += '\n#include "tests\\human_subtile\\bump_fixture_observer.dm"\n'
    dme += '\n#include "tests\\human_subtile\\bump_fixture_probe.dm"\n'
    return {
        LIVING: stage_observer.stage(living, candidate),
        'code/game/mob/living/simple_animal/subtile_movement.dm': stage_observer.stage_npc_finish(inputs['code/game/mob/living/simple_animal/subtile_movement.dm']),
        PROBE: stage_observer.stage_prepared_probe(probe, candidate),
        OBSERVER: observer,
        SCENARIO: scenario,
        'human_subtile.dme': dme.encode(),
    }

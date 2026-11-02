"""Exact source reconstruction for a fixture-only pair-order measurement."""
import hashlib
import re

BASE = '7436e0d95c069ebf13ce620763c3e619417ede38'
BASE_TREE = '68a32a6f3b772b2daac56b64f7c995240b746774'
REVIEWED_PARENT_TREE = '782af0b64ac5f989323b7ec48e49ddfe2e4bf5ed'
SCOPE = 'human-goat forceMove versus raw loc assignment; observational fixture only'
FIXTURE = 'tests/human_subtile/pair_measure.dm'
FIXTURE_SHA256 = '63ddd3bb1df126ef257ab03e0ec40945017e761eecec229d14b6f8668daabd0a'
BLOBS = {
    'civ13.dme': '3dd48f947b1b681844fd71c9eb84586998b71caa',
    'code/game/mob/living/living.dm': '296c8a2e370cf4aef77c68a6c7b3ee86b9c15e22',
    'code/game/mob/living/carbon/human/subtile_movement.dm': '3a3566e5c766ef4ce7d97971c6021cf8b5b7b534',
    'code/game/mob/living/simple_animal/friendly/farm_animals.dm': '42da8b3fb0223ab9a4d9542fdd566d4a4ff08042',
    'code/game/mob/living/simple_animal/subtile_movement.dm': 'c658aa260cd486f5c8a82dc796e048c321362d54',
    'code/game/mob/living/simple_animal/hostile/tactical_ai.dm': 'e83f103f7f014b8e47a3a852eb78c8e5e2c98f1f',
    'tests/human_subtile/probe.dm': '58afd77c15b3b89a3c924e428068085b04f6614a',
    'tests/human_subtile/npc.dm': '000b3713c9a156e4a35029fea4efa5af3af1778b',
    'tests/human_subtile/run-npc.py': '8a73c8ab42e2b33782c674a3ca4c37958731b768',
}


def blob(raw):
    return hashlib.sha1(b'blob ' + str(len(raw)).encode() + b'\0' + raw).hexdigest()


def once(text, old, new):
    if text.count(old) != 1:
        raise ValueError('pair stage preimage mismatch')
    return text.replace(old, new, 1)


def reconstruct(inputs, fixture):
    if set(inputs) != set(BLOBS):
        raise ValueError('incomplete base inputs')
    for path, expected in BLOBS.items():
        if blob(inputs[path]) != expected:
            raise ValueError('base blob mismatch: ' + path)
    if hashlib.sha256(fixture).hexdigest() != FIXTURE_SHA256:
        raise ValueError('fixture hash mismatch')
    probe = inputs['tests/human_subtile/probe.dm'].decode('utf-8')
    probe = once(probe, '\t\t\thuman_subtile_fixture_headless()', '\t\t\tpair_run()')
    entered = '/turf/floor/plating/subtile_fixture/Entered(atom/A, atom/old)\n\t. = ..()\n'
    observed = ('/turf/floor/plating/subtile_fixture/Entered(atom/A, atom/old)\n'
                '\tpair_observe_actor("turf_entered_before", A)\n\t. = ..()\n'
                '\tpair_observe_actor("turf_entered_after", A)\n')
    probe = once(probe, entered, observed)
    old_scope = '"scope" = "actual human/codec; headless authority adapter"'
    pair_scope = ('"scope" = "' + SCOPE + '", "pair_mode" = pair_mode, '
                  '"pair_rows" = pair_rows, "pair_case" = pair_case, '
                  '"pair_checks" = pair_checks, "pair_partial" = pair_events, '
                  '"pair_overflow" = pair_overflow')
    probe = once(probe, old_scope, pair_scope)
    dme = inputs['civ13.dme'].decode('utf-8')
    dme = re.sub(r'^#include ".*\.dmm"\s*$', '', dme, flags=re.M)
    dme += '\n#include "tests\\human_subtile\\mining.dm"\n#include "tests\\human_subtile\\probe.dm"\n'
    dme += '\n#include "tests\\human_subtile\\npc.dm"\n#include "tests\\human_subtile\\pair_measure.dm"\n'
    return {'tests/human_subtile/probe.dm': probe.encode('utf-8'),
            FIXTURE: fixture, 'human_subtile.dme': dme.encode('utf-8')}

"""Fixture-only staging for PR 3493 current-source bump observations.

No native process is launched by this module. Its output requires a separately
reviewed bounded runner and receipt validator before execution.
"""
import hashlib
import re

BASE_HEAD = '91fdf711dc3bd8d65c40ef246fd820b3f001fecb'
CANDIDATE_HEAD = '5b0040a099cdacf1091bc8b4859c298f65dda63d'
CANDIDATE_TREE = '6559a4507c5e874051966b55c758c2908541e711'
BASE_LIVING = '296c8a2e370cf4aef77c68a6c7b3ee86b9c15e22'
CANDIDATE_LIVING = 'ce6975c4090a2bb1657ef44e5de27a5e05a33165'
PROBE = '58afd77c15b3b89a3c924e428068085b04f6614a'
DME = '21272eb04d52cb7dedfab9faeaf141acef190c4a'
FIXTURE = '26b6c26798db593bccfdea20cc7e7e576e25fc43e848e6a880bacdc3c36f284a'
SCOPE = 'ordinary human-goat help bump; current-source headless fixture'


def blob(raw):
    return hashlib.sha1(b'blob ' + str(len(raw)).encode() + b'\0' + raw).hexdigest()


def once(text, old, new):
    if text.count(old) != 1:
        raise ValueError('fixture instrumentation preimage mismatch')
    return text.replace(old, new, 1)


def instrument(living, candidate):
    text = living.decode('utf-8')
    if text.count('forceMove(tmob.loc)') != 2 or text.count('tmob.forceMove(oldloc)') != 2:
        raise ValueError('unexpected paired swap-leg count')
    for indent in ('\t'*6, '\t'*5):
        old = (indent + 'var/turf/oldloc = loc\n' + indent + 'forceMove(tmob.loc)\n' +
               indent + 'tmob.forceMove(oldloc)\n')
        new = (indent + 'var/turf/oldloc = loc\n' + indent + 'ordinary_bump_trace_leg("first_leg_before", src, tmob)\n' +
               indent + 'forceMove(tmob.loc)\n' + indent + 'ordinary_bump_trace_leg("first_leg_after", src, tmob)\n' +
               indent + 'ordinary_bump_trace_leg("second_leg_before", src, tmob)\n' + indent + 'tmob.forceMove(oldloc)\n' +
               indent + 'ordinary_bump_trace_leg("second_leg_after", src, tmob)\n')
        text = once(text, old, new)
    if candidate:
        old = '\t\t\t\tif (ordinary_human_animal_swap(tmob))\n\t\t\t\t\tnow_pushing = FALSE\n'
        new = '\t\t\t\tif (ordinary_human_animal_swap(tmob))\n\t\t\t\t\tordinary_bump_trace_leg("veto", src, tmob)\n\t\t\t\t\tnow_pushing = FALSE\n'
        text = once(text, old, new)
    elif 'ordinary_human_animal_swap' in text:
        raise ValueError('baseline unexpectedly contains candidate veto')
    return text.encode('utf-8')


def reconstruct(living, probe, dme, fixture, candidate):
    if type(candidate) is not bool:
        raise ValueError('candidate mode must be explicit')
    if blob(living) != (CANDIDATE_LIVING if candidate else BASE_LIVING) or blob(probe) != PROBE or blob(dme) != DME:
        raise ValueError('source differs from reviewed current-source preimages')
    if hashlib.sha256(fixture).hexdigest() != FIXTURE:
        raise ValueError('fixture differs from reviewed bytes')
    source = probe.decode('utf-8')
    source = once(source, '\t\t\thuman_subtile_fixture_headless()', '\t\t\tordinary_bump_run()')
    source = once(source, '"scope" = "actual human/codec; headless authority adapter"',
                  '"scope" = "' + SCOPE + '", "ordinary_bump_mode" = world.params["ordinary_bump_mode"], "ordinary_bump_rows" = ordinary_bump_rows, '
                  '"ordinary_bump_case" = ordinary_bump_case, "ordinary_bump_partial" = ordinary_bump_events, '
                  '"ordinary_bump_overflow" = ordinary_bump_overflow')
    game = re.sub(r'^#include ".*\.dmm"\s*$', '', dme.decode('utf-8'), flags=re.M)
    game += '\n#include "tests\\human_subtile\\mining.dm"\n#include "tests\\human_subtile\\probe.dm"\n'
    game += '#include "tests\\human_subtile\\ordinary_bump_probe.dm"\n'
    return {'code/game/mob/living/living.dm': instrument(living, candidate),
            'tests/human_subtile/probe.dm': source.encode('utf-8'),
            'tests/human_subtile/ordinary_bump_probe.dm': fixture,
            'human_subtile.dme': game.encode('utf-8')}
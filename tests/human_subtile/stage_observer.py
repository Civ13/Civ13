"""Exact source substitutions for an isolated, unexecuted bump observer.

This is not integrated with a worker, DME, selector, archive, or native run.
"""
from pathlib import Path
import build_guard

BASELINE_BLOB = '296c8a2e370cf4aef77c68a6c7b3ee86b9c15e22'
CANDIDATE_BLOB = '9f26f9f1ea34949d9c07cd1ceae78baf35960c3d'
SCOPE = 'human-goat ordinary bump; headless authority adapter; no wildlife activation'


def stage(raw, candidate):
    raw = raw.replace(b'\r\n', b'\n')
    if build_guard.blob(raw) != (CANDIDATE_BLOB if candidate else BASELINE_BLOB):
        raise ValueError('unexpected living source blob')
    text = raw.decode('utf-8')
    start = text.index('/mob/living/Bump(atom/movable/AM, yes)')
    end = text.index('/proc/swap_density_check', start)
    prefix, body, suffix = text[:start], text[start:end], text[end:]
    anchor = '\tspawn(0)\n\t\tif ((!( yes ) || now_pushing) || !loc)'
    if body.count(anchor) != 1:
        raise ValueError('impact anchor')
    body = body.replace(anchor, '\tvar/fixture_bump_id = fixture_bump_observe("collision", src, AM)\n' + anchor, 1)
    anchor = '\t\tnow_pushing = TRUE\n\t\tif (istype(AM, /mob/living))'
    if body.count(anchor) != 1:
        raise ValueError('deferred anchor')
    latch = 'ordinary_owned_at_impact' if candidate else 'null'
    body = body.replace(anchor, '\t\tnow_pushing = TRUE\n\t\tfixture_bump_observe("deferred", src, AM, fixture_bump_id, ' + latch + ')\n\t\tif (istype(AM, /mob/living))', 1)
    anchor = '\t\t\tif (can_swap_with(tmob)) // mutual brohugs all around!\n'
    if body.count(anchor) != 1:
        raise ValueError('swap decision anchor')
    body = body.replace(anchor, anchor + '\t\t\t\tfixture_bump_observe("swap_branch", src, tmob, fixture_bump_id)\n', 1)
    anchor = '\t\tspawn(0)\n\t\t\t..()\n'
    if body.count(anchor) != 1:
        raise ValueError('parent callback anchor')
    body = body.replace(anchor, '\t\tspawn(0)\n\t\t\tfixture_bump_observe("parent_bump_before", src, AM, fixture_bump_id)\n\t\t\t..()\n\t\t\tfixture_bump_observe("parent_bump_after", src, AM, fixture_bump_id)\n', 1)
    lines = body.splitlines(keepends=True)
    out, counts = [], {'forceMove(tmob.loc)': 0, 'tmob.forceMove(oldloc)': 0, 'step(AM, t)': 0}
    for line in lines:
        token = line.strip()
        if token in counts:
            counts[token] += 1
            indent = line[:len(line) - len(line.lstrip('\t'))]
            other = 'AM' if token == 'step(AM, t)' else 'tmob'
            label = 'legacy_push' if other == 'AM' else 'legacy_swap_leg'
            out.append(indent + 'fixture_bump_observe("' + label + '_before", src, ' + other + ', fixture_bump_id)\n')
            out.append(line)
            out.append(indent + 'fixture_bump_observe("' + label + '_after", src, ' + other + ', fixture_bump_id)\n')
        else:
            out.append(line)
    if counts != {'forceMove(tmob.loc)': 2, 'tmob.forceMove(oldloc)': 2, 'step(AM, t)': 1}:
        raise ValueError('legacy mutation anchors')
    density_end = suffix.index('/mob/living/proc/can_swap_with(')
    density, tail = suffix[:density_end], suffix[density_end:]
    anchor = '\t\tif (!A.CanPass(swapee, T, TRUE))\n\t\t\treturn TRUE'
    if density.count(anchor) != 1:
        raise ValueError('swap CanPass preimage')
    replacement = ('\t\tfixture_bump_observe("canpass_before", swapper, swapee)\n'
                   '\t\tvar/fixture_bump_pass = A.CanPass(swapee, T, TRUE)\n'
                   '\t\tfixture_bump_observe("canpass_after", swapper, swapee, null, null, null, !!fixture_bump_pass)\n'
                   '\t\tif (!fixture_bump_pass)\n\t\t\treturn TRUE')
    density = density.replace(anchor, replacement, 1)
    return (prefix + ''.join(out) + density + tail).encode('utf-8')


def stage_prepared_probe(raw, candidate):
    """Adapt the exact output of npc.prepare(), not an arbitrary probe."""
    text = raw.decode('utf-8')
    expected = '\t\t\tnpc_subtile_fixture()'
    old_scope = '"scope" = "actual human/codec; headless authority adapter"'
    if text.count(expected) != 1 or text.count(old_scope) != 1:
        raise ValueError('prepared probe preimage mismatch')
    text = text.replace(expected, '\t\t\tfixture_bump_run()', 1)
    entered = '/turf/floor/plating/subtile_fixture/Entered(atom/A, atom/old)\n\t. = ..()\n'
    if text.count(entered) != 1:
        raise ValueError('fixture turf Entered preimage mismatch')
    text = text.replace(entered, '/turf/floor/plating/subtile_fixture/Entered(atom/A, atom/old)\n'
                        '\tfixture_bump_observe_actor("turf_enter_before", A)\n\t. = ..()\n'
                        '\tfixture_bump_observe_actor("turf_enter_after", A)\n', 1)
    variant = 'candidate' if candidate else 'baseline'
    new_scope = ('"scope" = "' + SCOPE + '", "bump_variant" = "' + variant + '", '
                 '"bump_setup" = fixture_bump_setup, "bump_rows" = fixture_bump_rows, "bump_case" = fixture_bump_case, '
                 '"bump_checks" = fixture_bump_assertions, "bump_partial" = fixture_bump_events, '
                 '"bump_overflow" = fixture_bump_overflow')
    return text.replace(old_scope, new_scope, 1).encode('utf-8')


def stage_npc_finish(raw):
    raw = raw.replace(b'\r\n', b'\n')
    if build_guard.blob(raw) != build_guard.WALKER_BLOB:
        raise ValueError('unexpected NPC movement source blob')
    text = raw.decode('utf-8')
    start = text.index('/datum/npc_subtile_transaction/proc/finish(')
    end = text.index('/mob/living/simple_animal/proc/npc_subtile_take_pulse', start)
    prefix, body, suffix = text[:start], text[start:end], text[end:]
    anchor = '\tvar/reached = !failed_pulse && !remaining_x && !remaining_y && valid()'
    if body.count(anchor) != 1:
        raise ValueError('NPC finish actor anchor')
    body = body.replace(anchor, '\tvar/mob/living/simple_animal/fixture_bump_finished_actor = actor\n' + anchor, 1)
    anchor = '\t\t\t\tactor.living_movement_completed()'
    if body.count(anchor) != 1:
        raise ValueError('NPC completion hook anchor')
    body = body.replace(anchor, '\t\t\t\tfixture_bump_observe("animal_living_before", actor, fixture_bump_human, null, null, src)\n' +
                        anchor + '\n\t\t\t\tfixture_bump_observe("animal_living_after", actor, fixture_bump_human, null, null, src)', 1)
    anchor = '\tfinished = TRUE\n'
    if body.count(anchor) != 1:
        raise ValueError('NPC terminal anchor')
    body = body.replace(anchor, anchor + '\tfixture_bump_observe("animal_tx_finished", fixture_bump_finished_actor, fixture_bump_human, null, null, src)\n', 1)
    return (prefix + body + suffix).encode('utf-8')

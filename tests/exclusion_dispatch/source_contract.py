"""Fail-closed source contract; no compiler or runtime execution."""
import re
import json
import os
from pathlib import Path
import subprocess
import tempfile

CURRENT_BASE = '99647037c70786a3c3944fcf5ae51b570b377f08'
MERGE_BASE = 'c4585fabaf81e1357054b4527d71d4f3a2d8a0b2'
MERGE_MASTER = 'eedc9862fcb7b2b7c3617c6972965fafa650e51a'


# Reviewed bounded-save integration adds only these non-hook blocks to the
# pinned 5bf351 baseline. Keep complete-file equality after this projection;
# deriving a baseline from candidate source would hide unrelated changes.
BOUNDED_BLOCKS = (
    ('\t\tlist/saving_export_stack = list()\n',
     '\t\tlist/saving_content_owners = list()\n\t\tlist/saving_world_movables = list()\n\t\tvar/saving_work = 0\n\t\tvar/saving_slice_start = 0\n'),
    ('\tsaving_export_stack = list()\n',
     '\tsaving_content_owners = list()\n\tsaving_world_movables = list()\n\tsaving_work = 0\n\tsaving_slice_start = world.tick_usage\n'),
    ('/map_storage/proc/add_export_content(datum/save_export_frame/frame, ref)\n\tif(!ref) return\n\tvar/key = "[ref]"\n',
     '\t// Keep the first captured edge if a completed child later moves.\n\tvar/owner = saving_content_owners[key]\n\tif(owner && owner != frame.entry) return\n\tsaving_content_owners[key] = frame.entry\n'),
)

AREA_POLICY = ('// Author policy is not restored from an ordinary or historical area payload.\n'
               '/area/persistence_runtime_var(key)\n'
               '\treturn key == "lighting_reserved_clearance_enabled" || ..()\n\n')


def reconstruct_list_baseline(master):
    """Reverse only the three reviewed switch hooks in pinned current master."""
    for kind in ('atom', 'turf', 'mob'):
        pattern = rf'^/{kind}/persistence_runtime_var\(key\)\n(?P<prefix>(?:\t[^\n]*\n)*?)\tswitch\(key\)\n\t\tif \(([^\n]+)\)\n\t\t\treturn TRUE\n\treturn \.\.\(\)'
        matches = list(re.finditer(pattern, master, re.M))
        if len(matches) != 1:
            raise ValueError(f'Expected exactly one pinned master {kind} switch hook')
        match = matches[0]
        replacement = f'/{kind}/persistence_runtime_var(key)\n{match["prefix"]}\treturn (key in list({match[2]})) || ..()'
        master = master[:match.start()] + replacement + master[match.end():]
    return master


def project_bounded_save(baseline):
    for anchor, addition in BOUNDED_BLOCKS:
        # Match complete lines: the reset anchor must not match declarations.
        pattern = re.compile(r'^' + re.escape(anchor), re.M)
        if len(list(pattern.finditer(baseline))) != 1:
            raise ValueError('Expected exactly one bounded-save baseline anchor')
        baseline = pattern.sub(lambda match: match[0] + addition, baseline, count=1)
    return baseline


def project_reserved_policy(baseline):
    """Apply only this PR's declared policy to the historical list baseline."""
    anchor = '\treturn (key in list("affecting_lights", "lighting_overlay"'
    insertion = '// HUD objects belong to a client session and are rebuilt by the normal HUD path.'
    if baseline.count(anchor) != 1 or baseline.count(insertion) != 1:
        raise ValueError('Historical reserved-policy projection anchors drifted')
    if '"lighting_reserved"' in baseline or '/area/persistence_runtime_var(key)' in baseline:
        raise ValueError('Historical baseline already contains reserved policy')
    return baseline.replace(anchor, '\treturn (key in list("lighting_reserved", "affecting_lights", "lighting_overlay"', 1).replace(insertion, AREA_POLICY + insertion, 1)


def project_fullbright_exclusions(baseline):
    """Apply exactly the two runtime-only fullbright serialization exclusions."""
    pairs = (
        ('list(/mob/new_player, /atom/movable/lighting_overlay)',
         'list(/mob/new_player, /atom/movable/lighting_overlay, /atom/movable/lighting_fullbright)'),
        ('if(istype(object, /obj/map_metadata) || istype(object, /atom/movable/lighting_overlay))',
         'if(istype(object, /obj/map_metadata) || istype(object, /atom/movable/lighting_overlay) || istype(object, /atom/movable/lighting_fullbright))'),
    )
    if '/atom/movable/lighting_fullbright' in baseline:
        raise ValueError('Historical baseline already contains fullbright exclusions')
    for before, after in pairs:
        if baseline.count(before) != 1:
            raise ValueError('Historical fullbright exclusion anchor drifted')
        baseline = baseline.replace(before, after, 1)
    return baseline


def project_area_change_owner(baseline):
    """Exclude only the new process-local area transition identity."""
    anchor = '/turf/persistence_runtime_var(key)\n'
    if baseline.count(anchor) != 1 or '"area_change_owner"' in baseline:
        raise ValueError('Area-change ownership projection anchor drifted')
    return baseline.replace(anchor, anchor + '\tif (key == "area_change_owner")\n\t\treturn TRUE\n', 1)


def project_lighting_policy(master):
    """The two fullbright exclusions and transient area-owner guard only."""
    return project_area_change_owner(project_fullbright_exclusions(master))


def current_lighting_policy(base):
    """Accept exact pre/post-addition event bases, never partial lighting policy.

    The candidate is not normalized: losing an existing exclusion must fail.
    Keep the strict historical projections above unchanged.
    """
    token = '/atom/movable/lighting_fullbright'
    if token in base:
        pairs = (
            'list(/mob/new_player, /atom/movable/lighting_overlay, /atom/movable/lighting_fullbright)',
            'if(istype(object, /obj/map_metadata) || istype(object, /atom/movable/lighting_overlay) || istype(object, /atom/movable/lighting_fullbright))',
        )
        if base.count(token) != 2 or any(base.count(anchor) != 1 for anchor in pairs):
            raise ValueError('Event base has partial or changed fullbright exclusions')
    else:
        base = project_fullbright_exclusions(base)
    owner = '/turf/persistence_runtime_var(key)\n\tif (key == "area_change_owner")\n\t\treturn TRUE\n'
    if '"area_change_owner"' in base:
        if base.count('"area_change_owner"') != 1 or base.count(owner) != 1:
            raise ValueError('Event base has partial or changed area-owner guard')
    else:
        base = project_area_change_owner(base)
    return base


def transform(baseline):
    expected = project_reserved_policy(project_bounded_save(baseline))
    for kind in ('atom', 'turf', 'mob'):
        pattern = rf'^/{kind}/persistence_runtime_var\(key\)\n(?P<prefix>(?:\t[^\n]*\n)*?)\treturn \(key in list\((.*?)\)\) \|\| \.\.\(\)'
        matches = list(re.finditer(pattern, expected, re.M))
        if len(matches) != 1:
            raise ValueError(f'Expected exactly one baseline {kind} hook')
        match = matches[0]
        replacement = f'/{kind}/persistence_runtime_var(key)\n{match["prefix"]}\tswitch(key)\n\t\tif ({match[2]})\n\t\t\treturn TRUE\n\treturn ..()'
        expected = expected[:match.start()] + replacement + expected[match.end():]
    return expected


def validate(baseline, candidate):
    if transform(baseline) != candidate:
        raise ValueError('Only approved dispatch and reserved-policy projections may differ')


def validate_current_master(master, candidate):
    """Preserve the immutable event base, adding only missing lighting policy."""
    if current_lighting_policy(master) != candidate:
        raise ValueError('Only approved fullbright exclusions and area-owner guard may differ from event base')


def validate_historical_bounded(master, candidate):
    """Master already owns dispatch/policy; only the bounded blocks may differ."""
    if project_bounded_save(master) != candidate:
        raise ValueError('Only approved bounded-save additions may differ from pinned current master')


def project_merged_source(feature):
    """Apply master bounded-save, pre-round and save-vote changes to the pinned feature source."""
    result = project_bounded_save(feature)
    changes = (
        ('/datum/controller/gameticker/proc/savemap(datum/persistence_restart_transaction/transaction)\n',
         '\t// A lobby/setting-up world has no round to persist; restored rounds are PLAYING.\n'
         '\tif(current_state < GAME_STATE_PLAYING)\n\t\treturn FALSE\n'),
        ('\toperation.finish(TRUE)\n\treturn 1\n\n/map_storage\n',
         None),
    )
    for anchor, addition in changes:
        if result.count(anchor) != 1:
            raise ValueError('Merged source projection anchor changed')
        if addition is None:
            result = result.replace(anchor, '\toperation.finish(TRUE)\n\tlast_persistence_save_time = world.time\n\treturn 1\n\n/map_storage\n', 1)
        else:
            result = result.replace(anchor, anchor + addition, 1)
    return result


def validate_merged_source(feature, candidate):
    if project_merged_source(feature) != candidate:
        raise ValueError('Merged source differs from the exact feature plus master projection')


def event_identity(repo, environ=os.environ):
    """Bind the active CI event to the exact checked-out commit and event base."""
    if environ.get('GITHUB_ACTIONS') != 'true':
        return None
    kind = environ.get('GITHUB_EVENT_NAME')
    try:
        event = json.loads(Path(environ['GITHUB_EVENT_PATH']).read_text(encoding='utf-8'))
        head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=repo, text=True).strip()
        if kind == 'pull_request':
            pr = event['pull_request']
            event_head, base = pr['head']['sha'], pr['base']['sha']
        elif kind == 'push':
            event_head = environ['GITHUB_SHA']
            if event.get('after') != event_head:
                raise ValueError('Push event after SHA does not match checkout')
            base = event['before']
        elif kind == 'workflow_dispatch':
            event_head = environ['GITHUB_SHA']
            inputs = event.get('inputs')
            base = inputs.get('exclusion_comparison_base') if isinstance(inputs, dict) else None
            if not isinstance(base, str) or not re.fullmatch(r'[0-9a-f]{40}', base):
                raise ValueError('Manual exclusion checks require exclusion_comparison_base as a full commit SHA')
        else:
            raise ValueError('Unsupported source identity event')
        if not all(isinstance(x, str) and re.fullmatch(r'[0-9a-f]{40}', x)
                   for x in (head, event_head, base)) or head != event_head:
            raise ValueError('Source event head does not match checkout')
        if base == head or base == '0' * 40:
            raise ValueError('Source event requires a distinct nonzero comparison base')
        merge_base = subprocess.check_output(['git', 'merge-base', head, base], cwd=repo, text=True).strip()
        if not re.fullmatch(r'[0-9a-f]{40}', merge_base):
            raise ValueError('Source event commits have no validated merge base')
        if kind in ('push', 'workflow_dispatch') and merge_base != base:
            raise ValueError('Source event comparison base must be an ancestor of head')
        return {'head': head, 'base': base, 'merge_base': merge_base}
    except (KeyError, TypeError, OSError, json.JSONDecodeError, subprocess.SubprocessError) as error:
        raise ValueError('Source event identity unavailable') from error


def replay_reviewed_merge(base, reviewed_base, reviewed_result):
    """Reapply the reviewed source delta to a verified evolving event base."""
    with tempfile.TemporaryDirectory(prefix='exclusion-source-projection-') as directory:
        paths = [Path(directory) / name for name in ('event-base.dm', 'reviewed-base.dm', 'reviewed-result.dm')]
        for path, text in zip(paths, (base, reviewed_base, reviewed_result)):
            path.write_text(text, encoding='utf-8', newline='\n')
        result = subprocess.run(['git', 'merge-file', '-p', *map(str, paths)],
                                capture_output=True, text=True, encoding='utf-8', timeout=15)
        if result.returncode != 0:
            raise ValueError('Reviewed source projection conflicts with the event base')
        return result.stdout


def resolve_event_projection(repo, identity, feature, candidate, master, reviewed):
    """Select an exact master- or feature-ancestry projection, rejecting drift."""
    base = current_lighting_policy(subprocess.check_output(['git', 'show', identity['base'] + ':code/modules/persistence/functions.dm'], cwd=repo, text=True))
    feature, master, reviewed = map(current_lighting_policy, (feature, master, reviewed))
    try:
        projected = replay_reviewed_merge(base, master, reviewed)
    except ValueError:
        projected = None
    if candidate == projected:
        return projected, 'master-base'
    ancestor = subprocess.check_output(['git', 'merge-base', identity['base'], MERGE_BASE], cwd=repo, text=True).strip()
    if ancestor != MERGE_BASE:
        raise ValueError('Event base is not descended from the reviewed feature')
    projected = replay_reviewed_merge(base, feature, reviewed)
    if candidate != projected:
        raise ValueError('Source does not match a reviewed projection of the event base')
    return projected, 'feature-base'

"""Prepare a full-source, synthetic spatial writer/reader probe; never execute it.

This review adapter stages a committed Git snapshot plus an explicit, hashed
overlay of the candidate's dirty files. It does not compile, run BYOND, access
the network, or authorize native execution. The process envelope and failure
controls still need review before a native runner may be attached.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
OVERLAY = (
    'code/game/mob/living/carbon/human/human.dm',
    'code/game/mob/living/carbon/human/subtile_movement.dm',
    'code/game/mob/living/carbon/human/update_icons.dm',
    'code/game/mob/living/carbon/human/pull_pair_producer.dm',
    'code/game/mob/living/carbon/human/pull_pair_ownership.dm',
    'code/modules/persistence/functions.dm',
    'code/modules/persistence/loading.dm',
    'code/modules/persistence/saving.dm',
)
DRIVER_INPUTS = (
    'tests/movement_save_chunks/human_spatial_stage.py',
    'tests/movement_save_chunks/human_spatial_run.py',
    'tests/movement_save_chunks/benchmark.py',
    'tests/human_subtile/run.py', 'scripts/byond_runtime.py',
    'scripts/byond_toolchain.py', 'tools/byond/version.json',
)
SCOPE_INPUTS = tuple(sorted(set(OVERLAY + DRIVER_INPUTS +
                               ('tests/movement_save_chunks/human_spatial_probe.dm',))))


def sha(data):
    return hashlib.sha256(data).hexdigest()


def review_scope():
    """Canonical explicit overlay/driver content to approve outside the run."""
    rows = {}
    for name in SCOPE_INPUTS:
        data = (ROOT / name).read_bytes()
        rows[name] = {'bytes': len(data), 'sha256': sha(data)}
    body = {'schema': 1, 'files': rows}
    canonical = json.dumps(body, sort_keys=True, separators=(',', ':'), ensure_ascii=True).encode()
    return {'sha256': sha(canonical), **body}


def replace_once(data, old, new, label):
    if data.count(old) != 1:
        raise ValueError('Fixture anchor drift: ' + label)
    return data.replace(old, new, 1)


def instrument_legacy_parent_refusal(data):
    """Record fixture-only evidence without changing the refusal condition."""
    original = '\t\tif(!istype(legacy_parent) || legacy_parent.z != H.z) throw EXCEPTION("Human legacy save has no valid parent")'
    instrumented = (
        '\t\tif(!istype(legacy_parent) || legacy_parent.z != H.z)\n'
        '\t\t\ttry\n'
        '\t\t\t\thuman_spatial_fixture_record_legacy_refusal(H, legacy_parent, record["mode"])\n'
        '\t\t\tcatch(var/exception/diagnostic_error)\n'
        '\t\t\t\thuman_spatial_fixture_legacy_diagnostic = list("diagnostic_error" = TRUE)\n'
        '\t\t\tthrow EXCEPTION("Human legacy save has no valid parent")'
    )
    return replace_once(data, original, instrumented, 'legacy parent refusal diagnostic')


def stage(output):
    spec = importlib.util.spec_from_file_location('human_fixture_stager', ROOT / 'tests/human_subtile/run.py')
    legacy = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(legacy)
    manifest = legacy.prepare(ROOT, output, 'human')
    root = output / 'stage'
    overlays = {}
    for name in OVERLAY:
        source = (ROOT / name).read_bytes()
        target = root / name
        if not target.is_file():
            raise ValueError('Overlay target missing: ' + name)
        original = target.read_bytes()
        target.write_bytes(source)
        overlays[name] = {'base_sha256': sha(original), 'candidate_sha256': sha(source)}

    path = root / 'code/game/mob/living/carbon/human/subtile_movement.dm'
    data = path.read_text(encoding='utf-8')
    data = replace_once(data,
        '\treturn owner && client == owner && owner.mob == src && owner.canmove && owner.moving',
        '\treturn (!owner && human_spatial_fixture_authorized) || (owner && client == owner && owner.mob == src && owner.canmove && owner.moving)',
        'headless authority')
    data = replace_once(data,
        '\t\tif (actor.human_subtile_save_request)\n\t\t\tactor.human_subtile_save_request.acknowledge(actor, src)',
        '\t\tif (human_spatial_fixture_handoffs && actor.persistence_owner_ckey == "syntheticfixture") human_spatial_fixture_pulses_after++\n'
        '\t\tif (actor == human_spatial_fixture_late_actor && human_spatial_fixture_late_capsule && persistence_save_in_progress) human_spatial_fixture_late_pulses++\n'
        '\t\tif (actor.human_subtile_save_request)\n\t\t\tactor.human_subtile_save_request.acknowledge(actor, src)',
        'post-handoff pulse instrumentation')
    data = replace_once(data,
        '\t\tcaptured = TRUE\n\t\treturn TRUE',
        '\t\tcaptured = TRUE\n'
        '\t\tif (human_spatial_fixture_authorized && T && H.persistence_owner_ckey == "syntheticfixture")\n'
        '\t\t\thuman_spatial_fixture_handoffs++\n'
        '\t\t\thuman_spatial_fixture_capsule = position.Copy()\n'
        '\t\tif (H == human_spatial_fixture_late_actor) human_spatial_fixture_late_capsule = position.Copy()\n'
        '\t\treturn TRUE',
        'group capture instrumentation')
    data = replace_once(data,
        '\t\tactor.living_movement_completed()\n\t\tactor.human_movement_completed()',
        '\t\tactor.living_movement_completed()\n'
        '\t\tif (actor == human_spatial_fixture_drag_actor) human_spatial_fixture_living_completions++\n'
        '\t\tactor.human_movement_completed()\n'
        '\t\tif (actor == human_spatial_fixture_drag_actor) human_spatial_fixture_human_completions++',
        'drag completion instrumentation')
    data = replace_once(data,
        '\t\tstep_x = S["sx"]\n\t\tstep_y = S["sy"]',
        '\t\thuman_spatial_fixture_direct_actor = src\n'
        '\t\thuman_spatial_fixture_direct_active = TRUE\n'
        '\t\tstep_x = S["sx"]\n\t\tstep_y = S["sy"]\n'
        '\t\thuman_spatial_fixture_direct_active = FALSE',
        'direct assignment callback instrumentation')
    data = replace_once(data,
        '\tliving_movement_completed()\n\thuman_movement_completed()\n',
        '\tliving_movement_completed()\n'
        '\tif(src == human_spatial_fixture_direct_actor) human_spatial_fixture_restore_living++\n'
        '\thuman_movement_completed()\n'
        '\tif(src == human_spatial_fixture_direct_actor) human_spatial_fixture_restore_human++\n',
        'restore completion instrumentation')
    path.write_text(data, encoding='utf-8', newline='\n')

    human = root / 'code/game/mob/living/carbon/human/human.dm'
    data = human.read_text(encoding='utf-8')
    data = replace_once(data, '/mob/living/human/Move()\n',
        '/mob/living/human/Move()\n'
        '\tif(human_spatial_fixture_direct_active && src == human_spatial_fixture_direct_actor) human_spatial_fixture_direct_callbacks++\n',
        'direct Move callback instrumentation')
    human.write_text(data, encoding='utf-8', newline='\n')

    # The native living Move drag path requires a moving client. Only the
    # fixture's explicitly named headless actor may simulate that predicate;
    # every other movement and ownership condition remains production code.
    living = root / 'code/game/mob/living/living.dm'
    data = living.read_text(encoding='utf-8')
    start = data.index('/mob/living/Move(a, b, flag)\n')
    end = data.find('\n/mob/living/', start + 1)
    if end < 0: raise ValueError('Fixture living Move end anchor missing')
    original = data[start:end]
    adapted = replace_once(original, '(client && client.moving)',
        '((client && client.moving) || (src == human_spatial_fixture_drag_actor && human_spatial_fixture_authorized))',
        'headless drag predicate')
    living.write_text(data[:start] + adapted + data[end:], encoding='utf-8', newline='\n')

    saver = root / 'code/modules/persistence/saving.dm'
    data = saver.read_text(encoding='utf-8')
    data = instrument_legacy_parent_refusal(data)
    data = replace_once(data, '\trecord["mode"] = "spatial"\n\treturn record',
        '\trecord["mode"] = "spatial"\n'
        '\tif(H == human_spatial_fixture_late_actor) human_spatial_fixture_wait_late_pulse()\n'
        '\treturn record', 'late walker continuation witness')
    data = replace_once(data, '\tcapture_human_save_roster_positions(operation)',
        '\tcapture_human_save_roster_positions(operation)\n'
        '\tif(world.params["phase"] == "writer") human_spatial_fixture_start_late_walker()\n'
        '\tif(human_spatial_fixture_case == "roster") operation.human_roster_changed = TRUE',
        'roster invalidation control')
    data = replace_once(data, '\tinspect_human_saved_origins(operation)',
        '\thuman_spatial_fixture_geometry_metrics = list("turfs" = operation.human_geometry_turf_records, "objects" = operation.human_geometry_object_records, "added_fields" = operation.human_geometry_added_fields)\n'
        '\thuman_spatial_fixture_mutate_candidate(operation)\n'
        '\tinspect_human_saved_origins(operation)', 'candidate negative controls')
    data = replace_once(data, '\t\tcompleted_request.serialized = TRUE\n#endif\n\treturn ref',
        '\t\tcompleted_request.serialized = TRUE\n#endif\n'
        '\tif(ishuman(A) && A:persistence_owner_ckey == "syntheticseated") human_spatial_fixture_move_saved_seated(A)\n'
        '\treturn ref', 'legacy reference-first exit witness')
    saver.write_text(data, encoding='utf-8', newline='\n')

    probe = root / 'tests/human_subtile/probe.dm'
    data = probe.read_text(encoding='utf-8')
    data = replace_once(data, '\tturf = /turf/floor/plating/subtile_fixture', '\tturf = /turf/floor/dirt', 'fixture turf')
    data = replace_once(data, '/world/New()', '/world/proc/unused_human_spatial_fixture_startup()', 'fixture startup')
    probe.write_text(data, encoding='utf-8', newline='\n')
    fixture = (HERE / 'human_spatial_probe.dm').read_bytes()
    (root / 'tests/human_subtile/human_spatial_probe.dm').write_bytes(fixture)
    dme = output / manifest['dme']
    content = dme.read_text(encoding='utf-8')
    dme.write_text('#define CIV13_HUMAN_SPATIAL_EXPERIMENTAL 1\n' + content +
                   '\n#include "tests\\human_subtile\\human_spatial_probe.dm"\n', encoding='utf-8', newline='\n')
    scope = review_scope()
    manifest.update(candidate_overlays=overlays, fixture_sha256=sha(fixture),
                    driver_inputs={p: sha((ROOT / p).read_bytes()) for p in DRIVER_INPUTS},
                    review_scope_sha256=scope['sha256'],
                    adapted_subtile_sha256=sha(path.read_bytes()),
                    adapted_human_sha256=sha(human.read_bytes()),
                    adapted_living_sha256=sha(living.read_bytes()),
                    adapted_saver_sha256=sha(saver.read_bytes()),
                    adapted_probe_sha256=sha(probe.read_bytes()),
                    adapted_dme_sha256=sha(dme.read_bytes()),
                    scope='synthetic headless writer and fresh reader; no connected-client proof',
                    execution='not_run', native_runner='requires separate approval')
    manifest['stage_files'] = {
        p.relative_to(root).as_posix(): {'bytes': p.stat().st_size, 'sha256': sha(p.read_bytes())}
        for p in root.rglob('*') if p.is_file()
    }
    (output / 'human-spatial-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    (output / 'human-spatial-review-scope.json').write_text(json.dumps(scope, indent=2) + '\n', encoding='utf-8')
    return manifest


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--review-scope', action='store_true')
    args = parser.parse_args()
    if args.review_scope:
        if args.output: parser.error('--review-scope cannot prepare a stage')
        print(json.dumps(review_scope(), indent=2))
        raise SystemExit(0)
    if not args.output: parser.error('--output is required for staging')
    receipt = stage(args.output.resolve())
    print('Prepared only; native runner requires separate approval; head=' + receipt['head'])

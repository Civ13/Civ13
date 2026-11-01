"""Fixed 350,000-turf synthetic comparison staging; never runs native code."""
from __future__ import annotations
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
SCOPE_INPUTS = tuple(sorted((
    '.github/workflows/moving-save-chunks.yml',
    'scripts/travis_pre_byond.sh',
    'tests/movement_save_chunks/human_scale_stage.py',
    'tests/movement_save_chunks/human_scale_run.py',
    'tests/movement_save_chunks/human_scale_probe.dm',
    'tests/movement_save_chunks/test_human_scale.py',
    'tests/movement_save_chunks/test_human_scale_workflow.py',
    'tests/movement_save_chunks/human_spatial_run.py',
    'tests/movement_save_chunks/human_spatial_stage.py',
    'tests/movement_save_chunks/benchmark.py',
    'tests/movement_save_chunks/diagnostic_cases.py',
    'tests/movement_save_chunks/datum_profile.py',
    'tests/movement_save_chunks/preflight_fixture.py',
    'tests/human_subtile/run.py', 'tests/human_subtile/probe.dm',
    'scripts/byond_runtime.py', 'scripts/byond_toolchain.py',
    'tools/byond/version.json',
)))
MACRO = '#define CIV13_HUMAN_SPATIAL_EXPERIMENTAL 1\n'


def sha(data):
    return hashlib.sha256(data).hexdigest()


def review_scope():
    files = {}
    for name in SCOPE_INPUTS:
        data = (ROOT / name).read_bytes()
        files[name] = {'bytes': len(data), 'sha256': sha(data)}
    body = {'schema': 1, 'files': files}
    encoded = json.dumps(body, sort_keys=True, separators=(',', ':'), ensure_ascii=True).encode()
    return {'sha256': sha(encoded), **body}


def replace_once(data, old, new, label):
    if data.count(old) != 1:
        raise ValueError('Scale fixture anchor drift: ' + label)
    return data.replace(old, new, 1)


def adapt_probe(data):
    data = replace_once(data, '\tmaxx = 18\n', '\tmaxx = 700\n', 'width')
    data = replace_once(data, '\tmaxy = 14\n', '\tmaxy = 500\n', 'height')
    data = replace_once(data, '\tmaxz = 1\n', '\tmaxz = 1\n', 'level')
    data = replace_once(data, '\tturf = /turf/floor/plating/subtile_fixture',
                        '\tturf = /turf/floor/dirt', 'floor')
    return replace_once(data, '/world/New()', '/world/proc/unused_scale_fixture_startup()', 'startup')


def instrument_saver(data):
    # Identical in both variants. No yield, guard or deadline is changed.
    data = replace_once(data, '\tfor(var/A = 1, A <= world.maxz, A++)\n\t\tsaving_z = A',
                        '\thuman_scale_serialization_start = world.realtime\n'
                        '\tfor(var/A = 1, A <= world.maxz, A++)\n\t\tsaving_z = A', 'level start')
    data = replace_once(data, '\t\tsavefile.Flush()\n\t\tsavefile = null',
                        '\t\tsavefile.Flush()\n\t\thuman_scale_serialization_end = world.realtime\n'
                        '\t\tsavefile = null', 'level flush')
    data = replace_once(data, '\tinspect_human_saved_origins(operation)\n',
                        '\thuman_scale_human_checks_start = world.realtime\n'
                        '\tinspect_human_saved_origins(operation)\n', 'human checks start')
    return replace_once(data, '\toperation.seal_human_containment_proof()\n',
                        '\toperation.seal_human_containment_proof()\n'
                        '\thuman_scale_human_checks_end = world.realtime\n', 'human checks end')


def prepare(output, reviewed_head, reviewed_scope):
    """Stage committed game once and two DME files differing only by the macro."""
    import human_spatial_run as common
    spec = importlib.util.spec_from_file_location('scale_legacy_fixture', ROOT / 'tests/human_subtile/run.py')
    legacy = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(legacy)
    manifest = legacy.prepare(ROOT, output, 'human')
    if manifest['head'] != reviewed_head:
        raise ValueError('Scale staged head differs from reviewed head')
    scope = review_scope()
    if scope['sha256'] != reviewed_scope:
        raise ValueError('Scale staged scope differs from reviewed scope')
    stage = output / 'stage'
    probe = stage / 'tests/human_subtile/probe.dm'
    probe.write_text(adapt_probe(probe.read_text(encoding='utf-8')), encoding='utf-8', newline='\n')
    saver = stage / 'code/modules/persistence/saving.dm'
    saver.write_text(instrument_saver(saver.read_text(encoding='utf-8')), encoding='utf-8', newline='\n')
    target = stage / 'tests/human_subtile/human_scale_probe.dm'
    if target.exists():
        raise ValueError('Scale probe target already exists')
    fixture = (HERE / 'human_scale_probe.dm').read_bytes()
    if sha(fixture) != scope['files']['tests/movement_save_chunks/human_scale_probe.dm']['sha256']:
        raise ValueError('Scale fixture changed after scope verification')
    target.write_bytes(fixture)
    original = output / manifest['dme']
    dme = original.read_text(encoding='utf-8') + '\n#include "tests\\human_subtile\\human_scale_probe.dm"\n'
    if MACRO in dme:
        raise ValueError('Scale baseline unexpectedly contains the feature definition')
    disabled = stage / 'human_scale_disabled.dme'
    enabled = stage / 'human_scale_enabled.dme'
    disabled.write_text(dme, encoding='utf-8', newline='\n')
    enabled.write_text(MACRO + dme, encoding='utf-8', newline='\n')
    if enabled.read_bytes() != MACRO.encode() + disabled.read_bytes():
        raise ValueError('Scale DME variants differ beyond the feature definition')
    files = common.hashes(stage, total_limit=2 * 1024**3, max_entries=12000)
    if review_scope()['sha256'] != reviewed_scope:
        raise ValueError('Scale scope changed while staging')
    result = {'schema': 1, 'head': reviewed_head, 'scope_sha256': reviewed_scope,
              'world': {'x': 700, 'y': 500, 'z': 1, 'turfs': 350000, 'humans': 32, 'ground_items': 5000},
              'variants': ['disabled', 'enabled'], 'comparison': 'fixed_stationary_single_sample',
              'enabled_dme_is_only_macro_plus_disabled': True, 'stage_files': files,
              'execution': 'not_run', 'native_requires_separate_approval': True}
    (output / 'human-scale-manifest.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--review-scope', action='store_true', required=True)
    parser.parse_args()
    print(json.dumps(review_scope(), indent=2))

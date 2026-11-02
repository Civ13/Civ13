"""Prepare the reviewed debug-save candidate; never compile or run BYOND."""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
OVERLAY = (
    'civ13.dme', 'code/modules/admin/admin_verbs.dm',
    'code/modules/persistence/admin.dm', 'code/modules/persistence/functions.dm',
    'code/modules/persistence/saving.dm', 'code/modules/persistence/debug_lossy.dm',
)
SCOPE = tuple(sorted(OVERLAY + (
    'tests/save_debug_fixture/stage.py', 'tests/save_debug_fixture/probe.dm',
    'tests/save_debug_fixture/location_controls.dm',
    'tests/save_debug_fixture/controller.py', 'tests/save_debug_fixture/test_fixture.py', 'tests/save_debug_fixture/README.md', 'tests/human_subtile/run.py',
    'tests/human_subtile/probe.dm', 'tests/human_subtile/mining.dm',
    'scripts/byond_runtime.py', 'scripts/byond_toolchain.py',
    'tools/byond/version.json',
)))


def sha(data): return hashlib.sha256(data).hexdigest()


def canonical(raw):
    normalized = raw.replace(b'\r\n', b'\n')
    if b'\r' in normalized:
        raise ValueError('non-canonical lone carriage return')
    return normalized


def scope(root=ROOT):
    rows = {name: {'bytes': len(raw), 'sha256': sha(raw)}
            for name in SCOPE for raw in [canonical((root / name).read_bytes())]}
    manifest = {'schema': 1, 'files': rows}
    raw = json.dumps(manifest, sort_keys=True, separators=(',', ':')).encode()
    return {'sha256': sha(raw), **manifest}


def replace_once(source, before, after, label):
    if source.count(before) != 1:
        raise ValueError('fixture source anchor drift: ' + label)
    return source.replace(before, after, 1)


def inject_mob_handoff(source):
    # Synthetic-only deterministic move AFTER production encoded the child,
    # BEFORE its existing unchanged child/parent consistency guard.
    anchor = ('\t\t\tfor(var/mob/content in parent.contents)\n'
              '\t\t\t\tif(content.loc != parent) continue\n'
              '\t\t\t\tvar/child_ref = BuildVarDirectory(savefile, content, 1, TRUE)\n'
              '\t\t\t\trequire_export_frame(frame)\n')
    return replace_once(source, anchor, anchor +
        '\t\t\t\tdebug_fixture_after_child_capture(parent, content, child_ref)\n',
        'mob handoff')


def inject_late_location(source):
    # Test-only named actor mutation between round write and final audit.
    anchor = ('\tif(!text2file(json_encode(round_state), "map_saves/round.json"))\n'
              '\t\tthrow EXCEPTION("Could not write round state")\n'
              '\tif(debug_policy) debug_policy.audit(generation, operation)\n')
    return replace_once(source, anchor, anchor.replace(
        '\tif(debug_policy) debug_policy.audit(generation, operation)\n',
        '\tif(debug_policy) debug_fixture_before_final_audit(debug_policy)\n'
        '\tif(debug_policy) debug_policy.audit(generation, operation)\n'), 'late audit handoff')


def stage(output, expected_head, expected_scope):
    actual = scope()
    if not re.fullmatch(r'[0-9a-f]{40}', expected_head) or not re.fullmatch(r'[0-9a-f]{64}', expected_scope):
        raise ValueError('full reviewed head and scope required')
    if actual['sha256'] != expected_scope:
        raise ValueError('reviewed scope changed')
    spec = importlib.util.spec_from_file_location('debug_fixture_base', ROOT / 'tests/human_subtile/run.py')
    base = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(base)
    if base.git(ROOT, 'rev-parse', 'HEAD').decode().strip() != expected_head:
        raise ValueError('reviewed head changed')
    manifest = base.prepare(ROOT, output, 'human')
    staged = output / 'stage'
    overlays = {}
    for name in OVERLAY:
        target = staged / name
        before = sha(target.read_bytes()) if target.is_file() else None
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(canonical((ROOT / name).read_bytes()))
        overlays[name] = {'base_sha256': before, 'candidate_sha256': sha(target.read_bytes())}
    saver = staged / 'code/modules/persistence/saving.dm'
    saver.write_text(inject_late_location(inject_mob_handoff(saver.read_text(encoding='utf-8'))), encoding='utf-8', newline='\n')
    old_probe = staged / 'tests/human_subtile/probe.dm'
    old = old_probe.read_text(encoding='utf-8')
    old_probe.write_text(replace_once(old, '/world/New()\n', '/world/proc/unused_debug_base_probe()\n', 'old world startup'), encoding='utf-8', newline='\n')
    probe = staged / 'tests/save_debug_fixture/probe.dm'
    probe.parent.mkdir(parents=True, exist_ok=True)
    probe.write_bytes(canonical((ROOT / 'tests/save_debug_fixture/probe.dm').read_bytes()))
    location_controls = staged / 'tests/save_debug_fixture/location_controls.dm'
    location_controls.write_bytes(canonical((ROOT / 'tests/save_debug_fixture/location_controls.dm').read_bytes()))
    dme = (staged / 'civ13.dme').read_text(encoding='utf-8')
    dme = re.sub(r'^#include ".*\.dmm"\s*$', '', dme, flags=re.M)
    dme += '\n#include "tests\\human_subtile\\mining.dm"\n#include "tests\\human_subtile\\probe.dm"\n#include "tests\\save_debug_fixture\\probe.dm"\n#include "tests\\save_debug_fixture\\location_controls.dm"\n'
    (staged / 'human_subtile.dme').write_text(dme, encoding='utf-8', newline='\n')
    result = {'head': expected_head, 'scope': actual, 'overlays': overlays,
              'adaptations': manifest['adaptations'], 'instrumented_saver_sha256': sha(saver.read_bytes()),
              'adapted_base_probe_sha256': sha(old_probe.read_bytes()), 'dme_sha256': sha(dme.encode()),
              'prepared_only': True, 'native_executed': False}
    (output / 'debug-fixture-manifest.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--head', required=True)
    parser.add_argument('--scope', required=True)
    args = parser.parse_args()
    print(json.dumps(stage(args.output, args.head, args.scope)))

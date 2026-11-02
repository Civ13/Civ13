"""Build two copy-on-write stages from one exact production preimage."""
import copy
import hashlib
import os
from pathlib import Path
import shutil
import pair_stage

PROBE = 'tests/human_subtile/probe.dm'


def digest(raw):
    return {'bytes': len(raw), 'sha256': hashlib.sha256(raw).hexdigest()}


def npc_probe(raw):
    text = raw.decode('utf-8')
    text = pair_stage.once(text, '\t\t\thuman_subtile_fixture_headless()', '\t\t\tnpc_subtile_fixture()')
    text = pair_stage.once(text, '"checks" = human_subtile_fixture_checks,',
                           '"checks" = human_subtile_fixture_checks, "npc_checks" = npc_subtile_checks, "npc_rows" = npc_subtile_rows,')
    return text.encode('utf-8')


def prepare_pair(candidate_out, manifest, inputs, fixture):
    candidate_out = Path(candidate_out)
    candidate_stage = candidate_out / 'stage'
    parent_out = candidate_out.parent / 'npc-parent'
    if parent_out.exists() or not candidate_stage.is_dir() or manifest.get('dme') != 'stage/human_subtile.dme':
        raise ValueError('pair stage setup')
    overlay = pair_stage.reconstruct(inputs, fixture)
    for rel, expected in inputs.items():
        if rel == PROBE:
            continue
        path = candidate_stage / rel
        if path.is_symlink() or not path.is_file() or path.read_bytes() != expected:
            raise ValueError('staged preimage mismatch: ' + rel)
    probe = candidate_stage / PROBE
    if probe.is_symlink() or probe.read_bytes() != npc_probe(inputs[PROBE]):
        raise ValueError('staged probe mismatch')
    dme = candidate_stage / 'human_subtile.dme'
    suffix = b'#include "tests\\human_subtile\\pair_measure.dm"\n'
    if not overlay['human_subtile.dme'].endswith(suffix) or dme.read_bytes() != overlay['human_subtile.dme'][:-len(suffix)]:
        raise ValueError('staged DME mismatch')
    parent_out.mkdir()
    shutil.copytree(candidate_stage, parent_out / 'stage', copy_function=os.link)
    parent_manifest = copy.deepcopy(manifest)
    for folder, info, mode in ((parent_out, parent_manifest, 'legacy'),
                               (candidate_out, manifest, 'pair_first')):
        for rel, raw in overlay.items():
            target = folder / 'stage' / rel
            if target.is_symlink():
                raise ValueError('stage input symlink')
            target.parent.mkdir(parents=True, exist_ok=True)
            if target.exists():
                target.unlink()
            target.write_bytes(raw)
            info['stage_files'][rel] = digest(raw)
        info['pair_mode'] = mode
    for rel in overlay:
        if os.path.samefile(parent_out / 'stage' / rel, candidate_out / 'stage' / rel):
            raise ValueError('mutable pair overlay remains linked: ' + rel)
    return parent_out, parent_manifest

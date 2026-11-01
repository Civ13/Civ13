"""Prepare two copy-on-write fixture stages; does not run a compiler or daemon."""
import copy
import hashlib
import os
from pathlib import Path
import shutil
import stage_bundle


def digest(raw):
    return {'bytes': len(raw), 'sha256': hashlib.sha256(raw).hexdigest()}


def prepare_pair(candidate_out, manifest, inputs, old_guard, observer, scenario):
    candidate_out = Path(candidate_out)
    candidate_stage = candidate_out / 'stage'
    parent_out = candidate_out.parent / 'npc-parent'
    if parent_out.exists() or not candidate_stage.is_dir() or manifest.get('dme') != 'stage/human_subtile.dme':
        raise ValueError('paired fixture staging setup')
    baseline = stage_bundle.reconstruct(inputs, old_guard, observer, scenario, False)
    candidate = stage_bundle.reconstruct(inputs, old_guard, observer, scenario, True)
    for rel in inputs:
        if rel == stage_bundle.PROBE:
            continue  # npc.prepare makes two separately reconstructed changes.
        path = candidate_stage / rel
        if path.is_symlink() or path.read_bytes() != inputs[rel]:
            raise ValueError('staged production preimage mismatch: ' + rel)
    probe = candidate_stage / stage_bundle.PROBE
    if probe.read_bytes() != stage_bundle.prepare_probe(inputs[stage_bundle.PROBE]):
        raise ValueError('staged probe preimage mismatch')
    dme = candidate_stage / 'human_subtile.dme'
    suffix = (b'\n#include "tests\\human_subtile\\bump_fixture_observer.dm"\n'
              b'\n#include "tests\\human_subtile\\bump_fixture_probe.dm"\n')
    if not baseline['human_subtile.dme'].endswith(suffix) or dme.read_bytes() != baseline['human_subtile.dme'][:-len(suffix)]:
        raise ValueError('staged fixture DME preimage mismatch')
    parent_out.mkdir()
    shutil.copytree(candidate_stage, parent_out / 'stage', copy_function=os.link)
    parent_manifest = copy.deepcopy(manifest)
    for folder, info, overlay, variant in ((parent_out, parent_manifest, baseline, 'baseline'),
                                            (candidate_out, manifest, candidate, 'candidate')):
        for rel, raw in overlay.items():
            target = folder / 'stage' / rel
            if target.is_symlink():
                raise ValueError('staged input symlink')
            target.parent.mkdir(parents=True, exist_ok=True)
            if target.exists():
                target.unlink()
            target.write_bytes(raw)
            info['stage_files'][rel] = digest(raw)
        info['bump_variant'] = variant
    for rel in baseline:
        if os.path.samefile(parent_out / 'stage' / rel, candidate_out / 'stage' / rel):
            raise ValueError('mutable overlay remained hardlinked: ' + rel)
    return parent_out, parent_manifest

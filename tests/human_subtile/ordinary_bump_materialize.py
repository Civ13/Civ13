"""Copy-on-write staging for the exact merged ordinary-bump fixture.

Does not launch BYOND. Requires the existing bounded cloud controller.
"""
import copy
import hashlib
import os
from pathlib import Path
import re
import shutil
import types
import ordinary_bump_stage as stage

RUNNER_BLOB = '723044afb31a5de9c91cedc3169963acb90a90b3'


def adapted_runner(raw):
    if stage.blob(raw) != RUNNER_BLOB:
        raise ValueError('current human runner differs from pinned merged source')
    text = raw.decode('utf-8')
    text = stage.once(text, "def prepare(root, out, suite, control='none'):",
                      "def prepare(root, out, suite, control='none', fixture_source_head=None):")
    text = stage.once(text, "    head = git(root, 'rev-parse', 'HEAD').decode().strip()",
                      "    head = fixture_source_head or git(root, 'rev-parse', 'HEAD').decode().strip()")
    return text


def runner_module(raw, filename):
    module = types.ModuleType('ordinary_bump_pinned_human_runner')
    module.__file__ = str(filename)
    exec(compile(adapted_runner(raw), str(filename), 'exec'), module.__dict__)
    return module


def digest(raw):
    return {'bytes':len(raw), 'sha256':hashlib.sha256(raw).hexdigest()}


def prepare_pair(candidate_out, manifest, old_living, new_living, probe, dme, fixture, test_head):
    if type(test_head) is not str or re.fullmatch('[0-9a-f]{40}', test_head) is None:
        raise ValueError('test head must be an exact SHA')
    candidate_out=Path(candidate_out); candidate_stage=candidate_out/'stage'; parent_out=candidate_out.parent/'npc-parent'
    if parent_out.exists() or not candidate_stage.is_dir() or manifest.get('head') != stage.CANDIDATE_HEAD or manifest.get('dme') != 'stage/human_subtile.dme':
        raise ValueError('unexpected current human stage')
    old=stage.reconstruct(old_living,probe,dme,fixture,False)
    new=stage.reconstruct(new_living,probe,dme,fixture,True)
    expected={'code/game/mob/living/living.dm':new_living, 'tests/human_subtile/probe.dm':probe,
              'civ13.dme':dme, 'human_subtile.dme':new['human_subtile.dme'].removesuffix(b'#include "tests\\human_subtile\\ordinary_bump_probe.dm"\n')}
    for rel,raw in expected.items():
        path=candidate_stage/rel
        if path.is_symlink() or not path.is_file() or path.read_bytes()!=raw:
            raise ValueError('staged preimage mismatch: '+rel)
    parent_out.mkdir(); shutil.copytree(candidate_stage,parent_out/'stage',copy_function=os.link)
    parent_manifest=copy.deepcopy(manifest)
    for folder,info,overlay,mode in ((parent_out,parent_manifest,old,'legacy'),(candidate_out,manifest,new,'candidate')):
        for rel,raw in overlay.items():
            path=folder/'stage'/rel
            if path.is_symlink():raise ValueError('stage overlay symlink')
            path.parent.mkdir(parents=True,exist_ok=True)
            if path.exists():path.unlink()
            path.write_bytes(raw);info['stage_files'][rel]=digest(raw)
        info['game_head']=stage.CANDIDATE_HEAD;info['game_tree']=stage.CANDIDATE_TREE
        info['baseline_living_commit']=stage.BASE_HEAD;info['head']=test_head;info['ordinary_bump_mode']=mode
    for rel in old:
        if os.path.samefile(parent_out/'stage'/rel,candidate_out/'stage'/rel):
            raise ValueError('fixture overlay is still hardlinked')
    return parent_out,parent_manifest
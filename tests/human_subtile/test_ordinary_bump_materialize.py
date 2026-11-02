"""Offline controls for the exact merged-source human fixture materializer."""
import copy
import os
from pathlib import Path
import sys
import tempfile
import unittest

ROOT=Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT))
import ordinary_bump_stage as stage
import ordinary_bump_materialize as mat


class MaterializeControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.old=(ROOT/'ordinary_inputs/living-base.dm').read_bytes();cls.new=(ROOT/'ordinary_inputs/living-current.dm').read_bytes()
        cls.probe=(ROOT/'ordinary_inputs/probe-current.dm').read_bytes();cls.dme=(ROOT/'ordinary_inputs/civ13-current.dme').read_bytes()
        cls.fixture=(ROOT/'ordinary_bump_probe.dm').read_bytes();cls.runner=(ROOT/'ordinary_inputs/run-current.py').read_bytes()

    def test_pinned_runner_changes_only_explicit_source_head(self):
        adapted=mat.adapted_runner(self.runner)
        module=mat.runner_module(self.runner,ROOT/'ordinary_inputs/run-current.py')
        self.assertTrue(callable(module.prepare))
        self.assertIn('fixture_source_head or git(root',adapted)
        with self.assertRaises(ValueError):mat.adapted_runner(self.runner+b'X')

    def scaffold(self, root):
        out=Path(root)/'npc-smoke'; staging=out/'stage'; staging.mkdir(parents=True)
        built=stage.reconstruct(self.new,self.probe,self.dme,self.fixture,True)
        files={'code/game/mob/living/living.dm':self.new,'tests/human_subtile/probe.dm':self.probe,
               'civ13.dme':self.dme,'human_subtile.dme':built['human_subtile.dme'].removesuffix(b'#include "tests\\human_subtile\\ordinary_bump_probe.dm"\n')}
        for rel,data in files.items():
            path=staging/rel;path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(data)
        return out,{'head':stage.CANDIDATE_HEAD,'dme':'stage/human_subtile.dme',
                    'stage_files':{k:mat.digest(v) for k,v in files.items()}}

    def test_copy_on_write_preserves_exact_game_identity(self):
        with tempfile.TemporaryDirectory(dir=ROOT) as temp:
            out,manifest=self.scaffold(temp)
            parent,old=mat.prepare_pair(out,manifest,self.old,self.new,self.probe,self.dme,self.fixture,'a'*40)
            for key,expected in [('head','a'*40),('game_head',stage.CANDIDATE_HEAD),('game_tree',stage.CANDIDATE_TREE)]:
                self.assertEqual(manifest[key],expected);self.assertEqual(old[key],expected)
            self.assertEqual((old['ordinary_bump_mode'],manifest['ordinary_bump_mode']),('legacy','candidate'))
            for rel in stage.reconstruct(self.old,self.probe,self.dme,self.fixture,False):
                self.assertFalse(os.path.samefile(parent/'stage'/rel,out/'stage'/rel))
            self.assertNotEqual((parent/'stage/code/game/mob/living/living.dm').read_bytes(),
                                (out/'stage/code/game/mob/living/living.dm').read_bytes())

    def test_wrong_preimage_or_identity_rejected_before_copy(self):
        with tempfile.TemporaryDirectory(dir=ROOT) as temp:
            out,manifest=self.scaffold(temp)
            (out/'stage/tests/human_subtile/probe.dm').write_bytes(b'wrong')
            with self.assertRaises(ValueError):mat.prepare_pair(out,manifest,self.old,self.new,self.probe,self.dme,self.fixture,'a'*40)
            self.assertFalse((out.parent/'npc-parent').exists())
        with tempfile.TemporaryDirectory(dir=ROOT) as temp:
            out,manifest=self.scaffold(temp);manifest['head']='b'*40
            with self.assertRaises(ValueError):mat.prepare_pair(out,manifest,self.old,self.new,self.probe,self.dme,self.fixture,'a'*40)
            self.assertFalse((out.parent/'npc-parent').exists())


if __name__=='__main__':unittest.main()
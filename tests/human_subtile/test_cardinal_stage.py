"""Fixture staging/source identity checks, without native execution."""
import hashlib
import importlib.util
import os
from pathlib import Path
import tempfile
import unittest

HERE=Path(__file__).resolve().parent
ROOT=Path(os.environ.get('CARDINAL_OFFLINE_SOURCE_ROOT',HERE.parents[1])).resolve()
def load(name,path):
    spec=importlib.util.spec_from_file_location(name,path); result=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result); return result
stage=load('cardinal_stage',HERE/'cardinal_stage.py')
random=load('random_cadence_contract',ROOT/'tests/human_subtile/random_cadence_contract.py')


class Adaptor:
    @staticmethod
    def adapt(out, manifest, relative, old, new):
        path=out/'stage'/relative
        text=path.read_text(encoding='utf-8')
        if text.count(old)!=1: raise ValueError('preimage')
        path.write_text(text.replace(old,new,1),encoding='utf-8',newline='\n')


class CardinalStageTests(unittest.TestCase):
    def test_exact_production_preimages_and_manifest(self):
        sources=[stage.MOVEMENT,*stage.EXPECTED_SPECIES_BLOBS,stage.PROBE,stage.RANDOM_FIXTURE,stage.CORE]
        with tempfile.TemporaryDirectory() as td:
            out=Path(td); dest=out/'stage'; dest.mkdir()
            for rel in sources:
                target=dest/rel; target.parent.mkdir(parents=True,exist_ok=True)
                target.write_bytes((ROOT/rel).read_bytes())
            cardinal=dest/stage.CARDINAL_FIXTURE; cardinal.write_bytes((HERE/'cardinal_probe.dm').read_bytes())
            probe=dest/stage.PROBE
            text=probe.read_text(encoding='utf-8')
            for old,new in (('\t\t\thuman_subtile_fixture_headless()','\t\t\tnpc_subtile_fixture()'),
                            ('"checks" = human_subtile_fixture_checks,',
                             '"checks" = human_subtile_fixture_checks, "npc_checks" = npc_subtile_checks, "npc_rows" = npc_subtile_rows,')):
                self.assertEqual(text.count(old),1); text=text.replace(old,new,1)
            probe.write_text(text,encoding='utf-8',newline='\n')
            (dest/'human_subtile.dme').write_text('DME\n',encoding='utf-8')
            manifest={'head':'a'*40,'dme':'stage/human_subtile.dme','stage_files':{}}
            stage.adapt(out,manifest,Adaptor,random,'scope')
            for rel, value in manifest['stage_files'].items():
                raw=(dest/rel).read_bytes()
                self.assertEqual(value,{'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest()})
            self.assertIn('fixture_interval_cardinal_main()',probe.read_text())
            self.assertEqual((dest/stage.RANDOM_FIXTURE).read_text().count('"direction" = direction'),2)
            self.assertEqual(manifest['cardinal_movement_blob'],stage.EXPECTED_MOVEMENT_BLOB)
            with self.assertRaises(ValueError): stage.adapt(out,manifest,Adaptor,random,'scope')


if __name__=='__main__': unittest.main()

import copy
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from tools.procedural_maps.__main__ import main
from tools.procedural_maps.bundle import check_manifest,verify_bundle
from tools.procedural_maps.configuration import port_surface_preset
from tools.procedural_maps.io import read_json,new_output
from tools.procedural_maps.repo_source import read_pinned
from tools.procedural_maps.surface_generator import generate
from tools.procedural_maps.source_audit import audit

ROOT=Path(__file__).resolve().parents[2]


class PublicCLITests(unittest.TestCase):
    def invoke(self,*args):
        r=subprocess.run([sys.executable,'-B','-m','tools.procedural_maps',*map(str,args)],cwd=ROOT,capture_output=True,text=True,timeout=20)
        return r.returncode,json.loads(r.stdout)
    def test_beginner_generate_validate_export_verify(self):
        with tempfile.TemporaryDirectory(prefix='procedural-public-') as tmp:
            root=Path(tmp);config=root/'config.json';bundle=root/'map';again=root/'export'
            self.assertEqual(0,self.invoke('preset','--out',config)[0])
            self.assertEqual(0,self.invoke('validate-config',config)[0])
            code,r=self.invoke('generate','--config',config,'--out',bundle);self.assertEqual(0,code,r)
            self.assertFalse(r['native_ready']);self.assertEqual(0,self.invoke('validate',bundle/'map.ir.json')[0])
            code,r=self.invoke('verify',bundle);self.assertEqual(0,code,r);self.assertFalse(r['dmm_alone_full_ir_semantics'])
            code,r=self.invoke('export','--ir',bundle/'map.ir.json','--manifest',bundle/'seed.manifest.json','--out',again)
            self.assertEqual(0,code,r);self.assertEqual((bundle/'map.dmm').read_bytes(),(again/'map.dmm').read_bytes())
            manifest=json.loads((bundle/'seed.manifest.json').read_text());manifest.pop('catalog_binding')
            old_manifest=root/'old-manifest.json';old_manifest.write_text(json.dumps(manifest))
            code,r=self.invoke('export','--ir',bundle/'map.ir.json','--manifest',old_manifest,'--out',root/'unbound')
            self.assertEqual(2,code);self.assertIn('UNBOUND_MANIFEST_REQUIRES_CATALOG_VERSION',str(r))
            code,r=self.invoke('export','--ir',bundle/'map.ir.json','--manifest',old_manifest,'--out',root/'explicit','--catalog-version','civ13-static-layout/4')
            self.assertEqual(0,code,r)
    def test_existing_output_is_preserved(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);config=root/'config.json';bundle=root/'existing';bundle.mkdir();(bundle/'keep.txt').write_text('player edits')
            config.write_text(json.dumps(port_surface_preset('ports-0',64,80)))
            code,r=self.invoke('generate','--config',config,'--out',bundle)
            self.assertEqual(2,code);self.assertEqual('player edits',(bundle/'keep.txt').read_text());self.assertFalse((bundle/'complete.json').exists())
    def test_rejection_is_logged_and_nonzero(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);config=root/'bad.json';config.write_text('{"schema":"unsupported"}')
            code,r=self.invoke('generate','--config',config,'--out',root/'out')
            self.assertEqual(1,code);self.assertEqual('REJECTED_OFFLINE_CANDIDATE',r['status']);self.assertTrue((root/'out/rejection.json').is_file())
    def test_native_save_input_refused(self):
        with tempfile.TemporaryDirectory() as tmp:
            p=Path(tmp)/'world.sav';p.write_text('not read as a native save')
            self.assertEqual(2,self.invoke('validate',p)[0])
    def test_duplicate_config_and_nonfinite_refused(self):
        with tempfile.TemporaryDirectory() as tmp:
            p=Path(tmp)/'bad.json'
            for text in ['{"seed":1,"seed":2}','{"seed":NaN}']:
                p.write_text(text);self.assertEqual(2,self.invoke('validate-config',p)[0])
    def test_catalog_line_endings_and_drift(self):
        with tempfile.TemporaryDirectory() as tmp:
            p=Path(tmp)/'source.dm';lf=b'/turf/example\n\tname = "example"\n'
            pin=hashlib.sha1(b'blob '+str(len(lf)).encode()+b'\0'+lf).hexdigest()
            p.write_bytes(lf.replace(b'\n',b'\r\n'));self.assertEqual(lf,read_pinned('source.dm',pin,tmp))
            p.write_text('/turf/changed\n')
            with self.assertRaisesRegex(ValueError,'CATALOG_SOURCE_MISMATCH'):read_pinned('source.dm',pin,tmp)
    def test_source_audit_does_not_require_reference_image(self):
        r=audit();self.assertEqual('NOT_SUPPLIED',r['reference']['status']);self.assertEqual(18,r['levels']['2']['joinlateciv_count'])
    def test_manifest_wrong_config_seed_rejected(self):
        r=generate(port_surface_preset('ports-0',64,80));m=copy.deepcopy(r['manifest']);m['configuration']['seed']='different'
        with self.assertRaisesRegex(ValueError,'CONFIG_BINDING_MISMATCH'):check_manifest(r['document'],m)
    def test_manifest_wrong_version_rejected(self):
        r=generate(port_surface_preset('ports-0',64,80));m=copy.deepcopy(r['manifest']);m['algorithm_version']='wrong/1'
        with self.assertRaisesRegex(ValueError,'VERSION_BINDING_MISMATCH'):check_manifest(r['document'],m)
    def test_bundle_file_tamper_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);config=root/'config.json';config.write_text(json.dumps(port_surface_preset('ports-0',64,80)))
            self.assertEqual(0,self.invoke('generate','--config',config,'--out',root/'out','--no-preview')[0])
            (root/'out/map.dmm').write_text('changed')
            with self.assertRaisesRegex(ValueError,'BUNDLE_FILE_HASH_MISMATCH'):verify_bundle(root/'out')
    def test_symlink_output_component_refused(self):
        # No platform-dependent symlink privileges are needed for this call-path check.
        from unittest.mock import patch
        with patch.object(Path,'is_symlink',return_value=True):
            with self.assertRaisesRegex(ValueError,'symlink'):new_output('new-output')


if __name__=='__main__':unittest.main(verbosity=2)

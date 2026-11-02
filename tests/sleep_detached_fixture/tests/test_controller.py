"""Offline controller-oracle tests. No compiler, daemon, network, or game."""
from pathlib import Path
import hashlib
import importlib.util
import json
import shutil
import tempfile
import unittest
from unittest import mock

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('sleep_test_controller',ROOT/'controller_linux.py')
controller=importlib.util.module_from_spec(spec);spec.loader.exec_module(controller)

def valid_receipt(mode):
    return {'schema':1,'mode':mode,'result':'PASS','runtime':0,'port':0,'synthetic_authority':1}

def valid_manifest(body):
    return {'schema':1,'state':'unverified','round_id':'Round-A','account':'fixtureaccount','nonce':'a'*32,'root_ref':1,'entries':3,'lists':1,'edges':7,'payload_length':len(body),'payload_md5':hashlib.md5(body,usedforsecurity=False).hexdigest()}

class ControllerTests(unittest.TestCase):
    def test_source_binding_and_bad_controller_hash(self):
        h=hashlib.sha256((ROOT/'controller_linux.py').read_bytes()).hexdigest()
        self.assertEqual(controller.source_binding(h)['status'],'source_only_unrun')
        with self.assertRaises(ValueError):controller.source_binding('0'*64)
    def test_receipt_exact_types_and_identity(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/'r.json';p.write_text(json.dumps(valid_receipt('writer')),encoding='utf-8')
            self.assertEqual(controller.receipt(p,'writer')['result'],'PASS')
            for key,value in [('result','FAIL'),('port',False),('runtime','0'),('synthetic_authority',1.0),('schema',True),('mode','reader')]:
                row=valid_receipt('writer');row[key]=value;p.write_text(json.dumps(row),encoding='utf-8')
                with self.subTest(key=key),self.assertRaises(ValueError):controller.receipt(p,'writer')
            p.write_text('{"schema":1,"schema":1,"mode":"writer","result":"PASS","runtime":0,"port":0,"synthetic_authority":1}',encoding='utf-8')
            with self.assertRaises(ValueError):controller.receipt(p,'writer')
    def test_payload_round_hash_size_and_duplicate_rejections(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d);body=b'synthetic ascii graph payload';(root/'sleep-payload.txt').write_bytes(body)
            path=root/'sleep-manifest.json';good=valid_manifest(body);path.write_text(json.dumps(good),encoding='utf-8')
            got=controller.validate_payload(root)
            self.assertEqual(got['payload_sha256'],hashlib.sha256(body).hexdigest())
            for key,value in [('round_id','round-a'),('account','wrong'),('nonce','b'*32),('entries',513),('root_ref',True),('payload_md5','0'*32),('payload_length',len(body)+1)]:
                row=valid_manifest(body);row[key]=value;path.write_text(json.dumps(row),encoding='utf-8')
                with self.subTest(key=key),self.assertRaises(ValueError):controller.validate_payload(root)
            path.write_text(json.dumps(good),encoding='utf-8');(root/'sleep-payload.txt').write_bytes(b'')
            with self.assertRaises(ValueError):controller.validate_payload(root)
            (root/'sleep-payload.txt').write_bytes(body)
            path.write_text('{"schema":1,"schema":1}',encoding='utf-8')
            with self.assertRaises(ValueError):controller.validate_payload(root)
    def test_working_source_mutation_is_refused(self):
        h=hashlib.sha256((ROOT/'controller_linux.py').read_bytes()).hexdigest()
        manifest=controller.source_binding(h)
        with tempfile.TemporaryDirectory() as d:
            work=Path(d)
            for name in controller.STAGED:shutil.copyfile(controller.STAGE/name,work/name)
            controller.work_binding(work,manifest)
            target=work/'reader_probe.dm';target.write_bytes(target.read_bytes()+b'\n// changed\n')
            with self.assertRaises(ValueError):controller.work_binding(work,manifest)
    def test_space_admission_boundary(self):
        with mock.patch.object(controller.shutil,'disk_usage') as disk:
            disk.return_value=mock.Mock(free=16*1024**3)
            controller.require_free(Path('fixture'))
            disk.return_value=mock.Mock(free=16*1024**3-1)
            with self.assertRaises(ValueError):controller.require_free(Path('fixture'))
    def test_writer_receipt_requires_identical_bytes(self):
        with tempfile.TemporaryDirectory() as d:
            path=Path(d)/'writer-result.json';row=valid_receipt('writer')
            compact=json.dumps(row,separators=(',',':')).encode()
            pretty=json.dumps(row,indent=2).encode()
            self.assertEqual(json.loads(compact),json.loads(pretty))
            path.write_bytes(compact);controller.require_original_writer_receipt(path,compact)
            path.write_bytes(pretty)
            with self.assertRaises(ValueError):controller.require_original_writer_receipt(path,compact)
    def test_execution_is_linux_only_and_explicit(self):
        src=(ROOT/'controller_linux.py').read_text(encoding='utf-8')
        self.assertIn("p.add_argument('--run-native',action='store_true',required=True)",src)
        self.assertIn("require(sys.platform.startswith('linux') and os.geteuid()!=0,'unprivileged Linux only')",src)
        self.assertIn("source_binding(expected_controller)",src)
        self.assertIn("verifier.verify_linux(byond,archive)==identity",src)

if __name__=='__main__':unittest.main()
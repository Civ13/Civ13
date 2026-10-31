"""Offline contracts for exact source staging and production evidence."""
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import tarfile
import tempfile
import unittest

HERE = Path(__file__).resolve().parent
def load(name, path):
    spec = importlib.util.spec_from_file_location(name, HERE / path)
    module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
    return module

stage = load('production_stage_test', 'cloud_production_compile.py')
controller = load('production_controller_test', 'cloud_npc_controller.py')
HEAD, TREE = 'a' * 40, 'b' * 40

def blob(data):
    return hashlib.sha1(('blob %d\0' % len(data)).encode() + data).hexdigest()

def inventory(files):
    return b''.join(('100644 blob %s %d\t%s\0' % (blob(data), len(data), name)).encode()
                    for name, data in files.items())

def archive(files):
    stream = io.BytesIO()
    with tarfile.open(fileobj=stream, mode='w') as tar:
        for name, data in files.items():
            info = tarfile.TarInfo(name); info.size = len(data)
            tar.addfile(info, io.BytesIO(data))
    stream.seek(0)
    return stream

class ProductionContracts(unittest.TestCase):
    def test_exact_extraction_and_drift_detection(self):
        files = {'civ13.dme': b'game', 'code/unit.dm': b'code'}
        expected, total = stage.tree_inventory(inventory(files))
        self.assertEqual(total, 8)
        with tempfile.TemporaryDirectory() as root:
            target = Path(root); seen = stage.extract_exact(archive(files), target, expected)
            manifest = {'files': seen}; stage.verify_source(target, manifest)
            (target/'code/unit.dm').write_bytes(b'CODE')
            with self.assertRaisesRegex(RuntimeError, 'source changed'): stage.verify_source(target, manifest)

    def test_unsafe_inventory_and_bad_or_missing_archive_members_fail(self):
        files = {'civ13.dme': b'game', 'code/unit.dm': b'code'}
        expected, _ = stage.tree_inventory(inventory(files))
        bad_inventories = [inventory({'../civ13.dme': b'x'}),
            inventory({'civ13.dme': b'x'}).replace(b'100644', b'120000'),
            inventory({'civ13.dme': b'x'}).replace(blob(b'x').encode(), b'z'*40)]
        for data in bad_inventories:
            with self.subTest(data=data), self.assertRaises(RuntimeError): stage.tree_inventory(data)
        for candidate in ({'civ13.dme': b'GAME', 'code/unit.dm': b'code'},
                          {'civ13.dme': b'game'}, dict(files, **{'extra.dm': b'x'})):
            with self.subTest(candidate=candidate), tempfile.TemporaryDirectory() as root:
                with self.assertRaises(RuntimeError): stage.extract_exact(archive(candidate), Path(root), expected)

    def test_host_rejects_missing_changed_or_false_compile_evidence(self):
        filedata=b'game'; manifest={'head': HEAD, 'tree': TREE, 'dme':'civ13.dme',
            'source_unmodified':True, 'bytes':len(filedata), 'files':{'civ13.dme':{
            'bytes':len(filedata), 'sha256':hashlib.sha256(filedata).hexdigest(), 'git_blob':blob(filedata)}}}
        manifest_raw=json.dumps(manifest).encode()
        status={'head':HEAD,'outcome':'passed','phase':'complete','suite':'production_compile','fixture_dme_only':False}
        phase={'returncode':0,'timed_out':False,'oversized_log':False,'deadline':120}
        artifact={'bytes':1,'sha256':'c'*64}
        summary={'head':HEAD,'tree':TREE,'accepted':True,'suite':'production_compile','fixture_dme_only':False,
                 'scope':'unmodified full tracked production DME compile only; no daemon or game acceptance',
                 'source_file_count':1,'source_bytes':len(filedata),'source_manifest_sha256':hashlib.sha256(manifest_raw).hexdigest(),
                 'compile':phase,'artifacts':{'civ13.dmb':artifact,'civ13.rsc':artifact}}
        files={'harness-status.json':json.dumps(status).encode(),'smoke-summary.json':json.dumps(summary).encode(),
               'production/source-manifest.json':manifest_raw,
               'production/stage/compile-stdout.log':b'DM compiler version 516.1688\nciv13.dmb - 0 errors, 0 warnings\n',
               'production/stage/compile-stderr.log':b''}
        controller.validate_production_evidence(archive(files).getvalue(),HEAD,TREE)
        with self.assertRaises(RuntimeError): controller.validate_production_evidence(archive(files).getvalue(),HEAD,'d'*40)
        summary['compile']['returncode']=1; files['smoke-summary.json']=json.dumps(summary).encode()
        with self.assertRaises(RuntimeError): controller.validate_production_evidence(archive(files).getvalue(),HEAD,TREE)
        del files['production/source-manifest.json']
        with self.assertRaises((RuntimeError, KeyError)): controller.validate_production_evidence(archive(files).getvalue(),HEAD,TREE)

if __name__ == '__main__': unittest.main()

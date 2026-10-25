"""Offline exact-resource/source adapter checks, not actual Git/native admission."""
from audit_offline import install
install()
import hashlib
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import prepare
from grant import consume_grant

ROOT=Path(__file__).parent
SOURCE=Path(os.environ.get('WINTER_TEST_SOURCE',str(ROOT.parents[2]/'source')))

class Adapter(unittest.TestCase):
    def test_full_source_inventory_and_tree_identity(self):
        raw=(ROOT/'source-manifest.json').read_bytes(); rows=prepare.validate_inventory_bytes(raw)
        self.assertEqual(len(rows),5068)
        for name,row in rows.items():
            data=(SOURCE/name).read_bytes()
            self.assertEqual(hashlib.sha256(data).hexdigest(),row['sha256'],name)
        def tree(items):
            children={}
            for r in items:
                head,_,tail=r['path'].partition('/')
                if tail: children.setdefault(head,[]).append(dict(r,path=tail))
                else: children[head]=r
            data=b''
            for name,value in sorted(children.items(),key=lambda pair:pair[0]+('/' if isinstance(pair[1],list) else '')):
                mode,sha=('40000',tree(value)) if isinstance(value,list) else (value['mode'],value['sha'])
                data+=mode.encode()+b' '+name.encode()+b'\0'+bytes.fromhex(sha)
            return hashlib.sha1(b'tree '+str(len(data)).encode()+b'\0'+data).hexdigest()
        self.assertEqual(tree(list(rows.values())),prepare.TREE)
    def test_generated_all_variants_and_anchor_drift(self):
        inputs={n:(SOURCE/n).read_bytes() for n in prepare.INPUTS}
        for variant in prepare.VARIANTS:
            generated=prepare.generated_files(inputs,'a'*64,variant)
            self.assertIn(b'winter1688-probe.dm',generated['winter1688.dme'])
            self.assertNotRegex(generated['winter1688.dme'].decode(),r'#include ".*\.dmm"')
            self.assertIn(prepare.HEAD.encode(),generated['winter1688-probe.dm'])
            self.assertIn(prepare.ADAPTER.encode(),generated['winter1688-probe.dm'])
            self.assertNotIn(b'@BINDING@',generated['winter1688-probe.dm'])
        with self.assertRaises(ValueError):prepare.generated_files(dict(inputs,**{'code/world.dm':b'bad source'}),'a'*64,'baseline')
    def test_frozen_fixture_hashes(self):
        for name,h in prepare.FIXTURE_HASHES.items():self.assertEqual(prepare.digest((ROOT/name).read_bytes()),h)
    def test_one_shot_consumption_and_wrong_binding(self):
        with tempfile.TemporaryDirectory() as tmp:
            p=Path(tmp)/'reviewed-grant.json'
            grant={'schema':1,'adapter':prepare.ADAPTER,'head':prepare.HEAD,'tree':prepare.TREE,'candidate_manifest_sha256':'a'*64,'controller_sha256':prepare.digest(prepare.canonical({})),'archive_sha256':'16278f318cdeb4b77c57868dd7135032fde717ea6226269d22b2a1a50968e7f9','phases':12,'compiler_phases':5,'daemon_phases':7,'aggregate_wall_seconds':1200,'grant_id':'offline-only'}
            p.write_bytes(prepare.canonical(grant))
            with self.assertRaises(ValueError):consume_grant(p,{},'b'*64)
            self.assertFalse(p.with_name(p.name+'.consumed').exists())
            self.assertTrue(consume_grant(p,{},'a'*64)['consumed'])
            with self.assertRaises(FileExistsError):consume_grant(p,{},'a'*64)
    def test_old_grant_and_fake_bool_refused(self):
        with tempfile.TemporaryDirectory() as tmp:
            p=Path(tmp)/'g.json';p.write_text('{"schema": true}')
            with self.assertRaises(ValueError):consume_grant(p,{},'a'*64)
    def test_native_needs_opt_in_before_import_or_io(self):
        from backend_proposal import run_native
        with self.assertRaises(RuntimeError):run_native(None,None,None,None,None,None)
        with self.assertRaisesRegex(ValueError,'grant'):run_native(None,None,None,None,None,None,reviewed_native=True)

if __name__=='__main__':unittest.main()

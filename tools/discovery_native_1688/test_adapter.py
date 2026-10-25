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
SOURCE=Path(os.environ.get('DISCOVERY_TEST_SOURCE',str(ROOT.parents[1]/'source-export')))

class Adapter(unittest.TestCase):
    def test_full_source_inventory_and_tree_identity(self):
        raw=(ROOT/'source-manifest.json').read_bytes(); rows=prepare.validate_inventory_bytes(raw)
        self.assertEqual(len(rows),5061)
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
            self.assertIn(b'discovery1688-probe.dm',generated['discovery1688.dme'])
            self.assertNotRegex(generated['discovery1688.dme'].decode(),r'#include ".*\.dmm"')
            self.assertIn(prepare.HEAD.encode(),generated['discovery1688-probe.dm'])
            self.assertIn(prepare.ADAPTER.encode(),generated['discovery1688-probe.dm'])
            self.assertNotIn(b'@BINDING@',generated['discovery1688-probe.dm'])
        with self.assertRaises(ValueError):prepare.generated_files(dict(inputs,**{'code/world.dm':b'bad source'}),'a'*64,'baseline')
    def test_observation_adapter_changes_sinks_only(self):
        mind=(SOURCE/'code/datums/mind.dm').read_text()
        reagents=(SOURCE/'code/modules/reagents/reagent_containers.dm').read_text()
        adapted_mind,adapted_reagents=prepare.observation_sources(mind,reagents)
        self.assertEqual(adapted_mind.count('recipient.mind != src'),mind.count('recipient.mind != src'))
        self.assertEqual(adapted_reagents.count('record_smell_discovery(user, observation)'),1)
        restored=adapted_reagents.replace('discovery_capture_chat(user,','to_chat(user,',1)
        self.assertEqual(restored,reagents)
        expected=mind.replace('\tvar/client/C = recipient.client\n\tif(!C)\n\t\treturn\n','',1)
        expected=expected.replace('\trecipient << browse(replacetext(memory_stylized, "PLACEHOLDER", output),"window=memory;size=625x650")',
                                  '\tdiscovery_capture_notes(recipient, replacetext(memory_stylized, "PLACEHOLDER", output))',1)
        self.assertEqual(adapted_mind,expected)
        for bad_mind,bad_reagents in [(mind.replace('recipient.client','recipient.no_client'),reagents),
                                     (mind,reagents.replace('html_encode(observation)','observation'))]:
            with self.assertRaises(ValueError):prepare.observation_sources(bad_mind,bad_reagents)

    def test_only_named_control_anchor_changes_and_startup_stays_closed(self):
        inputs={n:(SOURCE/n).read_bytes() for n in prepare.INPUTS}
        for variant,(relative,old,new,target) in prepare.CONTROLS.items():
            data=prepare.generated_files(inputs,'a'*64,variant)
            self.assertNotIn(b'/world/New()',data['discovery1688-world.dm'])
            self.assertIn(b'world.OpenPort("none")',data['discovery1688-world.dm'])
            self.assertIn(b'\treturn\n',data['discovery1688-globals.dm'])
            changed=dict(inputs);changed[relative]=changed[relative].replace(old.encode(),b'anchor changed',1)
            with self.assertRaises(ValueError):prepare.generated_files(changed,'a'*64,variant)
            self.assertTrue(target)
        with self.assertRaises(ValueError):prepare.generated_files(inputs,'a'*64,'unreviewed')

    def test_real_smell_and_generic_mind_persistence_seams(self):
        probe=(ROOT/'probe.dm').read_text()
        saved=(ROOT/'discovery-save.dm').read_text()
        self.assertIn('var/observed = B.smell_description()',probe)
        self.assertIn('B.smell_for(H)',probe)
        self.assertIn('B.secondary_attack_self(H)',probe)
        self.assertIn('H.mind_initialize()',probe)
        self.assertIn('M.transfer_to(new_body)',probe)
        self.assertNotIn('.record_smell_discovery(',probe)
        self.assertIn('M.current = null',saved)
        self.assertIn('M.original = null',saved)
        self.assertIn('map_storage.BuildVarDirectory(F, M, 1)',saved)
        self.assertIn('map_storage.Load_Entry(F, entries["mind"])',saved)
        self.assertNotIn('learned_discoveries =',saved)
        self.assertIn('actual generic mind graphs',saved)

    def test_export_preview_cannot_be_used_as_admitted_preparation(self):
        from preview import tree_hash
        with tempfile.TemporaryDirectory() as tmp:
            output=Path(tmp)
            (output/'preview.json').write_text('{"actual_git_checked":false,"backend_admissible":false}')
            with self.assertRaises(FileNotFoundError):prepare.verify_prepared(output,{})
        # A separately hashed one-file Git tree is not the published full tree.
        self.assertNotEqual(tree_hash([{'path':'fake.dm','mode':'100644','sha':'a'*40}]),prepare.TREE)

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

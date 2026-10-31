"""Synthetic file/receipt failures only; no native process, network or capture."""
import copy
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import terminal_receipt as receipts


class TerminalReceipts(unittest.TestCase):
    def setUp(self):
        temp=tempfile.TemporaryDirectory();self.addCleanup(temp.cleanup)
        self.output=Path(temp.name)
        self.evidence={'scope':'synthetic fixture only','head':'a'*40,
            'source_sha256':{'fixture.dm':'b'*64},'input_sprite_sha256':'c'*64,
            'client':'guest=1;version=516;build=1688','captures':{},
            'cleanup':[{'phase':phase,'all_exited':True,'primitives':{'close_job':True},
                        'exits':[{'exit_code':1,'wait_signaled':True}]} for phase in ('client','server','compile')],
            'secondary_errors':[],'result':'PASS native guest renderer smoke, composition UNTESTED'}
        for phase in ('red','blue'):
            raw=(phase+' synthetic file, not a screenshot').encode()
            (self.output/(phase+'.png')).write_bytes(raw)
            self.evidence['captures'][phase]={'sha256':hashlib.sha256(raw).hexdigest(),'size':[224,224]}

    def load(self,name='receipt.json'):
        return json.loads((self.output/name).read_bytes())

    def assert_failed_checkpoint(self, error=None, *, allow_temporary=False):
        value=self.load()
        self.assertTrue(value['result'].startswith('FAIL'))
        self.assertFalse(value['terminal_committed'])
        self.assertLess((self.output/'receipt.json').stat().st_size,receipts.CAP)
        if error is not None:self.assertEqual(value['error'],error)
        if not allow_temporary:self.assertEqual(list(self.output.glob('*.tmp')),[])
        return value

    def test_compact_full_receipt_commits_only_after_checkpoints_and_witnesses(self):
        def check():
            self.assert_failed_checkpoint(allow_temporary=True)
            self.assertTrue((self.output/'cleanup-receipt.json').is_file())
        receipts.persist(self.output,self.evidence,check)
        self.assertTrue(self.load()['terminal_committed'])
        self.assertTrue(self.load()['result'].startswith('PASS'))
        self.assertFalse(self.load('cleanup-receipt.json')['terminal_committed'])
        self.assertEqual(self.load('source-receipt.json')['source_sha256'],self.evidence['source_sha256'])
        self.assertEqual(self.load('capture-receipt.json')['captures'],self.evidence['captures'])

    def test_overflow_keeps_primary_cleanup_and_each_core_witness(self):
        self.evidence.update(error='original capture failure',result='FAIL',extra='x'*receipts.CAP)
        self.evidence['cleanup'][0]['all_exited']=False
        with self.assertRaisesRegex(ValueError,'cap exceeded'):
            receipts.persist(self.output,self.evidence,lambda:None)
        row=self.assert_failed_checkpoint('original capture failure')
        self.assertFalse(row['cleanup'][0]['all_exited'])
        self.assertFalse(self.load('cleanup-receipt.json')['cleanup'][0]['all_exited'])
        self.assertEqual(self.load('source-receipt.json')['source_sha256'],self.evidence['source_sha256'])
        self.assertEqual(self.load('capture-receipt.json')['captures'],self.evidence['captures'])

    def test_source_overflow_does_not_skip_capture_retention_or_claim_success(self):
        self.evidence['source_sha256']={'oversized':'x'*receipts.CAP}
        with self.assertRaisesRegex(RuntimeError,'Independent terminal'):
            receipts.persist(self.output,self.evidence,lambda:None)
        self.assert_failed_checkpoint()
        self.assertFalse((self.output/'source-receipt.json').exists())
        self.assertEqual(self.load('capture-receipt.json')['captures'],self.evidence['captures'])

    def test_final_replace_failure_preserves_readable_failed_checkpoint(self):
        original=receipts.os.replace
        def fail_final(source,target):
            if Path(target).name=='receipt.json' and json.loads(Path(source).read_bytes()).get('terminal_committed') is True:
                self.assert_failed_checkpoint(allow_temporary=True)
                raise OSError('injected replace failure')
            return original(source,target)
        with patch.object(receipts.os,'replace',side_effect=fail_final):
            with self.assertRaisesRegex(OSError,'replace failure'):
                receipts.persist(self.output,self.evidence,lambda:None)
        self.assert_failed_checkpoint()

    def test_temp_fsync_expiry_never_promotes_pass(self):
        def check():
            if (self.output/'source-receipt.json').exists() and (self.output/'capture-receipt.json').exists():
                raise RuntimeError('original entry budget expired')
        with self.assertRaisesRegex(RuntimeError,'budget expired'):
            receipts.persist(self.output,self.evidence,check)
        self.assert_failed_checkpoint()

    def test_final_temp_fsync_failure_keeps_checkpoint_and_removes_owned_temp(self):
        original=receipts.os.fsync
        calls=0
        def fail_final(fd):
            nonlocal calls
            calls+=1
            if calls==5:raise OSError('injected final fsync failure')
            return original(fd)
        with patch.object(receipts.os,'fsync',side_effect=fail_final):
            with self.assertRaisesRegex(OSError,'fsync failure'):
                receipts.persist(self.output,self.evidence,lambda:None)
        self.assert_failed_checkpoint()

    def test_cleanup_checkpoint_failure_still_retains_other_evidence_and_fails(self):
        original=receipts.atomic_write
        def fail(path,*args,**kwargs):
            if path.name=='cleanup-receipt.json':raise OSError('cleanup checkpoint disk failure')
            return original(path,*args,**kwargs)
        with patch.object(receipts,'atomic_write',side_effect=fail):
            with self.assertRaisesRegex(RuntimeError,'Independent terminal'):
                receipts.persist(self.output,self.evidence,lambda:None)
        self.assert_failed_checkpoint()
        self.assertTrue((self.output/'capture-receipt.json').is_file())

    def test_malformed_or_nonfinite_full_evidence_keeps_failure_checkpoint(self):
        for value in (object(),float('nan')):
            with self.subTest(value=type(value).__name__),tempfile.TemporaryDirectory() as temp:
                evidence=copy.deepcopy(self.evidence);evidence['unserializable']=value
                for phase in ('red','blue'):
                    (Path(temp)/(phase+'.png')).write_bytes((self.output/(phase+'.png')).read_bytes())
                with self.assertRaises((TypeError,ValueError)):
                    receipts.persist(Path(temp),evidence,lambda:None)
                self.assertTrue(json.loads((Path(temp)/'receipt.json').read_bytes())['result'].startswith('FAIL'))

    def test_oversized_cleanup_uses_explicit_bounded_failure_summary(self):
        self.evidence.update(error='original failure',result='FAIL')
        self.evidence['cleanup'][0].update(all_exited=False,detail='x'*receipts.CAP)
        with self.assertRaisesRegex(ValueError,'cap exceeded'):
            receipts.persist(self.output,self.evidence,lambda:None)
        row=self.assert_failed_checkpoint('original failure')
        self.assertTrue(row['detail_omitted'])
        self.assertFalse(row['cleanup'][0]['all_exited'])
        self.assertEqual(len(row['cleanup'][0]['original']['sha256']),64)

    def test_uncertain_cleanup_missing_or_changed_capture_cannot_be_green(self):
        for mode in ('cleanup','missing','changed','guest'):
            with self.subTest(mode=mode),tempfile.TemporaryDirectory() as temp:
                output=Path(temp);evidence=copy.deepcopy(self.evidence)
                for phase in ('red','blue'):(output/(phase+'.png')).write_bytes((self.output/(phase+'.png')).read_bytes())
                if mode=='cleanup':evidence['cleanup'][0]['all_exited']=False
                elif mode=='missing':(output/'red.png').unlink()
                elif mode=='changed':(output/'red.png').write_bytes(b'changed')
                else:evidence['client']='wrong guest/build'
                with self.assertRaises(RuntimeError):receipts.persist(output,evidence,lambda:None)
                self.assertFalse(json.loads((output/'receipt.json').read_bytes())['terminal_committed'])

    def test_cap_is_strict_and_existing_or_changed_target_is_not_overwritten(self):
        with self.assertRaisesRegex(ValueError,'cap exceeded'):
            receipts.atomic_write(self.output/'limit.json',b'x'*receipts.CAP)
        path=self.output/'existing.json';path.write_bytes(b'original')
        with self.assertRaisesRegex(RuntimeError,'Unexpected'):
            receipts.atomic_write(path,b'replacement')
        self.assertEqual(path.read_bytes(),b'original')
        def change():path.write_bytes(b'foreign update')
        with self.assertRaisesRegex(RuntimeError,'changed before commit'):
            receipts.atomic_write(path,b'replacement',expected=b'original',before_commit=change)
        self.assertEqual(path.read_bytes(),b'foreign update')
        path.write_bytes(b'original')
        with self.assertRaisesRegex(RuntimeError,'changed before commit'):
            receipts.atomic_write(path,b'replacement',expected=b'original',before_commit=path.unlink)
        self.assertFalse(path.exists())


if __name__=='__main__':unittest.main()

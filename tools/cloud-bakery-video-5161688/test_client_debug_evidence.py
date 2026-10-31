"""Independent post-cleanup retention of the single bounded diagnostic."""
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
import evidence


class DiagnosticEvidence(unittest.TestCase):
    def fixture(self):
        temp=tempfile.TemporaryDirectory();self.addCleanup(temp.cleanup)
        source=Path(temp.name)/'source';source.mkdir()
        output=Path(temp.name)/'output';output.mkdir()
        (source/'intro-checks.txt').write_text('retained witness')
        result={'head':'a'*40,'run_id':'123','cleanup':[{'role':'client','all_exited':True}],
                'status':'CLIENT_STARTUP_DIAGNOSTIC_REVIEW_REQUIRED',
                'client_startup_diagnostic':{'status':'DIAGNOSTIC_REVIEW_REQUIRED','native_acceptance':False}}
        return source,output,result
    def test_cleanup_precedes_diagnostic_and_both_are_independent(self):
        source,output,result=self.fixture();order=[];write=evidence.write_new
        def record(path,raw):order.append(path.name);return write(path,raw)
        with patch.object(evidence,'write_new',side_effect=record):
            records=evidence.retain_independent(source,output,result)
        self.assertLess(order.index('cleanup-receipt.json'),order.index('client-startup-diagnostic.json'))
        self.assertEqual(records['client-startup-diagnostic.json']['status'],'retained')
        self.assertFalse(json.loads((output/'client-startup-diagnostic.json').read_text())['native_acceptance'])
    def test_diagnostic_write_failure_does_not_drop_cleanup_or_other_witness(self):
        source,output,result=self.fixture();write=evidence.write_new
        def fail(path,raw):
            if path.name=='client-startup-diagnostic.json':raise OSError('test-only')
            return write(path,raw)
        with patch.object(evidence,'write_new',side_effect=fail):
            records=evidence.retain_independent(source,output,result)
        self.assertTrue((output/'cleanup-receipt.json').is_file())
        self.assertTrue((output/'intro-checks.txt').is_file())
        self.assertEqual(result['status'],'FAILED_EVIDENCE_RETENTION')
        self.assertEqual(records['client-startup-diagnostic.json']['status'],'rejected')
    def test_oversize_diagnostic_retains_failure_hash_instead_of_dropping_it(self):
        source,output,result=self.fixture()
        result['client_startup_diagnostic']={'huge':'x'*70000}
        evidence.retain_independent(source,output,result)
        row=json.loads((output/'client-startup-diagnostic.json').read_text())
        self.assertEqual(row['status'],'FAILED_DIAGNOSTIC_EVIDENCE_BOUND')
        self.assertEqual(len(row['original']['sha256']),64)
        self.assertEqual(result['status'],'FAILED_EVIDENCE_RETENTION')


if __name__=='__main__':unittest.main()

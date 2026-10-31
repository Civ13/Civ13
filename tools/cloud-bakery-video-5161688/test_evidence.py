"""Offline retention/error-path regressions; no native execution."""
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import evidence as e


class Evidence(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.source = Path(self.temp.name)/'source'; self.source.mkdir()
        self.output = Path(self.temp.name)/'output'; self.output.mkdir()
        self.result = {'status': 'FAILED', 'head': 'a'*40, 'run_id': '123',
                       'error': 'original pixel failure',
                       'cleanup': [{'role': 'client', 'all_exited': True}]}

    def retain(self):
        self.result['independent_evidence'] = e.retain_independent(
            self.source, self.output, self.result)

    def test_cleanup_first_and_raw_witnesses_precede_any_aggregate(self):
        raw = b'{"phase":"opaque"}\r\n'
        (self.source/'intro-state-before.json').write_bytes(raw)
        calls = []
        original = e.write_new
        def record(path, data):
            calls.append(Path(path).name)
            return original(path, data)
        with patch.object(e, 'write_new', side_effect=record):
            self.retain()
        self.assertEqual(calls[0], 'cleanup-receipt.json')
        self.assertEqual((self.output/'intro-state-before.json').read_bytes(), raw)
        self.assertFalse((self.output/'receipt.json').exists())
        e.write_aggregate(self.output, self.result)
        self.assertTrue((self.output/'receipt.json').exists())

    def test_duplicate_large_checks_reference_complete_retained_text(self):
        checks = 'x'*50000
        (self.source/'intro-checks.txt').write_text(checks)
        self.result.update(native_checks=checks, failed_capture_readiness={'native_checks': checks})
        self.retain(); e.write_aggregate(self.output, self.result)
        receipt = json.loads((self.output/'receipt.json').read_bytes())
        self.assertEqual(receipt['status'], 'FAILED')
        self.assertEqual(receipt['error'], 'original pixel failure')
        self.assertEqual(receipt['native_checks']['artifact'], 'intro-checks.txt')
        self.assertEqual(receipt['failed_capture_readiness']['native_checks'], receipt['native_checks'])
        self.assertEqual((self.output/'intro-checks.txt').read_text(), checks)
        self.assertLess((self.output/'receipt.json').stat().st_size, e.CAP)

    def test_oversized_aggregate_retains_independent_evidence_and_reports_omission(self):
        (self.source/'intro-state-after.json').write_text('{"phase":"clear"}')
        self.result['unexpected_detail'] = 'z'*200000
        self.retain(); e.write_aggregate(self.output, self.result)
        receipt = json.loads((self.output/'receipt.json').read_bytes())
        self.assertEqual(receipt['status'], 'FAILED_RECEIPT_BOUND')
        self.assertTrue(receipt['detail_omitted'])
        self.assertGreater(receipt['field_summaries']['unexpected_detail']['bytes'], e.CAP)
        self.assertEqual(receipt['error'], 'original pixel failure')
        self.assertTrue((self.output/'cleanup-receipt.json').exists())
        self.assertTrue((self.output/'intro-state-after.json').exists())
        self.assertLess((self.output/'receipt.json').stat().st_size, e.CAP)

    def test_loaded_module_evidence_survives_oversized_aggregate_after_cleanup(self):
        module={'modules':{'d3dx9_43.dll':{'location':'app-local','sha256':'a'*64}}}
        self.result['nuget_owned_modules']=module
        self.result['unexpected_detail']='z'*200000
        self.retain();e.write_aggregate(self.output,self.result)
        self.assertEqual(json.loads((self.output/'nuget-module-receipt.json').read_text()),module)
        self.assertEqual(self.result['independent_evidence']['cleanup-receipt.json']['status'],'retained')
        self.assertEqual(self.result['status'],'FAILED_RECEIPT_BOUND')

    def test_serialization_error_cannot_erase_independent_receipts(self):
        self.result['unexpected_detail'] = object()
        self.retain(); e.write_aggregate(self.output, self.result)
        receipt = json.loads((self.output/'receipt.json').read_bytes())
        self.assertEqual(receipt['status'], 'FAILED_RECEIPT_BOUND')
        self.assertEqual(receipt['field_summaries']['unexpected_detail']['serialization_error'], 'object')
        self.assertTrue((self.output/'witness-receipt.json').exists())

    def test_one_oversized_witness_does_not_block_later_witness_or_cleanup(self):
        (self.source/'source-receipt.json').write_bytes(b'x'*e.CAP)
        (self.source/'intro-state-after.json').write_text('{}')
        self.retain(); e.write_aggregate(self.output, self.result)
        files = self.result['independent_evidence']
        self.assertEqual(files['source-receipt.json']['reason'], 'byte_cap')
        self.assertEqual(files['intro-state-after.json']['status'], 'retained')
        self.assertEqual(files['cleanup-receipt.json']['status'], 'retained')
        self.assertEqual(self.result['status'], 'FAILED_EVIDENCE_RETENTION')

    def test_cleanup_io_failure_does_not_block_witness_and_is_not_verified(self):
        original = e.write_new
        def fail_cleanup(path, raw):
            if Path(path).name == 'cleanup-receipt.json': raise OSError('fixture failure')
            return original(path, raw)
        (self.source/'intro-state-before.json').write_text('{}')
        with patch.object(e, 'write_new', side_effect=fail_cleanup): self.retain()
        self.assertEqual(self.result['independent_evidence']['cleanup-receipt.json']['status'], 'rejected')
        self.assertTrue((self.output/'intro-state-before.json').exists())
        self.assertEqual(self.result['status'], 'FAILED_EVIDENCE_RETENTION')

    def test_oversized_cleanup_is_explicit_failure_not_successful_summary(self):
        self.result['cleanup'][0]['unexpected_detail'] = 'x'*e.CAP
        self.retain()
        receipt = json.loads((self.output/'cleanup-receipt.json').read_bytes())
        self.assertFalse(receipt['all_exited'])
        self.assertTrue(receipt['detail_omitted'])
        self.assertEqual(self.result['status'], 'FAILED_EVIDENCE_RETENTION')

    def test_utf8_byte_cap_and_existing_files_are_not_overwritten(self):
        with self.assertRaises(ValueError): e.write_new(self.output/'large.json', ('\u00e9'*40000).encode())
        path = self.output/'receipt.json'; path.write_bytes(b'prior')
        self.retain()
        with self.assertRaises(FileExistsError): e.write_aggregate(self.output, self.result)
        self.assertEqual(path.read_bytes(), b'prior')


if __name__ == '__main__': unittest.main()

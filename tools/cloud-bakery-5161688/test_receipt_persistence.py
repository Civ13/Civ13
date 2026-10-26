import copy
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import receipt_persistence as p

PASS='PASS_NATIVE_CIV13_FLAX_A_FRAMES'

class PersistenceTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root=Path(self.tmp.name);self.source=self.root/'source';self.out=self.root/'out'
        self.source.mkdir();self.out.mkdir()
        self.result={'status':PASS,'head':'a'*40,'source':{'revision':'exact'},'take':{'complete':True},
            'cleanup':[{'role':role,'all_exited':True,'exits':[{'identity':{'pid':i},'process_handle_closed':True}],'primitives':{'close_job':True},'errors':[]} for i,role in enumerate(('client','server','compiler'))],
            'directx_setup':{'cleanup':{'all_exited':True,'primitives':{'close_job':True},'exits':[]}},
            'native_checks':'check\n'*6000}
        self.result['native_checks']=self.result['native_checks'].strip()
        data={'source-receipt.json':p.packed(self.result['source']),'filming-take.json':p.packed(self.result['take']),
              'filming-checks.txt':(self.result['native_checks']+'\r\n').encode(), 'filming-viewport.txt':b'[1,2]\n'}
        for name,value in data.items():(self.source/name).write_bytes(value)
        self.result['viewport_evidence']={'sha256':hashlib.sha256(data['filming-viewport.txt']).hexdigest()}
        self.terminal=p.checkpoint(self.result,self.out)
    def finish(self):
        return p.finalize(self.result,self.source,self.out,self.terminal,PASS)
    def test_deadline_before_pass_commit(self):
        r=p.finalize(self.result,self.source,self.out,self.terminal,PASS,started=0,clock=lambda:180)
        self.assertEqual(r['status'],'FAILED_TOTAL_BUDGET')
        self.assertEqual(json.loads((self.out/'receipt.json').read_bytes())['cleanup'],self.result['cleanup'])
        self.assertFalse(r['persistence_complete'])

    def test_final_atomic_write_crossing_deadline_fails_closed(self):
        ticks=iter([179.9,179.95,180.1,180.2])
        r=p.finalize(self.result,self.source,self.out,self.terminal,PASS,started=0,clock=lambda:next(ticks))
        persisted=json.loads((self.out/'receipt.json').read_bytes())
        self.assertEqual(persisted['status'],'FAILED_TOTAL_BUDGET')
        self.assertEqual(persisted['elapsed_seconds'],180.1)
        self.assertEqual(persisted['cleanup'],self.result['cleanup'])
        self.assertFalse(r['persistence_complete'])

    def test_stale_pass_on_failed_invalidation_has_no_success_marker(self):
        import io
        from contextlib import redirect_stdout
        real_atomic=p.atomic
        def fail_failed_replacement(path,data,**kw):
            if path.name=='receipt.json' and json.loads(data).get('status')=='FAILED_TOTAL_BUDGET':
                raise OSError('storage unavailable after pass replacement')
            return real_atomic(path,data,**kw)
        ticks=iter([179,179.5,180.1,180.2]);log=io.StringIO()
        with patch.object(p,'atomic',side_effect=fail_failed_replacement),redirect_stdout(log):
            r=p.finalize(self.result,self.source,self.out,self.terminal,PASS,started=0,clock=lambda:next(ticks))
        self.assertEqual(json.loads((self.out/'receipt.json').read_bytes())['status'],PASS)
        self.assertEqual(r['status'],'FAILED_TOTAL_BUDGET')
        self.assertNotIn('receipt_persistence_terminal_v1',log.getvalue())

    def test_flush_overrun_keeps_checkpoint_before_pass_replace(self):
        ticks=iter([179,180,180.1])
        r=p.finalize(self.result,self.source,self.out,self.terminal,PASS,started=0,clock=lambda:next(ticks))
        self.assertEqual(r['status'],'FAILED_TOTAL_BUDGET')
        self.assertFalse(json.loads((self.out/'receipt.json').read_bytes())['persistence_complete'])
        self.assertFalse((self.out/'receipt.json.pending').exists())

    def test_success_reports_post_write_sample(self):
        import io
        from contextlib import redirect_stdout
        ticks=iter([179,179.2,179.5]);log=io.StringIO()
        with redirect_stdout(log):
            r=p.finalize(self.result,self.source,self.out,self.terminal,PASS,started=0,clock=lambda:next(ticks))
        self.assertEqual(r['status'],PASS)
        self.assertEqual(r['elapsed_seconds'],179)
        marker=json.loads(log.getvalue())
        self.assertEqual(marker['persistence_post_write_elapsed_seconds'],179.5)
        self.assertEqual(marker['receipt_sha256'],hashlib.sha256((self.out/'receipt.json').read_bytes()).hexdigest())
        self.assertEqual(marker['marker'],'receipt_persistence_terminal_v1')

    def test_pending_checkpoint_preserves_cleanup_without_pass(self):
        self.assertEqual(self.terminal['status'],'FAILED_PERSISTENCE_PENDING_FINALIZATION')
        self.assertFalse(self.terminal['persistence_complete'])
        self.assertEqual(self.terminal['cleanup'],self.result['cleanup'])
        self.assertEqual(self.terminal['directx_cleanup'],self.result['directx_setup']['cleanup'])
    def test_success_exact_bytes_and_compact_summary(self):
        final=self.finish()
        self.assertEqual(final['status'],PASS)
        self.assertTrue(final['persistence_complete'])
        self.assertEqual(final['cleanup'],self.result['cleanup'])
        for name in p.REQUIRED:self.assertEqual((self.source/name).read_bytes(),(self.out/name).read_bytes())
        self.assertEqual(final['native_checks']['bytes'],(self.source/'filming-checks.txt').stat().st_size)
        self.assertLess((self.out/'receipt.json').stat().st_size,65536)
        self.assertFalse(list(self.out.glob('*.pending')))
    def test_oversized_field_retains_real_cleanup_failure(self):
        self.result['large_diagnostic']='x'*20000
        final=self.finish()
        self.assertEqual(final['status'],'FAILED_PERSISTENCE')
        self.assertEqual(final['cleanup'],self.result['cleanup'])
        self.assertIn('field cap',final['persistence_error'])
        for name in p.REQUIRED:self.assertEqual((self.source/name).read_bytes(),(self.out/name).read_bytes())
    def test_missing_required_evidence_never_passes(self):
        for name in p.REQUIRED:
            value=(self.source/name).read_bytes();(self.source/name).unlink()
            self.assertEqual(self.finish()['status'],'FAILED_PERSISTENCE')
            (self.source/name).write_bytes(value)
    def test_oversized_exact_evidence_fails_without_truncating(self):
        (self.source/'filming-checks.txt').write_bytes(b'x'*65537)
        self.assertEqual(self.finish()['status'],'FAILED_PERSISTENCE')
    def test_missing_cleanup_not_fabricated(self):
        self.result['cleanup']=[]
        self.result.pop('directx_setup')
        self.terminal=p.checkpoint(self.result,self.out)
        final=self.finish()
        self.assertEqual(final['cleanup'],[])
        self.assertIsNone(final['directx_cleanup'])
        self.assertEqual(final['status'],'FAILED_PERSISTENCE')
    def test_changed_cleanup_and_bindings_fail(self):
        saved=copy.deepcopy(self.result)
        for key in ('cleanup','source','take','viewport_evidence','native_checks'):
            self.result=copy.deepcopy(saved)
            if key=='cleanup':self.result[key][0]['all_exited']=False
            elif key=='native_checks':self.result[key]='wrong'
            else:self.result[key]={'wrong':True}
            self.assertEqual(self.finish()['status'],'FAILED_PERSISTENCE',key)
    def test_failure_write_preserves_initial_if_storage_breaks(self):
        original=(self.out/'receipt.json').read_bytes()
        with patch.object(p,'atomic',side_effect=OSError('disk failure')):
            self.assertEqual(self.finish()['status'],'FAILED_PERSISTENCE')
        self.assertEqual((self.out/'receipt.json').read_bytes(),original)
    def test_count_cap_includes_reserved_existing_artifacts(self):
        for i in range(90):(self.out/f'frame-{i}').write_bytes(b'x')
        self.assertEqual(self.finish()['status'],PASS) # 90+receipt+4 evidence+5 reserved=100
        (self.out/'one-extra').write_bytes(b'x')
        self.assertEqual(self.finish()['status'],'FAILED_PERSISTENCE')
    def test_artifact_byte_cap_and_invalid_text(self):
        for i in range(12):(self.out/f'bounded-log-{i}').write_bytes(bytes(1048576))
        self.assertEqual(self.finish()['status'],'FAILED_PERSISTENCE')
        for path in self.out.glob('bounded-log-*'):path.unlink()
        (self.source/'filming-checks.txt').write_bytes(b'\xff')
        self.assertEqual(self.finish()['status'],'FAILED_PERSISTENCE')
    def test_malformed_cleanup_is_explicit_unknown(self):
        self.result['cleanup']=[{'role':'unowned','all_exited':True}]
        self.terminal=p.checkpoint(self.result,self.out)
        self.assertIsNone(self.terminal['cleanup'])
        self.assertIn('cleanup_evidence_error',self.terminal)
        self.assertEqual(self.finish()['status'],'FAILED_PERSISTENCE')
    def test_nested_failure_checks_summary_and_error_preserved(self):
        self.result['status']='FAILED'
        self.result['error']='original native error'
        self.result['failed_capture_readiness']={'native_checks':self.result['native_checks'],'render_readiness_proven':False}
        self.terminal=p.checkpoint(self.result,self.out)
        final=self.finish()
        self.assertEqual(final['status'],'FAILED')
        self.assertEqual(final['error'],'original native error')
        self.assertFalse(final['failed_capture_readiness']['render_readiness_proven'])
        self.assertEqual(final['failed_capture_readiness']['native_checks'],final['native_checks'])
        self.result['huge']='x'*17000
        final=self.finish()
        self.assertEqual(final['original_error'],'original native error')
        self.assertEqual(final['status'],'FAILED_PERSISTENCE')
    def test_exact_environment_directory_excluded_only(self):
        (self.out/'environment').mkdir()
        (self.out/'environment'/'runtime-data').write_bytes(b'owned runtime data')
        self.assertEqual(self.finish()['status'],PASS)
        (self.out/'unexpected').mkdir()
        self.assertEqual(self.finish()['status'],'FAILED_PERSISTENCE')
        (self.out/'unexpected').rmdir()
        (self.out/'environment'/'runtime-data').unlink()
        (self.out/'environment').rmdir()
        (self.out/'environment').symlink_to(self.source,target_is_directory=True)
        self.assertEqual(self.finish()['status'],'FAILED_PERSISTENCE')
    def test_evidence_errors_preserve_later_valid_files(self):
        (self.source/'source-receipt.json').write_bytes(b'x'*65537)
        (self.source/'filming-take.json').unlink()
        stop=b'actual failure detail\r\n'
        (self.source/'filming-stop.txt').write_bytes(stop)
        final=self.finish()
        self.assertEqual(final['status'],'FAILED_PERSISTENCE')
        self.assertEqual([e['file'] for e in final['evidence_errors']],['source-receipt.json','filming-take.json'])
        self.assertEqual((self.out/'filming-stop.txt').read_bytes(),stop)
        self.assertEqual((self.out/'filming-checks.txt').read_bytes(),(self.source/'filming-checks.txt').read_bytes())
        self.assertEqual(set(final['retained_evidence']),{'filming-checks.txt','filming-viewport.txt','filming-stop.txt'})
        self.assertTrue(all(len(e['error'])<=160 for e in final['evidence_errors']))
    def test_total_compact_cap_not_just_field_cap(self):
        self.result.update({f'extra{i}':'x'*16000 for i in range(5)})
        self.assertEqual(self.finish()['status'],'FAILED_PERSISTENCE')
        self.assertIn('Compact receipt cap',json.loads((self.out/'receipt.json').read_bytes())['persistence_error'])

if __name__=='__main__':unittest.main()

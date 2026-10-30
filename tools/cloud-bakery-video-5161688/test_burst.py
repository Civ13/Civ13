import hashlib, json, tempfile, unittest, time
from pathlib import Path
from types import SimpleNamespace
import deferred_recording as burst
from cadence_schema import validate_manifest
from capture import pixel_diagnostics
from viewport_border import viewport_border
class Clock:
    def __init__(self): self.n=0
    def monotonic(self): return self.n/1e9
    def ns(self): return self.n
    def sleep(self,s): self.n+=max(1,round(s*1e9))
    def info(self,name): return SimpleNamespace(implementation='offline-test',resolution=1e-9,monotonic=True,adjustable=False)

class ImmediateTestSpool:
    """Synchronous test double for the existing virtual-clock tests only."""
    def __init__(self): self.hashes={}; self.created=[]
    def check(self): pass
    def submit(self,index,path,data):
        digest=hashlib.sha256(data).hexdigest()
        with path.open('xb') as f:
            self.created.append(path)
            if f.write(data)!=len(data): raise OSError('Incomplete raw spool write')
        self.hashes[index]=digest
    def finish(self,count,watch,timeout=.5):
        if set(self.hashes)!=set(range(count)):raise RuntimeError('Raw spool incomplete')
        return dict(self.hashes)
    def stats(self):
        return dict(capacity=4,peak_outstanding=1,submitted=len(self.hashes),completed=len(self.hashes),max_hash_ns=1,max_write_ns=1)
    def created_paths(self): return list(self.created)
    def cancel_and_join(self,timeout=2): return True

class Review(unittest.TestCase):
    def run_sample(self,late=False,rate=20,owner_bad=False):
        clock=Clock(); owner=dict(pid=11,creation_filetime=22,hwnd=33)
        # Small repeatable color pattern exercises diagnostics, not game visuals.
        rgb=bytes(range(256))*2700
        facts=pixel_diagnostics(rgb,480,480); border=viewport_border(rgb,480,480)
        calls=[]
        config=dict(world_fps=rate,world_tick_lag=10/rate,client_fps=0,client_tick_lag=0,same_admitted_client=True)
        def acquire(*args):
            start=clock.n;clock.n+=60_000_000 if late else 1_000_000
            return dict(status='OWNED_RAW_UNVALIDATED',checkpoints=burst.CHECKPOINTS,cleanup=burst.CLEANUP,width=480,height=480,
                identity=dict(pid=12 if owner_bad else 11,creation_filetime=22),window=dict(hwnd=33,client_rect=[0,0,480,480]),rgb=rgb,
                readback_timing=dict(clock='perf_counter_ns',bitblt_begin_ns=start,bgra_readback_end_ns=clock.n))
        def validate(c,path):
            data=b'offline schema test only'.ljust(64,b' ');path.write_bytes(data)
            return dict(status='captured',identity=c['identity'],window=c['window'],checkpoints=burst.CHECKPOINTS,cleanup=burst.CLEANUP,
                viewport_border=border,pixel_diagnostics=facts,png_sha256=hashlib.sha256(data).hexdigest(),png_bytes=len(data))
        with tempfile.TemporaryDirectory(prefix='bakery-offline-') as directory:
            try:
                result=burst._record_burst(None,None,directory,'offline',lambda:None,lambda:config,config,owner,0,
                    acquire=acquire,validate=validate,clock=clock.monotonic,sleep=clock.sleep,sample_clock=clock.ns,clock_info=clock.info,on_first_sample=lambda:calls.append(clock.n),spool_factory=ImmediateTestSpool)
                validate_manifest(result,expected_count=240)
                self.assertEqual(len(calls),1)
                self.assertEqual(result['raw_spool_bytes'],165888000)
                self.assertEqual(result['frames'][-1]['due_ns'],11_950_000_000)
                self.assertLess(result['acquisition_end_ns'],12_000_000_000)
                return result
            finally:
                receipt=json.loads((Path(directory)/'cadence-recording.json').read_text())
                self.assertTrue(receipt['raw_spool_released'])
                self.assertFalse((Path(directory)/'environment/cadence-raw').exists())
    def test_240_actual_timestamp_samples(self):
        result=self.run_sample()
        for key,value in [('capacity',5),('peak_outstanding',5),('completed',239),('max_write_ns',-1)]:
            mutated=dict(result,spool_stats=dict(result['spool_stats'],**{key:value}))
            with self.subTest(key=key),self.assertRaises(ValueError): validate_manifest(mutated,expected_count=240)
    def test_missed_interval_rejected(self):
        with self.assertRaisesRegex(RuntimeError,'missed native interval'): self.run_sample(late=True)
    def test_non20_configuration_rejected(self):
        with self.assertRaisesRegex(RuntimeError,'20 FPS'): self.run_sample(rate=24)
    def test_owner_change_rejected(self):
        with self.assertRaisesRegex(RuntimeError,'owner/geometry'): self.run_sample(owner_bad=True)
    def test_public_capture_held(self):
        from unittest.mock import patch
        with patch.object(burst,'NATIVE_RELEASED',False):
            with self.assertRaisesRegex(RuntimeError,'HOLD'): burst.record_burst()
    def test_raw_spool_tamper_rejected_and_cleaned(self):
        from unittest.mock import patch
        original=Path.read_bytes
        def read(path):
            if path.suffix=='.rgb': return b'\0'*691200
            return original(path)
        with patch.object(Path,'read_bytes',read):
            with self.assertRaisesRegex(RuntimeError,'Raw spool changed'):self.run_sample()
    def test_raw_spool_open_failure_preserves_manifest_and_cleanup(self):
        from unittest.mock import patch
        original=Path.open
        def opening(path,*args,**kwargs):
            if path.suffix=='.rgb':raise OSError('offline simulated spool I/O failure')
            return original(path,*args,**kwargs)
        with patch.object(Path,'open',opening):
            with self.assertRaisesRegex(OSError,'spool I/O'):self.run_sample()

    def test_backlog_aborts_and_stuck_worker_never_claims_spool_cleanup(self):
        for joined in (True,False):
            with self.subTest(joined=joined), tempfile.TemporaryDirectory(prefix='bakery-worker-failure-') as directory:
                clock=Clock(); owner=dict(pid=11,creation_filetime=22,hwnd=33)
                config=dict(world_fps=20,world_tick_lag=.5,client_fps=0,client_tick_lag=0,same_admitted_client=True)
                class FailingSpool:
                    def check(self): pass
                    def submit(self,index,path,data): raise RuntimeError('Raw spool backlog exhausted')
                    def stats(self): return dict(capacity=4,peak_outstanding=4,submitted=4,completed=0,max_hash_ns=0,max_write_ns=0)
                    def created_paths(self): return []
                    def cancel_and_join(self,timeout=2): return joined
                def acquire(*args):
                    start=clock.n;clock.n+=1_000_000
                    return dict(status='OWNED_RAW_UNVALIDATED',checkpoints=burst.CHECKPOINTS,cleanup=burst.CLEANUP,width=480,height=480,
                        identity=dict(pid=11,creation_filetime=22),window=dict(hwnd=33,client_rect=[0,0,480,480]),rgb=bytes(range(256))*2700,
                        readback_timing=dict(clock='perf_counter_ns',bitblt_begin_ns=start,bgra_readback_end_ns=clock.n))
                with self.assertRaises(RuntimeError):
                    burst._record_burst(None,None,directory,'offline',lambda:None,lambda:config,config,owner,0,
                        acquire=acquire,clock=clock.monotonic,sleep=clock.sleep,sample_clock=clock.ns,
                        clock_info=clock.info,on_first_sample=lambda:None,spool_factory=FailingSpool)
                receipt=json.loads((Path(directory)/'cadence-recording.json').read_text())
                self.assertTrue(receipt['rejected'])
                self.assertIn('backlog exhausted',receipt['error'])
                self.assertIs(receipt['raw_spool_released'],joined)
                self.assertEqual((Path(directory)/'environment/cadence-raw').exists(),not joined)
                if not joined:self.assertIn('worker_not_joined',receipt['spool_cleanup_errors'])

    def test_real_threaded_spool_with_real_clock_and_injected_capture(self):
        from unittest.mock import patch
        owner=dict(pid=11,creation_filetime=22,hwnd=33)
        config=dict(world_fps=20,world_tick_lag=.5,client_fps=0,client_tick_lag=0,same_admitted_client=True)
        data=bytes(range(256))*2700
        facts=pixel_diagnostics(data,480,480);border=viewport_border(data,480,480)
        def acquire(*args):
            start=time.perf_counter_ns()
            result=dict(status='OWNED_RAW_UNVALIDATED',checkpoints=burst.CHECKPOINTS,cleanup=burst.CLEANUP,width=480,height=480,
                identity=dict(pid=11,creation_filetime=22),window=dict(hwnd=33,client_rect=[0,0,480,480]),rgb=data)
            end=time.perf_counter_ns()
            result['readback_timing']=dict(clock='perf_counter_ns',bitblt_begin_ns=start,bgra_readback_end_ns=end)
            return result
        def validate(c,path):
            encoded=b'offline injected capture only'.ljust(64,b' ');path.write_bytes(encoded)
            return dict(status='captured',identity=c['identity'],window=c['window'],checkpoints=burst.CHECKPOINTS,cleanup=burst.CLEANUP,
                viewport_border=border,pixel_diagnostics=facts,png_sha256=hashlib.sha256(encoded).hexdigest(),png_bytes=len(encoded))
        with tempfile.TemporaryDirectory(prefix='bakery-threaded-spool-') as directory, patch.object(burst,'MAX_COUNT',10):
            result=burst._record_burst(None,None,directory,'offline',lambda:None,lambda:config,config,owner,time.monotonic(),
                acquire=acquire,validate=validate,on_first_sample=lambda:None)
            self.assertEqual(len(result['frames']),10)
            self.assertEqual(result['spool_stats']['completed'],10)
            self.assertLessEqual(result['spool_stats']['peak_outstanding'],4)
            self.assertTrue(result['raw_spool_released'])

if __name__=="__main__": unittest.main()

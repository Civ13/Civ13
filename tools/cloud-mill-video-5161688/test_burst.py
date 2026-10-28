import hashlib, json, tempfile, unittest
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
        with tempfile.TemporaryDirectory(prefix='mill-offline-') as directory:
            try:
                result=burst._record_burst(None,None,directory,'offline',lambda:None,lambda:config,config,owner,0,
                    acquire=acquire,validate=validate,clock=clock.monotonic,sleep=clock.sleep,sample_clock=clock.ns,clock_info=clock.info,on_first_sample=lambda:calls.append(clock.n))
                validate_manifest(result,expected_count=160)
                self.assertEqual(len(calls),1)
                self.assertEqual(result['raw_spool_bytes'],110592000)
                self.assertEqual(result['frames'][-1]['due_ns'],7_950_000_000)
                self.assertLess(result['acquisition_end_ns'],8_000_000_000)
                return result
            finally:
                receipt=json.loads((Path(directory)/'cadence-recording.json').read_text())
                self.assertTrue(receipt['raw_spool_released'])
                self.assertFalse((Path(directory)/'environment/cadence-raw').exists())
    def test_160_actual_timestamp_samples(self): self.run_sample()
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

if __name__=="__main__": unittest.main()

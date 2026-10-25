import json
from pathlib import Path
import tempfile
import unittest
import test_recording
from encode_local import validate, encode, PINS, sha

class EncodeTests(unittest.TestCase):
    def fixture(self):
        helper=test_recording.RecordingTests();self.addCleanup(helper.doCleanups)
        root,go,*_=helper.run_fake();go()
        cleanup=dict(all_exited=True,primitives=dict(terminate_job=True,close_job=True),
            exits=[dict(wait_signaled=True,exit_code_read=True,thread_handle_closed=True,process_handle_closed=True)],errors=[])
        receipt=dict(head='reviewed',status='PASS_NATIVE_CIV13_BAKERY_FRAMES',engine='516.1688',
            execution_source_sha256={n:sha(Path(__file__).with_name(n)) for n in ('capture.py','run_scene.py','recording.py','encode_local.py')},
            scene_revision='58404f5bd16e3fed80f1d9844c5db3edd144942c',
            cleanup=[dict(role=r,**cleanup) for r in ('compiler','server','client')],
            directx_setup=dict(status='PASSED',cleanup=cleanup))
        (root/'receipt.json').write_text(json.dumps(receipt));return root,receipt

    def test_complete_verified_input(self):
        root,_=self.fixture();_,m=validate(root,'reviewed');self.assertEqual(len(m['frames']),80)

    def test_failed_scene_never_encoded(self):
        root,r=self.fixture();r['status']='FAILED';(root/'receipt.json').write_text(json.dumps(r))
        with self.assertRaisesRegex(RuntimeError,'not accepted'):validate(root,'reviewed')

    def test_cleanup_failure_rejected(self):
        root,r=self.fixture();r['cleanup'][0]['all_exited']=False;(root/'receipt.json').write_text(json.dumps(r))
        with self.assertRaisesRegex(RuntimeError,'Cleanup'):validate(root,'reviewed')

    def test_changed_frame_rejected(self):
        root,_=self.fixture();(root/'recording-002.png').write_bytes(b'framex')
        with self.assertRaisesRegex(RuntimeError,'hash mismatch'):validate(root,'reviewed')

    def test_wrong_head_rejected(self):
        root,_=self.fixture()
        with self.assertRaisesRegex(RuntimeError,'not accepted'):validate(root,'other')

    def test_no_downloads_overlays_or_interpolation(self):
        source=Path(__file__).with_name('encode_local.py').read_text()
        for forbidden in ('drawtext','minterpolate','requests.','urllib.','shell=True'):
            self.assertNotIn(forbidden,source)
        for token in ("'-protocol_whitelist','file'","'-fps_mode','passthrough'","'-threads','1'",'RLIMIT_AS','RLIMIT_CPU','RLIMIT_FSIZE','os.killpg',"int(v['nb_read_frames'])==80"):
            self.assertIn(token,source)
        self.assertEqual(set(PINS),{'/usr/bin/ffmpeg','/usr/bin/ffprobe'})

if __name__=='__main__':unittest.main()

"""Offline workflow and bounded acquisition contracts; no network or Docker."""
import base64
import contextlib
import hashlib
import importlib.util
import io
import json
import lzma
from pathlib import Path
import tarfile
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
spec=importlib.util.spec_from_file_location('cloud_npc_job',HERE/'cloud_npc_job.py')
job=importlib.util.module_from_spec(spec);spec.loader.exec_module(job)


class JobContracts(unittest.TestCase):
    def test_source_estimate_rejects_oversized_or_nonblob_inputs(self):
        good=b'100644 blob '+b'a'*40+b' 10\tcode/test.dm\0'
        result=job.selected_estimate(good)
        self.assertEqual(result['blob_bytes'],10)
        self.assertEqual(result['archive_and_stage_estimate_bytes'],20+16384)
        big=b'100644 blob '+b'a'*40+b' 600000000\tcode/test.dm\0'
        with self.assertRaises(RuntimeError): job.selected_estimate(big)
        nonblob=b'160000 commit '+b'a'*40+b' -\tcode/submodule\0'
        with self.assertRaises(RuntimeError): job.selected_estimate(nonblob)
        link=b'120000 blob '+b'a'*40+b' 3\tcode/link\0'
        with self.assertRaises(RuntimeError): job.selected_estimate(link)

    def test_host_disk_limit_is_sampled_and_detects_threshold(self):
        before=job.MIN_FREE+job.HOST_GROWTH+100
        with patch.object(job,'disk_free',side_effect=[before,before-5,job.MIN_FREE-1]):
            monitor=job.Storage(Path('.'));monitor.observe()
            self.assertEqual(monitor.receipt()['sampled_growth_bytes'],5)
            self.assertIn('not a hard host filesystem quota',monitor.receipt()['limitation'])
            with self.assertRaises(RuntimeError): monitor.observe()

    def test_log_evidence_is_bounded_and_contains_only_allowed_files(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary); setup=root/'setup'; control=root/'control';setup.mkdir();control.mkdir()
            (setup/'coordinator.json').write_text('{}');(setup/'pinned.zip').write_bytes(b'not evidence')
            (control/'controller.json').write_text('{}')
            out=io.StringIO()
            with contextlib.redirect_stdout(out): job.emit_evidence(setup,control)
            lines=out.getvalue().splitlines();meta=json.loads(lines[0].split(' ',1)[1])
            encoded=''.join(line.split(' ',2)[2] for line in lines[1:]);payload=base64.b64decode(encoded)
            self.assertEqual(hashlib.sha256(payload).hexdigest(),meta['sha256'])
            self.assertEqual(meta['compression'],'xz')
            with tarfile.open(fileobj=io.BytesIO(payload),mode='r:xz') as archive:
                self.assertEqual(archive.getnames(),['coordinator.json','controller.json'])

    def test_outer_evidence_keeps_nested_manifest_payload_within_existing_cap(self):
        rows={f'code/path/{i:04d}.dm':{'bytes':i+1,'sha256':hashlib.sha256(str(i).encode()).hexdigest()}
              for i in range(3823)}
        manifest=json.dumps({'original_git_files':rows,'stage_files':rows},indent=2).encode()
        nested=io.BytesIO()
        with tarfile.open(fileobj=nested,mode='w') as archive:
            for name in ('npc-manifest.json','cloud-manifest.json'):
                entry=tarfile.TarInfo(name);entry.size=len(manifest);archive.addfile(entry,io.BytesIO(manifest))
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary);setup=root/'setup';control=root/'control';setup.mkdir();control.mkdir()
            (setup/'coordinator.json').write_text('{}');(control/'controller.json').write_text('{}')
            (control/'harness-evidence.tar').write_bytes(nested.getvalue())
            log=b'HARNESS_EVIDENCE_PART '+base64.b64encode(lzma.compress(nested.getvalue(),preset=6))
            (control/'container-tail.log').write_bytes(log)
            out=io.StringIO()
            with contextlib.redirect_stdout(out): job.emit_evidence(setup,control)
            lines=out.getvalue().splitlines();meta=json.loads(lines[0].split(' ',1)[1])
            payload=base64.b64decode(''.join(line.split(' ',2)[2] for line in lines[1:]))
            self.assertLessEqual(len(payload),1024**2)
            self.assertEqual(hashlib.sha256(payload).hexdigest(),meta['sha256'])
            with tarfile.open(fileobj=io.BytesIO(payload),mode='r:xz') as archive:
                self.assertEqual(archive.extractfile('harness-evidence.tar').read(),nested.getvalue())
                self.assertEqual(archive.extractfile('container-tail.log').read(),log)

    def test_default_off_manual_selector_and_unrelated_job_guard(self):
        workflow=(ROOT/'.github/workflows/moving-save-chunks.yml').read_text(encoding='utf-8')
        self.assertIn('wildlife_smoke:\n',workflow)
        self.assertIn('default: false',workflow)
        self.assertIn("github.event_name != 'workflow_dispatch' || inputs.wildlife_smoke != true",workflow)
        self.assertIn("github.event_name == 'workflow_dispatch' && inputs.wildlife_smoke == true",workflow)
        self.assertIn('persist-credentials: false',workflow)
        self.assertIn('tests/human_subtile/cloud_npc_job.py --execute',workflow)
        wildlife=workflow.split('  wildlife-cloud-smoke:',1)[1]
        self.assertNotIn('actions/upload-artifact',wildlife)
        self.assertNotIn('sudo ',wildlife)

if __name__=='__main__': unittest.main()

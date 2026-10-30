import os,tempfile,unittest
from pathlib import Path
from unittest.mock import patch
import workflow_source

class WorkflowSource(unittest.TestCase):
    def test_ci_reads_only_exact_committed_blob(self):
        sha='a'*40
        with tempfile.TemporaryDirectory() as root, patch.dict(os.environ,{'GITHUB_ACTIONS':'true','GITHUB_WORKSPACE':root,'GITHUB_SHA':sha}),patch.object(workflow_source.subprocess,'check_output',side_effect=[(sha+'\n').encode(),b'exact-workflow\n']) as git:
            self.assertEqual(workflow_source.workflow_text(),'exact-workflow\n')
            self.assertEqual(git.call_args_list[1].args[0][-1],sha+':.github/workflows/cloud-bakery-video-5161688.yml')
    def test_ci_rejects_head_mismatch_without_fallback(self):
        with tempfile.TemporaryDirectory() as root, patch.dict(os.environ,{'GITHUB_ACTIONS':'true','GITHUB_WORKSPACE':root,'GITHUB_SHA':'a'*40}),patch.object(workflow_source.subprocess,'check_output',return_value=('b'*40+'\n').encode()) as git:
            with self.assertRaisesRegex(ValueError,'head mismatch'):workflow_source.workflow_text()
            self.assertEqual(git.call_count,1)
    def test_missing_ci_binding_fails_closed(self):
        with patch.dict(os.environ,{'GITHUB_ACTIONS':'true','GITHUB_WORKSPACE':'','GITHUB_SHA':'invalid'}):
            with self.assertRaisesRegex(ValueError,'identity'):workflow_source.workflow_text()
    def test_offline_uses_local_reference(self):
        with patch.dict(os.environ,{'GITHUB_ACTIONS':'false'}),patch.object(Path,'read_text',return_value='local-reference') as read:
            self.assertEqual(workflow_source.workflow_text(),'local-reference')
            self.assertEqual(read.call_count,1)

if __name__=='__main__':unittest.main()

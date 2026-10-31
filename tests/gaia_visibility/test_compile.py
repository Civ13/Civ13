"""Injected compiler contracts, no compiler or game process is launched."""
import json
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch
import compile_fixture


class CompileOnly(unittest.TestCase):
    def exercise(self, banner='516.1688', status=0, summary=True, binary=True):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            compiler = root / 'bin' / 'DreamMaker'
            compiler.parent.mkdir(); compiler.write_text('not executable')
            def stage(packet, head):
                packet.mkdir()
                manifest = {'head': head, 'toolchain': '516.1688'}
                (packet / 'gaia-visibility-manifest.json').write_text(json.dumps(manifest))
                return manifest
            def fake(command, **kwargs):
                self.assertEqual(command, [str(compiler), '-max_errors', '0', 'gaia_visibility.dme'])
                self.assertEqual(kwargs['timeout'], 300)
                self.assertNotIn('shell', kwargs)
                kwargs['stdout'].write(('DM compiler version '+banner+'\n'+('gaia_visibility.dmb - 0 errors, 0 warnings\n' if summary else 'error\n')).encode())
                if binary: (kwargs['cwd'] / 'gaia_visibility.dmb').write_bytes(b'fake')
                return SimpleNamespace(returncode=status)
            with patch.object(compile_fixture.prepare, 'prepare', stage):
                result = compile_fixture.compile_packet('a'*40, root / 'output', compiler.parent, execute=fake)
            self.assertFalse(result['executed_game'])
            self.assertTrue((root / 'output/evidence/compile.json').is_file())
            return result
    def test_ci_is_compile_only_and_uploads_evidence_not_runtime(self):
        workflow = (Path(__file__).resolve().parents[2] / '.github/workflows/test.yml').read_text()
        step = workflow.split('      - name: Compile exact Gaia visibility fixture without running it', 1)[1].split('      - name: Compile Art of the Deal', 1)[0]
        self.assertIn("contains(fromJSON(needs.changes.outputs.new_tests || '[]'), 'tests/gaia_visibility')", step)
        self.assertIn('compile_fixture.py --head "$GAIA_FIXTURE_HEAD"', step)
        self.assertNotIn('DreamDaemon', step)
        self.assertNotIn('-trusted', step)
        self.assertIn('gaia-visibility-compile/evidence/', step)

    def test_exact_banner_success_no_game_execution(self):
        self.assertEqual(self.exercise()['status'], 'passed')
    def test_wrong_banner_status_diagnostics_and_missing_binary_reject(self):
        for options in [{'banner':'516.1681'}, {'status':1}, {'summary':False}, {'binary':False}]:
            self.assertEqual(self.exercise(**options)['status'], 'failed')

if __name__ == '__main__': unittest.main()

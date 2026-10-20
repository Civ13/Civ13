"""No native execution: check CI preparation and registered runtime coverage."""
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts/gameplay_bridge'))
import run_gather_ci as runner

class NativeCI(unittest.TestCase):
    def test_prepare_only_materializes_all_real_profiles_without_processes(self):
        with tempfile.TemporaryDirectory() as temp:
            output = Path(temp) / 'packet'
            source = output / 'source'
            source.mkdir(parents=True)
            def read(root, command, revision):
                self.assertEqual(command, 'show')
                return (ROOT / revision.split(':', 1)[1]).read_bytes()
            with patch.object(runner, 'prepare', return_value=source), patch.object(runner, 'git', side_effect=read), patch.object(runner.subprocess, 'run', side_effect=AssertionError('native forbidden')):
                runner.run(ROOT, output, 'a' * 40, None, prepare_only=True)
            for profile in runner.PROFILES:
                dme = (source / ('gather_' + profile + '.dme')).read_text()
                self.assertIn('tests/gameplay_bridge/native/gather_probe.dm', dme)
                self.assertTrue((source / 'gather_generated' / (profile + '_mobs.dm')).is_file())

    def test_ci_runs_actual_gather_and_enabled_mining(self):
        workflow = (ROOT / '.github/workflows/test.yml').read_text()
        self.assertIn('scripts/gameplay_bridge/run_gather_ci.py', workflow)
        self.assertIn('--bridge-enabled --output "$RUNNER_TEMP/bump-mining/bridge-enabled"', workflow)
        self.assertIn('gameplay-gather-native/runtime/**/result.json', workflow)
        self.assertIn('gameplay-gather-native/runtime/**/*.log', workflow)

"""Native countdown probe for code/modules/persistence/shutdown_notice.dm (developer evidence).

Usage: python3 tests/shutdown_notice/run.py
Needs the pinned BYOND from scripts/cloud_byond_setup.sh in ~/byond-<version>; about 40 s.
"""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
NOTICE = ROOT / 'code/modules/persistence/shutdown_notice.dm'


def byond_bin():
    pin = json.loads((ROOT / 'tools/byond/version.json').read_text(encoding='utf-8'))['version']
    path = Path.home() / ('byond-' + pin) / 'byond' / 'bin'
    return path if (path / 'DreamMaker').exists() else None


class ShutdownNoticeProbe(unittest.TestCase):
    def test_countdown_milestones_cancel_and_discord(self):
        binp = byond_bin()
        env = dict(os.environ, LD_LIBRARY_PATH=str(binp) + ':' + os.environ.get('LD_LIBRARY_PATH', ''),
                   BYOND_SYSTEM=str(binp.parent), PATH=str(binp) + ':' + os.environ['PATH'])
        with tempfile.TemporaryDirectory(prefix='civ13-shutdown-notice-') as work:
            work = Path(work)
            shutil.copy(NOTICE, work / 'shutdown_notice.dm')
            shutil.copy(Path(__file__).with_name('probe.dm'), work / 'probe.dm')
            (work / 'probe.dme').write_text('#define R_SERVER 2\n#include "shutdown_notice.dm"\n#include "probe.dm"\n')
            built = subprocess.run(['DreamMaker', 'probe.dme'], cwd=work, env=env, capture_output=True, text=True, timeout=120)
            self.assertIn('0 errors, 0 warnings', built.stdout + built.stderr, built.stdout + built.stderr)
            subprocess.run(['DreamDaemon', 'probe.dmb', '0', '-invisible', '-close', '-trusted'], cwd=work, env=env,
                           capture_output=True, text=True, timeout=180)
            result = json.loads((work / 'result.json').read_text())
            self.assertEqual(result['failures'], 0, result['messages'])



if __name__ == '__main__':
    if not byond_bin():
        sys.exit('pinned BYOND not installed (bash scripts/cloud_byond_setup.sh)')
    unittest.main()

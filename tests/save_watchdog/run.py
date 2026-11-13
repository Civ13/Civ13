"""Native probe for the save stall watchdog (code/modules/persistence/save_watchdog.dm).

Stages save_watchdog.dm and the production save_work_check() from saving.dm
beside probe.dm, compiles and runs them in an isolated DreamDaemon.
Usage: python3 tests/save_watchdog/run.py
Needs the pinned BYOND from scripts/cloud_byond_setup.sh in ~/byond-<version>; about 10 s.
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
sys.path.insert(0, str(ROOT / 'tests/save_movement'))
from source_adapter import extract, read  # noqa: E402

WATCHDOG = ROOT / 'code/modules/persistence/save_watchdog.dm'


def byond_bin():
    pin = json.loads((ROOT / 'tools/byond/version.json').read_text(encoding='utf-8'))['version']
    path = Path.home() / ('byond-' + pin) / 'byond' / 'bin'
    return path if (path / 'DreamMaker').exists() else None


def stage(work):
    work = Path(work)
    shutil.copy(WATCHDOG, work / 'save_watchdog.dm')
    shutil.copy(Path(__file__).with_name('probe.dm'), work / 'probe.dm')
    body = extract(read('code/modules/persistence/saving.dm'), '/map_storage/proc/save_work_check')
    (work / 'save_work_check.dm').write_text('/map_storage/proc/save_work_check()\n' + body + '\n', encoding='utf-8')
    (work / 'probe.dme').write_text('#include "probe.dm"\n#include "save_watchdog.dm"\n#include "save_work_check.dm"\n')


class SaveWatchdogProbe(unittest.TestCase):
    def test_stalled_save_is_alarmed_stopped_and_released(self):
        binp = byond_bin()
        if not binp:
            self.skipTest('pinned BYOND not installed (bash scripts/cloud_byond_setup.sh)')
        env = dict(os.environ, LD_LIBRARY_PATH=str(binp) + ':' + os.environ.get('LD_LIBRARY_PATH', ''),
                   BYOND_SYSTEM=str(binp.parent), PATH=str(binp) + ':' + os.environ['PATH'])
        with tempfile.TemporaryDirectory(prefix='civ13-save-watchdog-') as work:
            work = Path(work)
            stage(work)
            built = subprocess.run(['DreamMaker', 'probe.dme'], cwd=work, env=env, capture_output=True, text=True, timeout=120)
            self.assertIn('0 errors, 0 warnings', built.stdout + built.stderr, built.stdout + built.stderr)
            ran = subprocess.run(['DreamDaemon', 'probe.dmb', '0', '-invisible', '-close', '-trusted'], cwd=work, env=env,
                                 capture_output=True, text=True, timeout=120)
            self.assertTrue((work / 'result.json').exists(), ran.stdout + ran.stderr)
            result = json.loads((work / 'result.json').read_text())
            self.assertEqual(result['failures'], 0, result['messages'])


if __name__ == '__main__':
    unittest.main()

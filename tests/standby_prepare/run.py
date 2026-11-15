"""Native probe for code/modules/persistence/standby_prepare.dm (developer evidence).

Builds the real standby_prepare.dm, ClearMap (functions.dm) and the turf grid codec
(loading.dm) beside small stubs, then checks that a handover's standby clears the boot
map and sets turfs from the last save while it waits, keeps what those turfs made for
the load, leaves lava alone, ignores a record for another map or size, and stops when
the load starts.

Usage: python3 tests/standby_prepare/run.py
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
PERSISTENCE = ROOT / 'code/modules/persistence'


def byond_bin():
    pin = json.loads((ROOT / 'tools/byond/version.json').read_text(encoding='utf-8'))['version']
    path = Path.home() / ('byond-' + pin) / 'byond' / 'bin'
    return path if (path / 'DreamMaker').exists() else None


def cut(text, start, end):
    begin = text.index(start)
    return text[begin:text.index(end, begin + len(start))]


def extracted():
    functions = (PERSISTENCE / 'functions.dm').read_text(encoding='utf-8')
    loading = (PERSISTENCE / 'loading.dm').read_text(encoding='utf-8')
    return '\n'.join([
        cut(functions, '/map_storage/var/tmp/list/standby_kept_objects', '\n/datum/data/record'),
        cut(loading, '/proc/turf_grid_runs(list/grid)', '\n// The turf types of level z'),
        cut(loading, '/proc/decode_turf_grid_runs(list/encoded)', '\n/map_storage/proc/validation_record_turfs'),
    ]) + '\n'


class StandbyPrepareProbe(unittest.TestCase):
    def test_standby_prepares_while_the_old_world_saves(self):
        binp = byond_bin()
        env = dict(os.environ, LD_LIBRARY_PATH=str(binp) + ':' + os.environ.get('LD_LIBRARY_PATH', ''),
                   BYOND_SYSTEM=str(binp.parent), PATH=str(binp) + ':' + os.environ['PATH'])
        with tempfile.TemporaryDirectory(prefix='civ13-standby-prepare-') as work:
            work = Path(work)
            (work / 'map_saves').mkdir()
            shutil.copy(PERSISTENCE / 'standby_prepare.dm', work / 'standby_prepare.dm')
            shutil.copy(Path(__file__).with_name('probe.dm'), work / 'probe.dm')
            (work / 'extracted.dm').write_text(extracted(), encoding='utf-8')
            (work / 'probe.dme').write_text('#include "probe.dm"\n#include "extracted.dm"\n#include "standby_prepare.dm"\n')
            built = subprocess.run(['DreamMaker', 'probe.dme'], cwd=work, env=env, capture_output=True, text=True, timeout=120)
            self.assertIn('0 errors, 0 warnings', built.stdout + built.stderr, built.stdout + built.stderr)
            subprocess.run(['DreamDaemon', 'probe.dmb', '0', '-invisible', '-close', '-trusted'], cwd=work, env=env,
                           capture_output=True, text=True, timeout=120)
            result = json.loads((work / 'result.json').read_text())
            self.assertEqual(result['failures'], 0, result['messages'])


if __name__ == '__main__':
    if not byond_bin():
        sys.exit('pinned BYOND not installed (bash scripts/cloud_byond_setup.sh)')
    unittest.main()

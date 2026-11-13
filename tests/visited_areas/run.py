"""Native probe for code/modules/persistence/visited_areas.dm (developer evidence).

Builds the real visited_areas.dm and valid_visited_record (functions.dm) beside small
stubs, then checks that players mark the chunks around them, that a save captures a
valid record and logs the counts, that a loaded record merges with new visits,
that malformed records are rejected, and which wild animals a save leaves out.

Usage: python3 tests/visited_areas/run.py
Needs the pinned BYOND from scripts/cloud_byond_setup.sh in ~/byond-<version>; about 5 s.
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
    ecology = (ROOT / 'code/modules/ecology/ecology_spawning.dm').read_text(encoding='utf-8')
    return (cut(functions, '#define VISITED_CHUNK', '\n/map_storage/proc/read_round_state()') + '\n'
            + cut(ecology, '/proc/ecology_wild_animal(', '\n/proc/eco_species(') + '\n')


class VisitedAreasProbe(unittest.TestCase):
    def test_players_mark_where_they_have_been(self):
        binp = byond_bin()
        env = dict(os.environ, LD_LIBRARY_PATH=str(binp) + ':' + os.environ.get('LD_LIBRARY_PATH', ''),
                   BYOND_SYSTEM=str(binp.parent), PATH=str(binp) + ':' + os.environ['PATH'])
        with tempfile.TemporaryDirectory(prefix='civ13-visited-areas-') as work:
            work = Path(work)
            shutil.copy(PERSISTENCE / 'visited_areas.dm', work / 'visited_areas.dm')
            shutil.copy(Path(__file__).with_name('probe.dm'), work / 'probe.dm')
            (work / 'extracted.dm').write_text(extracted(), encoding='utf-8')
            (work / 'probe.dme').write_text('#include "probe.dm"\n#include "extracted.dm"\n#include "visited_areas.dm"\n')
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

"""Persistence scratch savefiles must not come from BYOND's shared cache.

An anonymous /savefile lives in the per-user BYOND cache that every Dream
Daemon on the host shares. Mars and Jungle started in the same second on
2026-11-13, picked the same cache file and Windows refused the second one
("file is in use"), so both worlds failed loading their saves. Persistence
code makes scratch files through new_scratch_savefile(), which gives each
world its own files on Windows and only deletes files nothing references.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
PERSISTENCE = ROOT / 'code/modules/persistence'
HELPER = PERSISTENCE / 'stream/save_stream.dm'
ANONYMOUS = re.compile(r'new\s*/savefile\s*(\(\s*\))?\s*$|savefile/\w+\s*=\s*new\s*(\(\s*\))?\s*$', re.M)


def helper_body(text):
    start = text.index('/proc/new_scratch_savefile()')
    end = text.index('\n/proc/', start + 1)
    return text[start:end]


class PrivateScratchSavefileTest(unittest.TestCase):
    def test_persistence_makes_no_anonymous_savefiles(self):
        found = []
        for path in sorted(PERSISTENCE.rglob('*.dm')):
            text = path.read_text(encoding='utf-8')
            if path == HELPER:
                text = text.replace(helper_body(text), '')
            for match in ANONYMOUS.finditer(text):
                line = text.count('\n', 0, match.start()) + 1
                found.append(f'{path.relative_to(ROOT)}:{line}')
        self.assertEqual(found, [], 'use new_scratch_savefile() for scratch savefiles')

    def test_windows_files_are_private_to_the_world(self):
        body = helper_body(HELPER.read_text(encoding='utf-8'))
        self.assertIn('if(world.system_type != MS_WINDOWS) return new /savefile', body)
        self.assertIn('world.port', body)
        self.assertIn('data/scratch-saves/[persistence_scratch_run]/', body)

    def test_sweep_only_deletes_unreferenced_files(self):
        text = HELPER.read_text(encoding='utf-8')
        start = text.index('/proc/sweep_released_scratch_savefiles()')
        body = text[start:text.index('\n/proc/', start + 1)]
        self.assertIn('refcount(F) <= unused', body)
        self.assertLess(body.index('del(F)'), body.index('fdel(path)'))


if __name__ == '__main__':
    unittest.main()

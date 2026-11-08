"""The stream reader's scratch-file cache must stay far below the open-file limit.

Each cached scratch file is a temporary savefile held open in the BYOND cache.
A cap of 256 (#4027) pushed Gaia's preflight past the Windows C runtime's 512
open files: BYOND failed with errno 24 and the world came up without its save.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/modules/persistence/stream/level_stream.dm'
CRT_OPEN_FILE_LIMIT = 512


class StreamScratchCapTest(unittest.TestCase):
    def test_cap_is_well_below_the_open_file_limit(self):
        text = SOURCE.read_text(encoding='utf-8')
        match = re.search(r'^#define PERSISTENCE_STREAM_SCRATCH_FILE_CAP (\d+)\s*$', text, re.M)
        self.assertIsNotNone(match, 'PERSISTENCE_STREAM_SCRATCH_FILE_CAP is not defined')
        self.assertLessEqual(int(match.group(1)), CRT_OPEN_FILE_LIMIT // 4)

    def test_reader_has_no_literal_cache_limit(self):
        text = SOURCE.read_text(encoding='utf-8')
        for value in re.findall(r'\blimit = (\d+)', text):
            self.assertLessEqual(int(value), CRT_OPEN_FILE_LIMIT // 4, f'literal scratch limit {value}')


if __name__ == '__main__':
    unittest.main()

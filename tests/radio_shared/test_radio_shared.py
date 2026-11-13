"""Structure and handheld radios share one Topic and broadcast implementation.

The fixtures freeze the /obj/structure/radio Topic and broadcast bodies that
/obj/item/weapon/radio had copied. The shared procs read the radio's vars by
name (R:freq); after normalising that prefix and src -> R, each must equal its
frozen original line for line. Source checks only; no BYOND runtime.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
RADIO = ROOT / 'code/modules/1713/radio.dm'
PAIRS = {'radio_topic': 'original_Topic.dm.txt', 'radio_broadcast': 'original_broadcast.dm.txt'}


def body(source, header):
    match = re.search(r'(?m)^' + re.escape(header) + r'.*\n((?:\t.*\n|[ \t]*\n)*)', source)
    return match.group(1) if match else ''


def normalise(text):
    lines = []
    for line in text.splitlines():
        line = re.sub(r'//.*', '', line).rstrip()
        if not line.strip() or line.strip() == 'var/mob/user = usr':
            continue
        line = re.sub(r'\bR[:.]', '', line)
        line = re.sub(r'\bsrc\b', 'R', line)
        lines.append(line)
    return lines


def errors(source):
    found = []
    for proc, fixture in PAIRS.items():
        original = (HERE / fixture).read_text(encoding='utf-8').split('\n', 1)[1]
        if normalise(body(source, f'/proc/{proc}(')) != normalise(original):
            found.append(f'{proc} differs from the frozen original')
    for kind in ('/obj/structure/radio', '/obj/item/weapon/radio'):
        if body(source, kind + '/Topic(').strip() != 'radio_topic(src, usr, href_list)':
            found.append(f'{kind} Topic must call radio_topic')
        if body(source, kind + '/proc/broadcast(').strip() != 'radio_broadcast(src, msg, speaker, verbage)':
            found.append(f'{kind} broadcast must call radio_broadcast')
        if body(source, kind + '/interact(').strip() != 'radio_interact(src, m)':
            found.append(f'{kind} interact must call radio_interact')
    return found


class RadioShared(unittest.TestCase):
    def setUp(self):
        self.source = RADIO.read_text(encoding='utf-8')

    def test_shared_procs_match_frozen_originals(self):
        self.assertEqual(errors(self.source), [])

    def test_detects_changed_frequency_bounds(self):
        altered = self.source.replace('min=150, max=300', 'min=100, max=300', 1)
        self.assertTrue(errors(altered))


if __name__ == '__main__':
    unittest.main()

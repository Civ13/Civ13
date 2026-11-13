"""Source parity for the shared capture_step win-condition chain.

legacy_chains.json freezes each map's pre-refactor capture chain (four or
more copied win_condition.check branches plus the else). Each map now calls
capture_step(attacker, defender, threshold, long_timer, timer_arg, id) and
returns the message from its capture_message(id). These offline tests parse
both forms and check they describe the same branches in the same order, with
the same thresholds, timers and messages.
"""
import json
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
R = 'roundend_condition_sides'
LEGACY = re.compile(
    rf'if \(win_condition\.check\(typesof\({R}\[{R}\[([12])\]\]\), {R}\[([12])\], {R}\[\1\], ([0-9.]+), TRUE\)\)\s*'
    rf'if \(!win_condition\.check\(typesof\({R}\[{R}\[\2\]\]\), {R}\[\1\], {R}\[\2\], \3\)\)\s*'
    rf'if \(last_win_condition != win_condition\.hash\)\s*'
    rf'current_win_condition = (".*")\s*'
    rf'next_win = world\.time \+\s*(short|long)_win_time\(([^()\n]*)\)\s*'
    rf'announce_current_win_condition\(\)\s*'
    rf'current_winner = roundend_condition_def2army\({R}\[\2\]\[1\]\)\s*'
    rf'current_loser = roundend_condition_def2army\({R}\[\1\]\[1\]\)')
CALL = re.compile(r'capture_step\(([12]), ([12]), ([0-9.]+), (TRUE|FALSE), ([^,()]+(?:\([^)]*\))?), (\d+)\)')


def legacy_branches(original):
    return [(a, d, th, timer, arg.strip(), msg) for d, a, th, msg, timer, arg in LEGACY.findall(original)]


def messages(source, owner):
    match = re.search(r'(?m)^' + re.escape(owner) + r'/capture_message\(id\)\n((?:\t.*\n|[ \t]*\n)*)', source)
    if not match:
        return None
    return dict(re.findall(r'if \((\d+)\)\n\t+return (".*")', match.group(1)))


def live_branches(replacement, table):
    found = []
    for a, d, th, long_timer, arg, msg_id in CALL.findall(replacement):
        found.append((a, d, th, 'long' if long_timer == 'TRUE' else 'short', arg.strip(), table.get(msg_id)))
    return found


def errors(entries, read):
    found = []
    for entry in entries:
        source = read(entry['file'])
        where = f'{entry["file"]} {entry["type"]}'
        if entry['replacement'] not in source:
            found.append(f'{where}: capture_step chain missing')
            continue
        if entry['original'] in source:
            found.append(f'{where}: copied capture chain is back')
        table = messages(source, entry['type'])
        if table is None:
            found.append(f'{where}: capture_message missing')
            continue
        old = legacy_branches(entry['original'])
        if len(old) < 2 or old != live_branches(entry['replacement'], table):
            found.append(f'{where}: capture_step chain differs from the frozen chain')
    return found


class CaptureChainTest(unittest.TestCase):
    def setUp(self):
        self.entries = json.loads((HERE / 'legacy_chains.json').read_text(encoding='utf-8'))
        self.cache = {}

    def read(self, path):
        if path not in self.cache:
            self.cache[path] = (ROOT / path).read_text(encoding='utf-8')
        return self.cache[path]

    def test_fixture_is_well_formed(self):
        self.assertGreaterEqual(len(self.entries), 49)
        for entry in self.entries:
            self.assertGreaterEqual(len(legacy_branches(entry['original'])), 2, entry['type'])

    def test_maps_use_the_shared_capture_step(self):
        self.assertEqual(errors(self.entries, self.read), [])

    def test_shared_helper_matches_capture_branch(self):
        source = self.read('code/game/objects/map_metadata/_map_metadata.dm')
        def proc(name):
            match = re.search(r'(?m)^/obj/map_metadata/proc/' + name + r'\(.*\n((?:\t.*\n)*)', source)
            self.assertIsNotNone(match, name)
            return match.group(1)
        step, branch = proc('capture_step'), proc('capture_branch')
        for line in ('return FALSE', 'if (last_win_condition != win_condition.hash)', 'announce_current_win_condition()', 'return TRUE'):
            self.assertIn(line, step)
            self.assertIn(line, branch)
        self.assertIn('current_win_condition = capture_message(message_id)', step)

    def test_detects_changed_message(self):
        entry = self.entries[0]
        table = messages(self.read(entry['file']), entry['type'])
        first = next(iter(table.values()))
        changed = self.read(entry['file']).replace('return ' + first, 'return "changed"', 1)
        self.assertTrue(errors([entry], lambda path: changed if path == entry['file'] else self.read(path)))

    def test_detects_swapped_sides(self):
        entry = self.entries[-1]
        swapped = entry['replacement'].replace('capture_step(1, 2,', 'capture_step(9, 9,', 1).replace('capture_step(2, 1,', 'capture_step(1, 2,', 1).replace('capture_step(9, 9,', 'capture_step(2, 1,', 1)
        self.assertNotEqual(swapped, entry['replacement'])
        source = self.read(entry['file']).replace(entry['replacement'], swapped, 1)
        changed = dict(entry, replacement=swapped)
        self.assertTrue(errors([changed], lambda path: source if path == entry['file'] else self.read(path)))


if __name__ == '__main__':
    unittest.main()

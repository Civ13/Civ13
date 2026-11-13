"""Source contracts for shared stack pile icons and neighbour joining.

legacy_piles.json freezes 29 copied update_icon switches that picked a pile
sprite ("", "_2", "_3"...) from the stack amount. Each now calls
pile_suffix(amount, thresholds); these tests replay every whole amount from
0 to 2000 through the frozen switch and through pile_suffix and require the
same sprite. original_check_relatives.dm.txt freezes the copied joining
body that covers, the Japanese barricade and four windows now share as
join_neighbours.
"""
import json
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
STACK = ROOT / 'code/game/objects/items/stacks/stack.dm'
ATOMS = ROOT / 'code/game/atoms.dm'
JOINERS = {
    'code/game/objects/covers_types/cover_walltypes.dm': ['/obj/covers'],
    'code/game/objects/structures/barricades.dm': ['/obj/structure/barricade/jap'],
    'code/game/objects/structures/window.dm': ['/obj/structure/window_frame/abashiri', '/obj/structure/window_frame/medieval',
                                               '/obj/structure/window/classic/abashiri', '/obj/structure/window/classic/medieval'],
}
CALL = re.compile(r'icon_state = "([^"\n]*)\[pile_suffix\(amount, list\(([0-9, ]+)\)\)\]"')


def legacy_icon(original, amount):
    suffix = ''
    for low, high, value in re.findall(r'if \(([0-9]+) to ([0-9]+|INFINITY)\)\n\t\t\ticon_suffix = "([^"\n]*)"', original):
        if int(low) <= amount and (high == 'INFINITY' or amount <= int(high)):
            suffix = value
            break
    base = re.search(r'icon_state = "([^"\n]*)\[icon_suffix\]"', original).group(1)
    return base + suffix


def pile_suffix(amount, thresholds):
    for i in range(len(thresholds), 0, -1):
        if amount >= thresholds[i - 1]:
            return f'_{i + 1}'
    return ''


def proc_body(source, header):
    match = re.search(r'(?m)^' + re.escape(header) + r'.*\n((?:\t.*\n|[ \t]*\n)*)', source + '\n')
    return match.group(1) if match else None


def pile_errors(entries, read):
    found = []
    for entry in entries:
        source = read(entry['file'])
        where = entry['type']
        if entry['original'] in source:
            found.append(f'{where}: copied pile switch is back')
        if entry['replacement'] not in source:
            found.append(f'{where}: pile_suffix call missing')
            continue
        base, listed = CALL.search(entry['replacement']).groups()
        thresholds = [int(x) for x in listed.split(',')]
        bad = [n for n in range(0, 2001) if legacy_icon(entry['original'], n) != base + pile_suffix(n, thresholds)]
        if bad:
            found.append(f'{where}: pile sprite differs at amounts {bad[:5]}')
    return found


class PileIconTest(unittest.TestCase):
    def setUp(self):
        self.entries = json.loads((HERE / 'legacy_piles.json').read_text(encoding='utf-8'))

    def read(self, path):
        return (ROOT / path).read_text(encoding='utf-8')

    def test_fixture_covers_the_copies(self):
        self.assertGreaterEqual(len(self.entries), 29)
        self.assertEqual(len({e['type'] for e in self.entries}), len(self.entries))

    def test_piles_match_the_frozen_switches(self):
        self.assertEqual(pile_errors(self.entries, self.read), [])

    def test_helper_matches_the_python_model(self):
        body = proc_body(STACK.read_text(encoding='utf-8'), '/proc/pile_suffix(')
        self.assertEqual([l.strip() for l in body.strip().splitlines()],
                         ['. = ""', 'for (var/i = thresholds.len, i >= 1, i--)',
                          'if (amount >= thresholds[i])', 'return "_[i + 1]"'])

    def test_detects_shifted_threshold(self):
        entry = self.entries[0]
        shifted = re.sub(r'list\((\d+)', lambda m: f'list({int(m.group(1)) + 1}', entry['replacement'], 1)
        source = self.read(entry['file']).replace(entry['replacement'], shifted, 1)
        changed = dict(entry, replacement=shifted)
        self.assertTrue(pile_errors([changed], lambda path: source))


class JoinNeighboursTest(unittest.TestCase):
    def test_joiners_share_one_body(self):
        original = (HERE / 'original_check_relatives.dm.txt').read_text(encoding='utf-8')
        call = '\tjoin_neighbours(src, src:adjusts, src:base_icon_state, update_self, update_others)\n'
        for path, types in JOINERS.items():
            source = (ROOT / path).read_text(encoding='utf-8')
            self.assertNotIn(original, source, path)
            for typ in types:
                body = proc_body(source, f'{typ}/check_relatives(var/update_self = FALSE, var/update_others = FALSE)')
                self.assertEqual(body.rstrip() + "\n", call, typ)

    def test_helper_keeps_the_joining_rules(self):
        helper = proc_body(ATOMS.read_text(encoding='utf-8'), '/proc/join_neighbours(')
        for line in ('if (!adjusts)', 'for (var/checkdir in cardinal)', 'if (!A.can_join_with(CV))',
                     'junction |= get_dir(A,CV)', 'CV.check_relatives(1,0)', 'A.icon_state = "[base_state][junction]"'):
            self.assertIn(line, helper)


if __name__ == '__main__':
    unittest.main()

"""Offline check of the trumpet's production note-to-sample dispatch."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/game/objects/items/devices/trombone.dm'


def sample_table():
    source = SOURCE.read_text(encoding='utf-8')
    body = source.split('/obj/item/trombone/proc/playnote', 1)[1].split(
        '/obj/item/trombone/proc/playsong', 1)[0]
    table = {}
    for names, path in re.findall(r'if \(([^\n]+)\)\s+soundfile = \'([^\']+)\'', body):
        for name in re.findall(r'"([A-G][bn#][2-6])"', names):
            if name in table:
                raise AssertionError(f'duplicate note: {name}')
            table[name] = path
    return table


class TrumpetNotes(unittest.TestCase):
    def test_sharps_use_the_equivalent_available_pitch(self):
        table = sample_table()
        for octave in range(2, 7):
            for sharp, flat in [('C', 'D'), ('D', 'E'), ('F', 'G'),
                                ('G', 'A'), ('A', 'B')]:
                with self.subTest(note=f'{sharp}#{octave}'):
                    self.assertEqual(table.get(f'{sharp}#{octave}'),
                                     f'sound/trombone/{flat}b{octave}.mid')
            self.assertEqual(table.get(f'E#{octave}'), f'sound/trombone/Fn{octave}.mid')
        for octave in range(2, 6):
            self.assertEqual(table.get(f'B#{octave}'), f'sound/trombone/Cn{octave + 1}.mid')

    def test_naturals_and_flats_remain_distinct_and_exist(self):
        table = sample_table()
        for note in ('Cn3', 'Db3', 'Gn4', 'Ab4', 'Bn6'):
            self.assertEqual(table.get(note), f'sound/trombone/{note}.mid')
            self.assertTrue((ROOT / table[note]).is_file())
        self.assertNotEqual(table['Cn3'], table['Db3'])
        self.assertNotIn('B#6', table)  # C natural 7 is outside the supplied samples.


if __name__ == '__main__':
    unittest.main()

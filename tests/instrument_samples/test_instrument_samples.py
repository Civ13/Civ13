"""Every instrument note resolves to a real, playable sample file.

The piano, violin, shamisen and trumpet (/obj/item/trombone) each keep a
samples table of note name to .ogg file and hand it to instrument_play_note
in code/game/objects/items/devices/instrument_song.dm, which retunes the
nearest sample when a note has none of its own. The violin and trumpet used
to ship MIDI notes, which the BYOND client plays silent on most setups, and
the shamisen had samples for 27 notes only, so most songs played nothing.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SHARED = ROOT / 'code/game/objects/items/devices/instrument_song.dm'
INSTRUMENTS = {
    'piano': ('code/game/objects/structures/piano.dm', '/obj/structure/piano', 'sound/piano'),
    'violin': ('code/game/objects/items/devices/violin.dm', '/obj/item/violin', 'sound/violin'),
    'shamisen': ('code/game/objects/items/devices/shamisen.dm', '/obj/item/shamisen', 'sound/shamisen'),
    'trombone': ('code/game/objects/items/devices/trombone.dm', '/obj/item/trombone', 'sound/trombone'),
}
BASES = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11}
ACCIDENTALS = {'b': -1, 'n': 0, '#': 1}
MAX_RETUNE = 40
SEMITONES = 121


def semitone(note):
    return int(note[2]) * 12 + BASES[note[0]] + ACCIDENTALS[note[1]]


def samples(source, typ):
    match = re.search(re.escape(typ) + r'/var/static/list/samples = list\(\n(.*?)\)\n', source, re.S)
    if not match:
        raise AssertionError(f'{typ} has no samples table')
    table = {}
    for line in match.group(1).splitlines():
        entry = re.fullmatch(r'\t"([A-G][bn#][0-9])" = \'([^\']+)\',?', line)
        if not entry:
            raise AssertionError(f'{typ}: unexpected samples line {line!r}')
        if entry.group(1) in table:
            raise AssertionError(f'{typ}: duplicate note {entry.group(1)}')
        table[entry.group(1)] = entry.group(2)
    return table


def resolve(table, note):
    """Mirror of instrument_play_note: exact sample, else the nearest one,
    lower first, within MAX_RETUNE semitones. Returns (path, shift)."""
    by_semitone = {}
    for name, path in table.items():
        by_semitone[semitone(name)] = path
    target = semitone(note)
    for distance in range(MAX_RETUNE + 1):
        if target - distance >= 0 and target - distance in by_semitone:
            return by_semitone[target - distance], distance
        if target + distance < SEMITONES and target + distance in by_semitone:
            return by_semitone[target + distance], -distance
    return None, None


def playable_notes():
    # The song parser defaults to octave 3 and accepts octave digits 1-9.
    for octave in range(1, 10):
        for letter in BASES:
            for accidental in ACCIDENTALS:
                yield f'{letter}{accidental}{octave}'


class InstrumentSamplesTest(unittest.TestCase):
    def tables(self):
        for name, (path, typ, folder) in INSTRUMENTS.items():
            yield name, typ, folder, samples((ROOT / path).read_text(encoding='utf-8'), typ)

    def test_every_sample_is_a_real_ogg_file(self):
        for name, _typ, folder, table in self.tables():
            for note, path in table.items():
                with self.subTest(instrument=name, note=note):
                    self.assertTrue(path.startswith(folder + '/'), path)
                    self.assertTrue(path.endswith('.ogg'), path)
                    file = ROOT / path
                    self.assertTrue(file.is_file(), f'missing {path}')
                    self.assertEqual(file.read_bytes()[:4], b'OggS', f'{path} is not Ogg')
                    self.assertGreater(file.stat().st_size, 1000, f'{path} is empty')

    def test_every_sample_file_is_used(self):
        for name, _typ, folder, table in self.tables():
            with self.subTest(instrument=name):
                on_disk = {p.relative_to(ROOT).as_posix() for p in (ROOT / folder).iterdir()}
                self.assertEqual(on_disk - set(table.values()), set())

    def test_every_playable_note_has_a_sound(self):
        for name, _typ, _folder, table in self.tables():
            for note in playable_notes():
                with self.subTest(instrument=name, note=note):
                    path, _shift = resolve(table, note)
                    self.assertIsNotNone(path)

    def test_default_scale_plays_on_every_instrument(self):
        # "C,D,E,F,G,A,B" from the help text, all naturals in octave 3.
        for name, _typ, _folder, table in self.tables():
            for letter in 'CDEFGAB':
                with self.subTest(instrument=name, note=letter):
                    path, shift = resolve(table, f'{letter}n3')
                    self.assertIsNotNone(path)
                    self.assertLessEqual(abs(shift), 12)

    def test_resolution_prefers_exact_and_retunes_nearest(self):
        table = {'Cn3': 'a.ogg', 'Gn3': 'b.ogg'}
        self.assertEqual(resolve(table, 'Cn3'), ('a.ogg', 0))
        self.assertEqual(resolve(table, 'B#2'), ('a.ogg', 0))
        self.assertEqual(resolve(table, 'Dn3'), ('a.ogg', 2))
        self.assertEqual(resolve(table, 'Fn3'), ('b.ogg', -2))
        self.assertEqual(resolve(table, 'Cn9'), (None, None))
        self.assertEqual(resolve({'Cn3': 'a.ogg'}, 'Cn6'), ('a.ogg', 36))

    def test_instruments_use_the_shared_player(self):
        for name, typ, _folder, _table in self.tables():
            source = (ROOT / INSTRUMENTS[name][0]).read_text(encoding='utf-8')
            with self.subTest(instrument=name):
                self.assertIn(f'{typ}/proc/playnote(note)\n\tinstrument_play_note(src, note, samples)\n', source)
                self.assertNotIn('.mid\'', source)
                self.assertNotIn('<< sound(', source)
        shared = SHARED.read_text(encoding='utf-8')
        self.assertIn('#define INSTRUMENT_SEMITONES 121', shared)
        self.assertIn(f'#define INSTRUMENT_MAX_RETUNE {MAX_RETUNE}', shared)
        self.assertIn('for (var/distance = 0 to INSTRUMENT_MAX_RETUNE)', shared)
        self.assertIn('var/frequency = shift ? 2 ** (shift / 12) : 0', shared)
        self.assertIn('M.playsound_local(source, soundfile, 100, shift != 0, frequency, 5)', shared)

    def test_no_midi_instrument_samples_remain(self):
        for _name, (_path, _typ, folder) in INSTRUMENTS.items():
            self.assertEqual(sorted((ROOT / folder).glob('*.mid')), [])


if __name__ == '__main__':
    unittest.main()

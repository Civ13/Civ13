"""Source contracts for the shared instrument song player.

The piano, violin, shamisen and trumpet (/obj/item/trombone) each carried a
copy of playsong, the song panel and its Topic handler. original_*.dm.txt
freeze those copies. The instruments share their panel and Topic handlers
in code/game/objects/items/devices/instrument_song.dm and keep their own
sound tables. Handheld instruments also share the panel admission checks.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
SHARED = ROOT / 'code/game/objects/items/devices/instrument_song.dm'
INSTRUMENTS = {
    'violin': ('code/game/objects/items/devices/violin.dm', '/obj/item/violin', 'attack_self', 'Violin', 'violin', 'MAX_CHARS_PER_LINE'),
    'shamisen': ('code/game/objects/items/devices/shamisen.dm', '/obj/item/shamisen', 'attack_self', 'Shamisen', 'shamisen', 'MAX_CHARS_PER_LINE'),
    'trombone': ('code/game/objects/items/devices/trombone.dm', '/obj/item/trombone', 'attack_self', 'trombone', 'trombone', 'MAX_CHARS_PER_LINE'),
    'piano': ('code/game/objects/structures/piano.dm', '/obj/structure/piano', 'attack_hand', 'Piano', 'piano', 'MAX_LINES'),
}


def proc_body(source, header):
    match = re.search(r'(?m)^' + re.escape(header) + r'.*\n((?:\t.*\n|[ \t]*\n)*)', source + '\n')
    return match.group(1) if match else None


def parse_core(body):
    """The note parser: from the beat loop to the playnote call, comments and
    the instrument prefix stripped."""
    start = body.index('for (var/beat in')
    end = body.index('playnote(', start)
    end = body.index('\n', end)
    # The empty-beat guard (absent from the trumpet copy) never fires, since
    # splittext always returns at least one entry; the stop check is pinned
    # separately because items and the piano tested it differently.
    lines = []
    skip_return = False
    for line in body[start:end].splitlines():
        line = re.sub(r'//.*', '', line).strip().replace('I:', '')
        if not line:
            continue
        if skip_return and line == 'return':
            skip_return = False
            continue
        skip_return = False
        if 'notes.len)' in line and line.startswith('if (!') or line.startswith('if (!playing'):
            skip_return = 'notes.len)' in line
            continue
        lines.append(line)
    return lines


def errors(read):
    found = []
    shared = read(SHARED)
    for name, (path, typ, opener, title, window, limit) in INSTRUMENTS.items():
        source = read(ROOT / path)
        if f'{typ}/proc/playsong(' in source:
            found.append(f'{name} still has its own playsong')
        panel = proc_body(source, f'{typ}/{opener}(')
        panel_args = f'(src, user, "{title}", "{window}", {limit})'
        if opener == 'attack_self':
            if panel is None or panel.strip() != 'instrument_open_held_panel' + panel_args:
                found.append(f'{name} {opener} must call instrument_open_held_panel')
        elif panel is None or 'instrument_panel' + panel_args not in panel:
            found.append(f'{name} {opener} must call instrument_panel')
        topic = proc_body(source, f'{typ}/Topic(href, href_list)')
        if topic is None or topic.strip() != f'instrument_topic(src, usr, href_list, "{title}", "{window}", {limit})':
            found.append(f'{name} Topic must call instrument_topic')
        if source.count(f'{typ}/{opener}(') != 1 or source.count(f'{typ}/Topic(') != 1:
            found.append(f'{name} has a duplicate {opener} or Topic override')
        original = (HERE / f'original_{name}.dm.txt').read_text(encoding='utf-8')
        if proc_body(original, f'{typ}/Topic(') in source:
            found.append(f'{name} still carries a copied Topic body')
    if '/datum/song\n' in read(ROOT / INSTRUMENTS['piano'][0]):
        found.append('/datum/song is defined twice')
    playsong = proc_body(shared, '/proc/instrument_playsong(')
    if playsong is None:
        found.append('instrument_playsong missing')
    else:
        for name, (_, typ, *_rest) in INSTRUMENTS.items():
            original = proc_body((HERE / f'original_{name}.dm.txt').read_text(encoding='utf-8'), f'{typ}/proc/playsong(')
            if parse_core(original) != parse_core(playsong):
                found.append(f'shared note parser differs from the {name} original')
        if 'instrument_ready(I, I.loc)' not in playsong:
            found.append('instrument_playsong must stop when the instrument cannot play')
    return found


class InstrumentSongTest(unittest.TestCase):
    def read(self, path):
        return Path(path).read_text(encoding='utf-8')

    def test_instruments_use_the_shared_player(self):
        self.assertEqual(errors(self.read), [])

    def test_handheld_opening_checks_player_before_registering_and_opening(self):
        opener = proc_body(self.read(SHARED), '/proc/instrument_open_held_panel(')
        self.assertIsNotNone(opener)
        self.assertEqual(opener.rstrip(), (
            '\tif (!isliving(user) || user.stat || user.restrained() || user.lying)\n'
            '\t\treturn\n'
            '\tuser.set_using_object(instrument)\n'
            '\tinstrument_panel(instrument, user, title, window, max_lines)'
        ))

    def test_ready_rules_match_the_originals(self):
        ready = proc_body(self.read(SHARED), '/proc/instrument_ready(')
        self.assertIn('if (istype(I, /obj/structure))\n\t\treturn I.anchored', ready)
        self.assertIn('return isliving(holder)', ready)
        self.assertIn('!isliving(loc)', self.read(HERE / 'original_violin.dm.txt'))
        self.assertIn('!anchored', self.read(HERE / 'original_piano.dm.txt'))

    def test_single_line_edits_share_the_prompt_and_keep_distinct_guards(self):
        shared = self.read(SHARED)
        prompt = proc_body(shared, '/proc/instrument_prompt_for_line(')
        self.assertIsNotNone(prompt)
        self.assertIn(
            'html_encode(player_input(user, "Enter your line: ", title, default_line, "text", null, TRUE))',
            prompt,
        )
        self.assertIn(
            'if (line && length(line) > MAX_CHARS_PER_LINE)\n'
            '\t\tline = copytext(line, TRUE, MAX_CHARS_PER_LINE)\n\treturn line',
            prompt,
        )
        topic = proc_body(shared, '/proc/instrument_topic(')
        self.assertIn(
            'var/newline = instrument_prompt_for_line(user, title, null)\n'
            '\t\t\tif (!newline)\n\t\t\t\treturn\n'
            '\t\t\tif (song.lines.len > max_lines)\n\t\t\t\treturn\n'
            '\t\t\tsong.lines.Add(newline)',
            topic,
        )
        self.assertIn(
            'var/content = instrument_prompt_for_line(user, title, song.lines[num])\n'
            '\t\t\tif (!content)\n\t\t\t\treturn\n'
            '\t\t\tif (num > song.lines.len || num < 1)\n\t\t\t\treturn\n'
            '\t\t\tsong.lines[num] = content',
            topic,
        )

    def test_import_respects_the_instrument_line_limit(self):
        topic = proc_body(self.read(SHARED), '/proc/instrument_topic(')
        self.assertIn('if (lines.len > max_lines)', topic)
        self.assertIn('lines.Cut(max_lines+1)', topic)
        self.assertIn('if (song.lines.len > max_lines)', topic)
        self.assertIn('&& text2num(copytext(lines[1],6)))', topic)

    def test_detects_reintroduced_copy(self):
        def read(path):
            text = self.read(path)
            if str(path).endswith('violin.dm'):
                text += '\n' + self.read(HERE / 'original_violin.dm.txt')
            return text
        self.assertTrue(errors(read))

    def test_detects_changed_parser(self):
        def read(path):
            text = self.read(path)
            if path == SHARED:
                text = text.replace('cur_acc[cur_note] = "#"', 'cur_acc[cur_note] = "b"', 1)
            return text
        self.assertTrue(errors(read))


if __name__ == '__main__':
    unittest.main()

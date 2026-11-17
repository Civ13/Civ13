#!/usr/bin/env python3
"""Offline source contracts for the runtime errors Gaia's logs repeated most."""
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
BUILTIN_STAT = re.compile(r'(?<![\w.])(?:stat|statpanel)\(')


def read(path):
    return (ROOT / path).read_text(encoding='utf-8', errors='replace').replace('\r\n', '\n')


def code_lines(text):
    for line in text.split('\n'):
        yield line.split('//', 1)[0]


class LogRuntimes(unittest.TestCase):
    def test_no_builtin_stat_calls(self):
        # The stat panel is a web page fed by client.add_stat, and Stat() is
        # also called from Topic, where the built-ins raise "unexpected stat".
        found = []
        for path in sorted((ROOT / 'code').rglob('*.dm')):
            for number, line in enumerate(code_lines(path.read_text(encoding='utf-8', errors='replace')), 1):
                if BUILTIN_STAT.search(line):
                    found.append(f'{path.relative_to(ROOT)}:{number}')
        self.assertEqual(found, [])

    def test_extra_status_lines_use_the_web_panel(self):
        panel = read('code/modules/statpanel/statpanel.dm')
        self.assertIn('/client/proc/shows_status_tab()', panel)
        for path, label in (('code/modules/1713/cmss13_ops.dm', 'Respawn in:'),
                            ('code/modules/persistence/region_raid_reset.dm', 'Zone collapse in:'),
                            ('code/modules/space/pressure_suits.dm', 'Suit integrity:')):
            text = read(path)
            self.assertIn(f'client.add_stat("<b>{label}</b>"', text)
            self.assertIn('client.shows_status_tab()', text)

    def test_a_timer_name_survives_a_missing_target(self):
        timer = read('code/controllers/subsystem/timer.dm')
        body = timer[timer.index('/datum/timedevent/proc/getcallingtype()'):]
        body = body[:body.index('/**')]
        self.assertIn('else if (callBack.object)', body)

    def test_reagent_and_stack_guards(self):
        reagent = read('code/modules/reagents/Chemistry-Reagents.dm')
        body = reagent[reagent.index('/datum/reagent/proc/remove_self'):]
        self.assertIn('if (holder)\n\t\tholder.remove_reagent(id, amount)', body[:400])
        sheets = read('code/modules/materials/material_sheets.dm')
        body = sheets[sheets.index('/obj/item/stack/material/list_recipes'):]
        self.assertLess(body.index('if (!material)'), body.index('material.get_recipes_civs(U)'))


if __name__ == '__main__':
    unittest.main()

"""Offline source contract for rites at altars; does not execute DM."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


def read(rel):
    return (ROOT / rel).read_text(encoding='utf-8')


TEXT = read('code/modules/divine/arcane_rites.dm')


def body(text, header):
    return text.split(header, 1)[1].split('\n/', 1)[0]


class ArcaneRitesSource(unittest.TestCase):
    def test_included_and_reachable(self):
        self.assertIn('#include "code\\modules\\divine\\arcane_rites.dm"', read('civ13.dme'))
        self.assertIn('arcane_rite_at(O)', read('code/modules/divine/arcane_altars.dm'))
        self.assertIn('arcane_edit_rites(claim)', read('code/modules/admin/verbs/divine_patron.dm'))

    def test_four_kinds_up_to_five_rites(self):
        self.assertIn('#define ARCANE_RITES_MAX 5', TEXT)
        for kind in ('"animal"', '"food"', '"libation"', '"art"'):
            self.assertIn(kind + ' = ', TEXT)

    def test_led_without_a_god_click_and_once_a_day(self):
        at = body(TEXT, '/mob/living/human/proc/arcane_rite_at(')
        self.assertNotIn('divine_alert_operators', at)
        self.assertIn('magic_registered_repositories()', at)
        self.assertIn('target.magic_repo_roll_day()', at)
        self.assertIn('"rite_[R["kind"]]"', at)
        self.assertIn('ward_refill(target, amount, "rite", src)', at)
        self.assertIn('O.arcane_altar_percent()', at)
        self.assertIn('do_after(src, 100, O)', at)
        # checked again after the wait, and only spent once charge was taken
        self.assertLess(at.index('ward_refill('), at.index('arcane_rite_consume('))
        self.assertIn('"rite" = list("flat" = 400)', read('code/modules/divine/repository.dm'))

    def test_what_each_kind_takes(self):
        check = body(TEXT, '/mob/living/human/proc/arcane_rite_check(')
        self.assertIn('ARCANE_SACRIFICE_FRESH', check)
        self.assertIn('!A.arcane_sacrificed', check)
        self.assertIn('C.finished && C.author_ckey && !C.arcane_offered', check)
        self.assertIn('RG.volume * 0.9', check)
        consume = body(TEXT, '/proc/arcane_rite_consume(')
        self.assertIn('S.arcane_sacrificed = TRUE', consume)
        self.assertIn('I.arcane_offered = TRUE', consume)

    def test_god_sets_rites(self):
        edit = body(TEXT, '/client/proc/arcane_edit_rites(')
        self.assertIn('check_rights(R_ADMIN)', edit)
        self.assertIn('arcane_rites_save()', edit)
        self.assertIn('sanitize(raw, 40)', edit)
        self.assertNotIn('input(', edit.replace('player_input(', ''))


if __name__ == '__main__':
    unittest.main()

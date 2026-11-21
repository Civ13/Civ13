"""Offline source contract for devotion at altars; does not execute DM."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


def read(rel):
    return (ROOT / rel).read_text(encoding='utf-8')


TEXT = read('code/modules/divine/arcane_devotion.dm')


def body(text, header):
    return text.split(header, 1)[1].split('\n/', 1)[0]


class ArcaneDevotionSource(unittest.TestCase):
    def test_included(self):
        self.assertIn('#include "code\\modules\\divine\\arcane_devotion.dm"', read('civ13.dme'))

    def test_kept_at_an_altar_without_a_god_click(self):
        altars = read('code/modules/divine/arcane_altars.dm')
        self.assertIn('arcane_devote_at(O)', altars)
        devote = body(TEXT, '/mob/living/human/proc/arcane_devote_at(')
        self.assertIn('magic_registered_repositories()', devote)
        self.assertIn('arcane_custom_missing(god)', devote)
        self.assertNotIn('divine_alert_operators', devote)

    def test_rate_caps_and_worship(self):
        self.assertIn('#define ARCANE_DEVOTION_STEP 6000', TEXT)
        self.assertIn('#define ARCANE_DEVOTION_WORSHIP 18000', TEXT)
        loop = body(TEXT, '/mob/living/human/proc/arcane_devotion_loop(')
        self.assertIn('ward_refill(target, arcane_devotion_rate(god), "devotion", src)', loop)
        self.assertIn('O.arcane_altar_worship(src)', loop)
        self.assertIn('return min(rate, 4)', body(TEXT, '/mob/living/human/proc/arcane_devotion_rate('))
        repo = read('code/modules/divine/repository.dm')
        self.assertIn('"devotion" = list("flat" = 150)', repo)
        self.assertIn('magic_repo_follower_caps = list("devotion" = 30)', repo)

    def test_ends_on_move_harm_sleep_or_logout(self):
        loop = body(TEXT, '/mob/living/human/proc/arcane_devotion_loop(')
        for cond in ('!client', 'stat != CONSCIOUS', 'sleeping', 'get_turf(src) != start', '> start_damage', 'arcane_custom_missing(god)'):
            self.assertIn(cond, loop)

    def test_god_sets_up_to_three_customs(self):
        self.assertIn('#define ARCANE_CUSTOMS_MAX 3', TEXT)
        edit = body(TEXT, '/client/proc/arcane_edit_customs(')
        self.assertIn('check_rights(R_ADMIN)', edit)
        self.assertIn('arcane_customs_save()', edit)
        self.assertIn('arcane_edit_customs(claim)', read('code/modules/admin/verbs/divine_patron.dm'))


if __name__ == '__main__':
    unittest.main()

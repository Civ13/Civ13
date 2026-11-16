"""Building permits and trading licences: source contract checks.

    python3 tests/faction_permits/test_source.py
Native probe: python3 tests/ecology_spawning/run_linux.py . tests/faction_permits/probe.dm
"""
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/game/mob/groups/faction_permits.dm'


def read(path):
    return (ROOT / path).read_text(encoding='utf-8')


class FactionPermitsSource(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = SOURCE.read_text(encoding='utf-8')

    def test_included_after_treaties(self):
        self.assertIn('#include "code\\game\\mob\\groups\\faction_treaties.dm"\n#include "code\\game\\mob\\groups\\faction_permits.dm"', read('civ13.dme'))

    def test_permits_are_paper_kinds(self):
        papers = read('code/game/mob/groups/faction_papers.dm')
        self.assertIn('"build" = "building permit", "trade" = "trading licence"', papers)
        self.assertIn('permits_required(faction)', papers.split('/obj/map_metadata/proc/papers_normalize()', 1)[1].split('\n/', 1)[0])

    def test_off_by_default_and_members_exempt(self):
        missing = self.text.split('/proc/permit_missing(', 1)[1].split('\n/', 1)[0]
        self.assertIn('!map.permit_required(faction, kind) || H.civilization == faction', missing)
        self.assertIn('permit_deed_held(H, faction, at[2])', missing)

    def test_guard_rechecks_after_the_wait(self):
        guard = self.text.split('/datum/craft_guard/land_permit\n', 1)[1].split('\n/', 1)[0]
        self.assertIn('after_wait = TRUE', guard)
        self.assertNotIn('hides_recipe', guard)

    def test_permits_never_open_border_doors(self):
        admit = read('code/game/mob/groups/faction_papers.dm').split('/proc/papers_admit(', 1)[1].split('\n/', 1)[0]
        self.assertIn('(row[1] == "citizenship" || (row[1] == "pass" && admits >= PAPERS_ADMIT_PASSES))', admit)

    def test_setting_needs_the_papers_power_after_the_prompt(self):
        menu = self.text.split('/mob/living/human/proc/permits_require_menu(', 1)[1]
        self.assertIn('map.faction_power(src, faction, "papers")', menu)


if __name__ == '__main__':
    unittest.main()

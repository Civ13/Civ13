"""Taking a new name: source contract checks.

    python3 tests/name_change/test_source.py
Native probe: python3 tests/ecology_spawning/run_linux.py . tests/name_change/probe.dm
"""
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = 'code/game/mob/living/carbon/human/name_change.dm'


def read(path):
    return (ROOT / path).read_text(encoding='utf-8').replace('\r\n', '\n')


def body(text, head):
    return text.split(head, 1)[1].split('\n/', 1)[0]


class NameChangeSource(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = read(SOURCE)

    def test_included(self):
        self.assertIn('#include "code\\game\\mob\\living\\carbon\\human\\name_change.dm"', read('civ13.dme'))

    def test_seven_day_wait_and_persistent_worlds_only(self):
        self.assertIn('#define NAME_CHANGE_LOCK (7 * 24 * 36000)', self.text)
        self.assertIn('return map && (map.persistence || map.nomads)', self.text)
        take = body(self.text, '/mob/living/human/proc/take_new_name(')
        self.assertIn('name_change_lock = world.realtime + NAME_CHANGE_LOCK', take)
        self.assertIn('record_name_change(old_name, new_name, how)', take)

    def test_faction_members_go_through_the_clerk(self):
        verb = body(self.text, '/mob/living/human/verb/take_a_new_name(')
        self.assertIn('if (civilization && civilization != "none")', verb)
        # Rechecked after the prompt.
        self.assertGreaterEqual(verb.count('name_change_refusal('), 2)
        clerk = body(self.text, '/mob/living/human/proc/papers_record_name_change(')
        self.assertIn('map.faction_power(src, faction, "papers")', clerk.split('player_input(', 1)[1])
        self.assertIn('bill_blank_supply(src)', clerk)
        papers = read('code/game/mob/groups/faction_papers.dm')
        self.assertIn('papers_record_name_change(faction)', papers)
        self.assertIn('papers_name_change_lines(faction)', papers)

    def test_trail_is_kept_and_keyed_on_the_account(self):
        record = body(self.text, '/mob/living/human/proc/record_name_change(')
        self.assertIn('former_names += old_name', record)
        self.assertIn('faction_roster_account(src)', record)
        self.assertIn('log_admin(', record)
        self.assertIn('M.name_history_admin_html()', read('code/modules/admin/player_panel_pages.dm'))
        self.assertIn('record_name_change(old_name, new_name, "adoption")',
                      read('code/game/mob/living/carbon/human/nomads_adoption.dm'))

    def test_name_keyed_things_answer_to_former_names(self):
        self.assertIn('user.answers_to_name(owner_name)', read('code/game/objects/structures/key_doors/fitted_locks.dm'))
        self.assertIn('H.answers_to_name(setter_name)', read('code/modules/1713/stone_age_traps.dm'))
        register = read('code/modules/craft/craft_register.dm')
        self.assertIn('user.value_by_name(crew)', register)
        self.assertIn('user.any_name_in(barred)', register)

    def test_travel_carries_the_trail(self):
        travel = read('code/modules/persistence/region_travel.dm')
        for key in ('"former_names"', '"name_history"', '"name_change_lock"'):
            self.assertGreaterEqual(travel.count(key), 3, key)
        self.assertIn('name_history_valid(P[field])', travel)


if __name__ == '__main__':
    unittest.main()

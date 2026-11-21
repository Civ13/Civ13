#!/usr/bin/env python3
"""Offline source contracts for keeping knowledge after a death."""
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]


def read(path):
    return (ROOT / path).read_text(encoding='utf-8', errors='replace').replace('\r\n', '\n')


class DeathLegacyTests(unittest.TestCase):
    def test_the_module_is_compiled_in(self):
        self.assertIn('#include "code\\modules\\research_tree\\death_legacy.dm"', read('civ13.dme'))

    def test_death_records_before_the_dead_forget(self):
        death = read('code/game/mob/living/carbon/human/death.dm')
        self.assertLess(death.index('death_legacy_note(src, gibbed)'), death.index('\tforget_recipe_knowledge()'))

    def test_a_new_character_is_offered_the_record_at_its_start(self):
        spawn = read('code/game/mob/new_player/new_player.dm')
        self.assertLess(spawn.index('region_home_bed_spawn(character)'), spawn.index('death_legacy_return(character)'))
        self.assertIn('H.started_with_faction = TRUE', read('code/game/jobs/job_controller.dm'))
        self.assertIn('death_legacy_preview(choices, FACTION_START_WILDS)', read('code/game/mob/groups/faction_start.dm'))

    def test_a_bed_remembers_when_it_was_claimed(self):
        bed = read('code/modules/persistence/bed_return.dm')
        self.assertLess(bed.index('bed.persistence_bed_assigned_at = death_legacy_now()'),
                        bed.index('bed.persistence_bed_owner_ckey = owner'))

    def test_a_bed_start_costs_double(self):
        legacy = read('code/modules/research_tree/death_legacy.dm')
        self.assertIn('#define DEATH_LEGACY_BED_EXTRA 1', legacy)
        self.assertIn('var/bed_extra = by_station ? 0 : DEATH_LEGACY_BED_EXTRA * province_rank_bed_extra(account, get_turf(H))', legacy)
        self.assertIn('var/charged = record["returns"] + bed_extra', legacy)
        ranks = read('code/modules/provinces/province_ranks.dm')
        # Inside a Town 1.5 times, inside a City 1.25 times, else double.
        self.assertIn('return rank >= 4 ? 0.3219 : 0.585 // log2(1.25), log2(1.5)', ranks)
        self.assertIn('death_legacy_loss(record["cause"], charged)', legacy)
        # The loss doubles with each charged return (2 ** returns).
        self.assertIn('var/times = 2 ** clamp(returns, 0, 6)', legacy)

    def test_the_record_is_saved_checked_and_loaded(self):
        self.assertIn('round_state["death_legacy"] = death_legacy', read('code/modules/persistence/saving.dm'))
        self.assertIn('death_legacy_loaded(transfer_round_state)', read('code/modules/persistence/loading.dm'))
        functions = read('code/modules/persistence/functions.dm')
        self.assertIn('+ has_visited + has_death_legacy ||', functions)
        self.assertIn('!valid_death_legacy_record(state["death_legacy"])', functions)

    def test_every_attack_on_a_person_is_scaled(self):
        defense = read('code/game/mob/living/carbon/human/human_defense.dm')
        self.assertIn('effective_force *= death_weakness_scale(user, src)', defense)
        self.assertIn('P.damage *= death_weakness_scale(P.firer, src)', defense)
        self.assertIn('death_weakness_scale(H, src)', read('code/game/mob/living/carbon/human/human_attackhand.dm'))

    def test_the_limits_are_the_agreed_ones(self):
        module = read('code/modules/research_tree/death_legacy.dm')
        for name, value in (('DEATH_LEGACY_RANGE', '150'), ('DEATH_LEGACY_HOURS', '24'), ('DEATH_LEGACY_BED_HOURS', '24'),
                            ('DEATH_WEAKNESS_SECONDS', '1800'), ('DEATH_WEAKNESS_SCALE', '0.5')):
            self.assertRegex(module, r'#define %s %s\b' % (name, re.escape(value)))

    def test_the_weakness_spares_animals_and_is_shown(self):
        module = read('code/modules/research_tree/death_legacy.dm')
        self.assertIn('!istype(target, /mob/living/human)', module)
        self.assertIn('Shaken by death', read('code/game/mob/living/carbon/human/human.dm'))


if __name__ == '__main__':
    unittest.main()

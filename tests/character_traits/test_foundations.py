"""Offline source contracts and source-derived trait-table cases, not DM execution."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
TRAITS = 'code/game/mob/living/carbon/human/traits.dm'
BASIC = 'code/modules/client/preferencesSQLite/preference_setup/general/01_basic.dm'
PREFS = 'code/modules/client/preferencesSQLite/preferences.dm'
SAVE = 'code/modules/client/preferencesSQLite/preferences_saving&loading&del.dm'
LIFE = 'code/game/mob/living/carbon/human/human_life.dm'
PLAYSTYLE = 'code/game/mob/living/carbon/human/playstyle_traits.dm'
SETUP = 'code/modules/client/preferencesSQLite/character_setup_ui.dm'


def read(path):
    return (ROOT / path).read_text()


def definitions(source):
    return {name: (int(cost), re.findall(r'"([^"]+)"', excluded), description)
            for name, cost, excluded, description in re.findall(
                r'^\s*"([^"]+)"\s*=\s*list\((-?\d+),list\(([^)]*)\),"([^"]*)"\)', source, re.M)}


def validate(choices, table, budget=True):
    """Independent specification model; no claim to execute BYOND semantics."""
    if not isinstance(choices, list):
        return 'shape'
    seen = set()
    for choice in choices:
        if not isinstance(choice, str) or choice not in table:
            return 'unknown'
        if choice in seen:
            return 'duplicate'
        seen.add(choice)
    for choice in choices:
        if any(excluded in choices for excluded in table[choice][1]):
            return 'incompatible'
    if budget and sum(table[choice][0] for choice in choices) > 0:
        return 'budget'
    return None


def validator_contract(source):
    body = source.split('/proc/get_trait_selection_error(', 1)[1]
    for guard in ('!islist(trait_choices)', '!istext(choice)', '!(choice in trait_list)',
                  'choice in seen', 'trait_list[choice][2]', 'excluded in trait_choices',
                  'check_budget && check_trait_points(trait_choices) > 0', 'return null'):
        if guard not in body:
            raise AssertionError(guard)
    if re.search(r'trait_choices\s*(?:\+=|-=|=)|trait_choices\.(?:Cut|Add|Remove)', body):
        raise AssertionError('validator mutates choices')


class TraitFoundations(unittest.TestCase):
    def test_table_and_all_exclusions_both_orders(self):
        table = definitions(read(TRAITS))
        self.assertEqual(len(table), 68)  # +3 labour trades (Navvy, Miner, Woodcutter)
        self.assertEqual(table['Baldness'][0], 0)
        for name, (_, excluded, _) in table.items():
            for other in excluded:
                if other not in table:  # Historical disabled Cannibal definition.
                    continue
                for pair in ([name, other], [other, name]):
                    with self.subTest(pair=pair):
                        self.assertEqual(validate(pair, table, False), 'incompatible')
        # Asymmetric declarations must also be caught, independent of choice order.
        table['Agile'][1].append('Empathetic')
        for pair in (['Agile', 'Empathetic'], ['Empathetic', 'Agile']):
            self.assertEqual(validate(pair, table, False), 'incompatible')

    def test_legacy_invalid_data_retained_and_budget_editable(self):
        table = definitions(read(TRAITS))
        for choices, error in [(None, 'shape'), ('Agile', 'shape'), ([7], 'unknown'),
                               (['Removed Trait'], 'unknown'), (['Baldness'] * 2, 'duplicate'),
                               (['Agile'], 'budget')]:
            before = choices.copy() if isinstance(choices, list) else choices
            self.assertEqual(validate(choices, table), error)
            self.assertEqual(choices, before)
        self.assertIsNone(validate(['Agile'], table, False))
        self.assertIsNone(validate([], table))
        self.assertIsNone(validate(['Baldness'], table))
        self.assertIsNone(validate(['Agile', 'Deaf'], table))

    def test_validator_contract_and_negative_controls(self):
        source = read(TRAITS)
        validator_contract(source)
        for guard in ('choice in seen', 'excluded in trait_choices', '!islist(trait_choices)'):
            with self.subTest(omitted=guard), self.assertRaises(AssertionError):
                validator_contract(source.replace(guard, 'FALSE'))

    def test_save_load_preserves_choices_and_reports_invalid(self):
        source = read(SAVE)
        self.assertNotIn('traits -=', source)
        self.assertIn('get_trait_selection_error(traits)', source)
        self.assertIn('Your saved choices have been preserved', source)
        self.assertIn('"traits"', source)
        self.assertIn('if (i < val:len)', source)
        self.assertIn('(key == "traits" && !length(list)) ? list()', source)
        for choices in ([], ['Baldness', 'Baldness'], ['Old', 'Agile', 'Old']):
            encoded = '|'.join(choices)
            decoded = encoded.split('|') if encoded else []
            self.assertEqual(decoded, choices)

    def test_setup_window_shows_unknown_entries_and_rechecks_each_choice(self):
        source = read(SETUP)
        view = source.split('/datum/preferences/proc/trait_setup_data()', 1)[1].split('\n/datum/', 1)[0]
        # Reading never rewrites saved choices; unknown and repeated ones are listed.
        self.assertIn('if (!istext(choice) || !(choice in trait_list) || (choice in taken))\n\t\t\tinvalid += "[choice]"', view)
        self.assertNotRegex(view, r'\btraits\s*(?:\+=|-=|=[^=])|traits\.(?:Cut|Add|Remove)')
        add = source.split('/datum/preferences/proc/setup_add_trait(', 1)[1].split('\n/datum/', 1)[0]
        # No prompt can yield between the check and the write.
        for wait in ('input(', 'alert(', 'WWinput(', 'WWalert(', 'sleep('):
            self.assertNotIn(wait, source)
        self.assertIn('!(trait_name in trait_list)', add)
        self.assertIn('(trait_name in traits)', add)
        self.assertLess(add.index('get_trait_selection_error(candidate, FALSE)'), add.index('traits = candidate'))
        remove = source.split('/datum/preferences/proc/setup_remove_trait(', 1)[1].split('\n/datum/', 1)[0]
        self.assertIn('if (choice != trait_name)\n\t\t\tkept += choice', remove)

    def test_copy_is_independent_and_baldness_initializes_after_traits(self):
        source = read(PREFS).split('/datum/preferences/proc/copy_to(', 1)[1].split('/client/proc/', 1)[0]
        self.assertLess(source.index('get_trait_selection_error(traits)'), source.index('character.real_name ='))
        self.assertIn('character.traits = traits.Copy()', source)
        self.assertLess(source.index('character.traits_dirty = TRUE'), source.index('character.find_trait("Baldness")'))
        self.assertIn('character.h_style = "Bald"', source)
        self.assertIn('character.h_growth = 0', source)
        self.assertIn('return TRUE', source)

    def test_social_counts_other_living_humans_only(self):
        # Company is a lasting condition on the resting mood, counted by one helper.
        source = read('code/game/mob/living/carbon/human/playstyle_traits.dm')
        self.assertNotIn('find_trait("Extroverted")', read(LIFE))
        company = source[source.index('/mob/living/human/proc/mood_company('):source.index('/mob/living/human/proc/mood_needs_mode()')]
        self.assertEqual(company.count('if (H != src && H.stat != DEAD)'), 1)
        self.assertEqual(company.count('range(3, src)'), 1)
        social = source[source.index('/mob/living/human/collect_mood_rest_parts(list/parts)'):source.index('#undef PLAYSTYLE_FAST_SKILL')]
        self.assertEqual(social.count('= MOOD_REST_LIKED_COMPANY'), 2)
        self.assertEqual(social.count('= -MOOD_REST_WRONG_COMPANY'), 2)
        self.assertNotIn('adjust_mood(', social)
        # Counterexample to the historical bug: own living body is present.
        for nearby, expected in [([('self', False)], 0), ([('self', False), ('other', False)], 1),
                                 ([('self', False), ('other', True)], 0)]:
            count = sum(who != 'self' and not dead for who, dead in nearby)
            self.assertEqual(count, expected)
        self.assertNotEqual(company.replace('H != src && ', '').count('if (H != src && H.stat != DEAD)'), 1)

    def test_social_proximity_stops_after_first_match(self):
        source = read('code/game/mob/living/carbon/human/playstyle_traits.dm')
        social = source[source.index('/mob/living/human/proc/mood_company('):source.index('/mob/living/human/proc/mood_needs_mode()')]
        loop = ('for (var/mob/living/human/H in range(3, src))\n'
                '\t\tif (H != src && H.stat != DEAD)\n'
                '\t\t\t.++\n'
                '\t\t\tif (. >= limit)\n'
                '\t\t\t\treturn\n')
        def valid_loops(text):
            bodies = re.findall(r'for \(var/mob/living/human/H in range\(3, src\)\).*?(?=\n// )', text, re.S)
            return len(bodies) == 1 and all(body == loop for body in bodies)

        self.assertTrue(valid_loops(social))
        self.assertFalse(valid_loops(social.replace('\t\t\t\treturn\n', '')))
        self.assertFalse(valid_loops(social.replace('range(3, src))\n', 'range(3, src))\n\t\treturn\n')))

        # Compare modeled iteration counts and decisions; this does not execute DM.
        for nearby, visited in (([], 0), ([('self', False)], 1),
                                ([('self', False), ('other', True)], 2),
                                ([('other', False), ('another', False)], 1),
                                ([('self', False), ('other', True), ('another', False)], 3)):
            old_count = sum(who != 'self' and not dead for who, dead in nearby)
            found, iterations = False, 0
            for who, dead in nearby:
                iterations += 1
                if who != 'self' and not dead:
                    found = True
                    break
            self.assertEqual(found, bool(old_count))
            self.assertEqual(iterations, visited)

    def test_actual_body_modifiers_documented_without_rebalance(self):
        table = definitions(read(TRAITS))
        for trait, phrases in {'Dwarfism': ('Strength x0.7', 'crafting x1.5', 'food use x0.8'),
                               'Short': ('Strength x0.85', 'crafting x1.15'),
                               'Tall': ('Strength x1.15', 'dexterity x0.85'),
                               'Gigantism': ('Strength x1.5', 'dexterity x0.7', 'food use x1.4')}.items():
            for phrase in phrases:
                self.assertIn(phrase, table[trait][2])
        stats = read('code/game/mob/living/carbon/human/human_stats.dm')
        self.assertIn('craft_mod = 1.5', stats)
        self.assertIn('craft_mod = 1.15', stats)

    def test_playstyle_traits_are_free_exclusive_and_hooked(self):
        table = definitions(read(TRAITS))
        playstyle = ['Recluse Scholar', 'Menacing', 'Hardened Fighter', 'Quartermaster',
                     'Green Thumb', 'Tinkerer', 'Wanderer', 'Rallying Voice']
        for name in playstyle:
            self.assertEqual(table[name][0], 0, name)
            self.assertTrue(table[name][2].startswith('Playstyle.'), name)
            self.assertIsNone(validate([name], table))
            for other in playstyle:
                if other != name:
                    self.assertEqual(validate([name, other], table, False), 'incompatible')
        self.assertEqual(validate(['Recluse Scholar', 'Extroverted'], table, False), 'incompatible')
        self.assertEqual(validate(['Rallying Voice', 'Introverted'], table, False), 'incompatible')
        self.assertIsNone(validate(['Green Thumb', 'Agile', 'Deaf'], table))
        hooks = {
            'code/game/mob/living/carbon/human/human_stats.dm': ('trait_skill_gain_mult(statname)', 'find_trait("Tinkerer")'),
            LIFE: ('food_m *= trait_food_mult()', 'handle_playstyle_traits()'),
            PLAYSTYLE: ('/mob/living/human/say(', 'rally_shout()', 'proc/recluse_rate()', 'proc/pull_drag_mult()',
                        'proc/trait_pain_mult()', 'proc/trait_harvest_bonus(', 'proc/trait_stamina_recovery_mult()', 'wanderer_recover_stamina()',
                        'verb/intimidate()', 'player_input(src, "Who do you want to intimidate?"'),
        }
        for path, needles in hooks.items():
            source = read(path)
            for needle in needles:
                self.assertIn(needle, source, path)

    def test_point_trait_pairs_balance_and_exclude(self):
        table = definitions(read(TRAITS))
        pairs = {'Quick Learner': ('Slow Learner', 3), 'Light Eater': ('Glutton', 2),
                 'Deep Lungs': ('Asthmatic', 2), 'Thick Skinned': ('Low Pain Tolerance', 2),
                 'Bookworm': ('Dyslexic', 2), 'Steady Hands': ('Butterfingers', 2),
                 'Strong Back': ('Bad Back', 1)}
        for perk, (drawback, cost) in pairs.items():
            self.assertEqual(table[perk][0], cost)
            self.assertEqual(table[drawback][0], -cost)
            self.assertEqual(validate([perk, drawback], table, False), 'incompatible')
            self.assertEqual(validate([perk], table), 'budget')
            self.assertIsNone(validate([drawback], table))
        self.assertEqual(table['Squeamish'][0], -1)
        for a, b in (('Thick Skinned', 'Hardened Fighter'), ('Strong Back', 'Quartermaster'),
                     ('Squeamish', 'Hardened Fighter')):
            self.assertEqual(validate([a, b], table, False), 'incompatible')
        self.assertIsNone(validate(['Quick Learner', 'Glutton', 'Bad Back'], table))
        stats = read('code/game/mob/living/carbon/human/human_stats.dm')
        self.assertIn('mood_modifier*med_mod', stats)
        self.assertIn('wanderer_recover_stamina()', read(LIFE))
        source = read(PLAYSTYLE)
        for needle in ('find_trait("Quick Learner")', 'find_trait("Light Eater")', 'find_trait("Asthmatic")',
                       'find_trait("Low Pain Tolerance")', 'proc/trait_study_time_mult()', 'find_trait("Bad Back")',
                       'proc/trait_gore_mood_mult()', '/mob/living/human/adjust_mood(amount, cause = null)'):
            self.assertIn(needle, source)

    def test_sight_traits_cost_exclude_blind_and_hook(self):
        table = definitions(read(TRAITS))
        self.assertEqual(table['Nearsighted'][0], -2)
        self.assertEqual(table['Farsighted'][0], -1)
        for trait in ('Nearsighted', 'Farsighted'):
            self.assertEqual(validate([trait, 'Blind'], table, False), 'incompatible')
            self.assertIsNone(validate([trait], table))
        self.assertIsNone(validate(['Nearsighted', 'Farsighted'], table))
        sight = read('code/game/mob/living/carbon/human/sight_traits.dm')
        for needle in ('/obj/item/clothing/glasses/regular\n\tcorrects_vision = TRUE',
                       '/obj/item/clothing/glasses/monocle\n\tcorrects_vision = TRUE',
                       'proc/update_sight_fog()', 'proc/farsight_can_read(', 'proc/farsight_reading_mult()'):
            self.assertIn(needle, sight)
        self.assertIn('update_sight_fog()', read(LIFE))

if __name__ == '__main__':
    unittest.main()

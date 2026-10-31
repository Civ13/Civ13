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
        self.assertEqual(len(table), 24)
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

    def test_ui_safe_unknown_display_exact_removal_and_post_wait_validation(self):
        source = read(BASIC)
        self.assertIn('istext(choice) ? trait_list[choice] : null', source)
        self.assertIn('html_encode("[choice]")', source)
        self.assertNotIn('findtext(remove, i)', source)
        self.assertIn('pref.traits.Cut(index, index + 1)', source)
        self.assertIn('snapshot[i] != pref.traits[i]', source)
        add = source.split('else if (href_list["add_traits"])', 1)[1].split('else if (href_list["remove_traits"])', 1)[0]
        confirm = add.index('alert(user,')
        self.assertGreater(add.rindex('get_trait_selection_error(candidate, FALSE)'), confirm)
        self.assertGreater(add.index('pref.traits = candidate'), add.rindex('get_trait_selection_error(candidate, FALSE)'))
        self.assertIn('!CanUseTopic(user)', add[confirm:])

    def test_copy_is_independent_and_baldness_initializes_after_traits(self):
        source = read(PREFS).split('/datum/preferences/proc/copy_to(', 1)[1].split('/client/proc/', 1)[0]
        self.assertLess(source.index('get_trait_selection_error(traits)'), source.index('character.real_name ='))
        self.assertIn('character.traits = traits.Copy()', source)
        self.assertLess(source.index('character.traits_dirty = TRUE'), source.index('character.find_trait("Baldness")'))
        self.assertIn('character.h_style = "Bald"', source)
        self.assertIn('character.h_growth = 0', source)
        self.assertIn('return TRUE', source)

    def test_social_counts_other_living_humans_only(self):
        source = read(LIFE)
        social = source[source.index('if (find_trait("Extroverted"))'):source.index('if (!inducedSSD)', source.index('if (find_trait("Extroverted"))'))]
        self.assertEqual(social.count('if (HM != src && HM.stat != DEAD)'), 2)
        self.assertEqual(social.count('range(3,src)'), 2)
        self.assertEqual(social.count('mood += 0.12'), 2)
        self.assertEqual(social.count('mood -= 0.4'), 2)
        # Counterexample to the historical bug: own living body is present.
        for nearby, expected in [([('self', False)], 0), ([('self', False), ('other', False)], 1),
                                 ([('self', False), ('other', True)], 0)]:
            count = sum(who != 'self' and not dead for who, dead in nearby)
            self.assertEqual(count, expected)
        self.assertNotEqual(social.replace('HM != src && ', '').count('if (HM != src && HM.stat != DEAD)'), 2)

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


if __name__ == '__main__':
    unittest.main()

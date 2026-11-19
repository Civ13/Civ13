"""Source-projected checks for signal-smoke dialog races; these do not run DM."""

from pathlib import Path
import unittest


SOURCE = Path(__file__).resolve().parents[2] / 'code/game/objects/items/weapons/grenades/smokebomb.dm'
FACTIONS = ('AMERICAN', 'DUTCH', 'RUSSIAN')


def branch(source, faction):
    body = source.split('/obj/item/weapon/grenade/smokebomb/signal/attack_self(', 1)[1]
    body = body.split('/obj/item/weapon/grenade/smokebomb/signal/proc/', 1)[0]
    return body.split(f'\t\t\tif ({faction})\n', 1)[1].split('\n\t\t\tif (', 1)[0].split('\n\t\t\telse\n', 1)[0]


def finish_dialog(source, faction, active, choice):
    """Project the post-dialog admission check for one outstanding prompt."""
    body = branch(source, faction)
    after_prompt = body.split('var/choice = player_input(', 1)[1]
    guard = after_prompt.split('\n', 2)[1]
    assert guard == '\t\t\t\t\tif(src && choice && !active)'
    guarded = after_prompt.split(guard + '\n', 1)[1].split('\n\t\t\t\telse', 1)[0]
    assert guarded.count('\t\t\t\t\t\tthings_to_spawn = options[choice]') == 1
    assert guarded.count('\t\t\t\t\t\tfinish_supply_selection(user)') == 1
    assert guarded.index('things_to_spawn = options[choice]') < guarded.index('finish_supply_selection(user)')
    assert body.count('things_to_spawn = options[choice]') == 1
    if not choice or active:
        return active, None
    return True, choice


class SignalSmokeSelection(unittest.TestCase):
    def setUp(self):
        self.source = SOURCE.read_text(encoding='utf-8')

    def test_late_dialog_does_not_overwrite_active_selection(self):
        for faction in FACTIONS:
            with self.subTest(faction=faction):
                active, first = finish_dialog(self.source, faction, False, 'Ammunition')
                active, second = finish_dialog(self.source, faction, active, 'Medical supplies')
                self.assertTrue(active)
                self.assertEqual((first, second), ('Ammunition', None))
                old = self.source.replace('if(src && choice && !active)', 'if(src && choice)')
                with self.assertRaises(AssertionError):
                    finish_dialog(old, faction, True, 'Medical supplies')

    def test_cancelled_dialog_does_not_activate(self):
        for faction in FACTIONS:
            with self.subTest(faction=faction):
                self.assertEqual(finish_dialog(self.source, faction, False, None), (False, None))

    def test_huey_choice_remains_american_only(self):
        self.assertIn('options["Landing zone for the Huey"]', branch(self.source, 'AMERICAN'))
        self.assertIn('marks_lz = (choice == "Landing zone for the Huey")', branch(self.source, 'AMERICAN'))
        for faction in ('DUTCH', 'RUSSIAN'):
            self.assertNotIn('options["Landing zone for the Huey"]', branch(self.source, faction))
            self.assertNotIn('marks_lz =', branch(self.source, faction))

    def test_daylight_gate_and_success_sequence(self):
        for faction in FACTIONS:
            body = branch(self.source, faction)
            self.assertLess(body.index('if (time_of_day != "Night")'), body.index('player_input('))
            self.assertIn('There is no sufficient visibility for a supply drop!', body)
        helper = self.source.split('/obj/item/weapon/grenade/smokebomb/signal/proc/finish_supply_selection(', 1)[1]
        helper = helper.split('\n/obj/', 1)[0]
        actions = ('to_chat(user,', 'firer = user', 'activate(user)', 'add_fingerprint(user)',
                   'H.throw_mode_on()', 'triggered = TRUE')
        offsets = [helper.index(action) for action in actions]
        self.assertEqual(offsets, sorted(offsets))

    def test_broken_guard_and_missing_completion_are_detected(self):
        for mutation in (
            self.source.replace('if(src && choice && !active)', 'if(src && choice || !active)'),
            self.source.replace('finish_supply_selection(user)', 'return', 1),
        ):
            with self.assertRaises(AssertionError):
                finish_dialog(mutation, 'AMERICAN', True, 'Ammunition')


if __name__ == '__main__':
    unittest.main()

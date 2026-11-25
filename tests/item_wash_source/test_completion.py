"""Offline completion regression for washing an item at a water source."""
from pathlib import Path
import re
import unittest

SOURCE = Path(__file__).resolve().parents[2] / 'code/game/objects/structures/watercloset.dm'


class WashSourceTests(unittest.TestCase):
    def setUp(self):
        source = SOURCE.read_text(encoding='utf-8')
        attackby = source.split('/obj/structure/sink/attackby(', 1)[1]
        self.admission = attackby.split('\tvar/obj/item/weapon/reagent_containers/RG', 1)[0]
        self.completion = attackby.split('\n\tbusy = TRUE\n\tsleep(40)\n\tbusy = FALSE\n', 1)[1]
        self.gates, self.cleanup = self.completion.split('\n\tO.clean_blood()', 1)

    def test_wet_source_is_required_before_item_cleanup(self):
        # Project the remaining source gates after the player/item continuity
        # checks. Stubs stand in for the weather and BYOND object queries.
        lines = self.gates.split('\n')[1:]
        source_gates = []
        for raw in lines:
            line = raw.strip()
            if not line or line.startswith(('if (user.loc', 'if (!I)', 'if (user.get_active_hand')):
                continue
            if line.startswith('to_chat('):
                self.assertIn('is dry!</span>', line)
                self.assertIn(line, self.admission)
                source_gates.append('\t\twarnings.append("dry")')
            elif line == 'return':
                source_gates.append('\t\treturn False')
            else:
                match = re.fullmatch(r'if \((.+)\)( return)?', line)
                self.assertIsNotNone(match, line)
                condition = match[1].replace('||', 'or').replace('!', 'not ')
                source_gates.append('\tif (' + condition + '):' + (' return False' if match[2] else ''))
        body = '\n'.join(['def attempt():', *source_gates, '\treturn True'])
        for deleted, adjacent, dry, volume, expected, warnings in (
            (False, True, False, 1, True, []),
            (False, True, True, 1, False, ['dry']),
            (False, True, False, 0, False, ['dry']),
            (False, True, False, -1, False, ['dry']),
            (True, True, False, 1, False, []),
            (False, False, False, 1, False, []),
        ):
            with self.subTest(deleted=deleted, adjacent=adjacent, dry=dry, volume=volume):
                emitted = []
                context = dict(src=object(), user=object(), volume=volume, warnings=emitted,
                               QDELETED=lambda _: deleted, Adjacent=lambda _: adjacent,
                               heat_dried=lambda: dry)
                exec(body, context)
                self.assertEqual(context['attempt'](), expected)
                self.assertEqual(emitted, warnings)

    def test_cleanup_and_success_remain_after_source_checks(self):
        self.assertIn('C.hand_wash(user)', self.cleanup)
        self.assertIn('user.visible_message(', self.cleanup)
        self.assertIn('if (user.get_active_hand() != I) return', self.gates)

    def test_washed_hide_reserves_output_for_an_empty_hand_before_ground_merge(self):
        root = SOURCE.parents[4]
        leather = (root / 'code/game/objects/items/stacks/sheets/leather.dm').read_text(encoding='utf-8')
        output = leather.split('/proc/water_wash_output(', 1)[1].split('\n/obj/', 1)[0]
        self.assertLess(output.index('if (istype(held) && held.amount < held.max_amount)'),
                        output.index('wethide(site, 1, !!user.get_inactive_hand())'))
        self.assertIn('if (!QDELETED(made) && made.loc == site && !user.get_inactive_hand())', output)
        self.assertIn('user.put_in_inactive_hand(made)', output)


if __name__ == '__main__':
    unittest.main()

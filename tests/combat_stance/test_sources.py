"""Combat stances: offline seam checks.

The native probe (probe.dm, run.py) checks the zone scoring in a real build.
These checks keep the wiring it cannot reach: every melee path asks the
stance, the zone doll and hotkeys hand control back, the HUD button cycles the
stances, and agent tools list the same stances as the game.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]


def read(path):
    return (ROOT / path).read_text(encoding='utf-8')


SOURCE = read('code/game/mob/combat_stance.dm')
DEFINES = read('code/__defines/combat_stance.dm')
DME = read('civ13.dme')
ITEM_ATTACK = read('code/_onclick/item_attack.dm')
ATTACK_HAND = read('code/game/mob/living/carbon/human/human_attackhand.dm')
DEFENSE = read('code/game/mob/living/carbon/human/human_defense.dm')
HOTKEYS = read('code/game/mob/living/carbon/human/inventory.dm')
SCREENS = read('code/_onclick/hud/base_screen_objects.dm')
EXAMINE = read('code/game/mob/living/carbon/human/examine.dm')
AGENT = read('code/modules/agent_control/agent_stance.dm')
AUTOPILOT = read('tools/agent-control/autopilot.py')
CATALOG = read('tools/agent-control/catalog.py')

STANCES = ['manual', 'measured', 'aggressive', 'disarming', 'low', 'guarded']


class CombatStanceSources(unittest.TestCase):
    def test_sources_are_compiled(self):
        self.assertIn('#include "code\\__defines\\combat_stance.dm"', DME)
        self.assertIn('#include "code\\game\\mob\\combat_stance.dm"', DME)

    def test_stance_ids(self):
        found = re.findall(r'#define COMBAT_STANCE_\w+ "(\w+)"', DEFINES)
        self.assertEqual(found, STANCES)

    def test_melee_paths_ask_the_stance(self):
        self.assertIn('user.resolve_attack_zone(src, I, COMBAT_ATTACK_WEAPON)', ITEM_ATTACK)
        self.assertIn('H.resolve_attack_zone(src, null, attack_kind)', ATTACK_HAND)
        self.assertIn('user.resolve_attack_zone(src, null, COMBAT_ATTACK_KICK)', DEFENSE)
        # the shove decision follows the resolved zone, so Disarming can aim a disarm
        self.assertIn('if (tgt == "chest" || tgt == "random")\n\t\t\t\t\treturn try_deliberate_shove(M)', ATTACK_HAND)

    def test_attacks_are_recorded_for_reading(self):
        self.assertIn('note_struck_by(user, tgt, user.attacking_arm())', ITEM_ATTACK)
        self.assertIn('note_struck_by(H, hit_zone, H.attacking_arm())', ATTACK_HAND)
        self.assertIn('note_struck_by(user, hit_zone, "r_leg")', DEFENSE)
        # who struck is a ref text, never a saved pointer
        self.assertIn('var/tmp/last_struck_by = null', SOURCE)
        self.assertIn('last_struck_by = "\\ref[attacker]"', SOURCE)

    def test_doll_and_hotkeys_take_manual_control(self):
        self.assertEqual(SCREENS.count('parentmob.combat_stance_doll_clicked()'), 3)
        self.assertEqual(HOTKEYS.count('H.combat_stance_doll_clicked()'), 7)
        self.assertEqual(SCREENS.count('overlays += combat_doll_flash_image('), 3)

    def test_random_button_cycles_stances(self):
        self.assertIn('parentmob.set_combat_stance(combat_stance_order[1])', SCREENS)
        self.assertIn('combat_stance_labels[parentmob.combat_stance]', SCREENS)

    def test_examine_shows_stance(self):
        self.assertIn('combat_stance_examine_line(T)', EXAMINE)

    def test_agents_list_the_same_stances(self):
        self.assertIn('out["combat"] = M.combat_stance', AGENT)
        self.assertIn('"combat": ("%s")' % '", "'.join(STANCES), AUTOPILOT)
        self.assertEqual(CATALOG.count('"enum": ["%s"]' % '", "'.join(STANCES)), 2)


if __name__ == '__main__':
    unittest.main()

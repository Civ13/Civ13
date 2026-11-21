"""Combat stances: offline seam checks.

The native probe (probe.dm, run.py) checks the zone scoring in a real build.
These checks keep the wiring it cannot reach: every melee path asks the
stance, the zone doll and hotkeys hand control back, the HUD button cycles the
stances, and agent tools list the same stances as the game.
"""
from pathlib import Path
import re
import struct
import unittest
import zlib

ROOT = Path(__file__).resolve().parents[2]


def read(path):
    return (ROOT / path).read_text(encoding='utf-8')


SOURCE = read('code/game/mob/combat_stance.dm')
REACTIONS = read('code/game/mob/combat_reactions.dm')
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

def dmi_description(path):
    """The DMI metadata text, from its tEXt or zTXt "Description" chunk."""
    data = path.read_bytes()
    pos = 8
    while pos < len(data):
        length = struct.unpack('>I', data[pos:pos + 4])[0]
        kind = data[pos + 4:pos + 8]
        body = data[pos + 8:pos + 8 + length]
        if kind in (b'tEXt', b'zTXt') and body.startswith(b'Description\0'):
            rest = body[len(b'Description\0'):]
            return (zlib.decompress(rest[1:]) if kind == b'zTXt' else rest).decode('utf-8')
        pos += 12 + length
    return ''


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

    def test_stance_button_beside_tactic(self):
        self.assertIn('/obj/screen/combat_stance/Click()', SCREENS)
        self.assertIn('icon_state = "stance_[stance]"', SCREENS)
        # random leaves any stance, a stance leaves random
        self.assertIn('if (parentmob.combat_stance_active())\n\t\t\tparentmob.set_combat_stance(COMBAT_STANCE_MANUAL)', SCREENS)
        self.assertIn('leave_random_zone()', SOURCE)
        huds = [read(p) for p in ('code/_onclick/hud/hud_civstyle.dm', 'code/_onclick/hud/hud_fofstyle.dm',
                                  'code/_onclick/hud/hud_litewebstyle.dm', 'code/_onclick/hud/hud_newstyle.dm')]
        for hud in huds:
            self.assertIn('/obj/screen/combat_stance', hud)
        self.assertEqual(read('code/datums/hud.dm').count('/obj/screen/combat_stance'), 5)

    def test_every_hud_sheet_has_the_stance_art(self):
        for sheet in ('1713Style', 'ConsoleStyle', 'FoFStyle', 'litewebStyle'):
            text = dmi_description(ROOT / ('icons/mob/screen/%s.dmi' % sheet))
            for stance in STANCES:
                self.assertIn('state = "stance_%s"' % stance, text, sheet)

    def test_examine_shows_stance(self):
        self.assertIn('combat_stance_examine_line(T)', EXAMINE)

    def test_agents_list_the_same_stances(self):
        self.assertIn('out["combat"] = M.combat_stance', AGENT)
        self.assertIn('"combat": ("%s")' % '", "'.join(STANCES), AUTOPILOT)
        self.assertEqual(CATALOG.count('"enum": ["%s"]' % '", "'.join(STANCES)), 2)


    def test_reaction_hooks(self):
        self.assertIn('if (combat_reaction_try(user, COMBAT_TRIGGER_INCOMING, target_zone, I))\n\t\treturn null', DEFENSE)
        self.assertIn('combat_reaction_try(attacker, COMBAT_TRIGGER_AFTER_PARRY, def_zone, damage_source)', DEFENSE)
        self.assertIn('combat_reaction_try(user, COMBAT_TRIGGER_AFTER_HIT, hit_zone, I)', DEFENSE)
        self.assertIn('if (combat_reaction_try(H, COMBAT_TRIGGER_INCOMING, tgt, null))', ATTACK_HAND)
        self.assertIn('combat_reaction_try(H, COMBAT_TRIGGER_AFTER_HIT, hit_zone, null)', ATTACK_HAND)
        self.assertIn('if (combat_reaction_try(H, COMBAT_TRIGGER_GRAB_REACH, tgt, null))', ATTACK_HAND)
        # the incoming check runs before dodging
        self.assertLess(ATTACK_HAND.index('COMBAT_TRIGGER_INCOMING, tgt, null'), ATTACK_HAND.index('if(attempt_dodge())'))

    def test_reactions_never_chain(self):
        self.assertIn('if (!attacker || attacker == src || in_combat_reaction || attacker.in_combat_reaction)', REACTIONS)
        self.assertIn('next_move = old_next_move', REACTIONS)
        self.assertIn('if (forced_attack_zone)\n\t\treturn forced_attack_zone', SOURCE)

    def test_martial_reflexes_follow_the_plan(self):
        # Student 25%, Adept 45%, Master 65%; hands free; idle; not help intent.
        self.assertIn('var/global/list/martial_reflex_chance = list(0, 0, 25, 45, 65)', REACTIONS)
        self.assertIn('if (!martial_school || a_intent == I_HELP || world.time < next_martial_reflex)', REACTIONS)
        for school, reflex in (('wing_chun', 'bong_sau'), ('pugilism', 'slip'), ('grappling', 'sprawl'), ('hard_hand', 'block_counter')):
            self.assertIn('if ("%s")' % school, REACTIONS)
            self.assertIn('return "%s"' % reflex, REACTIONS)


if __name__ == '__main__':
    unittest.main()

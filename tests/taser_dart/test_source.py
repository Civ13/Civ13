"""Source checks for issue 6977: taser darts apply stun and agony once, scaled by protection."""
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PROJECTILE = ROOT / 'code/modules/projectiles/projectile.dm'
LIVING = ROOT / 'code/game/mob/living/living_defense.dm'


class TaserDartTest(unittest.TestCase):
    def test_generic_rider_skips_taser_stun_and_agony(self):
        text = PROJECTILE.read_text(encoding='utf-8')
        start = text.index('/obj/item/projectile/proc/on_hit(')
        body = text[start:text.index('\n/obj/', start + 1)]
        self.assertIn('var/hit_stun = taser_effect ? 0 : stun', body)
        self.assertIn('var/hit_agony = taser_effect ? 0 : agony', body)
        self.assertIn('L.apply_effects(hit_stun, weaken, paralyze, irradiate, stutter, eyeblur, drowsy, hit_agony, poisonous, blocked)', body)

    def test_taser_effect_still_goes_through_stun_effect_act(self):
        text = LIVING.read_text(encoding='utf-8')
        self.assertIn('if(P.taser_effect)\n\t\tstun_effect_act(P.stun, P.agony, def_zone, P)', text)

    def test_mixing_panel_targets_the_attached_beaker_not_its_row(self):
        dartgun = (ROOT / 'code/modules/projectiles/guns/projectile/dartgun.dm').read_text(encoding='utf-8')
        panel = dartgun.split('/dartgun/ui_interact(', 1)[1].split('\n/obj/', 1)[0]
        self.assertIn('var/beaker_ref = "\\ref[B]"', panel)
        self.assertIn('panel_button("Eject", "eject", beaker_ref)', panel)
        lookup = dartgun.split('/proc/attached_beaker_with_ref(', 1)[1].split('\n/obj/', 1)[0]
        self.assertIn('B in beakers', lookup)
        self.assertIn('!QDELETED(B) && B.loc == src && "\\ref[B]" == beaker_ref', lookup)
        handler = dartgun.split('/dartgun/Topic(', 1)[1].split('\n/obj/', 1)[0]
        for verb in ('stop_mix', 'mix', 'eject'):
            self.assertIn(f'attached_beaker_with_ref(href_list["{verb}"])', handler)
        self.assertNotIn('text2num', handler)
        self.assertNotIn('beakers[index]', handler)


if __name__ == '__main__':
    unittest.main()

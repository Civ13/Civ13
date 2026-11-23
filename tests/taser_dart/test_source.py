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


if __name__ == '__main__':
    unittest.main()

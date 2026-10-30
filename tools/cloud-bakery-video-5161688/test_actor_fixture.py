"""Headless subtype lifecycle contract; no native execution."""
from pathlib import Path
import unittest
HERE=Path(__file__).resolve().parent
class ActorFixture(unittest.TestCase):
    def test_only_fixture_subtype_adapts_disconnected_sleep(self):
        s=(HERE/'changed-source/filming/scene.dm').read_text()
        a=(HERE/'changed-source/filming/actions.dm').read_text()
        self.assertIn('/mob/living/human/intro_actor/ssd_check()\n\treturn FALSE',s)
        self.assertNotIn('/mob/living/human/ssd_check()',s)
        self.assertNotIn('/mob/living/human/intro_actor/Life()',s)
        self.assertIn('bakery_baker.Life()',s);self.assertIn('bakery_customer.Life()',s)
        self.assertIn('city_courier.Life()',s);self.assertIn('city_fireman.Life()',s);self.assertIn('city_brakeman.Life()',s)
        self.assertIn('var/mob/living/human/intro_actor/H = new',a)
        self.assertIn('!H.client && !H.ckey && H.stat == CONSCIOUS',a)

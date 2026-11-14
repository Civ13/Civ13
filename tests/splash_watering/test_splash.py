"""Spilled reagents water crops only by their water share (#5302).

Projects the production splash()/splash_water_share() bodies with stub holders.
"""
from pathlib import Path
import sys
from types import SimpleNamespace as NS
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tests/primitive_woodworking'))
from source_adapter import compile_body

SOURCE = (ROOT / 'code/modules/reagents/Chemistry-Holder.dm').read_text(encoding='utf-8')
# Pre-fix splash, frozen as a negative control: every unit counted as water.
OLD_SPLASH = '''/datum/reagents/proc/splash(var/atom/target, var/amount = TRUE, copy = FALSE)

	trans_to(target, amount, 1, copy)
	if (istype(target, /turf/floor/dirt))
		for (var/obj/structure/farming/plant/P in target)
			P.water = min(P.water+amount,P.max_water)
'''
FIELDS = ('reagent_list', 'total_volume', 'trans_to', 'splash_water_share')


def project(text, signature, args, env):
    body = text[text.index(signature):]
    body = body.replace('for (var/datum/reagent/R in reagent_list)', 'for R in reagent_list:')
    body = body.replace('for (var/obj/structure/farming/plant/P in target)', 'for P in target.plants:')
    return compile_body(body, signature, args, env, FIELDS)[0]


def is_type(obj, path):
    kind = getattr(obj, 'type', '')
    return kind == path or kind.startswith(path + '/')


class Holder:
    def __init__(self, text, **volumes):
        self.reagent_list = [NS(type='/datum/reagent/' + key, volume=value) for key, value in volumes.items()]
        env = dict(istype=is_type, min=min)
        self.splash_water_share = (lambda amount: share(self, amount)) if '/proc/splash_water_share(' in text else None
        if self.splash_water_share:
            share = project(text, '/datum/reagents/proc/splash_water_share(', 'self,amount', env)
        splash = project(text, '/datum/reagents/proc/splash(', 'self,target,amount=True,copy=False', env)
        self.splash = lambda target, amount: splash(self, target, amount)

    @property
    def total_volume(self):
        return sum(r.volume for r in self.reagent_list)

    def trans_to(self, target, amount, multiplier, copy):
        fraction = min(1, amount / self.total_volume) if self.total_volume else 0
        for r in self.reagent_list:
            r.volume -= r.volume * fraction


def watered(text, amount, **volumes):
    plant = NS(water=0, max_water=100)
    dirt = NS(type='/turf/floor/dirt', plants=[plant])
    Holder(text, **volumes).splash(dirt, amount)
    return plant.water


class SplashWateringTest(unittest.TestCase):
    def test_non_water_spill_gives_no_water(self):
        self.assertEqual(watered(SOURCE, 30, ethanol=30), 0)

    def test_mixture_gives_only_its_water_share(self):
        self.assertAlmostEqual(watered(SOURCE, 30, water=10, ethanol=20), 10)
        self.assertAlmostEqual(watered(SOURCE, 15, water=10, ethanol=20), 5)

    def test_water_and_its_subtypes_still_water(self):
        self.assertAlmostEqual(watered(SOURCE, 20, water=20), 20)
        self.assertAlmostEqual(watered(SOURCE, 20, **{'water/irradiated': 20}), 20)

    def test_asking_more_than_held_credits_only_what_was_held(self):
        self.assertAlmostEqual(watered(SOURCE, 50, water=10), 10)

    def test_negative_control_old_splash_counts_everything(self):
        self.assertEqual(watered(OLD_SPLASH, 30, ethanol=30), 30)


if __name__ == '__main__':
    unittest.main()

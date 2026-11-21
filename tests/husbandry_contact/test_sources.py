"""Offline source contract for #6313, #6320, #6333, #6300 and #6305.

Behaviour is covered natively by tests/husbandry_contact/probe.dm.
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


def read(path):
    return (ROOT / path).read_text(encoding='utf-8-sig')


def body(source, header):
    return source.split(header, 1)[1].split('\n/', 1)[0]


class HusbandryContact(unittest.TestCase):
    def test_eggs_keep_polling_while_carried(self):
        birds = read('code/game/mob/living/simple_animal/friendly/birds.dm')
        for egg in ('egg', 'turkeyegg'):
            grow = body(birds, f'/obj/item/weapon/reagent_containers/food/snacks/{egg}/proc/grow()')
            pause = grow.split('\telse\n', 1)[1]
            self.assertIn('grow()', pause)

    def test_milking_limits_to_free_space(self):
        milk = body(read('code/game/mob/living/simple_animal/friendly/farm_animals.dm'),
                    '/mob/living/simple_animal/proc/try_milk(')
        self.assertIn('get_free_space()', milk)
        self.assertIn('min(rand(5,10), free)', milk)

    def test_engine_chain_checks_generation(self):
        engine = read('code/modules/1713/machinery/engines/internal_combustion.dm')
        running = body(engine, '/obj/structure/engine/internal/running()')
        self.assertIn('generation == run_generation', running)
        self.assertIn('++run_generation', body(engine, '/obj/structure/engine/internal/turn_on('))
        self.assertIn('E.start_running()', read('code/modules/1713/machinery/modular_vehicles/aircraft/aircraft_twin.dm'))

    def test_organ_embeds_are_yankable(self):
        organ = read('code/modules/organs/organ_external.dm')
        self.assertIn('LAZYDISTINCTADD(embedded_items, W)', body(organ, '/obj/item/organ/external/proc/embed('))
        self.assertIn('organ.embedded_items', body(organ, '/mob/living/human/get_visible_implants('))

    def test_contact_gets_hit_zone(self):
        self.assertIn('I.on_weapon_contact(src, user, hit_zone)',
                      read('code/game/mob/living/carbon/human/human_defense.dm'))
        self.assertIn('electrocute_act(shockpower, src, 1.0, hit_zone)',
                      read('code/modules/magic/magic_weapons.dm'))


if __name__ == '__main__':
    unittest.main()

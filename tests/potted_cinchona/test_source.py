"""Source checks for issue 6972: potting a partly eaten cinchona must not refill it."""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
POTS = ROOT / 'code/game/objects/structures/plant_pots.dm'


def block(text, header):
    start = text.index(header + '\n')
    nxt = re.search(r'^/\S', text[start + len(header) + 1:], re.M)
    return text[start:start + len(header) + 1 + nxt.start()] if nxt else text[start:]


class PottedCinchonaTest(unittest.TestCase):
    def setUp(self):
        self.text = POTS.read_text(encoding='utf-8')

    def test_trowel_handlers_return_the_recorded_plant(self):
        for path in ('/obj/structure/plant_pot/clay/light', '/obj/structure/plant_pot/medium_planter/clay/yellow'):
            handler = block(self.text, path + '/attackby(obj/item/W as obj, mob/user as mob)')
            self.assertIn('remove_potted_plant()', handler, path)
            self.assertNotIn('new filled_type(loc)', handler, path)

    def test_potting_records_remaining_quinine_before_deleting_the_plant(self):
        plant = block(self.text, '/obj/structure/plant_pot/proc/plant_cinchona(obj/item/W, mob/user)')
        self.assertLess(plant.index('record_potted_cinchona(W)'), plant.index('qdel(W)'))
        record = block(self.text, '/obj/structure/plant_pot/proc/record_potted_cinchona(obj/item/weapon/reagent_containers/food/snacks/grown/cinchona/C)')
        self.assertIn('get_reagent_amount("quinine")', record)

    def test_removal_restores_recorded_quinine(self):
        remove = block(self.text, '/obj/structure/plant_pot/proc/remove_potted_plant()')
        self.assertIn('del_reagents()', remove)
        self.assertIn('add_reagent("quinine", potted_quinine)', remove)
        self.assertIn('!isnull(potted_quinine)', remove)


if __name__ == '__main__':
    unittest.main()

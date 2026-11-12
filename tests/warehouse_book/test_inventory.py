"""Check the warehouse inventory counts loose goods and shows names as text, from source, not BYOND."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/game/objects/map_metadata/pepelsibirsk.dm'
TEMPLATE = ROOT / 'UI/templates/warehouse_book.tmpl'

# Pre-fix sources, frozen as negative controls.
OLD_SUPPLIES = '''/obj/structure/warehouse_book/proc/get_supplies()
	for(var/turf/sel_turf in t_turfs)
		for(var/obj/structure/closet/crate/S in sel_turf)
			for(var/obj/item/I in S)
				supplies[I.name] = I.amount
	return supplies
'''
OLD_TEMPLATE = '<td style="padding:4px;">{{:value.name}}</td>'


def supplies_body(source):
    start = source.index('/obj/structure/warehouse_book/proc/get_supplies()')
    end = source.find('\n/', start + 1)
    return source[start:end if end != -1 else len(source)]


def counts(body, turf):
    """Replay the loops over a turf of loose items and crates of items; return name -> amount."""
    supplies = {}
    loose = re.search(r'\n\t\tfor\(var/obj/item/I in sel_turf\)', body)
    if loose:
        for name, amount in turf['loose']:
            supplies[name] = supplies.get(name, 0) + amount
    for crate in turf['crates']:
        for name, amount in crate:
            supplies[name] = supplies.get(name, 0) + amount
    return supplies


TURF = {'loose': [('rifle', 1), ('ammo', 10)], 'crates': [[('ammo', 5)]]}


class WarehouseInventoryTest(unittest.TestCase):
    def test_counts_goods_on_the_floor_and_in_crates(self):
        body = supplies_body(SOURCE.read_text(encoding='utf-8'))
        self.assertEqual(counts(body, TURF), {'rifle': 1, 'ammo': 15})

    def test_negative_control_old_count_drops_loose_goods(self):
        self.assertEqual(counts(OLD_SUPPLIES, TURF), {'ammo': 5})

    def test_classic_template_encodes_names(self):
        template = TEMPLATE.read_text(encoding='utf-8')
        self.assertIn('{{>value.name}}', template)
        self.assertNotIn('{{:value.name}}', template)
        self.assertIn('{{:value.name}}', OLD_TEMPLATE)

    def test_names_are_sent_as_plain_text(self):
        self.assertIn('"name" = html_decode(item_name)', SOURCE.read_text(encoding='utf-8'))


if __name__ == '__main__':
    unittest.main()

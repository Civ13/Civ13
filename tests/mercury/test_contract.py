"""Mercury from cinnabar and mercury poisoning: source contract checks.

Cinnabar is an independent mining roll from the Classical age (twice as
common on mercury-belt lands) and a seam ore; the extraction kit no longer
leaches it. Open roasting gives 2 units with fumes, the retort 6 with none
while its seal holds. The burden drains 10% per hour of play and its stages
sit at 20/40/70/100.

    python3 tests/mercury/test_contract.py
"""
import json
import re
import struct
import unittest
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/modules/1713/mercury.dm').read_text(encoding='utf-8')
ORES = (ROOT / 'code/modules/1713/ores.dm').read_text(encoding='utf-8')
MINING = (ROOT / 'code/game/turfs/floor_attackby.dm').read_text(encoding='utf-8')
SEAMS = (ROOT / 'code/modules/1713/mountain_seams.dm').read_text(encoding='utf-8')
# Defines other files use live in code/__defines (tests/dme_order).
SHARED_DEFINES = (ROOT / 'code/__defines/ore_processing.dm').read_text(encoding='utf-8')
DME = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
NODES = (ROOT / 'code/modules/research_tree/research_node.dm').read_text(encoding='utf-8')
RECIPES = (ROOT / 'config/crafting/material_recipes_global.txt').read_text(encoding='utf-8')
ATLAS = json.loads((ROOT / 'scripts/atlas/resource-sources.json').read_text(encoding='utf-8'))
DMI = ROOT / 'icons/obj/mercury.dmi'
METADATA = ROOT / 'code/game/objects/map_metadata/nomads'


def dmi_description(path):
    # Stdlib only: the hosted runner has no Pillow.
    data = path.read_bytes()
    pos = 8
    while pos < len(data):
        length, kind = struct.unpack('>I4s', data[pos:pos + 8])
        body = data[pos + 8:pos + 8 + length]
        if kind in (b'zTXt', b'tEXt') and body.startswith(b'Description\0'):
            text = body[len(b'Description\0'):]
            return zlib.decompress(text[1:]).decode() if kind == b'zTXt' else text.decode()
        pos += 12 + length
    return ''


def define(name):
    match = re.search(rf'#define {name} ([0-9.]+)', SOURCE + SHARED_DEFINES)
    assert match, name
    return float(match.group(1))


class Cinnabar(unittest.TestCase):
    def test_mining_roll_is_independent(self):
        self.assertIn('mining_cinnabar(H)', MINING)
        self.assertIn('#include "code\\modules\\1713\\mercury.dm"', DME)
        self.assertIn('map.ordinal_age < 1', SOURCE)
        self.assertEqual(define('CINNABAR_RICH_CHANCE'), 2 * define('CINNABAR_CHANCE'))

    def test_mercury_belts(self):
        for name in ('nomads_asia.dm', 'nomads_europe.dm'):
            self.assertIn('cinnabar_rich = TRUE', (METADATA / name).read_text(encoding='utf-8'))
        self.assertEqual((METADATA / 'nomads_americas.dm').read_text(encoding='utf-8').count('cinnabar_rich = TRUE'), 2)

    def test_seam_entry(self):
        self.assertRegex(SEAMS, r'/obj/item/stack/ore/mercury = list\(2, 1, 1, 2\)')

    def test_extraction_kit_route_removed(self):
        block = ORES[ORES.index('/obj/item/stack/ore/mercury\n'):ORES.index('/obj/item/stack/ore/fossilskull1')]
        self.assertNotIn('add_reagent', block)
        for entry in ATLAS['mechanisms']:
            if entry.get('name') == 'Ore extraction kit':
                self.assertNotIn('/obj/item/stack/ore/mercury', entry['inputs'])
        names = {entry['name'] for entry in ATLAS['mechanisms']}
        for name in ('Mine cinnabar', 'Roast cinnabar over a fire', 'Fire a mercury retort'):
            self.assertIn(name, names)


class Yields(unittest.TestCase):
    def test_retort_triples_open_roasting(self):
        self.assertEqual(define('MERCURY_ROAST_UNITS'), 2)
        self.assertEqual(define('MERCURY_RETORT_UNITS'), 6)

    def test_gates_and_recipes(self):
        self.assertIn('crafting_node_allowed_or_warn(H, "bronze_working")', SOURCE)
        self.assertIn('crafting_node_allowed_or_warn(H, "amalgamation")', SOURCE)
        for node, prereqs, era in (('ore_dressing', '"resource_processing"', 2),
                                   ('amalgamation', '"ore_dressing","apothecary"', 3)):
            self.assertRegex(NODES, rf'research_node\("{node}", "[^"]+", "Industrial", \d+, \d+, RESEARCH_MODE_ANALYSIS, list\({re.escape(prereqs)}\), {era}\)')
        self.assertIn('"/obj/structure/workshop_machine/mercury_retort" = "amalgamation"', NODES)
        self.assertIn(',/obj/structure/workshop_machine/mercury_retort,', RECIPES)
        self.assertIn(',/obj/item/weapon/reagent_containers/glass/mercury_flask,', RECIPES)


class Burden(unittest.TestCase):
    def test_stages(self):
        self.assertEqual([define(n) for n in ('MERCURY_LOW', 'MERCURY_MODERATE', 'MERCURY_HIGH', 'MERCURY_SEVERE')], [20, 40, 70, 100])

    def test_decay_is_ten_percent_an_hour(self):
        self.assertAlmostEqual(define('MERCURY_DECAY_TICK') ** 3600, 0.9, places=4)

    def test_life_guard_and_no_stamps(self):
        life = SOURCE[SOURCE.index('/mob/living/human/Life()'):]
        life = life[:life.index('\n\n')]
        self.assertIn('if (mercury_burden > 0)', life)
        self.assertNotIn('world.time', SOURCE)

    def test_vapour_is_an_event(self):
        self.assertIn('should_save = FALSE', SOURCE)
        self.assertIn('QDEL_IN(src, 30)', SOURCE)
        self.assertIn('signal_fire_open_sky(T) ? per_person * 0.5', SOURCE)
        self.assertIn('/obj/item/clothing/mask/gas', SOURCE)

    def test_diagnosis(self):
        self.assertIn('/obj/item/weapon/doctor_handbook/diagnose_poisons(', SOURCE)
        self.assertIn('/mob/living/human/illness_summary()', SOURCE)


class Sprites(unittest.TestCase):
    def test_states(self):
        text = dmi_description(DMI)
        for state in ('flask', 'flask_full', 'retort', 'retort_fired', 'retort_cracked', 'vapour'):
            self.assertIn(f'state = "{state}"', text)
        for state in re.findall(r'icon_state = "([a-z_]+)"', SOURCE):
            self.assertIn(f'state = "{state}"', text, state)


if __name__ == '__main__':
    unittest.main()

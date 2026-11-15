"""Atlas habitat and hazard rows (#4460): source tables and reviewed hazard evidence; no DM runtime."""
import json
from pathlib import Path
import re
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts'))
from atlas.facts import declared, resource_facts
from atlas.habitats import ECOLOGY, HAZARDS, HERBS, herbs, place_rows, sea, wildlife

SEA_LIFE = 'code/modules/1713/machinery/modular_vehicles/ships/sea_life.dm'


def source(*paths):
    return {path: (ROOT / path).read_text(encoding='utf-8', errors='replace') for path in paths}


class HabitatTests(unittest.TestCase):
    def test_every_species_row_is_read(self):
        files = source(ECOLOGY)
        body = files[ECOLOGY].split('/proc/ecology_default_species()', 1)[1].split('\n)', 1)[0]
        rows = re.findall(r'^\t\teco_species\("([^"]+)"', body, re.M)
        self.assertGreater(len(rows), 30)
        found = wildlife(files)
        for name, spawned in re.findall(r'^\t\teco_species\("([^"]+)",\s*list\(([^)]*)\)', body, re.M):
            for typepath in re.findall(r'/[\w/]+', spawned):
                self.assertIn(typepath, found, f'{name}: {typepath} has no habitat row')

    def test_species_row_text(self):
        found = wildlife(source(ECOLOGY))
        self.assertEqual(found['/mob/living/simple_animal/hostile/bear/boar/polar'], 'Wild in tundra lands, on snow')
        self.assertEqual(found['/mob/living/simple_animal/deer'], 'Wild in temperate and taiga lands, on grass, dirt or snow')
        # An excluded special subtype is not this species.
        self.assertNotIn('/mob/living/simple_animal/crab/small/trilobite', found)

    def test_wild_herb_climates(self):
        found = herbs(source(HERBS))
        self.assertEqual(found['/obj/structure/wild/flowers/wild_herb/comfrey'], 'Grows wild on grass in temperate lands')
        self.assertEqual(len(found), len(re.findall(r'if \(/obj/structure/wild/flowers/wild_herb/', source(HERBS)[HERBS])))

    def test_sea_zones_inherit(self):
        types = declared(source(SEA_LIFE))
        found = sea(types)
        self.assertEqual(found['/mob/living/simple_animal/sea/kelp_turtle'], 'The sea, over the shallow shelf')
        self.assertEqual(found['/mob/living/simple_animal/sea/drift_jelly'], 'The sea, from open water to deep water')


class HazardTests(unittest.TestCase):
    def test_evidence_still_in_source(self):
        entries = json.loads(HAZARDS.read_text())['hazards']
        self.assertGreater(len(entries), 10)
        for entry in entries:
            for path, text in entry['evidence']:
                self.assertIn(text, (ROOT / path).read_text(encoding='utf-8', errors='replace'),
                              f"{entry['type']}: review the hazard again, {path} changed")

    def test_types_exist(self):
        code = '\n'.join(path.read_text(encoding='utf-8', errors='replace') for path in (ROOT / 'code').rglob('*.dm'))
        for entry in json.loads(HAZARDS.read_text())['hazards']:
            self.assertRegex(code, rf'(?m)^{re.escape(entry["type"])}[ \t]*$', entry['type'])

    def test_hazard_inherits_but_nearest_wins(self):
        files = {'code/a.dm': '/mob/living/simple_animal/hostile/poison/snake\n\tname = "snake"\n'
                              '/mob/living/simple_animal/hostile/poison/snake/cobra\n\tname = "cobra"\n'
                              '/mob/living/simple_animal/hostile/poison/snake/constrictor\n\tname = "boa"\n'}
        rows = place_rows(files, declared(files))
        cobra = dict(rows['/mob/living/simple_animal/hostile/poison/snake/cobra'])
        boa = dict(rows['/mob/living/simple_animal/hostile/poison/snake/constrictor'])
        self.assertIn('venomous', cobra['Hazard'])
        self.assertIn('Wraps around', boa['Hazard'])

    def test_rows_reach_resource_pages(self):
        files = {'code/a.dm': '/turf/floor/lava\n\tname = "lava"\n\tdesc = "Hot."\n'}
        entry = resource_facts(files, {'/turf/floor/lava': '/turf/floor/lava'})['/turf/floor/lava']
        self.assertIn('Hazard', dict(entry['stats']))


if __name__ == '__main__':
    unittest.main()

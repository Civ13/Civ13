"""Peoples of the Nomads lands: the origin table stays consistent with the
languages, name generators and colour tables it points at. Offline only."""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ORIGINS = (ROOT / 'code/game/mob/living/carbon/human/origins.dm').read_text()
SPAWN = (ROOT / 'code/game/mob/living/carbon/human/nomads_spawn.dm').read_text()
CLIMATES = {'tundra', 'taiga', 'temperate', 'semiarid', 'sea', 'desert', 'savanna', 'jungle'}


def dm_list(text):
    return re.findall(r'"([^"]+)"', text)


def origins():
    found = {}
    for block in re.split(r'\n(?=/datum/origin/)', ORIGINS)[1:]:
        block = block.split('\nvar/global')[0]
        fields = dict(re.findall(r'^\t(\w+) = (.+)$', block, re.M))
        found[fields['id'].strip('"')] = fields
    return found


def tables():
    body = ORIGINS[ORIGINS.index('/proc/land_origin_tables()'):ORIGINS.index('/proc/land_has_origins')]
    named = {}
    for name, rows in re.findall(r'var/list/(\w+) = list\((.*?)\)\n', body, re.S):
        named[name] = dict(re.findall(r'"(\w+)" = "(\w+)"', rows))
    lands = dict(re.findall(r'(MAP_\w+) = (\w+)', body[body.index('tables = list('):]))
    return named, lands


class OriginTable(unittest.TestCase):
    def test_every_people_points_at_real_data(self):
        languages = set(re.findall(r'^\s*name\s*=\s*"([^"]+)"', (ROOT / 'code/game/mob/language/earth.dm').read_text(), re.M))
        species = (ROOT / 'code/game/mob/living/carbon/human/species/species.dm').read_text()
        colours = (ROOT / 'code/_helpers/global_lists.dm').read_text()
        hair = set(dm_list(colours[colours.index('var/list/hair_colors'):colours.index('var/list/eye_colors')])[::2])
        eyes = set(dm_list(colours[colours.index('var/list/eye_colors'):colours.index('var/global/list/global_mutations')])[::2])
        people = origins()
        self.assertGreaterEqual(len(people), 20)
        names = [f['name'] for f in people.values()]
        self.assertEqual(len(names), len(set(names)))
        for oid, f in people.items():
            self.assertIn(f['language'].strip('"'), languages, oid)
            self.assertIn('/datum/species/proc/get_random_%s_name(' % f['name_style'].strip('"'), species, oid)
            self.assertTrue(set(dm_list(f['hair'])) <= hair, oid)
            self.assertTrue(set(dm_list(f['eyes'])) <= eyes, oid)
            light, dark = [int(n) for n in re.findall(r'-?\d+', f['skin'])]
            self.assertTrue(0 >= light > dark >= -185, oid)

    def test_every_land_covers_every_climate(self):
        people = origins()
        named, lands = tables()
        for land in ('MAP_NOMADS_GAIA', 'MAP_NOMADS_EUROPE', 'MAP_NOMADS_AFRICA', 'MAP_NOMADS_ASIA',
                     'MAP_NOMADS_AMERICAS_NORTH', 'MAP_NOMADS_AMERICAS_SOUTH', 'MAP_NOMADS_JUNGLE',
                     'MAP_NOMADS_DESERT'):
            self.assertIn(land, lands)
        for land, table_name in lands.items():
            table = named[table_name]
            self.assertIn('default', table, land)
            self.assertTrue(set(table) - {'default'} <= CLIMATES, land)
            for origin_id in table.values():
                self.assertIn(origin_id, people, land)

    def test_the_americas_have_their_own_peoples(self):
        named, lands = tables()
        gaia = set(named[lands['MAP_NOMADS_GAIA']].values())
        for land in ('MAP_NOMADS_AMERICAS_NORTH', 'MAP_NOMADS_AMERICAS_SOUTH'):
            self.assertFalse(set(named[lands[land]].values()) & gaia, land)

    def test_spawn_uses_the_table_and_records_the_origin(self):
        self.assertIn('else if (map && land_has_origins(map.ID))\n\t\tchoose_origin(mob_area ? mob_area.climate : null)', SPAWN)
        for retired in ('MAP_NOMADS_EUROPE', 'MAP_NOMADS_AFRICA', 'MAP_NOMADS_ASIA', 'MAP_NOMADS_GAIA'):
            self.assertNotIn(retired, SPAWN)
        apply = ORIGINS[ORIGINS.index('/mob/living/human/proc/apply_origin'):]
        self.assertLess(apply.index('origin_id = O.id'), apply.index('if (keep_setup)'))
        self.assertLess(apply.index('if (keep_setup)'), apply.index('update_character_appearance'))
        choose = ORIGINS[ORIGINS.index('/mob/living/human/proc/choose_origin'):ORIGINS.index('/mob/living/human/proc/apply_origin')]
        # Nobody without a keyboard is asked anything, and a second call is a no-op.
        self.assertIn('if (!map || origin_id)\n\t\treturn FALSE', choose)
        self.assertLess(choose.index('if (client)'), choose.index('WWinput'))

    def test_inuktitut_survives_the_hearing_capitalisation(self):
        earth = (ROOT / 'code/game/mob/language/earth.dm').read_text()
        self.assertIn('name = "Inuktitut"', earth)
        self.assertNotIn('name = "inuktitut"', earth)


if __name__ == '__main__':
    unittest.main()

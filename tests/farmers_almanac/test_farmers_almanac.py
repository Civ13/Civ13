"""Farmer's almanac source projection: its weather table and crop rule must
match the production weather and farming code. Stdlib only; no BYOND runtime."""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ALMANAC = (ROOT / 'code/modules/1713/farmers_almanac.dm').read_text(encoding='utf-8')
WEATHER = (ROOT / 'code/modules/1713/weather.dm').read_text(encoding='utf-8')
FARMING = (ROOT / 'code/game/objects/farming.dm').read_text(encoding='utf-8')
SEASONS = ('WINTER', 'SPRING', 'SUMMER', 'FALL', 'Wet Season', 'Dry Season')
CLIMATES = ('tundra', 'taiga', 'temperate', 'sea', 'semiarid', 'desert', 'savanna', 'jungle')


def body(source, signature):
    start = source.index(signature)
    end = re.search(r'\n(?=/)', source[start + len(signature):])
    return source[start:start + len(signature) + (end.start() if end else len(source))]


def blocks(text, indent):
    """Split text at `if (...)` / `else` lines of exactly `indent` tabs."""
    pattern = re.compile(r'^' + '\t' * indent + r'(if \((.*)\)|else)\s*$', re.M)
    found = list(pattern.finditer(text))
    for index, match in enumerate(found):
        end = found[index + 1].start() if index + 1 < len(found) else len(text)
        labels = re.findall(r'"([^"]*)"|(WEATHER_\w+)', match.group(2) or '')
        yield [a or b for a, b in labels] or ['else'], text[match.end():end]


def production_weather():
    """(climate, season) -> (wet icon, storm icon) from apply_area_weather()."""
    source = body(WEATHER, '/proc/apply_area_weather(var/area/caribbean/A)')
    table = {}
    for climates, climate_text in blocks(source, 2):
        for seasons, season_text in blocks(climate_text, 4):
            icons = {}
            weathers = list(blocks(season_text, 6))
            if not weathers:  # no inner switch: one outcome for every weather
                icon = re.search(r'A\.icon_state = "([^"]*)"', season_text).group(1)
                icons = {'WEATHER_WET': icon, 'WEATHER_EXTREME': icon}
            for names, weather_text in weathers:
                icon = re.search(r'A\.icon_state = "([^"]*)"', weather_text).group(1)
                for name in names:
                    icons[name] = icon
                if names == ['else']:
                    icons.setdefault('WEATHER_WET', icon)
                    icons.setdefault('WEATHER_EXTREME', icon)
            for climate in climates:
                for season in seasons:
                    table[(climate, season)] = (icons['WEATHER_WET'], icons['WEATHER_EXTREME'])
    return table


def production_temperatures():
    source = body(WEATHER, '/proc/get_temp(var/atom/A)')
    source = source[:source.index('\tswitch (time_of_day)')]
    table = {}
    for seasons, season_text in blocks(source, 2):
        flat = re.search(r'loc_temp = (-?\d+)', season_text)
        per_climate = {names[0]: int(re.search(r'loc_temp = (-?\d+)', text).group(1))
                       for names, text in blocks(season_text, 4)}
        for season in seasons:
            for climate in CLIMATES:
                table[(climate, season)] = per_climate[climate] if per_climate else int(flat.group(1))
    return table


def almanac_table():
    table = {}
    section = ALMANAC[ALMANAC.index('var/global/list/farmers_almanac_climates'):]
    section = section[:section.index('\n\n')]
    climate = None
    for line in section.splitlines():
        heading = re.match(r'\t"(\w+)" = list\($', line)
        if heading:
            climate = heading.group(1)
            continue
        row = re.match(r'\t\t"([^"]+)" = list\((-?\d+), "([^"]*)", "([^"]*)"\)', line)
        if row:
            table[(climate, row.group(1))] = (int(row.group(2)), row.group(3), row.group(4))
    return table


class FarmersAlmanacTests(unittest.TestCase):
    def test_weather_table_matches_production_weather_and_temperatures(self):
        weather, temperatures, almanac = production_weather(), production_temperatures(), almanac_table()
        expected = {(c, s): (temperatures[(c, s)],) + weather[(c, s)] for c in CLIMATES for s in SEASONS}
        self.assertEqual(len(expected), 48)
        self.assertEqual(almanac, expected)

    def test_climate_map_list_matches_crop_growth(self):
        growth = FARMING[FARMING.index('var/currcl = a.climate'):]
        growth_maps = re.search(r'list\((MAP_[^)]*)\)\.Find\(map\.ID\)', growth).group(1)
        almanac_maps = re.search(r'map\.ID in list\((MAP_[^)]*)\)', ALMANAC).group(1)
        self.assertEqual(sorted(growth_maps.replace(' ', '').split(',')),
                         sorted(almanac_maps.replace(' ', '').split(',')))
        # The tropical season exemption is the same set crop growth uses.
        self.assertIn('if (list("jungle", "desert", "savanna").Find(currcl))', growth)
        self.assertIn('(climate in list("jungle", "desert", "savanna"))', ALMANAC)

    def test_crafting_is_gated_by_farming_skill_and_registered(self):
        stack = (ROOT / 'code/game/objects/items/stacks/stack.dm').read_text(encoding='utf-8')
        gate = stack[stack.index('findtext(recipe.title, "farmer\'s almanac")'):]
        self.assertIn('H.getStatCoeff("farming") < GET_MIN_STAT_COEFF(STAT_HIGH)', gate.split('else if')[0])
        recipes = (ROOT / 'config/crafting/material_recipes_global.txt').read_text(encoding='utf-8')
        rows = [line for line in recipes.splitlines() if '/obj/item/weapon/farmers_almanac,' in line]
        self.assertEqual(len(rows), 1)
        self.assertEqual(len(rows[0].replace('RECIPE: ', '').split(',')), 13)
        self.assertIn("farmer's almanac", rows[0])
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
        self.assertEqual(dme.count('#include "code\\modules\\1713\\farmers_almanac.dm"'), 1)
        research = (ROOT / 'code/modules/research_tree/research_node.dm').read_text(encoding='utf-8')
        self.assertIn('"/obj/item/weapon/farmers_almanac" = "basic_agriculture"', research)


if __name__ == '__main__':
    unittest.main()

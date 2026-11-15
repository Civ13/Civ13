"""Season names are defines, and scheme-aware questions are helpers.

Two season schemes share the global `season`: SPRING/SUMMER/FALL/WINTER and
the wet/dry seasons. Code compared raw strings, so a check written for spring
could silently skip wet-season maps. The names now live in
code/__defines/seasons.dm (with the saved string values unchanged) and
code/_helpers/seasons.dm answers "is it the four-season cycle" and "is it
wet". Raw name comparisons only go down.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
NAMES = {'SEASON_SPRING': 'SPRING', 'SEASON_SUMMER': 'SUMMER', 'SEASON_FALL': 'FALL',
         'SEASON_WINTER': 'WINTER', 'SEASON_WET': 'Wet Season', 'SEASON_DRY': 'Dry Season'}
RAW = re.compile(r'(?:^|[^_a-zA-Z0-9])(?:[A-Za-z_]+\.)?season ?(?:==|!=|=) ?"(?:SPRING|SUMMER|FALL|WINTER|Wet Season|Dry Season)"')
# global.dm compiles before the defines, so its initial value stays a literal.
# The others are source-pinned by tests/season_flow and tests/floor_decal_tracking.
ALLOWED = {'code/global.dm': 1, 'code/game/objects/map_metadata/_map_metadata.dm': 4,
           'code/game/objects/map_metadata/nomads/nomads_asia.dm': 1, 'code/modules/1713/roundstart_etc.dm': 10}
RAW_CEILING = 0


class SeasonHelpersTest(unittest.TestCase):
    def test_defines_keep_the_saved_strings(self):
        text = (ROOT / 'code/__defines/seasons.dm').read_text(encoding='utf-8')
        for define, value in NAMES.items():
            self.assertIn(f'#define {define} "{value}"', text)

    def test_helpers_cover_both_schemes(self):
        text = (ROOT / 'code/_helpers/seasons.dm').read_text(encoding='utf-8')
        self.assertIn('/proc/season_is_temperate()\n\treturn season == SEASON_SPRING || season == SEASON_SUMMER '
                      '|| season == SEASON_FALL || season == SEASON_WINTER\n', text)
        self.assertIn('/proc/season_is_wet()\n\treturn season == SEASON_SPRING || findtext(season, "Wet")\n', text)

    def test_rain_soaks_ground_for_mud_and_oil_fires(self):
        text = (ROOT / 'code/_helpers/seasons.dm').read_text(encoding='utf-8')
        self.assertIn('/proc/rain_soaks_ground(area/A)\n'
                      '\tif (!A || !(A.climate in list("semiarid", "jungle", "desert", "savanna")))\n'
                      '\t\treturn TRUE\n\treturn season == SEASON_WINTER || season_is_wet()\n', text)
        # Mud and oil fires share the rule; the oil-fire check used to be
        # `climate != a || climate != b ...`, which was always true.
        self.assertIn('if (rain_soaks_ground(F_area))', (ROOT / 'code/game/mob/mob_movement.dm').read_text(encoding='utf-8'))
        self.assertIn('if (rain_soaks_ground(A))', (ROOT / 'code/modules/1713/oil_fires.dm').read_text(encoding='utf-8'))

    def test_raw_season_names_only_go_down(self):
        extra = []
        for path in (ROOT / 'code').rglob('*.dm'):
            rel = str(path.relative_to(ROOT))
            count = len(RAW.findall(path.read_text(encoding='utf-8', errors='replace')))
            if count > ALLOWED.get(rel, 0):
                extra.append(f'{rel}: {count}')
        self.assertLessEqual(len(extra), RAW_CEILING, extra)


if __name__ == '__main__':
    unittest.main()

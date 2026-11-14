"""Faction HUD icons are chosen per map, not in human Life code.

code/_helpers/faction_hud.dm picks a player's faction icon: job rules first,
then the map (its `faction_hud_icons` list or faction_hud_icon() override),
then the faction's era default. The icons each map lists are frozen here so a
move or typo shows up, and human_life.dm may not grow map checks again.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
MAPS = ROOT / 'code/game/objects/map_metadata'
LIFE = ROOT / 'code/game/mob/living/carbon/human/human_life.dm'
HELPER = ROOT / 'code/_helpers/faction_hud.dm'
LISTED = re.compile(r'^/obj/map_metadata/([\w/]+)/faction_hud_icons = list\((.*)\)$', re.M)
FROZEN = {
    'twotribes': {'BRITISH': 'civ1', 'FRENCH': 'civ3'},
    'east_los_santos': {'INDIANS': 'ballas', 'AMERICAN': 'civ2'},
    'arab_town': {'ARAB': 'hez_basic', 'AMERICAN': 'idf_basic'},
    'whiterun': {'ROMAN': 'empire', 'CIVILIAN': 'stormcloak'},
    'clash': {'NORWEGIAN': 'ger0_basic', 'DANISH': 'barbarian_basic'},
    'yeltsin': {'RUSSIAN': 'ru_basic', 'CIVILIAN': 'sov_basic'},
    'grozny': {'RUSSIAN': 'ru_basic'},
    'operation_falcon': {'RUSSIAN': 'ru_basic'},
    'vadso_city': {'RUSSIAN': 'ru_basic'},
    'landing_at_constantinopoli': {'RUSSIAN': 'ru_basic'},
    'tantiveiv': {'AMERICAN': 'imp_basic', 'CIVILIAN': 'rebel_basic'},
    'retreat': {'CHINESE': 'sov_basic'},
    'capitol_hill': {'CIVILIAN': 'civ1'},
    'tadojsville': {'CIVILIAN': 'un'},
    'tsaritsyn': {'CIVILIAN': 'sov_basic'},
    'long_march': {'CIVILIAN': 'sov_basic'},
    'eft_factory': {'RUSSIAN': 'none', 'AMERICAN': 'none', 'CIVILIAN': 'none'},
    'bank_robbery': {'RUSSIAN': 'robbers'},
    'drug_bust': {'RUSSIAN': 'rednikov'},
}
OVERRIDES = ('african_warlords', 'syria', 'nationsrp/coldwar', 'wizard_boy', 'gulag13', 'bank_robbery', 'drug_bust')
LIFE_ICON_CEILING = 4  # the Occupation civilian blanks


class FactionHudTest(unittest.TestCase):
    def test_map_icon_lists_are_frozen(self):
        found = {}
        for path in MAPS.rglob('*.dm'):
            for m in LISTED.finditer(path.read_text(encoding='utf-8', errors='replace')):
                found[m.group(1)] = dict(re.findall(r'(\w+) = "([^"]*)"', m.group(2)))
        self.assertEqual(found, FROZEN)

    def test_conditional_maps_override_the_proc(self):
        text = '\n'.join(p.read_text(encoding='utf-8', errors='replace') for p in MAPS.rglob('*.dm'))
        for path in OVERRIDES:
            self.assertIn(f'/obj/map_metadata/{path}/faction_hud_icon(mob/living/human/H, faction_flag)', text)

    def test_map_decides_before_the_era_default(self):
        text = HELPER.read_text(encoding='utf-8')
        body = text[text.index('/proc/faction_hud_icon_state('):text.index('/proc/default_faction_hud_icon(')]
        self.assertLess(body.index('map.faction_hud_icon(H, faction_flag)'), body.index('default_faction_hud_icon(H, faction_flag)'))
        default = text[text.index('/proc/default_faction_hud_icon('):]
        self.assertNotIn('map.ID', default)
        self.assertNotIn('istype(map', default)

    def test_life_code_has_no_per_map_icons(self):
        text = LIFE.read_text(encoding='utf-8')
        start = text.index('/mob/living/human/proc/handle_hud_list()')
        body = text[start:text.index('\n/mob/', start + 1)]
        self.assertIn('var/faction_icon = faction_hud_icon_state(src)', body)
        self.assertIn('map.add_faction_hud_overlays(src, holder2)', body)
        self.assertLessEqual(body.count('holder2.icon_state = "'), LIFE_ICON_CEILING)


if __name__ == '__main__':
    unittest.main()

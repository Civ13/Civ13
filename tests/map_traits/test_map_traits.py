"""Map traits replace copied lists of map IDs in shared code.

Shared code used to repeat `map.ID == MAP_TRIBES || map.ID == MAP_THREE_TRIBES
|| map.ID == MAP_FOUR_KINGDOMS` (and the NationsRP and campaign lists). Each
map now sets `tribes`, `nationsrp` or `campaign` in its own file. This test
checks every trait covers exactly the maps the old lists named, and that the
full lists do not come back. The CAMPAIGN_MAP_LIST_* macros are gone: one of
them was used as a bare string in radio.dm and was always true.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
TRAITS = {
    'tribes': {'MAP_TRIBES', 'MAP_THREE_TRIBES', 'MAP_FOUR_KINGDOMS'},
    'nationsrp': {'MAP_NATIONSRP', 'MAP_NATIONSRPMED', 'MAP_NATIONSRP_COLDWAR', 'MAP_NATIONSRP_COLDWAR_CMP',
                  'MAP_NATIONSRP_TRIPLE', 'MAP_NATIONSRP_WW2'},
    'campaign': {'MAP_CAMPAIGN', 'MAP_CAMPAIGN_NEW', 'MAP_CAMPAIGN_1A', 'MAP_CAMPAIGN_1B', 'MAP_CAMPAIGN_2A',
                 'MAP_CAMPAIGN_2B', 'MAP_CAMPAIGN_3A', 'MAP_CAMPAIGN_3B', 'MAP_CAMPAIGN_4A', 'MAP_CAMPAIGN_4B'},
}
# Byte-pinned by tests/dictionary; they keep the old tribes list until that pin moves.
PINNED = {'code/game/mob/living/carbon/human/say.dm', 'code/game/mob/living/carbon/human/whisper.dm'}
LISTED = {'tribes': TRAITS['tribes'], 'nationsrp': TRAITS['nationsrp']}


def map_types():
    """type path -> {var: value} for every /obj/map_metadata block."""
    types = {}
    for path in (ROOT / 'code').rglob('*.dm'):
        text = path.read_text(encoding='utf-8', errors='replace')
        for match in re.finditer(r'^(/obj/map_metadata(?:/[\w]+)*)\r?\n((?:\t[^\n]*\n|\r?\n)*)', text, re.M):
            fields = types.setdefault(match.group(1), {})
            for var, value in re.findall(r'^\t(\w+) = ([^\n]+?)\s*$', match.group(2), re.M):
                fields[var] = value
    return types


def resolved(types, path, var):
    while path:
        if var in types.get(path, {}):
            return types[path][var]
        path = path.rsplit('/', 1)[0] if path.count('/') > 2 else None
    return None


class MapTraitsTest(unittest.TestCase):
    def test_traits_cover_exactly_the_old_lists(self):
        types = map_types()
        for trait, expected in TRAITS.items():
            ids = {resolved(types, path, 'ID') for path in types if resolved(types, path, trait) == 'TRUE'}
            self.assertEqual(ids, expected, trait)

    def test_traits_are_declared_off_by_default(self):
        meta = (ROOT / 'code/game/objects/map_metadata/_map_metadata.dm').read_text(encoding='utf-8')
        for trait in TRAITS:
            self.assertRegex(meta, r'\n\tvar/' + trait + r' = FALSE')

    def test_full_id_lists_do_not_come_back(self):
        found = []
        for path in (ROOT / 'code').rglob('*.dm'):
            if str(path.relative_to(ROOT)) in PINNED:
                continue
            for number, line in enumerate(path.read_text(encoding='utf-8', errors='replace').split('\n'), 1):
                named = set(re.findall(r'ID [!=]=\s*(MAP_[A-Z0-9_]+)', line))
                for trait, members in LISTED.items():
                    if members <= named:
                        found.append(f'{path.relative_to(ROOT)}:{number} {trait}')
                if 'CAMPAIGN_MAP_LIST_' in line:
                    found.append(f'{path.relative_to(ROOT)}:{number} campaign macro')
        self.assertEqual(found, [])


if __name__ == '__main__':
    unittest.main()

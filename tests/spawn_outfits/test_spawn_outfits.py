"""Starting clothes on lands with peoples follow the people and the era.

Source contracts for code/modules/1713/jobs/spawn_outfits.dm and its hook in
give_clothes(). Offline only; never launches BYOND.
"""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUTFITS = (ROOT / 'code/modules/1713/jobs/spawn_outfits.dm').read_text().replace('\r\n', '\n')
NOMADS = (ROOT / 'code/modules/1713/jobs/nomads.dm').read_text(encoding='utf-8-sig').replace('\r\n', '\n')
ORIGINS = (ROOT / 'code/game/mob/living/carbon/human/origins.dm').read_text()
STONEAGE = (ROOT / 'code/modules/1713/apparel_stoneage.dm').read_text()
ERAS = range(0, 10)  # 0 Stone Age ... 9 Digital (LATEST_ORDINAL_AGE)
SLOTS = {'under', 'under_f', 'head', 'head_f', 'shoes', 'shoes_f'}

TOKEN = re.compile(r'\s*(?:(list)\(|("[^"]*")|(/[\w/]+)|(\w+)|(\()|(\))|(,)|(=))')


def parse(text):
    """Parse a DM list(...) expression into Python dicts, lists and strings.
    Paths become strings starting with '/', variables become ('var', name)."""
    tokens = []
    pos = 0
    text = re.sub(r'//[^\n]*', '', text)
    while pos < len(text):
        if text[pos:].strip() == '':
            break
        m = TOKEN.match(text, pos)
        if not m:
            raise ValueError('cannot parse at %r' % text[pos:pos + 40])
        pos = m.end()
        kinds = ('list', 'str', 'path', 'word', '(', ')', ',', '=')
        for kind, value in zip(kinds, m.groups()):
            if value is not None:
                tokens.append((kind, value))
                break
    tokens.reverse()

    def value():
        kind, tok = tokens.pop()
        if kind == 'list':
            items, keyed = [], {}
            while tokens[-1][0] != ')':
                v = value()
                if tokens[-1][0] == '=':
                    tokens.pop()
                    keyed[v.strip('"')] = value()
                else:
                    items.append(v)
                if tokens[-1][0] == ',':
                    tokens.pop()
            tokens.pop()
            if keyed and items:
                raise ValueError('mixed list')
            return keyed if keyed else items
        if kind == 'str':
            return tok
        if kind == 'path':
            return tok
        if kind == 'word':
            return None if tok == 'null' else ('var', tok)
        raise ValueError('unexpected %r' % tok)

    result = value()
    return result


def proc_body(source, name):
    start = source.index('\n' + name + '(') + 1
    end = re.search(r'\n(?=[^\s#])', source[start + 1:])
    return source[start:start + 1 + end.start()] if end else source[start:]


def dress_styles():
    body = proc_body(OUTFITS, '/proc/origin_dress_styles')
    expr = body[body.index('list('):body.index('\n\treturn styles')]
    return {k: v.strip('"') for k, v in parse(expr).items()}


def outfit_table():
    body = proc_body(OUTFITS, '/proc/spawn_outfit_table')
    shared = {}
    for name, expr in re.findall(r'\t\tvar/list/(\w+) = (list\(.*?\))\n(?=\t\t(?:var/|//|table))', body, re.S):
        shared[name] = parse(expr)
    expr = body[body.index('table = list(') + len('table = '):body.index('\n\treturn table')]
    table = parse(expr)

    def resolve(v):
        if isinstance(v, tuple):
            return resolve(shared[v[1]])
        if isinstance(v, dict):
            return {k: resolve(x) for k, x in v.items()}
        if isinstance(v, list):
            return [resolve(x) for x in v]
        return v
    return resolve(table), shared


def era_pick(by_era, age):
    """Mirror of code/_helpers/era.dm era_pick()."""
    if str(age) in by_era:
        return by_era[str(age)]
    best, best_from = None, -1
    for key, v in by_era.items():
        if key.endswith('+') and best_from < int(key[:-1]) <= age:
            best, best_from = v, int(key[:-1])
    return best


def outfit_for(table, styles, origin_id, age):
    style = table.get(styles.get(origin_id))
    outfit = era_pick(style, age) if style else None
    return outfit or era_pick(table['common'], age) or table['common']['0']


def paths_in(outfit):
    for slot, choice in outfit.items():
        for p in (choice if isinstance(choice, list) else [choice]):
            if p is not None:
                yield slot, p


def defined_clothing():
    found = set()
    for f in (ROOT / 'code').rglob('*.dm'):
        for line in f.read_text(encoding='latin-1').splitlines():
            if line.startswith('/obj/item/clothing/'):
                found.add(line.split('//')[0].strip().split('(')[0].split(' ')[0])
    return found


class SpawnOutfitTable(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.table, cls.shared = outfit_table()
        cls.styles = dress_styles()
        cls.origins = re.findall(r'^\tid = "(\w+)"', ORIGINS, re.M)

    def test_every_people_has_a_style_with_a_stone_age_outfit(self):
        self.assertGreaterEqual(len(self.origins), 20)
        for origin in self.origins:
            self.assertIn(origin, self.styles, origin)
            self.assertIn(self.styles[origin], self.table, origin)
        for name, style in self.table.items():
            self.assertIn('0', style, name)

    def test_every_people_is_dressed_in_every_era(self):
        for origin in self.origins + [None]:
            for age in ERAS:
                outfit = outfit_for(self.table, self.styles, origin, age)
                self.assertIsInstance(outfit, dict, (origin, age))
                self.assertTrue(outfit.get('under'), (origin, age))
                self.assertTrue(set(outfit) <= SLOTS, (origin, age))

    def test_outfits_use_real_plain_clothing(self):
        known = defined_clothing()
        for name, style in self.table.items():
            for era, outfit in style.items():
                for slot, path in paths_in(outfit):
                    self.assertIn(path, known, (name, era, path))
                    self.assertTrue(path.startswith('/obj/item/clothing/' + {'under': 'under/', 'head': 'head/', 'shoes': 'shoes/'}[slot.split('_')[0]]), (name, era, path))
                    # Basic gear only: no armour, helmets, storage or armoured sandals.
                    for banned in ('/armor', '/helmet', '/storage', '/roman', '/greek', '/medieval/knight', 'jackboots'):
                        self.assertNotIn(banned, path, (name, era, path))

    def test_stone_age_is_hides_and_leaves(self):
        for origin in self.origins + [None]:
            outfit = outfit_for(self.table, self.styles, origin, 0)
            for slot, path in paths_in(outfit):
                self.assertIn('\n%s\n' % path, STONEAGE, (origin, path))
                self.assertFalse(slot.startswith('shoes'), origin)

    def test_peoples_differ_by_region(self):
        def under(origin, age):
            return outfit_for(self.table, self.styles, origin, age)['under']
        # Early eras dress each region its own way...
        self.assertNotEqual(under('zulu', 0), under('northmen', 0))
        self.assertNotEqual(under('cherokee', 0), under('northmen', 0))
        self.assertNotEqual(under('tupi', 0), under('inca', 0))
        self.assertNotEqual(under('han', 2), under('latins', 2))
        self.assertNotEqual(under('aztecs', 2), under('egyptians', 2))
        self.assertNotEqual(under('yamato', 1), under('gaels', 1))
        # ... and the modern eras share everyday clothes.
        self.assertEqual(under('han', 8), under('latins', 8))
        self.assertEqual(under('northmen', 5), under('zulu', 5))

    def test_clothes_advance_with_the_era(self):
        for origin in ('northmen', 'latins', 'han', 'aztecs', 'arabs', 'cherokee'):
            self.assertNotEqual(outfit_for(self.table, self.styles, origin, 0)['under'],
                                outfit_for(self.table, self.styles, origin, 2)['under'], origin)
            self.assertNotEqual(outfit_for(self.table, self.styles, origin, 2)['under'],
                                outfit_for(self.table, self.styles, origin, 6)['under'], origin)


class SpawnOutfitHooks(unittest.TestCase):
    def test_lands_with_peoples_use_the_table(self):
        give = NOMADS[NOMADS.index('/mob/living/human/proc/give_clothes()'):NOMADS.index('/mob/living/human/proc/give_era_clothes()')]
        self.assertIn('var/land_outfit = map && land_has_origins(map.ID)\n\tif (!land_outfit)\n\t\tgive_era_clothes()', give)
        # Dressed once the newcomer stands on the land, before the coat.
        delayed = give[give.index('\tspawn(5)\n\t\tvar/area/mob_area = get_area(src)'):]
        self.assertLess(delayed.index('give_land_clothes(mob_area)'), delayed.index('if (spawn_area_is_cold(mob_area))'))
        self.assertIn('/mob/living/human/proc/give_era_clothes()\n\tswitch (map.ordinal_age)', NOMADS)
        # Chad mode keeps its own leaves before any of this.
        self.assertLess(give.index('if (map.chad_mode)'), give.index('land_outfit'))

    def test_cold_places_keep_fur_boots(self):
        land = proc_body(OUTFITS, '/mob/living/human/proc/give_land_clothes')
        self.assertIn('if (key == "shoes" && spawn_area_is_cold(A))\n\t\t\tcontinue', land)
        self.assertIn('O = land_origin_for(map.ID, A ? A.climate : null)', land)
        cold = proc_body(OUTFITS, '/proc/spawn_area_is_cold')
        for climate in ('"tundra"', '"taiga"', 'season == SEASON_WINTER', 'MAP_NOMADS_ICE_AGE'):
            self.assertIn(climate, cold)

    def test_file_is_compiled_after_origins_and_era_helpers(self):
        dme = (ROOT / 'civ13.dme').read_text()
        self.assertIn('#include "code\\modules\\1713\\jobs\\spawn_outfits.dm"', dme)


if __name__ == '__main__':
    unittest.main()

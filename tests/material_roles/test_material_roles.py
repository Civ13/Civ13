"""Material properties and part roles (docs/material-roles.md).

code/modules/materials/material_properties.dm gives every material the same
physical properties; code/modules/materials/part_roles.dm turns them into a
rating for one job. This suite reads both files and mirrors
/datum/part_role/rate() in Python.

- Every named material has every property, and steel is 100 on each scale.
- The older weapon and structure numbers (hardness, weight, integrity) are
  frozen in legacy_values.json: adding properties must not move them.
- FROZEN_RATINGS pins a sample of ratings, so a changed formula or value is
  a deliberate edit here too.
- BEATS_STANDARD is the balance rule: only the listed materials may outperform
  a role's standard material. A new material that turns out better than the
  standard fails until someone decides that is intended.
"""
from pathlib import Path
import json
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
MATERIALS = ROOT / 'code/modules/materials/materials.dm'
PROPERTIES = ROOT / 'code/modules/materials/material_properties.dm'
ROLES = ROOT / 'code/modules/materials/part_roles.dm'
DEFINES = ROOT / 'code/__defines/material_roles.dm'
LEGACY = Path(__file__).with_name('legacy_values.json')

NUMBERS = ('density', 'firmness', 'toughness', 'wear', 'heat_limit', 'corrosion', 'conductivity', 'spring')
FLAGS = ('flammable', 'magnetic', 'sparks', 'toxic')


def strip_comments(text):
    text = re.sub(r'/\*.*?\*/', '', text, flags=re.S)
    return re.sub(r'//[^\n]*', '', text)


def type_blocks(text, root):
    """{type path: {var: raw value}} for top-level type blocks under root."""
    blocks, current = {}, None
    for line in strip_comments(text).replace('\r', '').split('\n'):
        head = re.match(r'^(' + re.escape(root) + r'(?:/[A-Za-z_]+)*)\s*$', line)
        if head:
            current = blocks.setdefault(head[1], {})
            continue
        if line and not line[0].isspace():
            current = None
            continue
        var = re.match(r'^\t(?:var/(?:list/)?)?([a-z_]+)\s*=\s*(.+?)\s*$', line)
        if current is not None and var:
            current[var[1]] = var[2]
    return blocks


def inherited(blocks, path, var):
    while path:
        if var in blocks.get(path, {}):
            return blocks[path][var]
        path = path.rsplit('/', 1)[0]
    return None


def number(raw):
    return {'TRUE': 1, 'FALSE': 0}.get(raw, None) if raw in ('TRUE', 'FALSE') else float(raw)


def load_materials():
    names = type_blocks(MATERIALS.read_text(encoding='utf-8', errors='ignore'), '/material')
    props = type_blocks(PROPERTIES.read_text(encoding='utf-8'), '/material')
    materials = {}
    for path, body in names.items():
        if 'name' not in body:
            continue
        name = body['name'].strip('"').lower()
        materials[name] = {key: number(inherited(props, path, key)) for key in NUMBERS + FLAGS}
        materials[name]['path'] = path
    return materials


def defines():
    found = {}
    for name, value in re.findall(r'#define\s+(\w+)\s+([^\s/]+)', DEFINES.read_text(encoding='utf-8')):
        found[name] = value
    return found


def load_roles():
    consts = defines()
    blocks = type_blocks(ROLES.read_text(encoding='utf-8'), '/datum/part_role')
    roles = {}
    for path in blocks:
        if path == '/datum/part_role':
            continue
        get = lambda var: inherited(blocks, path, var)
        terms = lambda raw: {k: float(v) for k, v in re.findall(r'"(\w+)" = (-?[\d.]+)', raw)}
        const = lambda raw: float(consts.get(raw.split('//')[0].strip(), raw.split('//')[0].strip()))
        roles[consts[get('id')].strip('"')] = {
            'standard': get('standard').strip('"'),
            'performance': terms(get('performance_terms')),
            'lifetime': terms(get('lifetime_terms')),
            'min_toughness': const(get('min_toughness')),
            'min_heat': const(get('min_heat')),
            'min_firmness': const(get('min_firmness')),
            'refuses_flammable': get('refuses_flammable') == 'TRUE',
        }
    return roles, consts


def role_property(material, name):
    if name == 'rustproof':
        return max(1, 100 - material['corrosion'])
    return material[name]


def refused(role, material):
    if (material['toughness'] < role['min_toughness'] or material['heat_limit'] < role['min_heat']
            or material['firmness'] < role['min_firmness']):
        return True
    if role['refuses_flammable'] and material['flammable']:
        return True
    return any(role_property(material, prop) <= 0 for prop in role['performance'])


def product(material, standard, terms):
    result = 1.0
    for prop, exponent in terms.items():
        base = role_property(standard, prop)
        if base > 0:
            result *= (max(0, role_property(material, prop)) / base) ** exponent
    return result


def rate(role, material, materials, consts, clamp=True):
    standard = materials[role['standard']]
    if refused(role, material):
        return None
    performance = product(material, standard, role['performance'])
    lifetime = product(material, standard, role['lifetime'])
    if clamp:
        performance = max(float(consts['PART_PERFORMANCE_MIN']), min(float(consts['PART_PERFORMANCE_MAX']), performance))
        lifetime = max(float(consts['PART_LIFETIME_MIN']), min(float(consts['PART_LIFETIME_MAX']), lifetime))
    return performance, lifetime, material['density'] / max(1, standard['density'])


# (role, material) -> (performance, lifetime) to two places, or None = refused.
FROZEN_RATINGS = {
    ('gear', 'steel'): (1.0, 1.0),
    ('gear', 'iron'): (0.84, 0.7),
    ('gear', 'bronze'): (0.74, 0.85),
    ('gear', 'hardwood'): (0.42, 0.2),
    ('gear', 'woodplank'): (0.34, 0.12),
    ('gear', 'plastic'): (0.33, 0.45),
    ('gear', 'lead'): None,
    ('gear', 'leather'): None,
    ('gear', 'flint'): None,
    ('edge', 'flint'): (0.92, 0.13),
    ('edge', 'bone'): (0.55, 0.19),
    ('edge', 'copper'): (0.59, 0.49),
    ('edge', 'bronze'): (0.77, 0.8),
    ('edge', 'iron'): (0.89, 0.75),
    ('striker', 'iron'): (1.0, 1.0),
    ('striker', 'lead'): (0.67, 0.25),
    ('striker', 'glass'): None,
    ('handle', 'woodplank'): (1.0, 1.0),
    ('handle', 'iron'): (0.75, 2.0),
    ('handle', 'bamboo'): (1.02, 1.0),
    ('spring', 'lead'): None,
    ('spring', 'bronze'): (0.45, 0.87),
    ('spring', 'bamboo'): None,
    ('limb', 'bamboo'): (1.25, 0.87),
    ('limb', 'steel'): (1.25, 1.58),
    ('vessel', 'woodplank'): None,
    ('vessel', 'plastic'): None,
    ('vessel', 'copper'): (0.68, 1.5),
    ('vessel', 'clay'): (0.25, 1.67),
    ('pipe', 'bamboo'): (1.0, 1.17),
    ('pipe', 'lead'): (1.0, 1.62),
    ('pipe', 'iron'): (1.0, 0.67),
    ('conductor', 'copper'): (1.0, 1.0),
    ('conductor', 'iron'): (0.25, 0.67),
    ('conductor', 'gold'): (0.7, 1.05),
    ('conductor', 'cloth'): None,
    ('bearing', 'bronze'): (0.95, 0.85),
    ('bearing', 'hardwood'): (0.62, 0.2),
    ('wheel', 'stone'): (0.33, 0.35),
}

# Materials allowed to outperform a role's standard, before clamping.
BEATS_STANDARD = {
    'edge': {'diamond'},
    'striker': {'steel', 'submarine hull'},
    'handle': {'bamboo'},
    'gear': set(),
    'bearing': {'diamond'},
    'spring': set(),
    'limb': {'bamboo', 'bronze', 'steel', 'submarine hull'},
    'pipe': set(),
    'vessel': set(),
    'conductor': {'silver'},
    'wheel': set(),
}


class MaterialRoles(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.materials = load_materials()
        cls.roles, cls.consts = load_roles()

    def test_every_material_has_every_property(self):
        self.assertGreater(len(self.materials), 90)
        for name, material in self.materials.items():
            for key in NUMBERS + FLAGS:
                self.assertIsNotNone(material[key], f'{name} lacks {key}')

    def test_steel_is_the_scale(self):
        steel = self.materials['steel']
        for key in ('density', 'firmness', 'toughness', 'wear', 'spring'):
            self.assertEqual(steel[key], 100, key)
        self.assertEqual(self.materials['copper']['conductivity'], 100)

    def test_legacy_numbers_unchanged(self):
        blocks = type_blocks(MATERIALS.read_text(encoding='utf-8', errors='ignore'), '/material')
        current = {path: {key: body[key] for key in ('hardness', 'weight', 'integrity') if key in body}
                   for path, body in sorted(blocks.items())}
        current = {path: body for path, body in current.items() if body}
        self.assertEqual(current, json.loads(LEGACY.read_text(encoding='utf-8')))

    def test_roles_with_known_standards(self):
        self.assertEqual(set(self.roles), set(BEATS_STANDARD))
        for role_id, role in self.roles.items():
            self.assertIn(role['standard'], self.materials, role_id)
            standard = rate(role, self.materials[role['standard']], self.materials, self.consts)
            self.assertIsNotNone(standard, role_id)
            self.assertAlmostEqual(standard[0], 1.0)
            self.assertAlmostEqual(standard[1], 1.0)

    def test_frozen_ratings(self):
        for (role_id, name), expected in FROZEN_RATINGS.items():
            rating = rate(self.roles[role_id], self.materials[name], self.materials, self.consts)
            if expected is None:
                self.assertIsNone(rating, f'{role_id} {name}')
                continue
            self.assertIsNotNone(rating, f'{role_id} {name}')
            self.assertEqual((round(rating[0], 2), round(rating[1], 2)), expected, f'{role_id} {name}')

    def test_only_listed_materials_beat_the_standard(self):
        for role_id, role in self.roles.items():
            better = set()
            for name, material in self.materials.items():
                rating = rate(role, material, self.materials, self.consts, clamp=False)
                if rating and rating[0] > 1.0001:
                    better.add(name)
            self.assertEqual(better, BEATS_STANDARD[role_id], role_id)

    def test_ratings_stay_in_bounds(self):
        low, high = float(self.consts['PART_PERFORMANCE_MIN']), float(self.consts['PART_PERFORMANCE_MAX'])
        for role in self.roles.values():
            for material in self.materials.values():
                rating = rate(role, material, self.materials, self.consts)
                if rating:
                    self.assertTrue(low <= rating[0] <= high)

    def test_examine_reads_the_summary(self):
        weapons = (ROOT / 'code/game/objects/items/weapons/material/material_weapons.dm').read_text(encoding='utf-8', errors='ignore')
        self.assertIn('material.property_summary()', weapons)


if __name__ == '__main__':
    unittest.main()

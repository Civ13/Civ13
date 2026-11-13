"""Classify compiler-resolved gun types into the issue #4443 coverage manifest.

Input rows come from probe.dm (one per /obj/item/weapon/gun type). Categories
follow the explicit ancestry rules below; the first matching prefix wins, so
order matters. "modern" lists the in-scope cartridge families; everything else
is a named separate category, never silently counted as complete.
"""
import json

MANIFEST = 'docs/firearm-coverage.json'
SCHEMA_VERSION = 1
GUN = '/obj/item/weapon/gun'
P = GUN + '/projectile'

# (prefix, category). Earlier rules win.
RULES = [
    (P + '/automatic/laser', 'energy'),
    (P + '/automatic/stationary', 'machine_gun_mounted'),
    (P + '/automatic', 'machine_gun'),
    (P + '/submachinegun', 'submachine_gun'),
    (P + '/semiautomatic', 'rifle_semiauto'),
    (P + '/boltaction', 'rifle_bolt'),
    (P + '/leveraction', 'rifle_lever'),
    (P + '/shotgun', 'shotgun'),
    (P + '/revolver', 'revolver'),
    (P + '/revolving', 'revolver'),
    (P + '/pistol', 'pistol'),
    (P + '/special', 'rifle_semiauto'),
    (P + '/custom', 'custom_gunsmith'),
    (P + '/flintlock', 'blackpowder'),
    (P + '/capnball', 'blackpowder'),
    (P + '/ancient', 'blackpowder'),
    (P + '/bow', 'bow'),
    (P + '/dartgun', 'dart'),
    (GUN + '/launcher', 'launcher'),
]
MODERN = {'revolver', 'pistol', 'rifle_bolt', 'rifle_lever', 'rifle_semiauto',
          'shotgun', 'submachine_gun', 'machine_gun', 'machine_gun_mounted'}
# Names that mark abstract parents nobody should spawn.
ABSTRACT_NAMES = {'gun', 'projectile gun', 'automatic weapon', 'semi-automatic rifle',
                  'bolt-action rifle', 'submachine gun', 'pistol', 'revolver', 'shotgun', 'revolving rifle'}


# Calibers that move a type out of the cartridge families whatever its parent.
CALIBER_CATEGORY = {'laser': 'energy', 'laserb': 'energy', 'taser': 'energy', 'rocket': 'launcher'}


def category(path, row):
    for prefix, name in RULES:
        if path == prefix or path.startswith(prefix + '/'):
            if name in MODERN and row.get('is_laser_mg'):
                return 'energy'
            if name in MODERN and row.get('caliber') in CALIBER_CATEGORY:
                return CALIBER_CATEGORY[row['caliber']]
            return name
    if path.startswith(P + '/'):
        return 'unclassified'
    return 'base' if path in (GUN, P) else 'unclassified'


def migration(row, scope):
    """modular: has parts; fixed: a modern design kept whole on purpose
    (firearm_fixed_reason, which separate categories may inherit and ignore);
    pending: not reviewed yet."""
    if row.get('firearm_family'):
        return 'modular'
    if row.get('firearm_fixed_reason') and scope == 'modern':
        return 'fixed'
    return 'pending'


def build(rows):
    entries = []
    for row in sorted(rows, key=lambda r: r['path']):
        cat = category(row['path'], row)
        entry = {
            'path': row['path'],
            'name': row.get('name'),
            'category': cat,
            'scope': 'modern' if cat in MODERN else 'separate',
            'caliber': row.get('caliber'),
            'load_method': row.get('load_method'),
            'max_shells': row.get('max_shells'),
            'magazine_type': row.get('magazine_type'),
            'ammo_type': row.get('ammo_type'),
            # "modular" once the type's family has component definitions
            # (code/modules/1713/gunsmithing/firearm_components.dm).
            'family': row.get('firearm_family'),
            'migration': migration(row, 'modern' if cat in MODERN else 'separate'),
        }
        if entry['migration'] == 'fixed':
            entry['fixed_reason'] = row['firearm_fixed_reason']
        if (row.get('name') or '').lower() in ABSTRACT_NAMES:
            entry['review'] = 'abstract-looking name; confirm whether players can obtain it'
        entries.append(entry)
    counts = {}
    for e in entries:
        counts[e['category']] = counts.get(e['category'], 0) + 1
    calibers = sorted({e['caliber'] for e in entries
                       if e['scope'] == 'modern' and e['caliber'] and 'review' not in e})
    return {
        'schema_version': SCHEMA_VERSION,
        'source': 'tests/firearm_coverage/run.py (pinned compiler, initial() values)',
        'scope_rule': 'modern = cartridge revolvers, pistols, rifles, shotguns, SMGs and machine guns; '
                      'blackpowder, energy, launchers, bows, darts and custom gunsmith guns are separate categories',
        'summary': {
            'types': len(entries),
            'modern': sum(e['scope'] == 'modern' for e in entries),
            'by_category': dict(sorted(counts.items())),
            'modern_calibers': len(calibers),
            'migrated': sum(e['migration'] == 'modular' for e in entries if e['scope'] == 'modern'),
            'fixed': sum(e['migration'] == 'fixed' for e in entries if e['scope'] == 'modern'),
        },
        'modern_calibers': calibers,
        'types': entries,
    }


def dump(manifest):
    return json.dumps(manifest, indent=1, sort_keys=False) + '\n'

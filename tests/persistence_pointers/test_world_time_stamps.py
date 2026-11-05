"""Saved world.time stamps must not survive a reboot (offline source audit, no BYOND).

world.time restarts at zero after a reboot, so a cooldown or "last time" stamp
restored from a save sits in the future and can block an action for hours.
code/modules/persistence/world_time_stamps.dm names those vars so they are
neither exported nor imported. This audit finds every var on a saved type that
is assigned from world.time and requires an entry there, an existing
type-specific exclusion, or a reviewed exception below.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
CODE = ROOT / 'code'
REGISTRY = (CODE / 'modules/persistence/world_time_stamps.dm').read_text()

# Saved without an allowlist: mobs, items, structures, map metadata and covers.
# Other objs and turfs save only map_storage_saved_vars (functions.dm get_saved_vars).
SAVED_TYPE = re.compile(r'^/?(atom|mob|obj/item|obj/structure|obj/map_metadata|obj/covers)(/|$)')
EXTRA_SAVED_TYPES = {'/datum/wound'}

# Reviewed: not a world.time stamp on that type, or deliberately left alone.
REVIEWED = {
    'civilization': 'regex hit on a comparison, not an assignment',
    'faction_text': 'regex hit on a comparison, not an assignment',
    'original_job_title': 'regex hit on a comparison, not an assignment',
    'move_delay': 'assigned on client, not on the saved gun',
    'last_action': 'grabs are never saved (should_save = FALSE)',
    'stopped_until': 'football map mode is not persistent',
    'round_deadline': 'extraction raid instances are not persistent',
    'next_checkpoint': 'extraction raid instances are not persistent',
    'npc_corpses': 'extraction raid instances are not persistent',
    'raid_items': 'extraction raid instances are not persistent',
    'next_population': 'extraction raid instances are not persistent',
    'next_win': 'map metadata restores it as an offset through the durable schema (durable_contract.dm)',
    'gcDestroyed': 'deleted atoms are never saved',
    'time': 'assigned on a callproc helper, not on compasses or syringes',
    'flee_ticket': 'a flee_ticket parameter list, not a saved mob var',
    'data': 'reagent message throttles share the generic data field with blood and dose data',
}

# An optional [key] catches stamps kept in a keyed list, such as next_emote["normal"].
ASSIGN = re.compile(r'^(?:[A-Za-z_]\w*\.)*([A-Za-z_]\w*)(?:\[[^\]]*\])?\s*(?:=|\+=)\s*(.*)$')


def dm_files():
    return sorted(CODE.rglob('*.dm'))


def registry():
    body = REGISTRY[REGISTRY.index('persistence_world_time_stamps = list('):]
    body = body[:body.index('\n)\n')]
    entries = {}
    for name, owners in re.findall(r'^\t"(\w+)" = list\(([^)]*)\)', body, re.M):
        entries[name] = [owner.strip() for owner in owners.split(',')]
    return entries


def scan():
    """Collect type var declarations, world.time assignments and existing exclusions.

    An assignment is (name, owner): owner is the proc's type for a bare name,
    or None for a dotted name such as H.frostbitten. Proc locals are skipped.
    """
    declared = {}
    assigned = set()
    excluded = set()
    defined_types = set()
    for path in dm_files():
        current = None
        in_proc = False
        locals_ = set()
        in_var_block = False
        in_exclusion = False
        for line in path.read_text(encoding='utf-8', errors='replace').splitlines():
            stripped = line.strip()
            if stripped.startswith('//'):
                continue
            if line and not line[0].isspace():
                head = re.match(r'^(/?[A-Za-z_][\w/]*?)(?:/(?:proc|verb))?(?:/(\w+))?\(', line)
                plain = re.match(r'^(/?[A-Za-z_][\w/]*)\s*(?://.*)?$', line)
                current = plain.group(1) if plain else (head.group(1) if head else None)
                if current and not current.startswith('/'):
                    current = '/' + current
                if plain:
                    defined_types.add(current)
                in_proc = bool(head) and not plain
                locals_ = set()
                in_exclusion = 'persistence_runtime_var(' in line
                in_var_block = False
                inline = re.match(r'^(/[\w/]+?)/var/(?:[\w]+/)*(\w+)\b', line)
                if inline:
                    declared.setdefault(inline.group(2), set()).add(inline.group(1))
                    defined_types.add(inline.group(1))
                continue
            if in_exclusion or 'saved -=' in stripped:
                excluded.update(re.findall(r'"(\w+)"', stripped))
            local = re.match(r'^var/(?:[\w]+/)*(\w+)\b', stripped)
            if in_proc and local:
                locals_.add(local.group(1))
                continue
            if stripped == 'var':
                in_var_block = True
                continue
            match = re.match(r'^\tvar/(?:[\w]+/)*(\w+)\b', line)
            if match and current:
                declared.setdefault(match.group(1), set()).add(current)
            elif in_var_block and current and re.match(r'^\t\t(?:\w+/)*(\w+)\b', line):
                declared.setdefault(re.match(r'^\t\t(?:\w+/)*(\w+)\b', line).group(1), set()).add(current)
            match = ASSIGN.match(stripped)
            if match and 'world.time' in match.group(2) and 'world.timeofday' not in match.group(2):
                name = match.group(1)
                if name in locals_:
                    continue
                dotted = '.' in stripped[:match.start(1) + len(name)] and not stripped.startswith('src.')
                assigned.add((name, None if dotted else current))
    return declared, assigned, excluded, defined_types


def saved_owner(owner):
    return bool(owner) and (bool(SAVED_TYPE.match(owner)) or any(owner == t or owner.startswith(t + '/') for t in EXTRA_SAVED_TYPES))


DECLARED, ASSIGNED, EXCLUDED, DEFINED_TYPES = scan()
ENTRIES = registry()


class WorldTimeStampRegistry(unittest.TestCase):
    def test_registry_parses(self):
        self.assertIn('last_bumped', ENTRIES)
        self.assertEqual(ENTRIES['last_bumped'], ['/atom'])
        self.assertEqual(ENTRIES['next_attack_hand'], ['/obj/structure/simple_door'])
        self.assertGreater(len(ENTRIES), 50)

    def test_keyed_list_stamps_are_registered(self):
        # Emote cooldowns live in a keyed list. A restored list blocked *pee and
        # *poop on Gaia until world.time caught up with the saved round.
        self.assertIn(('next_emote', '/mob/living/human'), ASSIGNED)
        self.assertEqual(ENTRIES['next_emote'], ['/mob/living/human'])

    def test_every_entry_names_a_declared_var(self):
        for name in ENTRIES:
            with self.subTest(name=name):
                self.assertIn(name, DECLARED, f'{name} is not declared on any type')

    def test_owner_types_exist(self):
        builtin = {'/atom', '/atom/movable', '/mob', '/datum/wound'}
        for name, owners in ENTRIES.items():
            for owner in owners:
                with self.subTest(name=name, owner=owner):
                    self.assertTrue(owner in builtin or owner in DEFINED_TYPES, owner)

    def test_registry_is_consulted_on_export_and_import(self):
        # get_saved_vars and Load_Entry both skip keys that persistence_runtime_var claims.
        self.assertIn('/atom/persistence_runtime_var(key)\n\treturn persistence_world_time_stamp(src, key) || ..()', REGISTRY)
        self.assertIn('/datum/wound/persistence_runtime_var(key)\n\treturn persistence_world_time_stamp(src, key) || ..()', REGISTRY)
        functions = (CODE / 'modules/persistence/functions.dm').read_text()
        loading = (CODE / 'modules/persistence/loading.dm').read_text()
        self.assertIn('persistence_runtime_var(key)', functions[functions.index('/datum/proc/get_saved_vars()'):])
        self.assertIn('if(object.persistence_runtime_var(v))', loading)
        dme = (ROOT / 'civ13.dme').read_text()
        self.assertIn('#include "code\\modules\\persistence\\world_time_stamps.dm"', dme)

    def test_saved_world_time_stamps_are_not_restored(self):
        missing = set()
        for name, owner in sorted(ASSIGNED, key=lambda row: (row[0], row[1] or '')):
            if name in ENTRIES or name in EXCLUDED or name in REVIEWED:
                continue
            owners = [owner] if owner else sorted(DECLARED.get(name, set()))
            if owner and name not in DECLARED:
                continue  # a builtin or a var on another object
            if any(saved_owner(candidate) for candidate in owners):
                missing.add(f'{name} on {owners}')
        self.assertEqual(sorted(missing), [], 'add these world.time stamps to world_time_stamps.dm or review them')

if __name__ == '__main__':
    unittest.main()

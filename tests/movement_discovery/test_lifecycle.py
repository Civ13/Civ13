"""Offline source projection and adapted list semantics, never native DM."""
from pathlib import Path
import random
import re
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[2]
BASE = '99647037c70786a3c3944fcf5ae51b570b377f08'
HELPERS = 'code/_helpers/mobs.dm'
GLOBAL = 'code/_helpers/global_lists.dm'
HUMAN = 'code/game/mob/mob_movement.dm'
ANIMAL = 'code/modules/1713/complex_animal/_backend.dm'
TYPE = '/mob/living/simple_animal/complex_animal'
WRITES = {
    HELPERS: 2, 'code/_helpers/unsorted.dm': 1,
    'code/game/mob/death.dm': 1,
    'code/game/mob/living/carbon/human/announcer.dm': 1,
    'code/game/mob/living/living.dm': 1,
    'code/game/mob/living/simple_animal/simple_animal.dm': 1,
    'code/game/mob/mob.dm': 2,
    'code/modules/admin/verbs/modifyvariables.dm': 2,
    'code/processes/human_corpse_decay.dm': 1,
    'code/processes/mob.dm': 2,
}


def read(path):
    return (ROOT / path).read_text(encoding='utf-8')


def baseline(path):
    return subprocess.check_output(['git', 'show', f'{BASE}:{path}'],
                                   cwd=ROOT).decode('utf-8')


def proc(text, signature):
    match = re.search('^' + re.escape(signature) + r'\n(.*?)(?=^/|\Z)',
                      text, re.M | re.S)
    if not match:
        raise ValueError(signature)
    return match[1].rstrip() + '\n'


def expected(path):
    """Full-file projection ensures all surrounding lifecycle logic is unchanged."""
    text = baseline(path)
    text = re.sub(r'(?:global\.)?living_mob_list ([+-])= (src|O|M)',
                  lambda m: ('register' if m[1] == '+' else 'unregister')
                  + '_living_mob(' + m[2] + ')', text)
    return text.replace('return global.living_mob_list.Remove(src)',
                        'return unregister_living_mob(src)')


def validate_projection(path, text):
    if path == HELPERS:
        start = text.index('// Mirror living-list writes')
        end = text.index('// Returns true if M was not already in the dead mob list', start)
        text = text[:start] + text[end:]
    if text.rstrip() != expected(path).rstrip():
        raise AssertionError(f'Lifecycle projection differs: {path}')


def remove_last(items, value):
    """Explicit adapter for documented repository native last-match semantics."""
    for i in range(len(items) - 1, -1, -1):
        if items[i] is value:
            del items[i]
            return True
    return False


class Mob:
    def __init__(self, name, animal=False):
        self.name, self.animal = name, animal
        self.dead = False
        self.x = self.y = 0
        self.z = 1
        self.sightrange, self.hearrange, self.smellrange = 8, 12, 15
        self.base_type = 'dog'
        self.has_base = True


class Registry:
    def __init__(self, source=None):
        self.live, self.animals = [], []
        self.source = source if source is not None else read(HELPERS)

    def execute(self, adding, mob):
        """Execute only the two actual helper bodies through a closed vocabulary."""
        name = 'register' if adding else 'unregister'
        body = proc(self.source, f'/proc/{name}_living_mob(var/datum/M)')
        active = True
        result = None
        for raw in body.splitlines():
            line = raw.strip()
            if not line:
                continue
            if line == f'if (istype(M, {TYPE}))':
                active = mob is not None and mob.animal
                continue
            instructions = {
                'global.living_mob_list += M': lambda: self.live.append(mob),
                'global.living_complex_animal_list += M': lambda: self.animals.append(mob),
                '. = global.living_mob_list.Remove(M)': lambda: remove_last(self.live, mob),
                'global.living_complex_animal_list.Remove(M)': lambda: remove_last(self.animals, mob),
            }
            if line not in instructions:
                raise ValueError(f'Unsupported helper instruction: {line}')
            if active:
                value = instructions[line]()
                if line.startswith('. ='):
                    result = value
        return result

    def filtered(self):
        # A native deleted reference may become null in either list.
        return [m for m in self.live if m is not None and m.animal]


class LifecycleTests(unittest.TestCase):
    def test_all_fourteen_original_writes_project_without_other_changes(self):
        for path, count in WRITES.items():
            with self.subTest(path=path):
                old = baseline(path)
                sites = re.findall(r'(?:global\.)?living_mob_list\s*(?:[+-]=|\.Remove\()', old)
                self.assertEqual(len(sites), count)
                validate_projection(path, read(path))

    def test_no_unreviewed_production_list_writes_or_aliases(self):
        # Every source reference is audited, not just assignment-shaped lines.
        paths = subprocess.check_output(['git', 'ls-files', 'code/**/*.dm'], cwd=ROOT).decode().splitlines()
        old_refs, new_refs = [], []
        for path in paths:
            text = read(path)
            for line in text.splitlines():
                if re.search(r'\bliving_mob_list\b', line):
                    new_refs.append((path, line.strip()))
            if path in WRITES:
                # Checked completely against immutable base in the preceding test.
                continue
            if re.search(r'\bliving_mob_list\b', text):
                old_refs.append(path)
                if path not in (GLOBAL, HUMAN, ANIMAL):
                    self.assertEqual(text, baseline(path))
        writers = [(p, s) for p, s in new_refs
                   if re.search(r'\bliving_mob_list\s*(?:[+-]=|\.Remove\()', s)]
        self.assertEqual(writers, [(HELPERS, 'global.living_mob_list += M'),
                                  (HELPERS, '. = global.living_mob_list.Remove(M)')])
        self.assertIn(GLOBAL, old_refs)
        self.assertIn('var/global/list/living_complex_animal_list = list()', read(GLOBAL))

    def test_duplicate_last_removal_and_readded_tail(self):
        a, b = Mob('wolf', True), Mob('dog', True)
        r = Registry()
        for m in (a, Mob('human'), b, a):
            r.execute(True, m)
        self.assertEqual(r.animals, [a, b, a])
        self.assertTrue(r.execute(False, a))
        self.assertEqual(r.animals, [a, b])
        r.execute(True, a)
        self.assertEqual(r.animals, [a, b, a])
        self.assertFalse(r.execute(False, Mob('absent', True)))

    def test_creation_death_revival_admin_cleanup_and_guarded_helpers(self):
        # Caller guards/order are source-projected; this adapter applies their writes.
        r, oracle = Registry(), []
        a, b, h = Mob('wolf', True), Mob('dog', True), Mob('human')
        actions = [(True, h), (True, a), (True, b), (False, a),
                   (True, a), (False, b), (True, b), (False, h),
                   (False, a), (False, a), (False, b)]
        for adding, mob in actions:
            if adding:
                oracle.append(mob)
            else:
                removed = remove_last(oracle, mob)
            result = r.execute(adding, mob)
            self.assertEqual(r.live, oracle)
            self.assertEqual(r.animals, r.filtered())
            if not adding:
                self.assertEqual(result, removed)
        self.assertEqual(r.animals, [])

    def test_five_thousand_mixed_lifecycle_operations(self):
        rng, r = random.Random(3267), Registry()
        mobs = [Mob(str(i), i % 3 == 0) for i in range(30)]
        for _ in range(5000):
            m = rng.choice(mobs)
            # Include DEAD entries: membership follows living_mob_list, not stat.
            m.dead = rng.choice([True, False])
            r.execute(rng.choice([True, False]), m)
            self.assertEqual(r.animals, r.filtered())

    def test_native_reference_nulling_adapter_preserves_remaining_animal_order(self):
        r = Registry()
        a, b, h = Mob('wolf', True), Mob('dog', True), Mob('human')
        for m in (a, h, b, a):
            r.execute(True, m)
        # Native reference clearing is adapted explicitly, not claimed executed.
        r.live = [None if m is a else m for m in r.live]
        r.animals = [None if m is a else m for m in r.animals]
        r.execute(False, None)
        self.assertEqual([m for m in r.animals if m], r.filtered())

    def test_omitted_transition_and_registry_mutations_are_rejected(self):
        path = 'code/game/mob/living/simple_animal/simple_animal.dm'
        with self.assertRaises(AssertionError):
            validate_projection(path, read(path).replace('register_living_mob(src)', 'living_mob_list += src'))
        for before, after in [
            ('living_complex_animal_list += M', 'living_complex_animal_list |= M'),
            ('living_complex_animal_list.Remove(M)', 'living_complex_animal_list.Cut(1,2)'),
            (f'istype(M, {TYPE})', f'istype(M, {TYPE}/dog)'),
        ]:
            with self.subTest(mutation=after), self.assertRaises(ValueError):
                r = Registry(read(HELPERS).replace(before, after))
                a = Mob('wolf', True)
                r.execute(True, a)
                r.execute(False, a)

    def test_missing_subset_append_and_removal_fail_lifecycle_oracle(self):
        for line in ('\t\tglobal.living_complex_animal_list += M\n',
                     '\t\tglobal.living_complex_animal_list.Remove(M)\n'):
            r = Registry(read(HELPERS).replace(line, ''))
            a = Mob('wolf', True)
            with self.subTest(omitted=line), self.assertRaises(AssertionError):
                r.execute(True, a)
                self.assertEqual(r.animals, r.filtered())
                r.execute(False, a)
                self.assertEqual(r.animals, r.filtered())


if __name__ == '__main__':
    unittest.main()

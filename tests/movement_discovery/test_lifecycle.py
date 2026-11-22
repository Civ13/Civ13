"""Offline source projection and adapted list semantics, never native DM."""
from collections import Counter
import json
from pathlib import Path
import random
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
FIXTURES = Path(__file__).resolve().parent / 'fixtures'
HELPERS = 'code/_helpers/mobs.dm'
GLOBAL = 'code/_helpers/global_lists.dm'
HUMAN = 'code/game/mob/mob_movement.dm'
ANIMAL = 'code/modules/1713/complex_animal/_backend.dm'
TYPE = '/mob/living/simple_animal/complex_animal'
# Review of a new reader, alias or write must update this inventory
# deliberately. Runtime tests never regenerate their own expected evidence.
WRITES = {
    HELPERS: 2, 'code/_helpers/unsorted.dm': 1,
    'code/game/mob/death.dm': 1,
    'code/game/mob/living/carbon/human/announcer.dm': 1,
    'code/game/mob/living/living.dm': 1,
    'code/game/mob/living/simple_animal/simple_animal.dm': 1,
    'code/game/mob/mob.dm': 2,
    'code/modules/admin/verbs/modifyvariables.dm': 2,
    'code/processes/human_corpse_decay.dm': 1,
    'code/processes/mob.dm': 1,
}
REGISTRY_REF = re.compile(
    r'\b(living_(?:complex_animal|mob)_list|(?:un)?register_living_mob|'
    r'(?:add_to|remove_from)_living_mob_list|'
    r'switch_from_(?:living_to_dead|dead_to_living)_mob_list)\b'
)


def read(path):
    return (ROOT / path).read_text(encoding='utf-8-sig')


def load_audit():
    return json.loads((FIXTURES / 'registry-audit.json').read_text(encoding='utf-8'))


def proc(text, signature):
    pattern = r'^' + re.escape(signature) + r'[^\n]*\n((?:[\t ][^\n]*\n|\n)*)'
    matches = re.findall(pattern, text.rstrip() + '\n', re.M)
    if len(matches) != 1:
        raise ValueError(signature)
    return matches[0].rstrip() + '\n'


def reference_inventory(path, text):
    owner = ''
    lines = []
    for raw in text.splitlines():
        line = raw.split('//', 1)[0].rstrip()
        if line.startswith('/') and not line.startswith('/*'):
            owner = line
        if REGISTRY_REF.search(line):
            lines.append((path, owner, line))
    return lines


def validate_inventory(expected, actual):
    missing = Counter(map(tuple, expected)) - Counter(actual)
    unexpected = Counter(actual) - Counter(map(tuple, expected))
    if missing or unexpected:
        raise AssertionError(f'Registry reference drift: missing={list(missing.elements())!r}; '
                             f'unexpected={list(unexpected.elements())!r}')


def validate_production_inventory(expected):
    actual = [ref for path in sorted((ROOT / 'code').rglob('*.dm'))
              for ref in reference_inventory(path.relative_to(ROOT).as_posix(),
                                            path.read_text(encoding='utf-8-sig'))]
    validate_inventory(expected, actual)


def validate_guard(path, source, guard):
    owner, label, text = guard['owner'], guard['label'], guard['body']
    if proc(source, owner).count(text) != 1:
        raise AssertionError(f'Lifecycle guard/order differs: {path}:{owner} ({label})')


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
    def test_thirteen_current_writes_keep_lifecycle_guards_and_order(self):
        audit = load_audit()
        for guard in audit['guards']:
            path = guard['path']
            with self.subTest(path=path, label=guard['label']):
                validate_guard(path, read(path), guard)
        writes = Counter()
        for path, _, line in audit['references']:
            if re.fullmatch(r'(?:return )?(?:un)?register_living_mob\((?:src|O|M)\)', line.strip()):
                writes[path] += 1
        self.assertEqual(writes, WRITES)
        self.assertEqual(sum(writes.values()), 13)
        self.assertEqual({guard['path'] for guard in audit['guards']}, set(WRITES) | {
            'code/game/mob/living/carbon/human/resuscitation.dm'})
        self.assertIn('var/global/list/living_complex_animal_list = list()', read(GLOBAL))

    def test_no_unreviewed_production_list_readers_writers_or_aliases(self):
        validate_production_inventory(load_audit()['references'])

    def test_unreviewed_reader_alias_and_lifecycle_call_rejected(self):
        path = 'code/processes/mob.dm'
        source = read(path)
        expected = reference_inventory(path, source)
        for mutation in (
            '\tvar/list/alias = living_mob_list\n',
            '\tvar/count = living_complex_animal_list.len\n',
            '\tunregister_living_mob(M)\n',
            '\tM.switch_from_dead_to_living_mob_list()\n',
        ):
            with self.subTest(mutation=mutation), self.assertRaises(AssertionError):
                validate_inventory(expected, reference_inventory(path, source + mutation))

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
        # Caller guards/order are checked in source; this adapter applies their writes.
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
        guard = next(g for g in load_audit()['guards'] if g['path'] == path)
        for before, after in (
            ('register_living_mob(src)', 'living_mob_list += src'),
            ('if (health > 0)', 'if (health >= 0)'),
            ('register_living_mob(src)\n\t\t\tstat = CONSCIOUS',
             'stat = CONSCIOUS\n\t\t\tregister_living_mob(src)'),
        ):
            with self.subTest(mutation=after), self.assertRaises(AssertionError):
                validate_guard(path, read(path).replace(before, after), guard)
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

"""Restricted production translations; RNG/callbacks/iteration are offline adapters."""
import re
import unittest
from test_lifecycle import ANIMAL, HUMAN, TYPE, Mob, Registry, baseline, proc, read


def body(path, text):
    if path == ANIMAL:
        return proc(text, TYPE + '/Move()')
    match = re.search(r'(\t+for \(var/mob/living/simple_animal/complex_animal/C in [^\n]+\n'
                      r'.*?C.onHumanMovement\(mob\)\n)', text, re.S)
    if not match:
        raise ValueError('Human movement loop missing')
    lines = match[1].splitlines()
    depth = len(lines[0]) - len(lines[0].lstrip('\t')) - 1
    return '\n'.join(line[depth:] for line in lines) + '\n'


def translate(source):
    words = {
        '..()': 'pass',
        'if (L == src)': 'if L is ctx.mover:',
        'continue': 'continue',
        f'if (istype(L, {TYPE}))': 'if L.animal:',
        'var/mob/living/simple_animal/complex_animal/C = L': 'C = L',
        'var/dist_x = abs(x - C.x)': 'dist_x = abs(ctx.mover.x - C.x)',
        'var/dist_y = abs(y - C.y)': 'dist_y = abs(ctx.mover.y - C.y)',
        'var/dist_y = abs(x - C.y)': 'dist_y = abs(ctx.mover.x - C.y)',
        'var/dist_x = abs(mob.x - C.x)': 'dist_x = abs(ctx.mover.x - C.x)',
        'var/dist_y = abs(mob.y - C.y)': 'dist_y = abs(ctx.mover.y - C.y)',
        'if (dist_x <= 10 && dist_y <= 10)': 'if dist_x <= 10 and dist_y <= 10:',
        'C.knows_about_mobs |= src': 'ctx.remember(C)',
        'C.onHumanMovement(mob)': 'ctx.callback(C, "human")',
        'C.onEveryBaseTypeMovement(src)': 'ctx.callback(C, "base")',
        'C.onEveryXMovement(type)': 'ctx.callback(C, "type")',
        'else if (vars.Find("base_type") && src:base_type == C.base_type)':
            'elif ctx.mover.has_base and ctx.mover.base_type == C.base_type:',
        'else': 'else:',
    }
    for registry in ('living_mob_list', 'living_complex_animal_list'):
        words[f'for (var/mob/living/L in {registry})'] = f'for L in ctx.entries("{registry}", False):'
        words[f'for (var/mob/living/simple_animal/complex_animal/C in {registry})'] = f'for C in ctx.entries("{registry}", True):'
    for prefix, chance, distance in [('if', 90, 'sight'), ('else if', 45, 'hear'), ('else if', 22, 'smell')]:
        words[f'{prefix} (prob({chance}) && dist_x <= C.{distance}range && dist_y <= C.{distance}range)'] = (
            ('if' if prefix == 'if' else 'elif') + f' ctx.prob(C, {chance}) and dist_x <= C.{distance}range and dist_y <= C.{distance}range:')
    lines = ['def execute(ctx):']
    for raw in source.splitlines():
        line = raw.split('//', 1)[0].strip()
        if not line:
            continue
        if line not in words:
            raise ValueError(f'Unsupported movement instruction: {line}')
        depth = len(raw) - len(raw.lstrip('\t'))
        lines.append('    ' * depth + words[line])
    namespace = {}
    exec(compile('\n'.join(lines), '<restricted movement source>', 'exec'), namespace)
    return namespace['execute']


class Context:
    def __init__(self, registry, mover, seed=0, callback_rng=False):
        self.registry, self.mover, self.seed = registry, mover, seed
        self.callback_rng = callback_rng
        self.visits, self.draws, self.trace, self.knowledge = 0, 0, [], {}

    def entries(self, name, animals_only):
        # Snapshot adapter is explicit: no claim about native mutation mid-loop.
        entries = self.registry.live if name == 'living_mob_list' else self.registry.animals
        for m in entries.copy():
            self.visits += 1
            if m is not None and (not animals_only or m.animal):
                yield m

    def prob(self, observer, chance):
        value = (self.draws * 37 + self.seed * 13) % 100 + 1
        self.draws += 1
        self.trace.append(('prob', observer.name, chance, value))
        return value <= chance

    def remember(self, observer):
        self.trace.append(('remember', observer.name, self.mover.name))
        self.knowledge.setdefault(observer.name, set()).add(self.mover.name)

    def callback(self, observer, kind):
        self.trace.append(('callback', observer.name, kind, self.mover.name))
        if self.callback_rng:
            self.prob(observer, 13)


class MovementTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.loops = {p: (translate(body(p, baseline(p))), translate(body(p, read(p))))
                     for p in (HUMAN, ANIMAL)}

    def compare(self, path, registry, mover, seed=0, callback_rng=False):
        old, new = [Context(registry, mover, seed, callback_rng) for _ in range(2)]
        self.loops[path][0](old)
        self.loops[path][1](new)
        self.assertEqual(old.trace, new.trace)
        self.assertEqual(old.knowledge, new.knowledge)
        self.assertEqual(old.draws, new.draws)
        return old, new

    def test_full_movement_files_differ_only_in_loop_collection(self):
        for path in (HUMAN, ANIMAL):
            candidate = read(path).replace('in living_complex_animal_list)', 'in living_mob_list)')
            if path == HUMAN:
                candidate = candidate.replace('in living_mob_list)\n',
                    'in living_mob_list) // living_mob_list fails here\n', 1)
            self.assertEqual(candidate.rstrip(), baseline(path).rstrip())

    def test_human_order_boundaries_cross_z_and_callback_rng(self):
        r, mover = Registry(), Mob('human')
        for i, distance in enumerate((0, 9, 10, 11, -10, -11)):
            r.execute(True, Mob('unrelated' + str(i)))
            m = Mob('observer' + str(i), True)
            m.x, m.y, m.z = distance, -distance, 2
            m.dead = i % 2 == 0  # No added stat gate at discovery.
            r.execute(True, m)
        old, new = self.compare(HUMAN, r, mover, callback_rng=True)
        self.assertEqual([v[1] for v in new.trace if v[0] == 'callback'],
                         ['observer0', 'observer1', 'observer2', 'observer4'])
        self.assertEqual((old.visits, new.visits), (12, 6))

    def test_animal_rng_order_short_circuit_geometry_and_base_paths(self):
        r, mover = Registry(), Mob('mover', True)
        r.execute(True, mover)
        for i, distance in enumerate((0, 8, 9, 10, 11, 12, 13, 15, 16, 100)):
            r.execute(True, Mob('human' + str(i)))
            m = Mob('observer' + str(i), True)
            m.x, m.y, m.z = distance, -distance, 2
            m.base_type = 'dog' if i % 2 else 'wolf'
            r.execute(True, m)
        for seed in range(100):
            for has_base in (False, True):
                mover.has_base = has_base
                self.compare(ANIMAL, r, mover, seed, callback_rng=True)
        _, new = self.compare(ANIMAL, r, mover)
        self.assertFalse(any(row[1] == 'mover' for row in new.trace))
        self.assertEqual([row[2] for row in new.trace if row[:2] == ('prob', 'observer9')], [90, 45, 22])

    def test_every_transition_compares_ordered_delivery_and_rng(self):
        r, mover = Registry(), Mob('mover', True)
        a, b, h = Mob('wolf', True), Mob('dog', True), Mob('human')
        for add, mob in [(True, h), (True, a), (True, mover), (True, b),
                         (True, a), (False, a), (False, b), (True, b),
                         (False, h), (False, mover), (True, mover),
                         (False, a), (False, b), (False, mover)]:
            r.execute(add, mob)
            for path in (HUMAN, ANIMAL):
                self.compare(path, r, mover, 99, callback_rng=True)

    def test_existing_animal_y_distance_uses_mover_x_unchanged(self):
        r, mover = Registry(), Mob('mover', True)
        mover.x, mover.y = 10, 100
        observer = Mob('observer', True)
        observer.x = observer.y = 10
        r.execute(True, observer)
        _, new = self.compare(ANIMAL, r, mover)
        self.assertIn(('remember', 'observer', 'mover'), new.trace)

    def test_operation_counts_are_candidate_visits_not_timings(self):
        for humans, animals in ((0, 0), (1000, 0), (0, 32), (1000, 32)):
            r, mover = Registry(), Mob('mover')
            for i in range(humans + animals):
                r.execute(True, Mob(str(i), i >= humans))
            for path in (HUMAN, ANIMAL):
                old, new = self.compare(path, r, mover)
                self.assertEqual((old.visits, new.visits), (humans + animals, animals))

    def test_new_z_filter_and_changed_rng_are_rejected(self):
        source = body(ANIMAL, read(ANIMAL))
        for mutation in [source.replace('prob(90)', 'prob(89)'),
                         source.replace('if (L == src)', 'if (L == src || L.z != z)'),
                         source.replace('living_complex_animal_list', 'dog_mob_list')]:
            with self.assertRaises(ValueError):
                translate(mutation)

    def test_reversing_subset_fails_ordered_trace_oracle(self):
        r = Registry()
        for name in ('wolf', 'dog'):
            r.execute(True, Mob(name, True))
        r.animals.reverse()
        for path in (HUMAN, ANIMAL):
            with self.subTest(path=path), self.assertRaises(AssertionError):
                self.compare(path, r, Mob('mover'), callback_rng=True)


if __name__ == '__main__':
    unittest.main()

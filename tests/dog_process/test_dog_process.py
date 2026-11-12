"""Offline source translation; this is neither a DM compiler nor native gameplay."""
from pathlib import Path
import hashlib
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
FIXTURE = Path(__file__).with_name('historical-fire.dm')


def fire_body(source):
    match = re.search(r'^/process/dog/fire\(\)\n(.*?)(?=^/|\Z)', source, re.M | re.S)
    if not match:
        raise ValueError('Missing dog fire procedure')
    return match.group(1)


def translate(source):
    # Only these statements are understood. Indentation and continue targets
    # come from the actual DM source; unknown instructions fail closed.
    vocabulary = {
        'try': 'try:',
        'for (current in current_list)': 'for current in ctx.dogs:',
        'if (!isDeleted(current))': 'if not current["deleted"]:',
        'var/mob/living/simple_animal/complex_animal/dog/dog = current': 'dog = current',
        'if (dog.stat == CONSCIOUS && dog.walking_to && !ecology_animal_frozen(dog))':
            'if dog["conscious"] and dog["walking_to"] and not dog["frozen"]:',
        'if (ismob(dog.walking_to))': 'if dog["target_is_mob"]:',
        'var/mob/M = dog.walking_to': 'M = dog',
        'if (world.time - M.last_movement >= 10)': 'if M["movement_age"] >= 10:',
        'continue': 'continue',
        'var/dist_x = abs(dog.x - dog.walking_to.x)': 'dist_x = abs(dog["dx"])',
        'var/dist_y = abs(dog.y - dog.walking_to.y)': 'dist_y = abs(dog["dy"])',
        'if (dist_x > 1 || dist_y > 1 || dog.walking_to != dog.following)':
            'if dist_x > 1 or dist_y > 1 or not dog["following_target"]:',
        'var/turf/target = get_step(dog.loc, get_dir(dog, dog.walking_to))': 'target = dog',
        'if (target.density)': 'if target["turf_dense"]:',
        'for (var/obj/S in target)': 'for S in target["objects"]:',
        'if (S.density)': 'if S:',
        # Deliberately wrong control: treat a dense object like a dense turf.
        'if (dense_object_control(target))': 'if any(target["objects"]):',
        'step(dog, get_dir(dog, dog.walking_to))': 'ctx.events.append((dog["name"], "step"))',
        'else': 'else:',
        'catchBadType(current)': 'ctx.events.append((current["name"], "bad_type"))',
        'dog_mob_list -= current': 'ctx.events.append((current["name"], "remove"))',
        'PROCESS_LIST_CHECK': 'ctx.events.append((current["name"], "list_check"))',
        'PROCESS_TICK_CHECK': 'ctx.events.append((current["name"], "tick_check"))',
        'catch (var/exception/e)': 'except RuntimeError:',
        'catchException(e)': 'ctx.events.append(("exception", "caught"))',
    }
    lines = ['def execute(ctx):']
    for raw in fire_body(source).splitlines():
        instruction = raw.strip()
        if not instruction:
            continue
        if instruction not in vocabulary:
            raise ValueError('Unsupported dog instruction: ' + instruction)
        depth = len(raw) - len(raw.lstrip('\t'))
        if depth < 1 or raw[:depth] != '\t' * depth:
            raise ValueError('Expected DM tab indentation')
        lines.append('    ' * depth + vocabulary[instruction])
    namespace = {}
    exec(compile('\n'.join(lines), '<restricted dog translation>', 'exec'), namespace)
    return namespace['execute']


def dog(name='dog', **changes):
    result = dict(name=name, deleted=False, conscious=True, walking_to=True,
                  frozen=False, target_is_mob=True, movement_age=0, dx=2, dy=0,
                  following_target=True, turf_dense=False, objects=[])
    result.update(changes)
    return result


def trace(source, dogs):
    class Context:
        pass
    ctx = Context()
    ctx.dogs = dogs
    ctx.events = []
    translate(source)(ctx)
    return ctx.events


class DogProcessTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.old = FIXTURE.read_text(encoding='utf-8')
        if hashlib.sha256(cls.old.encode('utf-8')).hexdigest() != 'aae8a95f4f35b482a33a3ef656a4f784ee0d7375e5ceed70762f65091bb5135a':
            raise ValueError('Historical dog fixture differs from the reviewed original')
        cls.new = (ROOT / 'code/processes/dog.dm').read_text(encoding='utf-8')

    def assert_parity(self, dogs, expected):
        self.assertEqual(trace(self.old, dogs), expected)
        self.assertEqual(trace(self.new, dogs), expected)

    def test_object_lists_do_not_prevent_step_attempt(self):
        for objects in ([], [False], [True], [False, True, False], [True, True]):
            with self.subTest(objects=objects):
                self.assert_parity([dog(objects=objects)], [
                    ('dog', 'step'), ('dog', 'list_check'), ('dog', 'tick_check')])

    def test_guards_and_scheduler_check_reachability(self):
        dogs = [dog('unconscious', conscious=False), dog('no_target', walking_to=False),
                dog('frozen', frozen=True), dog('in_range', dx=1, dy=1),
                dog('stale_mob', movement_age=10), dog('dense_turf', turf_dense=True),
                dog('deleted', deleted=True), dog('recent', movement_age=9),
                dog('nonmob', target_is_mob=False, movement_age=100),
                dog('different_following', dx=1, dy=1, following_target=False)]
        expected = []
        for name in ('unconscious', 'no_target', 'frozen', 'in_range'):
            expected.extend([(name, 'list_check'), (name, 'tick_check')])
        # The stale-target and dense-turf continues bypass both checks.
        expected.extend([('deleted', 'bad_type'), ('deleted', 'remove'),
                         ('deleted', 'list_check'), ('deleted', 'tick_check')])
        for name in ('recent', 'nonmob', 'different_following'):
            expected.extend([(name, 'step'), (name, 'list_check'), (name, 'tick_check')])
        self.assert_parity(dogs, expected)

    def test_dense_object_suppression_negative_control(self):
        marker = '\t\t\t\t\t\tstep(dog, get_dir(dog, dog.walking_to))'
        self.assertEqual(self.new.count(marker), 1)
        mutant = self.new.replace(marker, '\t\t\t\t\t\tif (dense_object_control(target))\n'
                                  '\t\t\t\t\t\t\tcontinue\n' + marker)
        case = [dog(objects=[False, True])]
        expected = trace(self.old, case)
        self.assertEqual(expected[0], ('dog', 'step'))
        self.assertNotEqual(trace(mutant, case), expected)
        self.assertEqual(trace(mutant, case), [])

    def test_unknown_source_fails_closed(self):
        with self.assertRaisesRegex(ValueError, 'Unsupported dog instruction'):
            translate(self.new.replace('PROCESS_LIST_CHECK', 'unexpected_operation()'))


if __name__ == '__main__':
    unittest.main()

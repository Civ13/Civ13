"""Offline comparison of the animal movement guard; no native BYOND execution."""
import re
import unittest

from test_lifecycle import ANIMAL, TYPE, Mob, Registry, read
from test_movement import Context, body, translate


class AnimalBaseTypeGuardTests(unittest.TestCase):
    def test_ordered_traces_and_invalid_missing_field_control(self):
        declaration = read('code/modules/1713/complex_animal/__complex_animal.dm')
        self.assertRegex(declaration, r'(?ms)^' + re.escape(TYPE) + r'\s*\n\s*var/base_type\s*=')
        source = body(ANIMAL, read(ANIMAL))
        direct = 'else if (base_type == C.base_type)'
        guarded = 'else if (vars.Find("base_type") && src:base_type == C.base_type)'
        self.assertEqual(source.count(direct), 1)
        old = translate(source.replace(direct, guarded))
        new = translate(source)
        for left, right in ((None, None), (None, 'dog'), ('dog', 'dog'), ('dog', 'wolf')):
            for distance in (10, 11):
                registry, mover = Registry(), Mob('mover', True)
                mover.base_type = left
                observer = Mob('observer', True)
                observer.base_type = right
                observer.x = observer.y = distance
                observer.sightrange = observer.hearrange = observer.smellrange = -1
                registry.execute(True, observer)
                before, after = Context(registry, mover, callback_rng=True), Context(registry, mover, callback_rng=True)
                old(before)
                new(after)
                self.assertEqual(before.trace, after.trace)
                self.assertEqual(before.knowledge, after.knowledge)
                callbacks = [row[2] for row in after.trace if row[0] == 'callback']
                self.assertEqual(callbacks, [('base' if left == right else 'type')] if distance == 10 else [])
                self.assertEqual([row[2] for row in after.trace if row[0] == 'prob'][:3], [90, 45, 22])
        # Missing a declared field is outside this proc's type contract and changes the result.
        mover.has_base = False
        mover.base_type = observer.base_type
        observer.x = observer.y = 0
        before, after = Context(registry, mover), Context(registry, mover)
        old(before)
        new(after)
        self.assertNotEqual(before.trace, after.trace)
        # A changed comparison is rejected by the restricted translator.
        with self.assertRaises(ValueError):
            translate(source.replace(direct, 'else if (base_type != C.base_type)'))


if __name__ == '__main__':
    unittest.main()

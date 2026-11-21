"""A goalkeeper only reports a catch once the ball is really in hand (#6292)."""
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('catch_adapter', ROOT / 'tests/save_movement/source_adapter.py')
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)
SOURCE = adapter.read('code/modules/1713/football.dm')
GUARD = 'if (!src.put_in_active_hand(FB) || FB.loc != src)'


class GoalkeeperCatchTest(unittest.TestCase):
    def assert_guarded(self, proc, effects):
        body = adapter.extract(SOURCE, proc)
        self.assertEqual(body.count('put_in_active_hand(FB)'), 1, proc)
        guard = body.index(GUARD)
        self.assertEqual(body[guard:].splitlines()[1].strip().split()[0], 'return', proc)
        for effect in effects:
            self.assertLess(guard, body.index(effect), (proc, effect))

    def test_pickup_verb_needs_the_ball_in_hand(self):
        self.assert_guarded('/mob/living/human/proc/football_gk_pickup',
                            ('FB.pickup(src)', 'FB.owner = null', 'picks up the ball!'))

    def test_shot_catch_needs_the_ball_in_hand(self):
        self.assert_guarded('/mob/living/human/proc/football_hitby',
                            ('blocks and picks up the ball!', 'FB.owner.football = null', 'FB.last_owner = src', 'FB.pickup(src)'))


if __name__ == '__main__':
    unittest.main()

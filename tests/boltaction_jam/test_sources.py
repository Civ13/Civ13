"""Standard bolt-action rifles honour their jam deadline (issue #6752).

Behaviour is covered natively:

    python3 tests/ecology_spawning/run_linux.py . tests/boltaction_jam/probe.dm
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/modules/1713/weapons/guns/bolt-action.dm').read_text(encoding='utf-8')


class BoltactionJam(unittest.TestCase):
    def test_special_check_reads_jam_deadline(self):
        body = SOURCE.split('/obj/item/weapon/gun/projectile/boltaction/special_check(mob/user)', 1)[1].split('\n/', 1)[0]
        guard = body.index('if (jammed_until > world.time)')
        self.assertLess(guard, body.rindex('return TRUE'))
        self.assertIn('return FALSE', body[guard:body.rindex('return TRUE')])

    def test_post_fire_still_sets_a_future_deadline(self):
        body = SOURCE.split('/obj/item/weapon/gun/projectile/boltaction/handle_post_fire()', 1)[1].split('\n/', 1)[0]
        self.assertIn('jammed_until = world.time + ', body)


if __name__ == '__main__':
    unittest.main()

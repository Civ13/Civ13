"""Offline source contract for gun follow-through (#6309, #6329, #6331).

Behaviour is covered natively by tests/gun_followthrough/probe.dm.
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


def read(path):
    return (ROOT / path).read_text(encoding='utf-8-sig')


def body(source, header):
    return source.split(header, 1)[1].split('\n/', 1)[0]


class GunFollowThrough(unittest.TestCase):
    def test_burst_checks_possession_each_round(self):
        fire = body(read('code/modules/projectiles/gun.dm'), '/obj/item/weapon/gun/proc/Fire(')
        loop = fire.index('for (var/i in 1 to _burst)')
        guard = fire.index('if (held_at_start && loc != user)', loop)
        self.assertLess(guard, fire.index('consume_next_projectile(user)', loop))

    def test_chambered_round_counts(self):
        proc = body(read('code/modules/projectiles/guns/projectile.dm'),
                    '/obj/item/weapon/gun/projectile/proc/has_next_projectile(')
        self.assertIn('if (chambered && chambered.BB)', proc)

    def test_machine_gun_trains_on_targets(self):
        target = body(read('code/game/objects/structures/target_stake.dm'),
                      '/obj/structure/practice_dummy/bullet_act(')
        self.assertIn('if (GUN_TYPE_MG)', target)
        self.assertIn('H.adaptStat("machinegun", 1)', target)


if __name__ == '__main__':
    unittest.main()

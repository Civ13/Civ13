"""Offline source checks for the shock outcome in do_revive (#6225); no BYOND runtime."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/game/objects/items/weapons/defib.dm').read_text(encoding='utf-8-sig')
START = '/obj/item/weapon/shockpaddles/proc/do_revive'


def do_revive():
    start = SOURCE.index(START)
    end = SOURCE.index('\n/obj/', start + 1)
    return SOURCE[start:end]


class RevivalOutcome(unittest.TestCase):
    def test_success_is_announced_only_after_the_restart_works(self):
        body = do_revive()
        burn = body.index('H.apply_damage(burn_damage_amt, BURN, "chest")')
        restart = body.index('if(!make_alive(H, user))')
        success = body.index('Resuscitation successful.')
        log = body.index('log_and_message_admins(')
        self.assertLess(burn, restart)
        self.assertLess(restart, success)
        self.assertLess(restart, log)
        self.assertEqual(body.count('make_alive(H, user)'), 1)

    def test_a_failed_restart_reports_why_and_stops(self):
        body = do_revive()
        failed = body[body.index('if(!make_alive(H, user))'):body.index('Resuscitation successful.')]
        self.assertIn('H.resuscitation_blocker()', failed)
        self.assertIn('Resuscitation failed.', failed)
        self.assertIn('defib_failed.ogg', failed)
        self.assertIn('\t\treturn', failed)


if __name__ == '__main__':
    unittest.main()

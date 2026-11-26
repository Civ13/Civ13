"""Offline source contracts for the fireman carry (no BYOND needed)."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]


def read(path):
    return (ROOT / path).read_text(encoding='utf-8')


def proc(source, header):
    start = source.index(header)
    following = re.search(r'\n/[^/\n]', source[start + len(header):])
    return source[start:start + len(header) + following.start()] if following else source[start:]


class FiremanCarrySource(unittest.TestCase):
    def setUp(self):
        self.carry = read('code/game/mob/grab_carry.dm')
        self.grab = read('code/game/mob/grab.dm')

    def test_included_after_grab(self):
        dme = read('civ13.dme')
        self.assertLess(dme.index('#include "code\\game\\mob\\grab.dm"'),
                        dme.index('#include "code\\game\\mob\\grab_carry.dm"'))

    def test_credits_cm_ss13(self):
        self.assertIn('CM-SS13', self.carry)
        self.assertIn('AGPL-3.0', self.carry)

    def test_only_downed_humans_are_carried(self):
        body = proc(self.carry, '/obj/item/weapon/grab/proc/carry_target_downed()')
        self.assertIn('ishuman(affecting)', body)
        self.assertIn('affecting.lying || affecting.stat != CONSCIOUS', body)
        click = proc(self.carry, '/obj/item/weapon/grab/proc/fireman_carry_click()')
        self.assertIn('state != GRAB_AGGRESSIVE || !carry_target_downed()', click)
        self.assertIn('do_mob(assailant, affecting, FIREMAN_CARRY_TIME)', click)
        # Recheck everything after the wait; the target may have stood up.
        after_wait = click[click.index('do_mob('):]
        self.assertIn('!carry_target_downed()', after_wait)
        self.assertIn('state != GRAB_AGGRESSIVE', after_wait)

    def test_click_self_carries_before_devour(self):
        attack = proc(self.grab, '/obj/item/weapon/grab/attack(mob/M, mob/living/user)')
        self.assertIn('if (!fireman_carry_click())\n\t\t\tdevour(affecting, assailant)', attack)

    def test_grip_cannot_change_while_carrying(self):
        click = proc(self.grab, '/obj/item/weapon/grab/proc/s_click(obj/screen/S)')
        self.assertLess(click.index('if (carrying)'), click.index('last_action = world.time'))

    def test_position_and_process_hooks(self):
        adjust = proc(self.grab, '/obj/item/weapon/grab/proc/adjust_position()')
        self.assertLess(adjust.index('if (carrying)'), adjust.index('if (affecting.lying && state != GRAB_KILL)'))
        process = proc(self.grab, '/obj/item/weapon/grab/process()')
        self.assertIn('check_fireman_carry()', process)

    def test_carry_is_faster_than_a_grab_or_pull(self):
        defines = dict(re.findall(r'#define (FIREMAN_CARRY_GRAB_DELAY|DEFAULT_GRAB_MOVE_DELAY) ([0-9.]+)', self.carry))
        self.assertLess(float(defines['FIREMAN_CARRY_GRAB_DELAY']), float(defines['DEFAULT_GRAB_MOVE_DELAY']))
        movement = read('code/game/mob/mob_movement.dm')
        self.assertIn('move_delay += mob.grab_move_delay()', movement)
        self.assertNotIn('\t\t\t\tmove_delay += 1.0\n\t\t\t\tvar/list/L = mob.ret_grab()', movement)
        # Pulling a mob stays slower than carrying one.
        pull = float(re.search(r'istype\(mob\.pulling, /mob\)\)\n\t+move_delay \+= ([0-9.]+)', movement).group(1))
        self.assertLess(float(defines['FIREMAN_CARRY_GRAB_DELAY']), pull)

    def test_prone_blocks_start_and_completion_of_the_lift(self):
        self.assertIn('/proc/fireman_carrier_ready()', self.carry)
        readiness = proc(self.carry, '/proc/fireman_carrier_ready()')
        for guard in ('QDELETED(assailant)', 'assailant.stat == CONSCIOUS', 'assailant.canmove', '!assailant.lying', '!assailant.prone'):
            self.assertIn(guard, readiness)
        click = proc(self.carry, '/proc/fireman_carry_click()')
        wait = click.index('do_mob(')
        self.assertIn('!fireman_carrier_ready()', click[:wait])
        self.assertIn('!fireman_carrier_ready()', click[wait:click.index('affecting.persistence_set_loc')])

    def test_movement_rechecks_carry_before_repositioning_patient(self):
        periodic = proc(self.carry, '/proc/check_fireman_carry()')
        self.assertIn('!fireman_carrier_ready()', periodic)
        self.assertIn('stop_fireman_carry(TRUE)', periodic)
        position = proc(self.carry, '/proc/fireman_carry_position()')
        self.assertIn('check_fireman_carry()', position)
        self.assertLess(position.index('check_fireman_carry()'), position.index('if (!carrying ||'))
        self.assertLess(position.index('if (!carrying ||'), position.index('affecting.persistence_set_loc'))
        release = proc(self.carry, '/proc/stop_fireman_carry(')
        self.assertIn('carrying = FALSE', release)
        self.assertIn('pixel_y = FALSE', release)
        self.assertNotIn('qdel', release)

    def test_prone_does_not_receive_carry_movement_discount(self):
        for header in ('/mob/proc/grab_move_delay()', '/mob/proc/grab_move_cost()'):
            self.assertIn('G.carrying && G.fireman_carrier_ready()', proc(self.carry, header))

    def test_carry_never_becomes_a_new_grab_state(self):
        # Neck/kill checks compare state numerically; a carry is a flag on an aggressive grab.
        self.assertNotIn('GRAB_CARRY', read('code/predefines.dm'))
        self.assertNotIn('state = ', self.carry)


if __name__ == '__main__':
    unittest.main()

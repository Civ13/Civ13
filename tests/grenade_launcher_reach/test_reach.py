"""Portable launchers: validate loading on both sides of the wait.

Offline source checks; no compiler, game or network.
"""
from pathlib import Path
import re
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tests/save_movement'))
from source_adapter import extract, project

SOURCE = ROOT / 'code/modules/1713/weapons/guns/grenade_launcher.dm'
ROCKET_SOURCE = SOURCE.with_name('rocket.dm')
LAUNCHER = '/obj/item/weapon/gun/launcher/rocket'
AMMO = '/obj/item/ammo_casing/rocket'
LEGACY_ATTACKBY = '''/obj/item/weapon/gun/launcher/grenade/attackby(obj/item/I, mob/user)
	if ((istype(I, /obj/item/weapon/grenade)))
		if (do_after(user, 10, src, can_move = TRUE))
			load(I, user)
'''


def block(text, header):
    match = re.search(r'^' + re.escape(header) + r'.*?(?=^\S)', text, re.M | re.S)
    if not match:
        raise AssertionError('missing ' + header)
    return match.group(0)


def finishes(attackby, guard_body, *, held, adjacent, waited=True):
    """Model whether a grenade is loaded, from the source text."""
    if not waited:
        return False
    if '&& can_finish_loading(I, user)' not in attackby:
        return True
    if 'user.get_active_hand() != G' in guard_body and not held:
        return False
    if '!Adjacent(user)' in guard_body and not adjacent:
        return False
    return True


class GrenadeLauncherReachTests(unittest.TestCase):
    def setUp(self):
        self.text = SOURCE.read_text(encoding='utf-8-sig')
        self.attackby = block(self.text, '/obj/item/weapon/gun/launcher/grenade/attackby(')
        self.guard = block(self.text, '/obj/item/weapon/gun/launcher/grenade/proc/can_finish_loading(')

    def test_out_of_reach_does_not_load(self):
        self.assertFalse(finishes(self.attackby, self.guard, held=True, adjacent=False))

    def test_grenade_no_longer_held_does_not_load(self):
        self.assertFalse(finishes(self.attackby, self.guard, held=False, adjacent=True))

    def test_in_reach_and_held_loads(self):
        self.assertTrue(finishes(self.attackby, self.guard, held=True, adjacent=True))

    def test_negative_control_legacy_loads_out_of_reach(self):
        self.assertTrue(finishes(LEGACY_ATTACKBY, self.guard, held=True, adjacent=False))

    def test_guard_runs_after_wait_and_before_load(self):
        self.assertIn('if (do_after(user, 10, src, can_move = TRUE) && can_finish_loading(I, user))\n\t\t\tload(I, user)',
                      self.attackby)
        self.assertIn('QDELETED(G)', self.guard)


LEGACY_ROCKET = f'''{LAUNCHER}/attackby(obj/item/I as obj, mob/user as mob)
	if(istype(I, {AMMO}))
		playsound(src.loc, 'sound/effects/rpgreload.ogg', 80, 0)
		if(rockets.len < max_rockets && do_after(user, load_delay, src, can_move = TRUE))
			user.drop_item()
			I.loc = src
			rockets += I
			to_chat(user, "You put the [I] into the [src].")
			update_icon()
		else
			to_chat(usr, "\\The [src] cannot hold more rockets.")
'''


class Rocket:
    def __init__(self, owner, caliber='rocket', subtype=''):
        self.loc, self.caliber, self.kind = owner, caliber, AMMO + subtype
        self.deleted = False


class Loader:
    deleted = False

    def __init__(self):
        self.hand = Rocket(self)
        self.adjacent = True
        self.allow_transfer = True
        self.transfers = 0

    def get_active_hand(self):
        return self.hand

    def drop_item(self):
        self.hand.loc = 'ground'
        self.hand = None

    def transfer_held_item_to(self, rocket, launcher):
        if not self.allow_transfer:
            return False
        if self.hand is not rocket or rocket.loc is not self:
            raise AssertionError('Attempted to transfer an unheld rocket')
        self.transfers += 1
        rocket.loc, self.hand = launcher, None
        return True


class RocketList(list):
    len = property(len)

    def __iadd__(self, rocket):
        self.append(rocket)
        return self


class RocketLauncher:
    deleted = False
    load_delay = 18
    max_rockets = 1

    def __init__(self, caliber):
        self.rockets, self.caliber, self.loc = RocketList(), caliber, 'ground'
        self.changed = 0

    def Adjacent(self, loader):
        return self.loc is loader or (self.loc == 'ground' and loader.adjacent)

    def update_icon(self):
        self.changed += 1


def rocket_projection(source, launcher, *, during_wait=None, waited=True):
    """Run the checked-in DM branches; only the engine boundaries are faked."""
    events = []
    def do_after(loader, delay, target, can_move):
        assert target is launcher and delay == launcher.load_delay and can_move
        events.append('wait')
        if during_wait and events.count('wait') == 1:
            during_wait()
        return waited

    def istype(value, path):
        return (isinstance(value, Loader) if path == '/mob/living' else
                isinstance(value, Rocket) and (value.kind == path or value.kind.startswith(path + '/')))

    env = dict(src=launcher, usr=None, QDELETED=lambda x: x is None or x.deleted,
               do_after=do_after, istype=istype, SPAN_WARNING=lambda msg: msg,
               to_chat=lambda *args: None, playsound=lambda *args: None)

    def bind(declaration, args):
        body = extract(source, declaration)
        body = body.replace('istype(R)', f'istype(R, {AMMO})').replace('istype(loader)', 'istype(loader, /mob/living)')
        body = re.sub(r'(?<=, )(/[\w/]+)(?=\))', r'"\1"', body)
        parts = re.split(r'''("(?:[^"\\]|\\.)*"|'[^']*')''', body)
        for i in range(0, len(parts), 2):
            for name in ('loc', 'caliber', 'rockets', 'max_rockets', 'load_delay',
                         'Adjacent', 'rocket_load_refusal', 'update_icon'):
                parts[i] = re.sub(r'(?<![\w.])' + name + r'\b', 'src.' + name, parts[i])
        adapted = f'{declaration}()\n' + ''.join(parts) + '\n'
        return project(adapted, declaration, args, env)

    if LAUNCHER + '/proc/rocket_load_refusal(' in source:
        launcher.rocket_load_refusal = bind(LAUNCHER + '/proc/rocket_load_refusal', 'R, loader')
    return bind(LAUNCHER + '/attackby', 'I, user'), events


class RocketLauncherLoadingTests(unittest.TestCase):
    def setUp(self):
        self.source = ROCKET_SOURCE.read_text(encoding='utf-8-sig')

    def test_matching_rounds_still_load(self):
        for caliber, subtype in (('rocket', '/pg7v'), ('rocket', '/og7v'), ('bazooka', '/bazooka'),
                                 ('rpb54', '/rpb54'), ('piat', '/piat'), ('piat', '/piat/mk3'),
                                 ('nuclear', '/nuclear')):
            with self.subTest(caliber=caliber, subtype=subtype):
                launcher, user = RocketLauncher(caliber), Loader()
                round_ = user.hand = Rocket(user, caliber, subtype)
                attack, events = rocket_projection(self.source, launcher)
                attack(round_, user)
                self.assertEqual(events, ['wait'])
                self.assertEqual(launcher.rockets, [round_])
                self.assertIs(round_.loc, launcher)
                self.assertIsNone(user.hand)
                self.assertEqual(launcher.changed, 1)

    def test_wrong_caliber_and_other_launcher_rounds_refused_before_wait(self):
        for caliber, ammo_caliber, subtype in (
            ('bazooka', 'nuclear', '/nuclear'), ('rocket', 'rocket', '/atgm/he'),
            ('rocket', 'rocket', '/panzerfaust'), ('rocket', 'rocket', '/m72law'), ('rocket', 'rocket', '/rpg22'),
        ):
            with self.subTest(subtype=subtype):
                launcher, user = RocketLauncher(caliber), Loader()
                round_ = user.hand = Rocket(user, ammo_caliber, subtype)
                attack, events = rocket_projection(self.source, launcher)
                attack(round_, user)
                self.assertEqual(events, [])
                self.assertEqual(launcher.rockets, [])
                self.assertIs(user.hand, round_)
                self.assertIs(round_.loc, user)

    def test_ground_launcher_left_out_of_reach_keeps_round_in_hand(self):
        launcher, user = RocketLauncher('rocket'), Loader()
        round_ = user.hand
        attack, events = rocket_projection(self.source, launcher, during_wait=lambda: setattr(user, 'adjacent', False))
        attack(round_, user)
        self.assertEqual(events, ['wait'])
        self.assertIs(user.hand, round_)
        self.assertEqual(launcher.rockets, [])

    def test_carried_launcher_can_move_with_loader(self):
        launcher, user = RocketLauncher('rocket'), Loader()
        launcher.loc = user
        round_ = user.hand
        attack, _ = rocket_projection(self.source, launcher, during_wait=lambda: setattr(user, 'adjacent', False))
        attack(round_, user)
        self.assertEqual(launcher.rockets, [round_])

    def test_capacity_race_only_transfers_winner(self):
        launcher, user, other = RocketLauncher('rocket'), Loader(), Loader()
        late_round, first_round = user.hand, other.hand
        attack, events = rocket_projection(self.source, launcher, during_wait=lambda: attack(first_round, other))
        attack(late_round, user)
        self.assertEqual(events, ['wait', 'wait'])
        self.assertEqual(launcher.rockets, [first_round])
        self.assertEqual(launcher.changed, 1)
        self.assertIs(user.hand, late_round)
        self.assertIs(late_round.loc, user)

    def test_round_or_active_hand_change_aborts_even_if_wait_reports_success(self):
        for mutation in ('location', 'hand', 'caliber', 'deletion'):
            with self.subTest(mutation=mutation):
                launcher, user = RocketLauncher('rocket'), Loader()
                round_ = user.hand
                def interrupt():
                    if mutation == 'location':
                        round_.loc = 'ground'
                    elif mutation == 'hand':
                        user.hand = Rocket(user)
                    elif mutation == 'caliber':
                        round_.caliber = 'nuclear'
                    else:
                        round_.deleted = True
                attack, _ = rocket_projection(self.source, launcher, during_wait=interrupt)
                attack(round_, user)
                self.assertEqual(user.transfers, 0)
                self.assertEqual(launcher.rockets, [])

    def test_canceled_wait_or_failed_transfer_never_registers_round(self):
        for waited in (False, True):
            with self.subTest(waited=waited):
                launcher, user = RocketLauncher('rocket'), Loader()
                user.allow_transfer = False
                round_ = user.hand
                attack, _ = rocket_projection(self.source, launcher, waited=waited)
                attack(round_, user)
                self.assertEqual(launcher.rockets, [])
                self.assertIs(user.hand, round_)
                self.assertIs(round_.loc, user)

    def test_single_use_keeps_its_reload_override(self):
        body = extract(self.source, LAUNCHER + '/single_shot/attackby')
        self.assertIn("You can't reload", body)
        self.assertNotIn('..(', body)
        self.assertNotIn('transfer_held_item_to', body)

    def test_legacy_negative_controls_load_wrong_round_remotely_and_over_capacity(self):
        launcher, user, other = RocketLauncher('bazooka'), Loader(), Loader()
        round_ = user.hand = Rocket(user, 'nuclear', '/nuclear')

        def interrupt():
            user.adjacent = False
            attack(other.hand, other)

        attack, _ = rocket_projection(LEGACY_ROCKET, launcher, during_wait=interrupt)
        attack(round_, user)
        self.assertEqual(len(launcher.rockets), 2)
        self.assertIs(round_.loc, launcher)
        self.assertIsNone(user.hand)


if __name__ == '__main__':
    unittest.main()

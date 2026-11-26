#!/usr/bin/env python3
"""Offline source contracts for immigration by smoke signal."""
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]


def read(path):
    return (ROOT / path).read_text(encoding='utf-8', errors='replace').replace('\r\n', '\n')


SOURCE = read('code/modules/1713/immigration_fires.dm')


def proc(name):
    start = SOURCE.index(name)
    end = SOURCE.find('\n/', start + 1)
    return SOURCE[start:end if end > 0 else len(SOURCE)]


def project_renewal(source):
    """Execute the deadline branch only; reaching the end means consent is next."""
    start = source.index('\tvar/open_for = IMMIGRATION_OPEN_TIME')
    end = source.index('\t// Someone who said no', start)
    statements = {
        'var/open_for = IMMIGRATION_OPEN_TIME': 'open_for = 18000',
        'var/now = world.time': 'now = clock',
        'if (immigration_until && now >= immigration_until)': 'if state["until"] and now >= state["until"]:',
        'immigration_close()': 'close()',
        'if (immigration_until)': 'if state["until"]:',
        'var/renewed = world.time + open_for': 'renewed = clock + open_for',
        'immigration_until = renewed': 'state["until"] = renewed',
        'immigration_until = now + open_for': 'state["until"] = now + open_for',
        'return': 'return "renewed"',
    }
    lines = ['def apply(state, clock, close):']
    for line in source[start:end].splitlines():
        indent = len(line) - len(line.lstrip('\t'))
        lines.append('    ' * indent + statements[line.strip()])
    lines.append('    return "ask"')
    env = {}
    exec('\n'.join(lines), env)
    return env['apply']


class ImmigrationFires(unittest.TestCase):
    def test_compiled_once_after_signal_fires(self):
        dme = read('civ13.dme')
        self.assertEqual(dme.count('1713\\immigration_fires.dm"'), 1)
        self.assertLess(dme.index('1713\\signal_fires.dm"'), dme.index('1713\\immigration_fires.dm"'))

    def test_every_signal_offers_it(self):
        signal = read('code/modules/1713/signal_fires.dm')
        send = signal[signal.index('/obj/structure/oven/fireplace/proc/send_smoke_signal('):]
        self.assertIn('\taddtimer(CALLBACK(src, PROC_REF(immigration_offer), user), 1)\n\treturn TRUE', send)

    def test_mainland_only_and_never_saved(self):
        self.assertIn('shard_group.region == shard_group.mainland', proc('/proc/immigration_land()'))
        opened = proc('/obj/structure/oven/fireplace/proc/immigration_open()')
        self.assertIn('!immigration_standing() || !immigration_land()', opened)
        self.assertIn('"immigration_until", "immigration_host", "immigration_faction", "immigration_declined"', proc('/obj/structure/oven/fireplace/persistence_runtime_var('))

    def test_the_offer_ends_when_the_fire_does(self):
        standing = proc('/obj/structure/oven/fireplace/proc/immigration_standing()')
        for guard in ('QDELETED(src)', '!on', '!isturf(loc)', '!signal_fire_open_sky(src)'):
            self.assertIn(guard, standing)
        self.assertIn('immigration_fires -= src', proc('/obj/structure/oven/fireplace/Destroy()'))

    def test_the_fire_is_checked_again_when_the_newcomer_spawns(self):
        start = proc('/proc/immigration_start_turf(')
        self.assertIn('F.immigration_open() ? F.immigration_ground() : null', start)
        self.assertIn('lobby.immigration_fire_choice = null', start)

    def test_newcomers_arrive_as_nomads(self):
        # Val: nobody starts with a faction before joining it in play.
        self.assertNotIn('civilization =', SOURCE.replace('user.civilization', ''))
        self.assertNotIn('faction_roster_add', SOURCE)
        self.assertNotIn('faction_start_choice', SOURCE)

    def test_lobby_offers_the_fire_and_the_faction_list_marks_it(self):
        prompt = read('code/game/mob/groups/faction_start.dm')
        self.assertIn('var/list/fires = immigration_fire_choices()', prompt)
        self.assertIn('immigration_fire_choice = fires[answer]', prompt)
        self.assertIn('"calling" = immigration_faction_calling(relf) ? 1 : 0', read('code/game/mob/groups/factions.dm'))
        self.assertIn('Calling newcomers by smoke signal.', read('tgui/src/interfaces/FactionList.tsx'))

    def test_expired_or_exact_deadline_closes_before_fresh_consent(self):
        apply = project_renewal(proc('/obj/structure/oven/fireplace/proc/immigration_offer('))
        for deadline in (99, 100, 101, 0):
            with self.subTest(deadline=deadline):
                state = dict(until=deadline, host='old' if deadline else None, registered=bool(deadline))
                def close():
                    state.update(until=0, host=None, registered=False)
                if deadline > 100:
                    self.assertEqual(apply(state, 100, close), 'renewed')
                    self.assertEqual(state, dict(until=18100, host='old', registered=True))
                else:
                    self.assertEqual(apply(state, 100, close), 'ask')
                    self.assertEqual(state, dict(until=0, host=None, registered=False))

    def test_someone_who_declined_is_not_asked_on_every_signal(self):
        self.assertIn('if (immigration_declined && (account in immigration_declined))\n\t\treturn', proc('/obj/structure/oven/fireplace/proc/immigration_offer('))


if __name__ == '__main__':
    unittest.main()

"""Offline source contract for the spirit wait and prayers for the dead; does not execute DM."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


def read(rel):
    return (ROOT / rel).read_text(encoding='utf-8')


TEXT = read('code/game/mob/observer/ghost/spirit_wait.dm')


def body(text, header):
    return text.split(header, 1)[1].split('\n/', 1)[0]


class SpiritWaitSource(unittest.TestCase):
    def test_included(self):
        self.assertIn('#include "code\\game\\mob\\observer\\ghost\\spirit_wait.dm"', read('civ13.dme'))

    def test_binding_is_persistent_worlds_only(self):
        bind = body(TEXT, '/proc/spirit_bind(')
        self.assertIn('map.persistence', bind)
        self.assertIn('spirit_bind(src)', read('code/game/mob/living/carbon/human/death.dm'))

    def test_freed_by_body_revival_or_moving_on(self):
        self.assertIn('#define SPIRIT_MOVE_ON_TIME 3000', TEXT)
        binding = body(TEXT, '/proc/spirit_binding(')
        for cond in ('QDELETED(body)', 'body.stat != DEAD', 'world.realtime >= until'):
            self.assertIn(cond, binding)

    def test_respawn_waits_for_moving_on(self):
        self.assertIn('if (spirit_wait_blocks())', body(read('code/game/mob/mob.dm'), '/mob/verb/abandon_mob()'))
        blocks = body(TEXT, '/mob/proc/spirit_wait_blocks()')
        self.assertIn('world.realtime + SPIRIT_MOVE_ON_TIME', blocks)
        self.assertIn('player_alert(', blocks)
        self.assertIn('spirit_release(G.ckey)', read('code/modules/admin/verbs/random_verbs.dm'))

    def test_ghost_leashed_to_body(self):
        self.assertIn('ghost.spirit_leash()', read('code/game/mob/observer/ghost/ghost.dm'))
        spirits = read('code/modules/divine/arcane_spirits.dm')
        self.assertIn('spirit_refresh_leash()', body(spirits, '/mob/observer/ghost/forceMove('))
        self.assertIn('spirit_leashed && spirit_binding(ckey)', body(spirits, '/mob/observer/ghost/verb/arcane_linger()'))

    def test_anyone_may_pray_and_staff_answer(self):
        pray = body(TEXT, '/mob/living/human/verb/spirit_pray_for()')
        self.assertIn('set src in oview(1)', pray)
        self.assertIn('do_after(P, SPIRIT_PRAY_TIME', pray)
        self.assertIn('SPIRIT_PRAY_COOLDOWN', pray)
        self.assertNotIn('divine_patron', pray)
        self.assertIn('prayer_hearers()', body(TEXT, '/datum/spirit_revival_prayer/proc/alert_staff()'))
        topic = body(TEXT, '/datum/spirit_revival_prayer/Topic(')
        self.assertIn('check_rights(R_ADMIN', topic)
        self.assertIn('current()', topic)
        self.assertIn('log_admin(', topic)

    def test_god_revival_needs_a_head(self):
        revive = body(TEXT, '/mob/living/human/proc/spirit_divine_revive()')
        self.assertIn('ORGAN_DESTROYED', revive)
        self.assertIn('restart_from_death(null)', revive)
        self.assertIn('return_revived_spirit()', revive)


if __name__ == '__main__':
    unittest.main()

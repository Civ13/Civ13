"""Offline source contract for spirits and communing; does not execute DM."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


def read(rel):
    return (ROOT / rel).read_text(encoding='utf-8')


TEXT = read('code/modules/divine/arcane_spirits.dm')


def body(text, header):
    return text.split(header, 1)[1].split('\n/', 1)[0]


class ArcaneSpiritsSource(unittest.TestCase):
    def test_included(self):
        self.assertIn('#include "code\\modules\\divine\\arcane_spirits.dm"', read('civ13.dme'))

    def test_lingering_anchors_every_move(self):
        self.assertIn('#define ARCANE_SPIRIT_RANGE 15', TEXT)
        move = body(TEXT, '/mob/observer/ghost/forceMove(')
        self.assertIn('!arcane_in_anchor_range(destination)', move)
        self.assertIn('return FALSE', move)
        anchor = body(TEXT, '/mob/observer/ghost/proc/arcane_find_anchor()')
        self.assertIn('/obj/structure/religious/grave', anchor)

    def test_hour_cooldown_after_stopping(self):
        self.assertIn('#define ARCANE_LINGER_COOLDOWN 36000', TEXT)
        linger = body(TEXT, '/mob/observer/ghost/verb/arcane_linger()')
        self.assertIn('arcane_linger_stopped[ckey] = world.realtime', linger)
        self.assertIn('ARCANE_LINGER_COOLDOWN', linger)
        self.assertIn('admin_ghosted', linger)

    def test_commune_is_gated_and_once_per_rest(self):
        commune = body(TEXT, '/mob/living/human/proc/arcane_commune()')
        for gate in ('arcane_magic_user()', 'verified_discord_id(ckey)', 'arcane_commune_ready()', 'arcane_communed_at = world.realtime'):
            self.assertIn(gate, commune)
        self.assertIn('arcane_communed_at = 0', read('code/modules/divine/arcane_materials.dm'))
        self.assertIn('/mob/living/human/proc/arcane_commune', read('code/modules/divine/arcane_altars.dm'))

    def test_communion_is_private_bounded_and_logged(self):
        self.assertIn('#define ARCANE_COMMUNE_TIME 6000', TEXT)
        whisper = body(TEXT, '/mob/observer/ghost/proc/arcane_spirit_whisper()')
        self.assertIn('to_chat(C.living, CHAT_TYPED(CHAT_PRAYER', whisper)
        self.assertNotIn('visible_message', whisper)
        self.assertIn('log_game(', whisper)
        self.assertIn('log_admin(', body(TEXT, '/datum/arcane_communion/New('))
        current = body(TEXT, '/datum/arcane_communion/proc/current()')
        self.assertIn('ends_at', current)
        self.assertIn('get_dist(T, start) <= 1', current)

    def test_signs_are_harmless_and_paid_for(self):
        sign = body(TEXT, '/mob/observer/ghost/proc/arcane_spirit_sign()')
        self.assertIn('arcane_signs < 1', sign)
        self.assertIn('arcane_signs--', sign)
        for forbidden in ('adjust', 'damage', 'forceMove', 'open(', 'unlock', 'qdel('):
            self.assertNotIn(forbidden, sign)
        self.assertIn('log_admin(', sign)

    def test_defines_are_file_local(self):
        for line in TEXT.splitlines():
            if line.startswith('#define '):
                self.assertIn('#undef ' + line.split()[1], TEXT)


if __name__ == '__main__':
    unittest.main()

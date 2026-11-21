"""Offline source contract for observing as a spirit on persistent worlds; does not execute DM."""
from pathlib import Path
import struct
import unittest
import zlib

ROOT = Path(__file__).resolve().parents[2]


def read(rel):
    return (ROOT / rel).read_text(encoding='utf-8')


TEXT = read('code/game/mob/observer/ghost/spirit_observe.dm')


def body(text, header):
    return text.split(header, 1)[1].split('\n/', 1)[0]


def dmi_description(path):
    data = path.read_bytes()
    pos = 8
    while pos < len(data):
        length = struct.unpack('>I', data[pos:pos + 4])[0]
        kind = data[pos + 4:pos + 8]
        chunk = data[pos + 8:pos + 8 + length]
        if kind == b'zTXt':
            key, rest = chunk.split(b'\0', 1)
            if key == b'Description':
                return zlib.decompress(rest[1:]).decode('utf-8')
        pos += 12 + length
    return ''


class SpiritObserveSource(unittest.TestCase):
    def test_included(self):
        self.assertIn('#include "code\\game\\mob\\observer\\ghost\\spirit_observe.dm"', read('civ13.dme'))

    def test_spirits_only_on_persistent_worlds_and_not_staff(self):
        spirit = body(TEXT, '/mob/observer/ghost/proc/is_spirit()')
        for cond in ('map.persistence', 'admin_ghosted', 'R_ADMIN|R_MOD'):
            self.assertIn(cond, spirit)

    def test_limited_dark_vision(self):
        self.assertIn('#define SPIRIT_SIGHT_RANGE 4', TEXT)
        sight = body(TEXT, '/mob/observer/ghost/proc/spirit_update_sight()')
        self.assertIn('see_in_dark = SPIRIT_SIGHT_RANGE', sight)
        self.assertIn('seedarkness = TRUE', sight)
        self.assertIn('spirit_update_sight()', read('code/game/mob/observer/ghost/login.dm'))
        darkness = body(read('code/game/mob/observer/ghost/ghost.dm'), '/mob/observer/ghost/verb/toggle_darkness()')
        self.assertIn('if (is_spirit())', darkness)
        screen = body(TEXT, '\n/obj/screen/spirit_sight\n')
        for prop in ('plane = LIGHTING_MASK_PLANE', 'blend_mode = BLEND_ADD', 'mouse_opacity = FALSE', 'screen_loc = "CENTER-4,CENTER-4"'):
            self.assertIn(prop, screen)
        desc = dmi_description(ROOT / 'icons/effects/spirit_sight.dmi')
        self.assertIn('width = 288', desc)
        self.assertIn('state = "sight"', desc)

    def test_hearing_and_radio_stay_local(self):
        hears = body(TEXT, '/mob/proc/ghost_hears_everywhere(')
        self.assertIn('G.is_spirit()', hears)
        self.assertIn('M.ghost_hears_everywhere()', read('code/game/mob/living/say.dm'))
        self.assertIn('M.ghost_hears_everywhere()', read('code/game/mob/living/carbon/human/whisper.dm'))
        self.assertIn('M.ghost_hears_everywhere(/datum/client_preference/ghost_sight)', read('code/game/mob/emote.dm'))
        hear = read('code/game/mob/hear_say.dm')
        self.assertNotIn('is_preference_enabled(/datum/client_preference/ghost_ears)', hear)
        self.assertIn('!is_spirit_observer()', hear)  # no real names behind disguises
        self.assertEqual(read('code/modules/1713/radio.dm').count('if (O.is_spirit_observer())'), 2)

    def test_haunt_and_jump_to_living_players(self):
        targets = body(TEXT, '/proc/spirit_haunt_targets(')
        self.assertIn('H.get_visible_name()', targets)
        self.assertIn('H.stat == DEAD || !H.ckey', targets)
        ghost = read('code/game/mob/observer/ghost/ghost.dm')
        self.assertIn('set name = "Haunt"', ghost)
        self.assertIn('observer_targets_for(usr)', body(ghost, '/mob/observer/ghost/verb/follow('))
        self.assertIn('observer_targets_for(usr)', ghost.split('/mob/observer/ghost/verb/jumptomob(', 1)[1].split('\n', 1)[0])
        leash = body(TEXT, '/mob/observer/ghost/move_to_turf(')
        self.assertIn('arcane_in_anchor_range(T)', leash)
        self.assertIn('stop_following()', leash)
        click = body(read('code/_onclick/ghost.dm'), '/mob/observer/ghost/DblClickOn(')
        self.assertIn('if (is_spirit())', click)
        self.assertIn('A spirit can', body(read('code/game/mob/mob.dm'), '/mob/verb/observe()'))

    def test_walls_and_closed_doors_stop_spirits(self):
        solid = body(TEXT, '/proc/spirit_turf_solid(')
        self.assertIn('T.density', solid)
        self.assertIn('O.density && O.opacity && O.anchored', solid)
        self.assertIn('mob.incorporeal_step_allowed(step)', read('code/game/mob/mob_movement.dm'))
        self.assertEqual(read('code/modules/multiz/movement.dm').count('incorporeal_step_allowed(locate('), 2)

    def test_death_notices_without_place(self):
        notice = body(read('code/modules/1713/cmss13_afterlife.dm'), '/proc/death_notice_text(')
        spirit_part = notice.split('if (G && G.is_spirit())', 1)[1].split('\n', 2)[1]
        self.assertIn('get_visible_name()', spirit_part)
        self.assertNotIn('track=', spirit_part)

    def test_lobby_spirits_start_where_players_do(self):
        self.assertIn('spirit_observer_start_turf()', read('code/game/mob/new_player/new_player.dm'))
        start = body(TEXT, '/proc/spirit_observer_start_turf()')
        self.assertIn('pick_new_player_ground()', start)
        self.assertIn('"JoinLateCiv"', start)


if __name__ == '__main__':
    unittest.main()

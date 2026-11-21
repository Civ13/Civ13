"""Offline source contract for the spirit HUD (status plate, reach, Haunt/Jump/Return); does not execute DM."""
from pathlib import Path
import re
import struct
import unittest
import zlib

ROOT = Path(__file__).resolve().parents[2]


def read(rel):
    return (ROOT / rel).read_text(encoding='utf-8')


TEXT = read('code/game/mob/observer/ghost/spirit_hud.dm')
CODE = '\n'.join(line.split('//', 1)[0] for line in TEXT.splitlines())


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


class SpiritHudSource(unittest.TestCase):
    def test_included(self):
        self.assertIn('#include "code\\game\\mob\\observer\\ghost\\spirit_hud.dm"', read('civ13.dme'))

    def test_only_spirits_get_it_and_it_is_cleaned_up(self):
        refresh = body(TEXT, '/mob/observer/ghost/proc/spirit_hud_refresh()')
        self.assertIn('if (QDELETED(src) || !client || !is_spirit())\n\t\tspirit_hud_remove()\n\t\treturn', refresh)
        sight = body(read('code/game/mob/observer/ghost/spirit_observe.dm'), '/mob/observer/ghost/proc/spirit_update_sight()')
        # before the staff branch returns, so losing spirit status removes the HUD
        self.assertLess(sight.index('spirit_hud_refresh()'), sight.index('if (!is_spirit())'))
        destroy = body(read('code/game/mob/observer/ghost/ghost.dm'), '/mob/observer/ghost/Destroy()')
        self.assertIn('spirit_hud_remove()', destroy)
        remove = body(TEXT, '/mob/observer/ghost/proc/spirit_hud_remove()')
        for step in ('deltimer(spirit_hud_timer)', 'client.screen -= S', 'qdel(S)', 'spirit_hud = null'):
            self.assertIn(step, remove)

    def test_refreshes_on_a_timer_not_a_spawn(self):
        self.assertIn('#define SPIRIT_HUD_TICK 10', TEXT)
        refresh = body(TEXT, '/mob/observer/ghost/proc/spirit_hud_refresh()')
        self.assertIn('addtimer(CALLBACK(src, PROC_REF(spirit_hud_refresh)), SPIRIT_HUD_TICK, TIMER_LOOP | TIMER_STOPPABLE)', refresh)
        self.assertNotRegex(CODE, r'\bspawn\s*\(')
        self.assertNotRegex(CODE, r'\b(input|alert)\s*\(')  # prompts go through player_input

    def test_status_plate_states(self):
        status = body(TEXT, '/mob/observer/ghost/proc/spirit_hud_status()')
        for state, title in (('bound', 'Bound to your body'), ('moving', 'Moving on'), ('away', 'Out of body'),
                             ('observe', 'Observing'), ('free', 'Free - Respawn')):
            self.assertIn('list("%s", "%s' % (state, title), status)
        self.assertIn('spirit_binding(ckey)', status)
        # lobby observers are never offered a respawn
        self.assertLess(status.index('if (started_as_observer)'), status.index('"free"'))
        # the countdown runs on world.time: world.realtime is too coarse for seconds
        self.assertIn('spirit_hud_ends = world.time + max(0, until - world.realtime)', status)
        pressed = body(TEXT, '/obj/screen/spirit_hud/plate/pressed(')
        self.assertRegex(pressed, r'if \("bound", "moving"\)\n\t\t\tG\.spirit_wait_blocks\(\)')
        self.assertRegex(pressed, r'if \("free"\)\n\t\t\tG\.abandon_mob\(\)')
        self.assertNotIn('"observe"', pressed)

    def test_reach_readout_while_leashed(self):
        refresh = body(TEXT, '/mob/observer/ghost/proc/spirit_hud_refresh()')
        self.assertIn('if (arcane_anchor && here && here.z == arcane_anchor.z)', refresh)
        self.assertIn('get_dist(here, arcane_anchor)', refresh)
        self.assertIn('[far] / [range] tiles', refresh)
        self.assertIn('far >= range - SPIRIT_HUD_WARN ? SPIRIT_HUD_WARM : SPIRIT_HUD_INK', refresh)
        self.assertIn('client.screen -= reach', refresh)
        spirits = read('code/modules/divine/arcane_spirits.dm')
        self.assertIn('/proc/arcane_spirit_range()\n\treturn ARCANE_SPIRIT_RANGE', spirits)

    def test_buttons_follow_the_verbs(self):
        pick = body(TEXT, '/mob/observer/ghost/proc/spirit_hud_pick(')
        self.assertIn('observer_targets()', pick)
        self.assertIn('player_input(src, message, title, null, "anything", targets, TRUE)', pick)
        self.assertIn('G.ManualFollow(M)', body(TEXT, '/obj/screen/spirit_hud/button/haunt/pressed('))
        jump = body(TEXT, '/obj/screen/spirit_hud/button/jump/pressed(')
        self.assertIn('G.stop_following()\n\tif (!G.forceMove(T) && G.arcane_anchor)', jump)
        self.assertIn('They are beyond your reach.', jump)
        self.assertIn('G.reenter_corpse()', body(TEXT, '/obj/screen/spirit_hud/button/body/pressed('))
        has_body = body(TEXT, '/mob/observer/ghost/proc/spirit_hud_has_body()')
        self.assertIn('mind && mind.current && can_reenter_corpse', has_body)
        refresh = body(TEXT, '/mob/observer/ghost/proc/spirit_hud_refresh()')
        self.assertIn('if (spirit_hud_has_body())\n\t\tclient.screen |= body\n\telse\n\t\tclient.screen -= body', refresh)

    def test_clicks_only_act_for_the_owning_spirit(self):
        click = body(TEXT, '/obj/screen/spirit_hud/Click(')
        self.assertIn('if (!istype(G) || G != spirit || !G.client || !G.is_spirit() || G.spirit_hud_busy)\n\t\treturn TRUE', click)
        self.assertIn('mouse_opacity = FALSE', body(TEXT, '\n/obj/screen/spirit_hud/reach\n'))

    def test_screen_tiles_and_art(self):
        locs = re.findall(r'screen_loc = "([^"]+)"', TEXT)
        self.assertEqual(locs, ['CENTER-5,SOUTH:6', 'CENTER-5,SOUTH:24', 'CENTER:2,SOUTH:6',
                                'CENTER+2:2,SOUTH:6', 'CENTER+4:2,SOUTH:6'])
        desc = dmi_description(ROOT / 'icons/mob/screen/spirit_hud.dmi')
        self.assertIn('width = 32', desc)
        states = set(re.findall(r'state = "([^"]+)"', desc))
        used = set(re.findall(r'icon_state = "([a-z_]+)"', TEXT)) | set(re.findall(r'"((?:plate|reach|button)_[a-z]+)"', TEXT))
        used |= {'plate_' + s for s in re.findall(r'list\("([a-z]+)", "', TEXT)}
        self.assertTrue(used)
        self.assertEqual(used - states, set())
        self.assertNotIn('—', TEXT)


if __name__ == '__main__':
    unittest.main()

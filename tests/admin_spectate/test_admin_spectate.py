"""Offline checks for admin spectating (no compiler, world or network).

Hide Ghost and View As Player live in code/modules/admin/verbs/admin_spectate.dm.
These checks pin the wiring and the safety rules that a headless world cannot
exercise because no client connects: staff guards, the click shield over the
mirrored HUD, the stop conditions, the hidden ghost reapplied on aghost, and
the player map's View button. probe.dm is the DreamDaemon evidence for the
hidden ghost, the follow-list filter and the mirror's list sync.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/modules/admin/verbs/admin_spectate.dm'


def read(path):
    return (ROOT / path).read_text(encoding='utf-8-sig')


def proc_body(text, header):
    start = text.index(header)
    nxt = re.search(r'\n(?=[/#])', text[start + len(header):])
    return text[start:start + len(header) + (nxt.start() if nxt else len(text))]


class AdminSpectateTests(unittest.TestCase):
    def setUp(self):
        self.text = SOURCE.read_text(encoding='utf-8-sig')

    def test_included_and_in_staff_verb_lists(self):
        self.assertIn('#include "code\\modules\\admin\\verbs\\admin_spectate.dm"', read('civ13.dme'))
        verbs = read('code/modules/admin/admin_verbs.dm')
        for name in ('admin_verbs_admin', 'admin_verbs_mod', 'admin_verbs_trialadmin'):
            start = verbs.index(f'var/list/{name} = list(')
            body = verbs[start:verbs.index('\n)', start)]
            for verb in ('toggle_admin_ghost_hidden', 'admin_view_player', 'admin_stop_player_view'):
                self.assertIn(f'/client/proc/{verb},', body, (name, verb))
        start = verbs.index('var/list/admin_verbs_mentor = list(')
        mentor = verbs[start:verbs.index('\n)', start)]
        self.assertNotIn('admin_view_player', mentor)
        self.assertNotIn('toggle_admin_ghost_hidden', mentor)

    def test_staff_guards(self):
        self.assertIn('C.holder.rights & (R_ADMIN|R_MOD)', proc_body(self.text, '/proc/admin_spectate_allowed('))
        for header in ('/client/proc/toggle_admin_ghost_hidden()', '/client/proc/admin_view_player()'):
            self.assertIn('check_rights(R_ADMIN|R_MOD)', proc_body(self.text, header), header)
        self.assertIn('admin_spectate_allowed(src)', proc_body(self.text, '/client/proc/admin_start_player_view('))
        # Losing rights mid-view ends it.
        self.assertIn('admin_spectate_allowed(viewer)', proc_body(self.text, '/datum/admin_player_view/proc/sync()'))
        # Viewing follows the player, so it respects the admin jump switch, and is announced.
        start = proc_body(self.text, '/client/proc/admin_start_player_view(')
        self.assertIn('config.allow_admin_jump', start)
        self.assertIn('log_admin(', start)
        self.assertIn('message_admins(', start)

    def test_hidden_ghost(self):
        body = proc_body(self.text, '/mob/observer/ghost/proc/set_admin_hidden(')
        self.assertIn('invisibility = INVISIBILITY_MAXIMUM', body)
        self.assertIn('C.images -= ghost_image', body)
        self.assertIn('ghost_darkness_images -= ghost_image', body)
        login = read('code/game/mob/observer/ghost/login.dm')
        self.assertIn('client.admin_ghost_hidden && admin_spectate_allowed(client)', login)
        self.assertIn('set_admin_hidden(TRUE)', login)
        fit = proc_body(self.text, '/proc/ghost_follow_targets()')
        self.assertIn('G.admin_hidden_from(usr)', fit)
        ghost = read('code/game/mob/observer/ghost/ghost.dm')
        self.assertNotIn('getfitmobs()', ghost)
        # Follow (Haunt) and Jump to Mob list through observer_targets(), which
        # gives non-spirits ghost_follow_targets() (spirit_observe.dm).
        self.assertEqual(ghost.count('observer_targets'), 4)
        spirit = (ROOT / 'code/game/mob/observer/ghost/spirit_observe.dm').read_text(encoding='utf-8')
        self.assertEqual(spirit.count('return ghost_follow_targets()'), 2)
        self.assertIn('user.client.holder', proc_body(self.text, '/mob/observer/ghost/proc/admin_hidden_from('))

    def test_camera_mirror_and_shield(self):
        sync = proc_body(self.text, '/datum/admin_player_view/proc/sync()')
        for needle in ('viewer.eye = eye', 'EYE_PERSPECTIVE', 'viewer.view = wanted_view', 'T.screen', 'T.images',
                       'ghost.sight = target.sight', 'ghost.see_invisible = target.see_invisible',
                       'ghost.see_in_dark = target.see_in_dark', 'want[shield] = TRUE', 'viewer.mob != ghost',
                       'ghost.following != target'):
            self.assertIn(needle, sync)
        shield = proc_body(self.text, '/obj/screen/admin_view_shield\n')
        self.assertIn('mouse_opacity = 2', shield)
        self.assertIn('WEST,SOUTH to EAST,NORTH', shield)
        self.assertRegex(proc_body(self.text, '/obj/screen/admin_view_shield/Click()'), r'Click\(\)\n\treturn\n')
        # The label only stops the view for its own viewer.
        self.assertIn('usr.client == view.viewer', proc_body(self.text, '/obj/screen/admin_view_label/Click()'))
        stop = proc_body(self.text, '/datum/admin_player_view/proc/stop(')
        for needle in ('put_back(viewer.screen, viewer.images)', 'viewer.eye = ghost',
                       'MOB_PERSPECTIVE', 'ghost.updateghostsight()'):
            self.assertIn(needle, stop)
        # The admin's own screen comes back whenever they are still in the ghost,
        # not only on an announced stop: switching straight to another player
        # otherwise saved a screen with no plane masters, and ending that view
        # drew the world pitch black.
        self.assertLess(stop.index('put_back('), stop.index('if (announce)'))
        put_back = proc_body(self.text, '/datum/admin_player_view/proc/put_back(')
        for needle in ('screen -= mirrored_screen', 'images -= mirrored_images', 'in own_screen',
                       'ghost.hud_used.plane_masters', 'in own_images'):
            self.assertIn(needle, put_back)
        start = proc_body(self.text, '/client/proc/admin_start_player_view(')
        self.assertLess(start.index('admin_player_view.stop('), start.index('new(src, mob, M)'))
        # The ghost's Life must not strip the mirrored HUD images.
        life = proc_body(read('code/game/mob/observer/ghost/ghost.dm'), '/mob/observer/ghost/Life()')
        self.assertLess(life.index('client.admin_player_view'), life.index('client.images.Remove'))

    def test_start_requires_same_live_player_before_and_after_aghost_wait(self):
        start = proc_body(self.text, '/client/proc/admin_start_player_view(')
        self.assertLess(start.index('!player_client || player_client.mob != M'), start.index('admin_ghost()'))
        post_wait_guard = 'if (!player_client || QDELETED(M) || M.client != player_client || player_client.mob != M'
        self.assertLess(start.index('sleep(2)'), start.index(post_wait_guard))
        self.assertLess(start.index(post_wait_guard), start.index('admin_player_view.stop('))

    def test_view_ends_instead_of_substituting_an_unoccupied_camera(self):
        sync = proc_body(self.text, '/datum/admin_player_view/proc/sync()')
        self.assertLess(sync.index('follow_player_client()'), sync.index('var/client/T = target_client'))
        guard = sync.index('if (!T || T.mob != target || target.client != T)\n\t\treturn FALSE')
        self.assertLess(guard, sync.index('viewer.eye = eye'))
        self.assertLess(guard, sync.index('T.screen'))
        self.assertLess(guard, sync.index('T.images'))
        self.assertNotIn('plane_masters', sync)
        follow = proc_body(self.text, '/datum/admin_player_view/proc/follow_player_client()')
        self.assertIn('var/mob/M = target_client.mob', follow)
        self.assertIn('ghost.ManualFollow(M)', follow)
        tick = proc_body(self.text, '/datum/admin_player_view/proc/tick()')
        self.assertIn('if (active && !sync())\n\t\tstop(TRUE, TRUE)', tick)
        stop = proc_body(self.text, '/datum/admin_player_view/proc/stop(')
        self.assertLess(stop.index('put_back('), stop.index('if (live_view_unavailable)'))
        self.assertIn('Returned to your ghost view.', stop)

    def test_admin_map_view_button(self):
        text = read('code/modules/admin/verbs/admin_map.dm')
        self.assertIn("btn('View',function(){go('am=view&m='", text)
        topic = proc_body(text, '/datum/admin_map_controller/Topic(')
        self.assertLess(topic.index('admin_map_allowed(C)'), topic.index('admin_start_player_view'))
        self.assertLess(topic.index('admin_map_sees_players(C)'), topic.index('admin_start_player_view'))


if __name__ == '__main__':
    unittest.main()

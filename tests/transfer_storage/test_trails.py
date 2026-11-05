"""Source contracts for player-built trails. Never launches BYOND.

Players build a trail marker; it stays closed until an admin approves it and
confirms where it leads.
"""
import os
import re
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def read(path):
    with open(os.path.join(ROOT, path), encoding='utf-8-sig') as f:
        return f.read().replace('\r\n', '\n')


def proc(source, name):
    start = source.index('\n' + name + '(') + 1
    end = re.search(r'\n(?=[^\s#])', source[start + 1:])
    return source[start:start + 1 + end.start()] if end else source[start:]


TRAILS = read('code/modules/persistence/region_trails.dm')
MARKER = '/obj/structure/region_gate/trail_marker'


class TrailMarkerTests(unittest.TestCase):
    def test_players_can_build_one_from_wood(self):
        recipes = read('config/crafting/material_recipes_global.txt')
        self.assertRegex(recipes, r'(?m)^RECIPE: /material/wood/,trail marker,' + re.escape(MARKER) + ',')

    def test_included_after_the_gate(self):
        dme = read('civ13.dme')
        self.assertLess(dme.index('region_travel.dm"'), dme.index('region_trails.dm"'))

    def test_closed_until_approved(self):
        self.assertIn('var/approved = FALSE', TRAILS)
        body = proc(TRAILS, MARKER + '/closed_reason')
        self.assertLess(body.index('if(!approved)'), body.index('return ..()'))
        # Using an unapproved marker only asks; it never travels.
        use = proc(TRAILS, MARKER + '/attack_hand')
        self.assertLess(use.index('if(approved)'), use.index('request(user)'))

    def test_approval_is_saved(self):
        saved = re.search(r'map_storage_saved_vars = "([^"]+)"', TRAILS).group(1).split(';')
        for var in ('destination', 'approved', 'requested_destination', 'requester_ckey', 'approved_by'):
            self.assertIn(var, saved)

    def test_only_admins_approve_or_reject(self):
        topic = proc(TRAILS, MARKER + '/Topic')
        self.assertLess(topic.index('check_rights(R_ADMIN)'), topic.index('admin_approve('))
        approve = proc(TRAILS, MARKER + '/proc/admin_approve')
        # The destination prompt sleeps: rights are checked again after it.
        self.assertLess(approve.index('input('), approve.index('check_rights(R_ADMIN, TRUE, admin)'))

    def test_approval_needs_a_known_peer(self):
        body = proc(TRAILS, MARKER + '/proc/approve')
        self.assertLess(body.index('in shard_group.peers'), body.index('approved = TRUE'))

    def test_requests_are_rate_limited(self):
        body = proc(TRAILS, MARKER + '/proc/request')
        self.assertIn('world.time < next_request', body)
        self.assertIn('next_request = world.time + REGION_TRAIL_REQUEST_COOLDOWN', body)

    def test_admins_see_waiting_trails_in_the_regions_panel(self):
        panel = read('code/modules/persistence/shard_group.dm')
        self.assertIn('if(holder)\n\t\thtml += region_trail_pending_html()', panel)


if __name__ == '__main__':
    unittest.main()

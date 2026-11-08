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

    def test_requests_are_limited_per_player_and_rechecked_after_the_prompt(self):
        body = proc(TRAILS, MARKER + '/proc/request')
        self.assertGreater(body.index('request_refusal(user.client.ckey)', body.index('input(')), body.index('input('))
        self.assertIn('region_trail_next_request[requester_ckey] = world.time + REGION_TRAIL_REQUEST_COOLDOWN', body)
        refusal = proc(TRAILS, MARKER + '/proc/request_refusal')
        self.assertIn('requester_ckey != ckey', refusal)
        self.assertIn('REGION_TRAIL_PENDING_MAX', refusal)
        # The cooldown is runtime only, so a reload never inherits an old world.time.
        self.assertIn('var/global/list/region_trail_next_request = list()', TRAILS)
        self.assertNotIn('next_request', proc(TRAILS, MARKER + '/proc/admin_reject'))

    def test_unapproved_markers_never_catch_arrivals(self):
        self.assertIn(MARKER + '/accepts_arrivals()\n\treturn approved', TRAILS)
        travel = read('code/modules/persistence/region_travel.dm')
        body = proc(travel, '/proc/region_travel_arrival_turf')
        self.assertLess(body.index('gate.type == /obj/structure/region_gate'), body.index('gate.accepts_arrivals()'))

    def test_players_cannot_dismantle_a_gate_holding_a_traveller(self):
        self.assertNotIn('not_disassemblable = FALSE', TRAILS)
        travel = read('code/modules/persistence/region_travel.dm')
        body = proc(travel, '/obj/structure/region_gate/Destroy')
        self.assertLess(body.index('M.forceMove(T)'), body.index('return ..()'))

    def test_stale_admin_links_do_nothing(self):
        topic = proc(TRAILS, MARKER + '/Topic')
        self.assertLess(topic.index('href_list["trail_at"] != "[x],[y],[z]"'), topic.index('admin_approve('))

    def test_admins_see_waiting_trails_in_the_regions_panel(self):
        panel = read('code/modules/persistence/shard_group.dm')
        self.assertIn('if(holder)\n\t\thtml += shard_group.panel_admin_html() + region_trail_pending_html()', panel)

    def test_built_only_outdoors_at_the_edge_of_the_world(self):
        self.assertRegex(TRAILS, r'#define REGION_TRAIL_EDGE_TILES \d+')
        edge = proc(TRAILS, '/proc/region_trail_at_edge')
        self.assertIn('A.location != AREA_OUTSIDE', edge)
        self.assertIn('turf_is_above_ground(T)', edge)
        for side in ('T.x <= d', 'T.y <= d', 'T.x > world.maxx - d', 'T.y > world.maxy - d'):
            self.assertIn(side, edge)
        refusal = proc(TRAILS, '/proc/region_trail_build_refusal')
        # Launch pads are trail markers too, but only the plain marker is held to the edge.
        self.assertIn('result_type != ' + MARKER + ') return null', refusal)
        self.assertIn('edge of the world', refusal)
        stack = read('code/game/objects/items/stacks/stack.dm')
        # produce_recipe has column-0 comments, so search from its start.
        body = stack[stack.index('/obj/item/stack/proc/produce_recipe('):]
        check = body.index('region_trail_build_refusal(user, recipe.result_type)')
        # Refused before any wood is spent or the build wait starts.
        self.assertLess(check, body.index('if (recipe.time)'))
        self.assertLess(check, body.index('if (!can_use(required))'))


if __name__ == '__main__':
    unittest.main()

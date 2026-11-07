"""Source contracts for the party train station project. Never launches BYOND."""
import os
import re
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, ROOT)

from tools.rail_yard import yard  # noqa: E402


def read(path):
    with open(os.path.join(ROOT, path), encoding='utf-8-sig') as f:
        return f.read().replace('\r\n', '\n')


def proc(source, name):
    start = source.index('\n' + name + '(') + 1
    end = re.search(r'\n(?=[^\s#])', source[start + 1:])
    return source[start:start + 1 + end.start()] if end else source[start:]


TRAIN = read('code/modules/persistence/party_train.dm')
OFFICE = '/obj/structure/region_gate/railway_station'
BERTH = '/obj/structure/region_gate/rail_berth'
DOOR = '/obj/structure/simple_door/party_train'
TRAVEL = read('code/modules/persistence/region_travel.dm')


class PartyTrainTests(unittest.TestCase):
    def test_the_yard_world_is_named_rail_yard(self):
        # The yard map uses plain Nomads metadata ("Nomads (Temperate)").
        group = read('code/modules/persistence/shard_group.dm')
        hook = group[group.index('/hook/startup/proc/shard_group_startup()'):]
        self.assertIn('shard_group.kind == "RAILYARD" && map && map.type == /obj/map_metadata/nomads', hook)
        self.assertIn('map.title = "Rail Yard"', hook)

    def test_built_from_the_crafting_menu_and_included_after_the_gate(self):
        recipes = read('config/crafting/material_recipes_global.txt')
        self.assertRegex(recipes, r'(?m)^RECIPE: /material/wood/,railway works office,' + re.escape(OFFICE) + ',')
        dme = read('civ13.dme')
        self.assertLess(dme.index('region_travel.dm"'), dme.index('party_train.dm"'))

    def test_a_station_needs_straight_track_to_the_map_edge(self):
        start = proc(TRAIN, OFFICE + '/proc/start')
        self.assertLess(start.index('station_problem()'), start.index('party = new_party'))
        self.assertIn('if(party_train_rail_to_edge(T))', proc(TRAIN, OFFICE + '/proc/station_problem'))
        # No fixed rail count any more: the line has to leave the land.
        self.assertNotIn('PARTY_TRAIN_TRACK_MIN', TRAIN)
        edge = proc(TRAIN, '/proc/party_train_rail_to_edge')
        self.assertIn('for(var/d in list(NORTH, SOUTH, EAST, WEST))', edge)
        self.assertIn('while(step && party_train_rail_at(step))', edge)
        self.assertIn('if(!get_step(last, d))', edge)
        self.assertNotIn('count <', edge)

    def test_a_finished_train_leaves_only_while_the_track_reaches_the_edge(self):
        closed = proc(TRAIN, OFFICE + '/closed_reason')
        self.assertLess(closed.index('if(!completed)'), closed.index('station_problem()'))
        self.assertLess(closed.index('station_problem()'), closed.index('return ..()'))

    def test_one_project_per_party_rechecked_after_the_prompt(self):
        start = proc(TRAIN, OFFICE + '/proc/start')
        prompt = start.index('alert(')
        self.assertLess(start.index('party_train_office_of(new_party, src)'), prompt)
        self.assertGreater(start.index('party_train_office_of(new_party, src)', prompt), prompt)

    def test_the_party_and_track_are_rechecked_after_the_prompt(self):
        start = proc(TRAIN, OFFICE + '/proc/start')
        prompt = start.index('alert(')
        self.assertGreater(start.index('party_train_party_of(user) != new_party', prompt), prompt)
        self.assertGreater(start.index('station_problem()', prompt), prompt)

    def test_a_renamed_faction_keeps_its_train(self):
        rename = proc(read('code/game/mob/groups/faction_rename.dm'), '/obj/map_metadata/proc/rename_faction')
        self.assertIn('party_train_rename_faction(old_name, new_name)', rename)
        renamed = proc(TRAIN, '/proc/party_train_rename_faction')
        self.assertIn('S.party = new_party', renamed)
        self.assertIn('H.party_train_party = new_party', renamed)

    def test_the_office_survives_vehicles_and_blasts(self):
        self.assertIn('crushable = FALSE', TRAIN)
        self.assertIn(OFFICE + '/ex_act(severity)\n\treturn', TRAIN)

    def test_trails_never_lead_to_the_rail_yard(self):
        choices = proc(read('code/modules/persistence/region_trails.dm'), '/obj/structure/region_gate/trail_marker/proc/peer_choices')
        self.assertIn('if(peer["kind"] == "RAILYARD") continue', choices)

    def test_closed_until_every_material_is_delivered(self):
        closed = proc(TRAIN, OFFICE + '/closed_reason')
        self.assertLess(closed.index('if(!completed)'), closed.index('return ..()'))
        give = proc(TRAIN, OFFICE + '/attackby')
        # Only what is still missing is taken, and completion follows the last delivery.
        self.assertIn('min(missing, S.amount)', give)
        self.assertLess(give.index('S.use(amount)'), give.index('complete(user)'))
        self.assertIn('if(!length(remaining()))', give)

    def test_only_the_party_boards_and_only_to_the_rail_yard(self):
        refusal = proc(TRAIN, OFFICE + '/travel_refusal')
        self.assertIn('if(!party_train_may_board(H, party))', refusal)
        self.assertIn('peer["kind"] == "RAILYARD"', proc(TRAIN, OFFICE + '/proc/rail_yard'))
        self.assertIn(OFFICE + '/accepts_arrivals()\n\treturn FALSE', TRAIN)

    def test_progress_is_saved(self):
        saved = re.search(r'map_storage_saved_vars = "([^"]+)"', TRAIN).group(1).split(';')
        for var in ('party', 'delivered', 'completed', 'completed_at', 'boarded'):
            self.assertIn(var, saved)

    def test_rail_yard_is_a_region_kind(self):
        self.assertIn("'RAILYARD'", read('scripts/shard-group/shard_group.py'))
        self.assertIn('"RAILYARD"', read('code/modules/persistence/shard_group.dm'))


class RailYardTests(unittest.TestCase):
    def test_trips_through_a_train_carry_the_party_and_where_they_left(self):
        depart = proc(TRAVEL, '/obj/structure/region_gate/proc/depart')
        self.assertIn('region_travel_payload(items, travel_party(H), ', depart)
        payload = proc(TRAVEL, '/mob/living/human/proc/region_travel_payload')
        self.assertIn('P["from"] = shard_group.region', payload)
        decode = proc(TRAVEL, '/proc/region_travel_decode')
        self.assertIn('party_train_valid_party(P["party"])', decode)
        for gate in (OFFICE, BERTH):
            self.assertIn(gate + '/travel_party(mob/living/human/H)\n\treturn party', TRAIN)

    def test_party_trips_arrive_at_the_berth_or_the_station(self):
        arrive = proc(TRAVEL, '/proc/region_travel_arrive')
        self.assertLess(arrive.index('party_train_arrival_turf(P) || T'), arrive.index('region_travel_build(P, at)'))
        self.assertIn('H.party_train_party = P["party"]', proc(TRAVEL, '/proc/region_travel_build'))
        turf = proc(TRAIN, '/proc/party_train_arrival_turf')
        self.assertIn('party_train_berth_of(party) || party_train_assign_berth(party)', turf)
        self.assertIn('party_train_office_of(party)', turf)
        self.assertNotIn('sleep', turf)

    def test_factions_of_the_same_name_in_different_lands_are_different_parties(self):
        self.assertIn('party_train_faction_party(H.civilization)', proc(TRAIN, '/proc/party_train_party_of'))
        self.assertIn('"civ:[shard_group.enabled ? shard_group.region : "local"]:[name]"', proc(TRAIN, '/proc/party_train_faction_party'))

    def test_only_the_party_boards_its_train_or_opens_its_doors(self):
        self.assertIn('if(!party_train_may_board(H, party))', proc(TRAIN, BERTH + '/travel_refusal'))
        self.assertIn(BERTH + '/accepts_arrivals()\n\treturn FALSE', TRAIN)
        self.assertIn('return party && party_train_party_of(user) == party', proc(TRAIN, '/proc/party_train_may_board'))
        self.assertIn('party_train_may_board(user, owner_party())', proc(TRAIN, DOOR + '/proc/party_member'))
        self.assertIn(DOOR + '/canOpen(mob/user)\n\treturn forced || party_member(user)', TRAIN)
        self.assertIn(DOOR + '/Dismantle(devastated = FALSE)\n\treturn', TRAIN)

    def test_raiders_force_doors_only_while_the_owners_are_here(self):
        self.assertIn('return party_members_online(party)', proc(TRAIN, '/proc/party_train_breachable'))
        online = proc(TRAIN, '/proc/party_members_online')
        self.assertIn('H.client && H.stat != DEAD && party_train_party_of(H) == party', online)
        breach = proc(TRAIN, DOOR + '/proc/breach')
        self.assertLess(breach.index('party_train_breachable(party)'), breach.index('breach_left -= amount'))
        self.assertLess(breach.index('breach_left -= amount'), breach.index('forced = TRUE'))
        self.assertNotIn('qdel', breach)
        attack = proc(TRAIN, DOOR + '/attackby')
        self.assertLess(attack.index('if(party_member(user))'), attack.index('breach(W.force, user)'))
        for hook in ('/bullet_act', '/ex_act', '/door_kick'):
            self.assertIn('breach(', proc(TRAIN, DOOR + hook))

    def test_the_party_secures_a_forced_door(self):
        secure = proc(TRAIN, DOOR + '/proc/secure')
        self.assertIn('forced = FALSE', secure)
        self.assertIn('breach_left = PARTY_TRAIN_DOOR_STRENGTH', secure)
        self.assertIn('if(forced && party_member(user))', proc(TRAIN, DOOR + '/attack_hand'))

    def test_the_saved_party_counts_only_in_the_yard(self):
        party_of = proc(TRAIN, '/proc/party_train_party_of')
        yard_rule = party_of.index('shard_group.kind == "RAILYARD" && party_train_valid_party(H.party_train_party)')
        self.assertLess(yard_rule, party_of.index('H.civilization'))
        self.assertEqual(party_of.count('H.party_train_party'), 2)
        # Coming home, a member rejoins the faction that owns the train.
        self.assertIn('party_train_restore_faction(H, P["party"])', proc(TRAVEL, '/proc/region_travel_build'))
        restore = proc(TRAIN, '/proc/party_train_restore_faction')
        self.assertIn('if(name in map.custom_civs)', restore)
        self.assertIn('"civ:[shard_group.region]:"', restore)

    def test_a_solo_party_belongs_only_to_its_player(self):
        self.assertIn('P["party"] != "ckey:[owner]"', proc(TRAVEL, '/proc/region_travel_decode'))

    def test_a_new_party_never_boards_for_a_full_yard(self):
        closed = proc(TRAIN, OFFICE + '/closed_reason')
        self.assertIn('if(!boarded && shard_group.peers[destination]["free_berths"] == 0)', closed)
        self.assertIn('boarded = TRUE', proc(TRAIN, OFFICE + '/depart'))
        group = read('code/modules/persistence/shard_group.dm')
        self.assertIn('.["free_berths"] = party_train_free_berths()', proc(group, '/datum/shard_group/proc/describe'))
        self.assertIn('peer["free_berths"] = isnum(reply["free_berths"])', group)

    def test_projects_need_the_region_group(self):
        start = proc(TRAIN, OFFICE + '/proc/start')
        self.assertLess(start.index('if(!shard_group.enabled)'), start.index('party = new_party'))

    def test_berths_are_saved_and_lead_home(self):
        saved = re.search(BERTH.replace('/', r'\/') + r'\n(?:\t.*\n)*?\tmap_storage_saved_vars = "([^"]+)"', TRAIN).group(1).split(';')
        for var in ('destination', 'berth', 'party', 'home_region'):
            self.assertIn(var, saved)
        closed = proc(TRAIN, BERTH + '/closed_reason')
        self.assertLess(closed.index('destination = home_region'), closed.index('return ..()'))

    def test_the_yard_map_has_one_party_train_per_numbered_berth(self):
        yard.verify_types(ROOT)
        cells, width, height = yard.layout(6, 2)
        berths = [int(m.group(1)) for r in cells.values() for m in [re.search(r'rail_berth\{berth = (\d+)', r)] if m]
        self.assertEqual(sorted(berths), [1, 2, 3, 4, 5, 6])
        doors = [int(m.group(1)) for r in cells.values() for m in [re.search(r'party_train\{berth = (\d+)', r)] if m]
        self.assertEqual(sorted(set(doors)), [1, 2, 3, 4, 5, 6])
        # Every train is closed: walls or party doors all round its floor.
        for (x, y, z), recipe in cells.items():
            if yard.TRAIN_AREA in recipe and yard.WALL not in recipe and "simple_door" not in recipe:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    self.assertIn(yard.TRAIN_AREA, cells[(x + dx, y + dy, z)], (x, y))
        self.assertEqual(sum(yard.METADATA in r for r in cells.values()), 1)
        self.assertTrue(any('JoinLateCiv' in r for r in cells.values()))

    def test_the_default_yard_holds_many_parties_within_size_limits(self):
        width, height, _ = yard.size(96, 4)
        self.assertLessEqual(max(width, height), yard.MAX_SIDE)
        with self.assertRaises(ValueError):
            yard.layout(400, 4)

    def test_rail_yard_text_round_trips(self):
        cells, width, height = yard.layout(2, 1)
        text = yard.write_text(cells, width, height)
        self.assertEqual(text.count('(1,1,'), 2)
        rows = text.split('(1,1,2) = {"\n')[1].split('\n"}')[0].split('\n')
        self.assertEqual(len(rows), height)
        self.assertEqual({len(r) for r in rows}, {width * len(text.split('"')[1])})


if __name__ == '__main__':
    unittest.main()

"""Source contracts for raid worlds (region_raid.dm). Never launches BYOND."""
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


RAID = read('code/modules/persistence/region_raid.dm')
TRAVEL = read('code/modules/persistence/region_travel.dm')
HOME = read('code/modules/persistence/region_home.dm')
EXIT = '/obj/structure/region_gate/raid_exit'


class RegionRaidTests(unittest.TestCase):
    def test_raid_is_a_region_kind_everywhere(self):
        self.assertIn('"RAID"', read('code/modules/persistence/shard_group.dm'))
        self.assertIn("'RAID'", read('scripts/shard-group/shard_group.py'))
        dme = read('civ13.dme')
        self.assertLess(dme.index('region_travel.dm"'), dme.index('region_raid.dm"'))

    def test_a_trip_into_a_raid_world_says_where_it_came_from(self):
        payload = proc(TRAVEL, '/mob/living/human/proc/region_travel_payload')
        self.assertIn('else if(raid)\n\t\tP["from"] = shard_group.region', payload)
        depart = proc(TRAVEL, '/obj/structure/region_gate/proc/depart')
        self.assertIn('H.region_travel_payload(items, travel_party(H), region_raid_peer(destination))', depart)
        self.assertIn('region_raid_note_origin(H, P)', proc(TRAVEL, '/proc/region_travel_build'))

    def test_origin_is_only_kept_in_a_raid_world_and_never_another_raid(self):
        note = proc(RAID, '/proc/region_raid_note_origin')
        self.assertIn('!region_raid_world()', note)
        self.assertIn('from != shard_group.region && (from in shard_group.peers) && !region_raid_peer(from)', note)

    def test_the_exit_leads_each_raider_home_and_keeps_a_busy_destination(self):
        refusal = proc(RAID, EXIT + '/travel_refusal')
        busy = refusal.index('if(busy)')
        self.assertLess(busy, refusal.index('destination = H.raid_origin'))
        self.assertLess(refusal.index('destination = H.raid_origin'), refusal.index('return ..()'))
        self.assertIn('return FALSE', proc(RAID, EXIT + '/accepts_arrivals'))

    def test_a_raid_death_goes_home_before_the_mainland_rule(self):
        death = proc(HOME, '/proc/region_home_death')
        self.assertLess(death.index('var/origin = region_raid_death_origin(H)'), death.index('if(!origin)'))
        self.assertLess(death.index('if(!origin)'), death.index('region_home_bed(account)'))
        self.assertIn('region_home_note(account, origin ? "depart" : "release", origin)', death)
        self.assertIn('return origin', proc(RAID, '/proc/region_raid_death_origin'))


if __name__ == '__main__':
    unittest.main()

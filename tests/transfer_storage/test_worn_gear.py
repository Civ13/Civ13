"""Source contracts for worn gear on a region trip. Never launches BYOND.

A traveller's own slots may hold material tools and weapons, single live
rounds and filled bags. Freight, landers and ship holds keep their own,
narrower codec.
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


TRAVEL = read('code/modules/persistence/region_travel.dm')
GEAR = read('code/modules/persistence/region_travel_gear.dm')
GENERIC = read('code/modules/persistence/region_travel_generic.dm')


class WornGearTests(unittest.TestCase):
    def test_included_after_travel(self):
        dme = read('civ13.dme')
        self.assertLess(dme.index('region_travel.dm"'), dme.index('region_travel_gear.dm"'))

    def test_only_the_travellers_own_slots_use_the_worn_kinds(self):
        self.assertIn('if(!region_travel_worn_kind(I))', proc(TRAVEL, '/mob/living/human/proc/region_travel_items'))
        self.assertIn('var/kind = region_travel_worn_kind(I)', proc(TRAVEL, '/mob/living/human/proc/region_travel_payload'))
        # The shared codec that freight, landers and holds build from knows none of them.
        for name in ('/proc/region_travel_item_kind', '/proc/region_travel_item_path', '/proc/region_travel_make_item'):
            body = proc(TRAVEL, name)
            for kind in ('gear:', 'bag:', 'round:', 'region_travel_worn', 'region_travel_loose'):
                self.assertNotIn(kind, body, name)
        for path in ('code/modules/persistence/party_freight.dm', 'code/modules/space/lander.dm'):
            self.assertNotIn('region_travel_worn', read(path), path)

    def test_ship_decks_and_chests_carry_what_a_traveller_can(self):
        ship = read('code/modules/naval/ship_crossing.dm')
        self.assertIn('return region_travel_worn_entry(I)', proc(ship, '/proc/sea_crossing_item_entry'))
        self.assertNotIn('region_travel_item_path', ship)
        self.assertNotIn('region_travel_make_item', ship)

    def test_arrivals_are_checked_and_built_through_the_worn_codec(self):
        self.assertIn('if(!region_travel_worn_valid(entry[2], entry[3])) return null', proc(TRAVEL, '/proc/region_travel_decode'))
        self.assertIn('region_travel_make_worn(entry[2], entry[3], T)', proc(TRAVEL, '/proc/region_travel_build'))
        self.assertIn('region_travel_worn_matches(I, entry[2])', proc(TRAVEL, '/proc/region_travel_replay_departure'))

    def test_gear_fields_are_bounded(self):
        body = proc(GEAR, '/proc/region_travel_gear_record')
        for line in ('if(!(key in list("t", "m", "q", "mh", "h", "p", "s"))) return null',
                     'if(!ispath(path, /obj/item/weapon/material)) return null',
                     'if(!istext(R["m"]) || !get_material_by_name(R["m"])) return null',
                     'if(!isnum(R["h"]) || R["h"] <= 0 || R["h"] > R["mh"]) return null'):
            self.assertIn(line, body)

    def test_bags_hold_one_level_and_arrive_with_only_what_travelled(self):
        record = proc(GEAR, '/proc/region_travel_bag_record')
        self.assertIn('if(!ispath(path, /obj/item/weapon/storage)) return null', record)
        self.assertNotIn('region_travel_bag_record(entry', record)
        self.assertNotIn('region_travel_worn_valid', record)
        build = proc(GEAR, '/proc/region_travel_make_bag')
        self.assertLess(build.index('B.startswith = null'), build.index('qdel(A)'))
        self.assertLess(build.index('qdel(A)'), build.index('region_travel_make_loose'))

    def test_a_round_travels_only_as_new(self):
        body = proc(GEAR, '/proc/region_travel_round_kind')
        self.assertIn('C.BB.type != C.projectile_type', body)
        self.assertIn('C.name != initial(C.name)', body)

    def test_anything_else_travels_whole(self):
        dme = read('civ13.dme')
        self.assertLess(dme.index('region_travel_gear.dm"'), dme.index('region_travel_generic.dm"'))
        worn = proc(GEAR, '/proc/region_travel_worn_kind')
        self.assertLess(worn.index('region_travel_bag_kind(I)'), worn.index('region_travel_generic_kind(I)'))
        # A plain item with a name or colour of its own is not rebuilt by type alone.
        self.assertIn('region_travel_generic_has_state(I)', proc(GEAR, '/proc/region_travel_held_kind'))
        self.assertIn('region_travel_generic_kind(I)', proc(GEAR, '/proc/region_travel_bag_blockers'))

    def test_whole_items_are_bounded_and_checked(self):
        record = proc(GENERIC, '/proc/region_travel_generic_record_valid')
        for line in ('if(!(key in list("t", "v", "m", "r", "c"))) return FALSE',
                     'if(!region_travel_generic_type_ok(path)) return FALSE',
                     'if(!region_travel_generic_field_ok(key) || !region_travel_generic_value_ok(fields[key])) return FALSE',
                     '!get_material_by_name(mats[key])',
                     '!chemical_reagents_list[pair[1]]',
                     'if(!region_travel_generic_record_valid(child, depth + 1)) return FALSE'):
            self.assertIn(line, record)
        for field in ('"loc"', '"contents"', '"type"', '"vars"', '"key"', '"ckey"', '"screen_loc"'):
            self.assertIn(field, GENERIC.split('var/global/list/region_travel_generic_skip')[1].split(')')[0])
        self.assertIn('/obj/item/weapon/grab, /obj/item/organ', proc(GENERIC, '/proc/region_travel_generic_type_ok'))
        # A creature inside never travels, and links to other things stay behind.
        capture = proc(GENERIC, '/proc/region_travel_generic_capture')
        self.assertIn('if(ismob(A)) return null', capture)
        self.assertIn('I.persistence_runtime_var(key)', capture)

    def test_parts_an_item_makes_itself_are_not_doubled(self):
        build = proc(GENERIC, '/proc/region_travel_generic_build')
        self.assertIn('region_travel_generic_build(child, I, match)', build)
        self.assertLess(build.index('fresh -= match'), build.index('qdel(A)'))

    def test_a_blocked_bag_names_what_to_take_out(self):
        self.assertIn('take out [english_list(inside)]', proc(TRAVEL, '/mob/living/human/proc/region_travel_items'))


if __name__ == '__main__':
    unittest.main()

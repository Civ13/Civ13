"""Source contracts for playing in the TDM Barracks (player reports 2026-11-08). Never launches BYOND."""
import unittest

from test_region_raid import proc, read

ANNEX = read('code/modules/tdm_barracks/barracks_annex.dm')
WORLD = read('code/modules/tdm_barracks/barracks_world.dm')


class BarracksPlayTests(unittest.TestCase):
    def test_a_called_car_has_a_lock_and_its_caller_gets_the_key(self):
        build = proc(ANNEX, '/obj/structure/barracks/vehicle_bay/proc/build')
        self.assertIn('PV.doorcode = rand(1000, 9999)', build)
        self.assertIn('K.code = PV.doorcode', build)
        self.assertIn('user.put_in_hands(K)', build)
        self.assertIn('build(user)', proc(ANNEX, '/obj/structure/barracks/vehicle_bay/attack_hand'))

    def test_only_booted_players_on_the_pitch_keep_the_ball(self):
        dribble = proc(WORLD, '/proc/barracks_can_dribble')
        self.assertIn('istype(map, /obj/map_metadata/football)', dribble)
        self.assertIn('/obj/item/clothing/shoes/football', dribble)
        self.assertIn('/area/caribbean/barracks/pitch', dribble)
        for name in ('/obj/item/football/Crossed', '/obj/item/football/update_movement',
                     '/mob/living/human/football_bump', '/mob/living/human/football_hitby'):
            self.assertIn('barracks_can_dribble(', proc(WORLD, name), name)

    def test_football_kit_comes_off_outside_the_football_map(self):
        for kit in ('shoes', 'under'):
            body = proc(WORLD, f'/obj/item/clothing/{kit}/football/mob_can_unequip')
            self.assertIn('return barracks_kit_unequip(src, M, slot, disable_warning)', body)


if __name__ == '__main__':
    unittest.main()

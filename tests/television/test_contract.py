"""Offline source/recipe contracts; native assertions are in game.dm, never run here."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/modules/1713/television.dm').read_text()
TELECOM = (ROOT / 'code/modules/1713/modern_telecom.dm').read_text()


def procedure(path, source=SOURCE):
    return source.split(path + '\n', 1)[1].split('\n/', 1)[0]


class TelevisionContracts(unittest.TestCase):
    def test_shared_1969_era_and_crafting_gates(self):
        self.assertIn('#define CIV_TELECOM_TV_AGE 7', TELECOM)
        self.assertIn('#define CIV_TELECOM_MODERN_AGE 8', TELECOM)
        era = procedure('/proc/civ_telecom_required_age(result_type)', TELECOM)
        for path in ('/obj/structure/telecom/tv', '/obj/structure/telecom/station/tv', '/obj/item/tv_camera'):
            self.assertIn(path, era)
        self.assertIn('return CIV_TELECOM_TV_AGE', era)
        self.assertNotIn('/obj/structure/telecom/terminal', era)
        self.assertNotIn('/obj/item/weapon/telephone/landline', era)

    def test_radio_pipeline_includes_tv_but_does_not_cross_radio_relays(self):
        live = procedure('/obj/structure/telecom/station/proc/transmit_live(mob/living/human/H, message, datum/language/speaking)', TELECOM)
        self.assertNotIn('if (television ||', live)
        self.assertIn('node_receiver_available(R)', live)
        self.assertIn('if (!television) civ_relay_outbound', live)
        node = (ROOT / 'code/modules/research_tree/node_broadcast.dm').read_text()
        self.assertNotIn('if (television || node_lesson_id', node)
        self.assertIn('R.television == television', node)

    def test_camera_pairing_is_physical_not_network_text_entry(self):
        pair = procedure('/obj/structure/telecom/station/tv/proc/pair_camera(mob/living/human/H, obj/item/tv_camera/C)')
        for condition in ('can_present(H)', 'H.can_use_hands()', 'C.loc != H', 'C.network_id = tv_network_id', 'C.frequency = frequency'):
            self.assertIn(condition, pair)
        available = procedure('/obj/structure/telecom/station/tv/proc/camera_available(obj/item/tv_camera/C)')
        for condition in ('C.network_id == tv_network_id', 'C.frequency == frequency', 'T.z == z', 'get_dist(src, T) <= 60', 'C.operational()'):
            self.assertIn(condition, available)
        self.assertNotRegex(SOURCE, r'network_id\s*=\s*input')

    def test_feed_cuts_and_view_ownership(self):
        feed = procedure('/obj/structure/telecom/tv/proc/feed_ok(mob/living/human/H)')
        for condition in ('H.using_object == src', 'get_turf(H) == tv_watchers[H]', 'get_turf(src) == receiver_origin', 'watching_station.video_available()'):
            self.assertIn(condition, feed)
        video = procedure('/obj/structure/telecom/station/tv/proc/video_available()')
        for condition in ('operational()', 'has_antenna()', 'get_turf(src) == video_desk_origin', 'video_camera.camera_eye() == video_eye', 'get_turf(video_camera) == video_camera_origin'):
            self.assertIn(condition, video)
        stop = procedure('/obj/structure/telecom/tv/proc/stop_watching(mob/living/human/H)')
        self.assertLess(stop.index('H.using_object == src'), stop.index('H.reset_view(null)'))
        self.assertIn('H.reset_view(S.video_eye)', SOURCE)
        self.assertIn('civ_tick_television()', TELECOM)

    def test_ui_and_equipment_movement_interrupt_synchronously(self):
        for kind, stop in (('tv', 'stop_all_watching()'), ('station/tv', 'stop_video()')):
            owner = '/obj/structure/telecom/' + kind
            for signature in ('/interrupt_node_reception()', '/Move()', '/forceMove(atom/destination, var/special_event)'):
                self.assertIn(stop, procedure(owner + signature))
        self.assertIn('civ_tick_tv_views()', procedure('/obj/item/tv_camera/forceMove(atom/destination, var/special_event)'))

    def test_saved_camera_and_network_but_no_viewer_references(self):
        for field in ('network_id', 'frequency', 'enabled', 'camera_health', 'battery_charge', 'tv_network_id'):
            self.assertRegex(SOURCE, r'var/' + field + r'\s*=')
            self.assertNotRegex(SOURCE, r'var/tmp/[^\n]*\b' + field + r'\b')
        for field in ('video_camera', 'video_eye', 'video_desk_origin', 'video_camera_origin', 'tv_watchers', 'watching_station', 'receiver_origin', 'receiver_eye'):
            self.assertRegex(SOURCE, r'var/tmp/[^\n]*\b' + field + r'\b')
            self.assertIn('"' + field + '"', SOURCE)
        self.assertIn('/obj/structure/telecom/station/tv/after_load()', SOURCE)
        self.assertIn('/obj/structure/telecom/tv/after_load()', SOURCE)
        self.assertNotIn('tv_network_id', (ROOT / 'code/modules/persistence/durable_contract.dm').read_text())

    def test_visible_powered_helmet_and_destructible_cameras(self):
        eye = procedure('/obj/item/tv_camera/proc/camera_eye()')
        self.assertIn('wearer.head == H', eye)
        self.assertIn('isturf(loc) && anchored', eye)
        self.assertIn('portable ? battery_charge > 0 : draw_cable_power()', SOURCE)
        self.assertIn('battery_charge = max(0, C.battery_charge - 1)', SOURCE)
        self.assertIn('camera_health -= W.force', SOURCE)
        self.assertIn('camera_health -= P.damage', SOURCE)
        head = (ROOT / 'code/modules/1713/cmss13_overwatch.dm').read_text()
        self.assertIn('A visible television camera is clipped to it.', head)

    def test_registry_and_audience_bounds(self):
        self.assertIn('#define CIV_TV_CAMERA_LIMIT 128', SOURCE)
        self.assertIn('#define CIV_TV_VIEWER_LIMIT 32', SOURCE)
        self.assertIn('count += R.tv_watchers.len', SOURCE)
        self.assertIn('count >= CIV_TV_VIEWER_LIMIT', SOURCE)
        self.assertNotIn(' in world', SOURCE)

    def test_recipes_and_safe_legacy_retirement(self):
        nodes = (ROOT / 'code/modules/research_tree/research_node.dm').read_text()
        recipes = (ROOT / 'config/crafting/material_recipes_global.txt').read_text()
        for suffix in ('', '/street', '/helmet'):
            path = '/obj/item/tv_camera' + suffix
            self.assertIn('"' + path + '" = "assembly_line"', nodes)
            self.assertIn(path + ',4,100,1,1,none,160,0,0,8,null', recipes)
        for p in (ROOT / 'config/crafting').glob('*.txt'):
            self.assertNotIn('/obj/structure/TV/television,', p.read_text())
        legacy = (ROOT / 'code/game/objects/structures/appliances.dm').read_text()
        self.assertIn('/obj/structure/TV/grandfather/attackby', legacy)
        self.assertIn('/obj/structure/TV/television/attackby', legacy)
        self.assertIn('legacy decorative', legacy)

    def test_isolated_fixture_and_opt_in_native(self):
        runner = (ROOT / 'tests/television/run.py').read_text()
        self.assertIn('if not args.compile_only and not args.trusted:', runner)
        self.assertIn('if args.compile_only:', runner)
        fixture = (ROOT / 'tests/television/game.dm').read_text()
        for label in ('actual cable supply loss', 'foreign camera network', 'helmet battery depletion', 'native television world reload', 'camera and settings persist', 'receiver restores without viewer references', 'TV full-series node lesson completes'):
            self.assertIn(label, fixture)
        self.assertIn('return port == "none" ? ..() : FALSE', fixture)

if __name__ == '__main__':
    unittest.main()

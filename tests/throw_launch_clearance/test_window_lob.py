"""Offline entry-point and flight-boundary contracts. See window_lob_probe.dm
for native movement, fitting, roof, range and fuse checks."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/modules/multiz/window_lob.dm').read_text()


def body(name):
    return SOURCE.split(f'{name}(', 1)[1].split('\n/', 1)[0]


class WindowLobContracts(unittest.TestCase):
    def test_verbal_entry_guards_hold_and_view_before_and_after_preview(self):
        verb = body('/mob/living/human/verb/lob_at_upper_window')
        for guard in ('window_lob_can_hold(G, ground)', 'look_up_target() != upper_eye'):
            self.assertIn(guard, verb[:verb.index('player_alert(src,')])
            self.assertIn(guard, verb[verb.index('player_alert(src,'):verb.index('unEquip(G,')])
        self.assertIn('target in visible_upper', verb)
        self.assertIn('outside != current_outside || inside != window_lob_inside', verb)
        self.assertIn('persistence_movement_allowed(G, ground)', verb)

    def test_one_deliberate_cross_level_landing_with_no_fuse_mutation(self):
        start = body('/obj/item/weapon/grenade/proc/start_window_lob')
        hop = body('/obj/item/weapon/grenade/proc/window_lob_hop')
        self.assertIn('throw_flight_token["window_lob_path"] = path', start)
        self.assertIn('throw_flight_token != flight', hop)
        self.assertIn('get_step(here, direction) != target', hop)
        self.assertIn('window_lob_inside(H, here, opening, direction)', hop)
        self.assertIn('isnull(throw_flight_token)', hop)
        self.assertIn('!advanced && throw_flight_token == flight', hop)
        for text in ('det_time', 'active =', 'activate(', 'prime(', 'sleep(', 'spawn('):
            self.assertNotIn(text, SOURCE)

    def test_window_candidate_is_not_an_unrestricted_vertical_destination(self):
        inside = body('/proc/window_lob_inside')
        for rule in ('building_upper_z(outside.z) != opening.z',
                     'window_lob_open_column(outside, opening.z)',
                     'get_step(upper_outside, direction) != opening',
                     'window_lob_floor(inside)', 'window_lob_grace_blocked(H, inside)'):
            self.assertIn(rule, inside)

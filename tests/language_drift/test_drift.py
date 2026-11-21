"""Language drift: pacing numbers and the source boundaries that keep drift
cheap, saved with the world and limited to heard speech. Offline only."""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def read(path):
    return (ROOT / path).read_text(encoding='utf-8', errors='replace')


D = {k: float(v) for k, v in re.findall(r'#define (LANGUAGE_\w+) ([\d.]+)', read('code/__defines/species_languages.dm'))}
DRIFT = read('code/game/mob/language/drift.dm')


def proc(name):
    body = DRIFT[DRIFT.index(name):]
    nxt = re.search(r'\n(?=/|#|var/)', body[len(name):])
    return body[:len(name) + nxt.start()] if nxt else body


def step(use, contact):
    total = use + contact
    return D['LANGUAGE_DRIFT_GAIN'] * (1 - 2 * contact / total) if total else 0


class Pacing(unittest.TestCase):
    def test_an_isolated_nation_needs_days_of_talk_to_split(self):
        ticks = D['LANGUAGE_SPLIT_DRIFT'] / D['LANGUAGE_DRIFT_GAIN']
        hours = ticks * D['LANGUAGE_DRIFT_TICK'] / 36000
        self.assertTrue(40 <= hours <= 100, hours)

    def test_a_listener_can_fill_a_tick_alone_but_not_flood_it(self):
        per_tick = D['LANGUAGE_DRIFT_TICK'] / D['LANGUAGE_DRIFT_HEAR_COOLDOWN']
        self.assertGreater(per_tick, D['LANGUAGE_DRIFT_MIN_LINES'])
        self.assertLessEqual(per_tick, 100)

    def test_contact_slows_then_reverses_drift(self):
        self.assertEqual(step(40, 0), D['LANGUAGE_DRIFT_GAIN'])
        self.assertAlmostEqual(step(30, 10), D['LANGUAGE_DRIFT_GAIN'] / 2)
        self.assertEqual(step(20, 20), 0)
        self.assertLess(step(10, 30), 0)
        self.assertIn('LANGUAGE_DRIFT_GAIN * (1 - 2 * contact / total)', proc('/proc/language_drift_step('))

    def test_split_needs_a_real_community(self):
        self.assertGreaterEqual(D['LANGUAGE_SPLIT_MIN_NATIVES'], 3)
        self.assertTrue(D['LANGUAGE_BROKEN'] < D['LANGUAGE_SPLIT_DRIFT'] < 100)


class Boundaries(unittest.TestCase):
    def test_only_heard_speech_feeds_drift_once_per_line(self):
        hear = read('code/game/mob/hear_say.dm')
        self.assertEqual(hear.count('language_drift_heard('), 1)
        self.assertLess(hear.index('H.language_exposure(language, speaker)'), hear.index('H.language_drift_heard(language, speaker)'))

    def test_heard_line_is_cheap_and_gated(self):
        body = proc('/mob/living/human/proc/language_drift_heard(')
        first = body.split('\n')[1]
        self.assertIn('civilization == "none"', first)
        self.assertIn('world.time < next_language_drift_heard', first)
        self.assertIn('mother_tongue() != L', body)
        self.assertIn('S.language_score(L) >= LANGUAGE_CONVERSATIONAL', body)
        self.assertNotIn('for (', body)

    def test_quiet_communities_do_not_change_and_lines_reset(self):
        body = proc('/proc/language_drift_tick(')
        self.assertIn('total < LANGUAGE_DRIFT_MIN_LINES', body)
        self.assertIn('language_drift_use = list()', body)
        self.assertIn('language_drift_contact = list()', body)

    def test_drift_is_clamped_and_saved_in_the_world_field(self):
        body = proc('/proc/set_language_drift(')
        self.assertIn('clamp(', body)
        self.assertIn('drift -= key', body)
        table = proc('/proc/language_drift_table(')
        self.assertIn('map.language_lineage_state', table)
        self.assertIn('state["daughters"]', table)
        contract = read('code/modules/persistence/durable_contract.dm')
        self.assertIn('"language_lineage_state"', contract)
        self.assertIn('if(version <= 5) schema -= "language_lineage_state"', contract)

    def test_community_keys_round_trip_nation_names_with_bars(self):
        self.assertIn('findlasttext(key, "|")', proc('/proc/language_community_parts('))

    def test_admin_view_is_registered_and_guarded(self):
        admin = read('code/modules/admin/verbs/origin_languages.dm')
        body = admin[admin.index('/client/proc/cmd_admin_check_language_drift('):]
        body = body[:body.index('\n/client/proc/', 10)]
        self.assertIn('check_rights(R_ADMIN)', body)
        self.assertIn('language_drift_report()', body)
        self.assertIn('/client/proc/cmd_admin_check_language_drift,', read('code/modules/admin/admin_verbs.dm'))

    def test_included_in_order(self):
        dme = read('civ13.dme')
        self.assertIn('#include "code\\game\\mob\\language\\drift.dm"\n#include "code\\game\\mob\\language\\earth.dm"', dme)


if __name__ == '__main__':
    unittest.main()

"""Offline source wiring checks; not native join/round gameplay."""
from pathlib import Path
import re
import unittest
ROOT = Path(__file__).resolve().parents[2]

class LegacyRoundTests(unittest.TestCase):
    def test_italian_coefficient_updates_italian_cap_only(self):
        source = (ROOT / 'code/game/jobs/job_controller.dm').read_text()
        block = source.split('if (map.faction_distribution_coeffs.Find(ITALIAN))', 1)[1].split('if (', 1)[0]
        self.assertIn('max_italian = ceil(relevant_clients * map.faction_distribution_coeffs[ITALIAN])', block)
        self.assertNotIn('max_dutch', block)

    def test_female_allowed_role_uses_shared_completion(self):
        source = (ROOT / 'code/game/mob/new_player/new_player.dm').read_text()
        block = source.split('if (client && client.prefs.gender == FEMALE && !job.can_be_female)', 1)[1]
        prefix = block.split('if (!job.can_be_minor', 1)[0]
        self.assertNotIn('create_character', prefix)
        self.assertNotIn('job.can_be_female', prefix)
        self.assertIn('return FALSE', prefix)
        self.assertIn('character = job_master.EquipRank(character, rank, TRUE)', block)

    def test_hydro_dam_keeps_farm_owner_independent(self):
        source = (ROOT / 'code/game/objects/map_metadata/vadso_city.dm').read_text()
        block = source.split('/area/caribbean/no_mans_land/capturable/five)', 1)[1].split('spawn(600)', 1)[0]
        self.assertNotIn('a4_control', block)
        self.assertEqual(len(re.findall(r'a5_control = "', block)), 3)
        self.assertIn('if (a5_control != "none")', block)
        self.assertIn('if (a5_control == "Russian Armed Forces")', block)
        self.assertIn('else if (a5_control == "British Armed Forces")', block)
        self.assertIn('[a5_control]', block)

if __name__ == '__main__':
    unittest.main()

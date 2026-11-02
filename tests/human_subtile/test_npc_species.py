"""Offline source contracts for staged species movement, without BYOND."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


class SpeciesContracts(unittest.TestCase):
    def test_crab_retains_one_lateral_choice_and_legacy_path(self):
        source = (ROOT / 'code/game/mob/living/simple_animal/friendly/crab.dm').read_text(encoding='utf-8')
        life = source.split('/mob/living/simple_animal/crab/Life()\n', 1)[1].split('/mob/living/simple_animal/crab/small/crab_san', 1)[0]
        for token in ('if (!ckey && !stat)', 'isturf(loc) && !resting && !buckled',
                      'turns_since_move >= move_to_delay', 'get_step(src, pick(4, 8))',
                      'if (npc_subtile_species_enabled)', 'ai_step(destination, move_to_delay, TRUE)',
                      'moved = Move(destination)', 'if (moved)', 'turns_since_move = FALSE'):
            self.assertIn(token, life)
        self.assertEqual(life.count('pick(4, 8)'), 1)
        self.assertLess(life.index('pick(4, 8)'), life.index('if (npc_subtile_species_enabled)'))

    def test_species_stage_is_off_and_not_saved(self):
        source = (ROOT / 'code/game/mob/living/simple_animal/subtile_movement.dm').read_text(encoding='utf-8')
        self.assertIn('var/npc_subtile_species_enabled = FALSE', source)
        self.assertIn('"npc_subtile_species_enabled"', source)
        for path in (ROOT / 'code').rglob('*.dm'):
            self.assertNotIn('npc_subtile_species_enabled = TRUE',
                             path.read_text(encoding='utf-8', errors='replace'), str(path))


if __name__ == '__main__':
    unittest.main()

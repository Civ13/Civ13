"""Offline scope checks for an unwired scheduler-only fixture draft."""
from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[2]

class SchedulerDraftTests(unittest.TestCase):
    def test_uses_real_scheduler_and_mob_process_without_manual_life(self):
        text=(ROOT/'tests/human_subtile/scheduler_core_draft.dm').read_text()
        self.assertIn('var/processScheduler/S = new',text)
        self.assertIn('var/process/mob/P = new(S)',text)
        self.assertIn('S.addProcess(P)',text)
        self.assertIn('S.start()',text)
        self.assertIn('P.schedule_interval == 1 SECONDS && P.start_delay == 0.6 SECONDS',text)
        self.assertIn('scheduler_process_quiesced',text)
        self.assertNotIn('.Life()',text)

    def test_draft_does_not_change_production_admission(self):
        text=(ROOT/'tests/human_subtile/scheduler_core_draft.dm').read_text()
        self.assertIn('npc_subtile_enabled = FALSE',text)
        self.assertIn('not acceptance',text)
        production=(ROOT/'code/game/mob/living/simple_animal/simple_ai.dm').read_text()
        self.assertIn('clients.len <= 0',production)
        self.assertNotIn('scheduler_core_draft.dm',(ROOT/'civ13.dme').read_text())

if __name__ == '__main__': unittest.main()

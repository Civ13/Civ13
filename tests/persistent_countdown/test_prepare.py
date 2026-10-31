"""Offline source/extraction checks only; these do not establish native behavior."""
import ast
from pathlib import Path
import unittest
import prepare

ROOT = Path(__file__).resolve().parent

class PreparationTests(unittest.TestCase):
    def test_baseline_retains_production_procedures(self):
        source = (ROOT / 'source/code/game/gameticker.dm').read_text(encoding='utf-8').replace('\r\n', '\n')
        original = prepare.between(source, '/datum/controller/gameticker/proc/cancel_pregame_autostart()', '/datum/controller/gameticker/proc/close_jobs()')
        generated = prepare.build('none')
        ticker = generated[:generated.index('/datum/admins/proc/persistent()')]
        for line in ('\t\t\t\tfixture_armed++\n', '\t\t\t\t\tfixture_setting_up++\n', '\tfixture_setup_entries++\n'):
            self.assertEqual(ticker.count(line), 1)
            ticker = ticker.replace(line, '', 1)
        self.assertEqual(ticker.rstrip(), original.rstrip())

    def test_controls_target_exactly_one_guard(self):
        baseline = prepare.build('none')
        boot = prepare.build('boot')
        self.assertEqual(boot, baseline.replace('\t\t\tif (!pregame_autostart_blocked())\n\t\t\t\tpregame_timeleft = GAMETICKER_PREGAME_TIME\n\t\t\t\tfixture_armed++', '\t\t\tpregame_timeleft = GAMETICKER_PREGAME_TIME\n\t\t\tfixture_armed++', 1))
        self.assertEqual(prepare.build('postvote'), baseline.replace('\t\t\t\t// A vote callback may have enabled persistence while we slept.\n\t\t\t\tif (pregame_autostart_blocked()) continue\n', '', 1))
        self.assertEqual(prepare.build('postadmission'), baseline.replace('\tif (pregame_autostart_blocked()) return FALSE\n\tif (!can_start_round)', '\tif (!can_start_round)', 1))
        self.assertEqual(prepare.build('latch'), baseline.replace('\t\tif (ticker) ticker.cancel_pregame_autostart()\n', '', 1))

    def test_harness_syntax_and_fixture_cases(self):
        ast.parse((ROOT / 'run_ci.py').read_text(encoding='utf-8'))
        fixture = (ROOT / 'fixture.dm').read_text(encoding='utf-8')
        for case in ('boot', 'latch', 'vote', 'admission', 'ordinary', 'manual', 'guards', 'hold'):
            self.assertIn('fixture_case == "' + case + '"', fixture)
        for oracle in ('boot_armed', 'vote_no_setup', 'admission_rejected', 'latch_cancelled', 'latch_no_setup'):
            self.assertIn('"' + oracle + '"', fixture)
        self.assertIn('OpenPort(0)', fixture)
        self.assertIn('fixture_setup_entries++', prepare.build('none'))

if __name__ == '__main__': unittest.main()

"""The Player Help guide must explain the TDM Barracks flow it is asked about there."""
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class BarracksTopicTests(unittest.TestCase):
    def test_guide_names_the_barracks_verbs(self):
        entries = json.loads((ROOT / 'UI/player-help.json').read_text(encoding='utf-8'))
        barracks = [e for e in entries if 'barracks' in e['topic']]
        self.assertEqual(len(barracks), 1)
        text = barracks[0]['text']
        for verb in ('Join Battle', 'Auto-join Battle', 'Return to Barracks', 'My Battle Record', 'Leaderboard'):
            self.assertIn(verb, text)
            self.assertIn(f'"{verb}"', (ROOT / 'code/modules/tdm_barracks').joinpath(
                'battle.dm' if verb == 'Return to Barracks' else 'barracks.dm').read_text(encoding='utf-8'))


if __name__ == '__main__':
    unittest.main()

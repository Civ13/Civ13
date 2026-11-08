"""TDM servers vote only between team battle epochs (code/processes/mapswap.dm); no BYOND runtime."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/processes/mapswap.dm').read_text(encoding='utf-8')
TDM_EPOCHS = ['Pre-Firearms (3000 B.C-1650 A.D.)', 'Early Fire Arms (1650-1930)', 'World War II (1931-1948)',
              'Modern Fire Arms (1949-2021)', 'Fiction']


def proc_body(signature):
    start = SOURCE.index(signature + '\n')
    following = re.search(r'^/[^/]', SOURCE[start + len(signature) + 1:], re.M)
    return SOURCE[start:start + len(signature) + 1 + (following.start() if following else len(SOURCE))]


def map_lists():
    """Each epoch's map list in /process/mapswap/fire(), as (epoch, [map ids])."""
    body = proc_body('/process/mapswap/fire()')
    found = []
    for case in re.finditer(r'^\t\t\tif \("([^"]+)"\)\n(.*?)^\t\t\t\t\)', body, re.M | re.S):
        found.append((case.group(1), re.findall(r'^\t+(MAP_\w+) = \d+', case.group(2), re.M)))
    return found


class TdmEpochTest(unittest.TestCase):
    def test_tdm_epochs_are_team_battles_only(self):
        body = proc_body('/proc/tdm_epochs()')
        self.assertEqual(re.findall(r'^\t\t"([^"]+)" = \d+', body, re.M), TDM_EPOCHS)
        for banned in ('PvE', 'Battle Royale', 'HRP', 'Chad', 'Civilization 13'):
            self.assertNotIn(banned, body)

    def test_tdm_server_and_battle_world_use_the_list(self):
        body = proc_body('/process/epochswap/fire()')
        self.assertIn('if (config.allowedgamemodes == "TDM" || tdm_battle_active())\n\t\t\tepochs = tdm_epochs()', body)
        tdm_branch = body[body.index('epochs = tdm_epochs()'):body.index('else if (config.allowedgamemodes == "RP")')]
        self.assertNotIn('epochs = list(', tdm_branch)

    def test_map_vote_falls_back_inside_the_tdm_list(self):
        body = proc_body('/process/mapswap/fire()')
        self.assertIn('if ((config.allowedgamemodes == "TDM" || tdm_battle_active()) && !(epoch in tdm_epochs()))\n'
                      '\t\t\tepoch = pick(tdm_epochs())', body)
        self.assertLess(body.index('epoch = pick(tdm_epochs())'), body.index('switch(epoch)'))

    def test_every_tdm_epoch_has_a_map_list(self):
        lists = dict(map_lists())
        for epoch in TDM_EPOCHS:
            self.assertTrue(lists.get(epoch), epoch)

    def test_no_map_is_listed_twice_in_an_epoch(self):
        for epoch, maps in map_lists():
            self.assertEqual(len(maps), len(set(maps)), epoch)


if __name__ == '__main__':
    unittest.main()

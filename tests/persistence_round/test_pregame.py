"""Offline source contracts and projections, not native DM/runtime acceptance."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
TICKER = (ROOT / 'code/game/gameticker.dm').read_text()
PERSISTENCE = (ROOT / 'code/modules/persistence/persistence.dm').read_text()


def procedure(name):
    return TICKER.split('/datum/controller/gameticker/proc/' + name + '()', 1)[1].split('\n/datum/', 1)[0]


def projected_helpers():
    # Execute the actual two small production helpers with mechanical DM syntax
    # translation. Reject unknown syntax rather than silently modelling it away.
    namespace = {'GAME_STATE_SETTING_UP': 2, 'GAME_STATE_PREGAME': 1}
    for name in ('cancel_pregame_autostart', 'pregame_autostart_blocked'):
        lines = ['def ' + name + '(self):']
        for line in procedure(name).splitlines():
            if not line.strip() or line.lstrip().startswith('//'):
                continue
            line = line.replace('\t', '    ')
            line = line.replace('&&', 'and').replace('||', 'or').replace('!', 'not ')
            for dm, py in [('TRUE', 'True'), ('FALSE', 'False'), ('null', 'None')]:
                line = re.sub(r'\b' + dm + r'\b', py, line)
            for var in ('pregame_autostart_cancelled', 'admin_started', 'current_state', 'pregame_timeleft', 'map', 'cancel_pregame_autostart'):
                line = re.sub(r'\b' + var + r'\b', 'self.' + var, line)
            if line.strip().startswith('if '):
                line += ':'
            assert re.match(r'^\s+(if |return |self\.)', line), line
            lines.append(line)
        exec('\n'.join(lines), namespace)
    return type('TickerProjection', (), {name: namespace[name] for name in ('cancel_pregame_autostart', 'pregame_autostart_blocked')})


class PregamePersistenceContracts(unittest.TestCase):
    def ticker(self, persistent=False, manual=False, state=1):
        ticker = projected_helpers()()
        ticker.map = type('Map', (), {'persistence': persistent})()
        ticker.pregame_autostart_cancelled = False
        ticker.admin_started = manual
        ticker.current_state = state
        ticker.pregame_timeleft = 90
        return ticker

    def test_boot_persistence_disarms_timer(self):
        ticker = self.ticker(persistent=True)
        self.assertTrue(ticker.pregame_autostart_blocked())
        self.assertIsNone(ticker.pregame_timeleft)
        self.assertEqual(ticker.current_state, 1)

    def test_toggle_cancels_even_expired_setup_and_stays_cancelled(self):
        ticker = self.ticker(state=2)
        ticker.pregame_timeleft = 0
        ticker.map.persistence = True
        ticker.cancel_pregame_autostart()
        ticker.map.persistence = False
        self.assertTrue(ticker.pregame_autostart_blocked())
        self.assertIsNone(ticker.pregame_timeleft)
        self.assertEqual(ticker.current_state, 1)
        body = PERSISTENCE.split('if (map && !map.persistence)', 1)[1]
        self.assertLess(body.index('ticker.cancel_pregame_autostart()'), body.index('map.apply_persistence_age_floor()'))

    def test_manual_start_survives_cancellation(self):
        ticker = self.ticker(persistent=True)
        ticker.pregame_autostart_blocked()
        ticker.admin_started = True
        ticker.pregame_timeleft = 1
        self.assertFalse(ticker.pregame_autostart_blocked())
        self.assertEqual(ticker.pregame_timeleft, 1)

    def test_nonpersistent_unchanged_and_playing_not_rewound(self):
        ticker = self.ticker()
        self.assertFalse(ticker.pregame_autostart_blocked())
        self.assertEqual(ticker.pregame_timeleft, 90)
        ticker = self.ticker(persistent=True, state=3)
        ticker.cancel_pregame_autostart()
        self.assertEqual(ticker.current_state, 3)

    def test_scheduling_and_deferred_vote_guards(self):
        body = procedure('pregame')
        self.assertIn('if (!pregame_autostart_blocked())\n\t\t\t\tpregame_timeleft = GAMETICKER_PREGAME_TIME', body)
        self.assertIn('if (!pregame_autostart_blocked())\n\t\t\t\tto_chat(world, "The game will start', body)
        self.assertLess(body.index('if (pregame_autostart_blocked()) continue'), body.index('pregame_timeleft--'))
        self.assertIn('while (vote.time_remaining && !pregame_autostart_blocked())', body)
        after_vote = body.split('// A vote callback', 1)[1]
        self.assertLess(after_vote.index('if (pregame_autostart_blocked()) continue'), after_vote.index('current_state = GAME_STATE_SETTING_UP'))
        self.assertIn('while(persistence_restart.startup_hold) sleep(10)', body)
        self.assertEqual(body.count('if(map_storage.round_restored) return'), 4)

    def test_fixture_adapters_include_helpers_and_allow_manual_start(self):
        import importlib.util
        path = ROOT / 'tests/world_save/build-round-adapter.py'
        spec = importlib.util.spec_from_file_location('round_adapter', path)
        adapter = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(adapter)
        for control in (None, 'setup', 'busy', 'tod'):
            generated, hashes = adapter.generate(ROOT, control)
            for helper in ('cancel_pregame_autostart', 'pregame_autostart_blocked'):
                self.assertIn('/datum/controller/gameticker/proc/' + helper + '()', generated)
            self.assertIn('code/game/gameticker.dm', hashes)
        fixture = (ROOT / 'tests/world_save/full_map_lifecycle/control.dm').read_text()
        self.assertNotIn('!ticker.pregame_timeleft', fixture)
        self.assertIn('ticker.pregame_timeleft = 1', fixture)

    def test_setup_guards_before_and_after_yield_preserve_recovery(self):
        body = procedure('setup')
        before, after = body.split('var/can_start_round = map && (admin_started || map.can_start())')
        for section in (before, after):
            self.assertIn('if (pregame_autostart_blocked()) return FALSE', section)
            self.assertLess(section.index('if(map_storage.round_restored) return TRUE'), section.index('if (pregame_autostart_blocked()) return FALSE'))
            self.assertIn('if(persistence_save_in_progress)\n\t\tsleep(1)', section)
        self.assertLess(after.index('if (pregame_autostart_blocked()) return FALSE'), after.index('current_state = GAME_STATE_PLAYING'))
        self.assertTrue(before.lstrip().startswith('if(persistence_restart.startup_hold)'))


if __name__ == '__main__':
    unittest.main()

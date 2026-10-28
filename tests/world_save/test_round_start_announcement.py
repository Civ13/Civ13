"""Offline source-bound round announcement checks; no BYOND or network."""
import re
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]


def source(path):
    return (ROOT / path).read_text(encoding='utf-8')


def proc(text, declaration):
    body = text.split(declaration + '\n', 1)[1]
    return body.split('\n/proc/', 1)[0]


def helper_projection(body):
    """Execute the production helper's small control-flow subset with inert sinks.

    This deliberately fails on unfamiliar statements instead of silently
    translating a changed implementation into a different test program.
    """
    translated = []
    for original in body.splitlines():
        line = original.lstrip('\t')
        indent = len(original) - len(line)
        line = line.split(' //', 1)[0].strip()
        if not line or line.startswith('//'):
            continue
        if line.startswith(('var/oocdiary = file(', 'oocdiary << ', 'world.log << ')):
            statement = 'pass'
        elif line == 'try':
            statement = 'try:'
        elif line == 'catch':
            statement = 'except Exception:'
        else:
            statement = line.replace('var/list/state =', 'state =')
            statement = statement.replace('state.len', 'len(state)')
            statement = statement.replace('||', ' or ').replace('&&', ' and ')
            statement = re.sub(r'!(?!=)', 'not ', statement)
            statement = re.sub(r'\bTRUE\b', 'True', statement)
            statement = re.sub(r'\bFALSE\b', 'False', statement)
            statement = statement.replace('istext(', 'istext(').replace('length(', 'len(')
            if statement.startswith('if('):
                match = re.fullmatch(r'if\((.*)\)(?: (return .+))?', statement)
                if not match:
                    raise AssertionError('Unsupported condition: ' + line)
                statement = 'if ' + match.group(1) + ':' + ((' ' + match.group(2)) if match.group(2) else '')
            elif not (statement.startswith(('return ', 'state = ', 'round_start_announced = ',
                                             'webhook_send_round_start('))):
                raise AssertionError('Unsupported statement: ' + line)
        translated.append('    ' * indent + statement)
    return '\n'.join(translated)


class RoundAnnouncementTests(unittest.TestCase):
    def setUp(self):
        self.webhooks = source('code/modules/webhooks/webhooks.dm')
        self.setup = source('code/setup.dm')
        self.world = source('code/world.dm')
        self.admin = source('code/modules/persistence/admin.dm')
        self.persistence = source('code/modules/persistence/functions.dm')
        helpers = ['announce_round_start_once', 'announce_restored_round_once']
        definitions = []
        for name in helpers:
            body = proc(self.webhooks, '/proc/' + name + '()')
            definitions.append('def ' + name + '():\n    global round_start_announced\n' + helper_projection(body))
        self.events = []
        owner = self
        class Storage:
            state = {}
            error = False
            def read_round_state(self):
                owner.events.append(('read', owner.env['game_id']))
                if self.error:
                    raise ValueError('fixture validation failure')
                return self.state
        self.storage = Storage()
        self.env = {'round_start_announced': False, 'game_id': 'generated',
                    'map_storage': self.storage, 'istext': lambda x: isinstance(x, str)}
        def send(identity):
            self.events.append(('send', identity, self.env['round_start_announced']))
        self.env['webhook_send_round_start'] = send
        exec('\n\n'.join(definitions), self.env)

    def test_fresh_round_announces_current_identity_once(self):
        self.assertTrue(self.env['announce_round_start_once']())
        self.assertFalse(self.env['announce_round_start_once']())
        self.assertEqual(self.events, [('send', 'generated', True)])

    def test_send_exception_cannot_replay_the_reserved_announcement(self):
        def failing_send(identity):
            self.events.append(('send', identity))
            raise ValueError('fixture transport failure')
        self.env['webhook_send_round_start'] = failing_send
        with self.assertRaisesRegex(ValueError, 'transport failure'):
            self.env['announce_round_start_once']()
        self.assertFalse(self.env['announce_round_start_once']())
        self.assertEqual(self.events, [('send', 'generated')])

    def test_restored_identity_is_validated_before_one_send(self):
        self.env['game_id'] = 'saved-round'
        self.storage.state = {'game_id': 'saved-round'}
        self.assertTrue(self.env['announce_restored_round_once']())
        self.assertFalse(self.env['announce_restored_round_once']())
        self.assertEqual([event for event in self.events if event[0] == 'send'],
                         [('send', 'saved-round', True)])
        self.assertLess(self.events.index(('read', 'saved-round')), self.events.index(('send', 'saved-round', True)))

    def test_missing_legacy_mismatched_or_invalid_state_never_sends(self):
        for state, error in [({}, False), ({'game_id': 'other-round'}, False), ({}, True)]:
            with self.subTest(state=state, error=error):
                self.storage.state, self.storage.error = state, error
                self.assertFalse(self.env['announce_restored_round_once']())
        self.assertFalse(any(event[0] == 'send' for event in self.events))
        self.assertFalse(self.env['round_start_announced'])

    def test_automatic_load_failure_then_success_uses_restored_identity(self):
        gate = re.search(r'if\((ticker\.loadmap\(\))\) (announce_restored_round_once\(\))', self.setup)
        self.assertIsNotNone(gate)
        class Ticker:
            ok = False
            def loadmap(inner):
                if inner.ok:
                    self.env['game_id'] = 'saved-round'
                    self.storage.state = {'game_id': 'saved-round'}
                return inner.ok
        ticker = Ticker()
        self.env['ticker'] = ticker
        instruction = 'if ' + gate.group(1) + ': ' + gate.group(2)
        exec(instruction, self.env)
        self.assertEqual(self.events, [])
        ticker.ok = True
        exec(instruction, self.env)
        self.assertEqual(self.events, [('read', 'saved-round'), ('send', 'saved-round', True)])
        exec(instruction, self.env)
        self.assertEqual(sum(event[0] == 'send' for event in self.events), 1)

    def test_recovery_failure_and_unready_players_cannot_announce(self):
        gate = re.search(r'if\((ticker && persistence_restart\.resume_startup\(\) && persistence_restart\.players_ready)\)\s+(announce_restored_round_once\(\))', self.setup)
        self.assertIsNotNone(gate)
        class Recovery:
            ok = False
            players_ready = False
            def resume_startup(inner):
                return inner.ok
        recovery = Recovery()
        self.env.update(ticker=True, persistence_restart=recovery, game_id='saved-round')
        self.storage.state = {'game_id': 'saved-round'}
        instruction = 'if ' + gate.group(1).replace('&&', ' and ') + ': ' + gate.group(2)
        exec(instruction, self.env)
        recovery.ok = True
        exec(instruction, self.env)
        self.assertEqual(self.events, [])
        recovery.players_ready = True
        exec(instruction, self.env)
        self.assertEqual(self.events, [('read', 'saved-round'), ('send', 'saved-round', True)])

    def test_unresolved_metadata_defers_notice_until_successful_manual_recovery(self):
        block = self.setup.split('if (!persistence_restart.startup_hold && fexists("map_saves/map.txt"))', 1)[1].split('\n\t\telse if', 1)[0]
        pending = re.search(r'\n\t\t\t(startup_round_pending = TRUE)', block)
        self.assertIsNotNone(pending)
        self.assertLess(pending.start(), block.index('file2text("map_saves/map.txt")'))
        self.assertIn('\n\t\t\tcatch\n', block)
        self.assertIn('istext(saved_metadata_text) ? splittext(saved_metadata_text, "\\n") : list()', block)
        fresh = re.search(r'if\(!startup_round_pending\)\s+(announce_round_start_once\(\))', self.setup)
        manual = re.search(r'if\((ticker\.loadmap\(\))\) (announce_restored_round_once\(\))', self.admin)
        self.assertIsNotNone(fresh)
        self.assertIsNotNone(manual)
        for header in ('OTHER_MAP', None, ''):
            with self.subTest(header=header):
                self.events.clear()
                self.env.update(round_start_announced=False, game_id='generated', startup_round_pending=False)
                # Existing map metadata is unresolved on mismatch, failed read,
                # or an empty header, and must reserve the fresh announcement.
                self.assertNotEqual(header, 'NOMADS_GAIA')
                exec(pending.group(1).replace('TRUE', 'True'), self.env)
                exec('if not startup_round_pending: ' + fresh.group(1), self.env)
                self.assertEqual(self.events, [])
                self.assertFalse(self.env['round_start_announced'])
                class Ticker:
                    def loadmap(inner):
                        self.env['game_id'] = 'recovered-round'
                        self.storage.state = {'game_id': 'recovered-round'}
                        return True
                self.env['ticker'] = Ticker()
                exec('if ' + manual.group(1) + ': ' + manual.group(2), self.env)
                self.assertEqual(self.events, [('read', 'recovered-round'), ('send', 'recovered-round', True)])

    def test_startup_and_manual_paths_are_success_gated(self):
        self.assertNotIn('webhook_send_round_start(game_id)', self.world)
        self.assertIn('var/startup_round_pending = persistence_restart.startup_hold', self.setup)
        self.assertRegex(self.setup, r'if \(fexists\("map_saves/save_complete.txt"\)\)\s+startup_round_pending = TRUE')
        self.assertRegex(self.setup, r'if\(ticker\.loadmap\(\)\) announce_restored_round_once\(\)')
        self.assertRegex(self.setup, r'if\(ticker && persistence_restart\.resume_startup\(\) && persistence_restart\.players_ready\)\s+announce_restored_round_once\(\)')
        self.assertRegex(self.setup, r'if\(!startup_round_pending\)\s+announce_round_start_once\(\)')
        self.assertRegex(self.setup, r'else\s+startup_round_pending = TRUE\s+admin_notice\("<span class=\'danger\'>A map save exists but has no completion marker')
        self.assertRegex(self.admin, r'if\(persistence_restart\.resume_startup\(\) && persistence_restart\.players_ready\)\s+announce_restored_round_once\(\)')
        self.assertRegex(self.admin, r'if\(ticker\.loadmap\(\)\) announce_restored_round_once\(\)')

    def test_saved_identity_precedes_success_return_and_callbacks(self):
        loader = self.persistence.split('/datum/controller/gameticker/proc/loadmap(', 1)[1].split('\n// The completion marker', 1)[0]
        self.assertLess(loader.index('map_storage.restore_round_state(src, saved_round)'),
                        loader.index('operation.finish(TRUE)'))
        self.assertLess(loader.index('operation.finish(TRUE)'), loader.index('return 1'))
        restore = self.persistence.split('/map_storage/proc/restore_round_state(', 1)[1]
        self.assertIn('global.game_id = state["game_id"]', restore)


if __name__ == '__main__':
    unittest.main()

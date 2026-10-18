"""Source boundaries for the bounded own-lobby dispatch cache, no game launch."""
from pathlib import Path
import re
import unittest

from test_source import procedure

ROOT = Path(__file__).resolve().parents[2]
FIELDS = ('lobby_join_attempts', 'lobby_join_phase', 'lobby_join_reason',
          'lobby_join_tick', 'lobby_join_result')


def audit(source):
    errors = []
    verb = procedure(source, '/mob/new_player/verb/Join()')
    trace = procedure(source, '/mob/new_player/proc/lobby_join_trace(')
    exclusions = procedure(source, '/mob/new_player/persistence_runtime_var(')
    for field in FIELDS:
        if f'"{field}"' not in exclusions:
            errors.append('runtime exclusion ' + field)
    for literal in ('min(lobby_join_attempts + 1, 65535)',
                    'lobby_join_trace("native_entry", "none")'):
        if literal not in verb:
            errors.append(literal)
    if verb.index('lobby_join_trace(') > verb.index('var/join_mode'):
        errors.append('entry after admission')
    for literal in ('copytext(phase, 1, 65)', 'copytext(reason, 1, 65)',
                    'lobby_join_tick = world.time'):
        if literal not in trace:
            errors.append(literal)
    # A trace call may only cache fixed codes, never prompt/role/account text.
    calls = re.findall(r'^\s*lobby_join_trace\((.*)\)$', source, re.M)
    if not calls or any(not re.fullmatch(r'"[a-z_]+", "[a-z_]+"', call) for call in calls):
        errors.append('nonconstant diagnostic code')
    return errors


class JoinTrace(unittest.TestCase):
    def test_cache_bounds_entry_and_persistence_with_negative_controls(self):
        source = (ROOT / 'code/game/mob/new_player/new_player.dm').read_text()
        self.assertEqual(audit(source), [])
        for old in ('min(lobby_join_attempts + 1, 65535)', 'copytext(phase, 1, 65)',
                    'copytext(reason, 1, 65)', '"lobby_join_tick"',
                    'lobby_join_trace("native_entry", "none")'):
            with self.subTest(boundary=old):
                self.assertTrue(audit(source.replace(old, 'null')))
        self.assertTrue(audit(source.replace('lobby_join_trace("native_entry", "none")',
                                             'lobby_join_trace("native_entry", key)')))

    def test_snapshot_reads_cache_without_evaluating_admission(self):
        source = (ROOT / 'code/modules/persistence/blackout_diagnostics.dm').read_text()
        section = source[source.index('if(istype(M, /mob/new_player))'):source.index('if(istype(M, /mob/living))')]
        for field in FIELDS:
            self.assertIn('N.' + field, section)
        self.assertNotRegex(section, r'\b(?:lobby_join_admission_current|quickBan_isbanned|handle_lobby_join|Join)\(')
        self.assertNotRegex(section, r'N\.\w+\s*=(?!=)')
        self.assertNotIn('prefs', section)


if __name__ == '__main__':
    unittest.main()

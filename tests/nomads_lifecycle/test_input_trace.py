"""Own-session input telemetry boundaries and negative controls, no BYOND launch."""
import hashlib
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
FIELDS = ('blackout_click_owner', 'blackout_click_client_ref', 'blackout_click_counts',
          'blackout_click_started', 'blackout_click_expires')


def audit(source, clicks, persistence):
    errors = []
    start = source.index('// BEGIN OWN CLICK TRACE:')
    trace = source[start:source.index('// END OWN CLICK TRACE', start)]
    for guard in ('!blackout_click_counts', 'world.time >= blackout_click_expires',
                  '!C', 'C.mob != src', 'C.ckey != blackout_click_owner',
                  'directory[blackout_click_owner] != C',
                  '"\\ref[C]:[C.blackout_click_session]" != blackout_click_client_ref',
                  '!C.holder', '!(C.holder.rights & R_HOST)'):
        if guard not in trace:
            errors.append('trace auth/window: '+guard)
    if not re.search(r'if\(!\(stage in list\("atom_entry".*?\)\)\)\n\t\treturn', trace):
        errors.append('fixed enum missing')
    if 'min((isnum(counts[stage]) ? counts[stage] : 0) + 1, 65535)' not in trace:
        errors.append('counter bound')
    if re.search(r'\b(?:params|target|A|address|key|name)\b', trace.replace('// BEGIN OWN CLICK TRACE: fixed codes only, no target or parameter retention.', '')):
        errors.append('private trace value')
    calls = re.findall(r'blackout_click_trace\(([^\n]*)\)', clicks)
    if not calls or any(not re.fullmatch('"[a-z_]+"', call) for call in calls):
        errors.append('nonconstant click code')
    for field in FIELDS:
        if '"'+field+'"' not in persistence:
            errors.append('runtime exclusion '+field)
    arm = source[source.index('\tvar/mob/M = C.mob'):source.index('\tvar/start_tick', source.index('\tvar/mob/M = C.mob'))]
    if 'M.blackout_click_expires = world.time + 3000' not in arm or 'M.blackout_click_client_ref != "\\ref[C]:[C.blackout_click_session]"' not in arm:
        errors.append('bounded first-session arming')
    if arm.index('if(M &&') > arm.index('M.blackout_click_expires ='):
        errors.append('unconditional rearm')
    if source.index('C.ckey != own_host') > source.index('\tvar/mob/M = C.mob'):
        errors.append('arm before own-host auth')
    return errors


class InputTrace(unittest.TestCase):
    def setUp(self):
        self.source = (ROOT/'code/modules/persistence/blackout_diagnostics.dm').read_text()
        self.clicks = (ROOT/'code/_onclick/click.dm').read_text()
        self.persistence = (ROOT/'code/modules/persistence/functions.dm').read_text()

    def test_bounded_private_own_session_trace(self):
        self.assertEqual(audit(self.source, self.clicks, self.persistence), [])

    def test_offhost_expiry_raw_params_and_persistence_controls(self):
        for guard in ('C.ckey != blackout_click_owner', 'C.mob != src',
                      'world.time >= blackout_click_expires', '!(C.holder.rights & R_HOST)'):
            with self.subTest(guard=guard):
                self.assertTrue(audit(self.source.replace(guard, 'FALSE'), self.clicks, self.persistence))
        self.assertTrue(audit(self.source, self.clicks.replace('blackout_click_trace("entry")', 'blackout_click_trace(params)'), self.persistence))
        for field in FIELDS:
            self.assertTrue(audit(self.source, self.clicks, self.persistence.replace('"'+field+'"', '"omitted"')))

    def test_disabled_trace_preserves_entire_prior_click_source(self):
        # Immutable f907c70ee source, normalized LF: removing observational calls
        # must recover the entire pre-telemetry implementation, including gates.
        prior = re.sub(r'^.*blackout_click_trace\("[a-z_]+"\)\n', '', self.clicks, flags=re.M)
        self.assertEqual(hashlib.sha256(prior.rstrip('\n').encode()).hexdigest(),
                         '6de55f9ad85dd8351f39917eef2ec90732dd08544283814e24330ca8263f0882')

    def test_capture_never_changes_gameplay_clocks(self):
        self.assertNotRegex(self.source, r'\.(?:next_click|next_move|may_do_after|may_do_mob)\s*=(?!=)')
        saver=(ROOT/'code/modules/persistence/saving.dm').read_text()
        self.assertIn('if(!A || istype(A, /client))', saver)


if __name__ == '__main__':
    unittest.main()

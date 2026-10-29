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

    def assert_disabled_trace_preserves_prior_source(self, clicks):
        # Immutable f907c70ee5409eb3c833ed78ad163537bcb4d3fc, normalized LF.
        # #3337 (10d264e5896221b34949ee4b67c0fd2b94bde249) deliberately
        # changed posture movement after telemetry was introduced. Require its
        # exact block in each named proc, then reverse only that reviewed delta
        # in this projection. Keep the original full-file hash and all gates.
        approved_posture = (
            '\tif (nloc == oloc)\n'
            '\t\tif (ishuman(src))\n'
            '\t\t\tvar/mob/living/human/subtile_human = src\n'
            '\t\t\tif (subtile_human.human_subtile_offset_owned && (step_x || step_y))\n'
            '\t\t\t\tsubtile_human.human_subtile_posture_move(F)\n'
            '\t\t\telse\n'
            '\t\t\t\tMove(F)\n'
            '\t\telse\n'
            '\t\t\tMove(F)\n'
            '\tscrambling = FALSE'
        )
        historical_posture = '\tif (nloc == oloc)\n\t\tMove(F)\n\tscrambling = FALSE'
        # The paid crawl change then admits the subtile crawl before each
        # posture wait and guards proning's turf argument. Reverse only those
        # exact reviewed blocks too.
        def crawl_block(delay, posture, message=''):
            return ('\tif (ishuman(src))\n'
                    '\t\tvar/mob/living/human/crawling_human = src\n'
                    '\t\ttry\n'
                    '\t\t\tif (crawling_human.human_subtile_crawl_move(F, ' + delay + ', "' + posture + '"))\n'
                    + message +
                    '\t\t\t\tscrambling = FALSE\n'
                    '\t\t\t\treturn\n'
                    '\t\tcatch (var/exception/crawl_error)\n'
                    '\t\t\tscrambling = FALSE\n'
                    '\t\t\tthrow crawl_error\n')
        crawl_deltas = {
            'scramble': [(crawl_block('9*slowness', 'scramble', "\t\t\t\tvisible_message(\"<span class = 'red'><b>[src]</b> crawls with difficulty!</span>\")\n")
                          + '\tsleep(9*slowness)\n', '\tsleep(9*slowness)\n')],
            'proning': [('(var/turf/floor/F)\n\tif (!isturf(F))\n\t\treturn FALSE\n', '(var/turf/floor/F)\n'),
                        ('\tvar/prone_delay = get_prone_delay()\n' + crawl_block('prone_delay', 'prone') + '\tsleep(prone_delay)\n',
                         '\tsleep(get_prone_delay())\n')],
        }
        prior = re.sub(r'^.*blackout_click_trace\("[a-z_]+"\)\n', '', clicks, flags=re.M)
        for proc in ('scramble', 'proning'):
            declaration = '/mob/proc/' + proc + '(var/turf/floor/F)\n'
            self.assertEqual(prior.count(declaration), 1, 'posture proc: ' + proc)
            start = prior.index(declaration)
            end = prior.index('\n/', start)
            body = prior[start:end]
            self.assertEqual(body.count(approved_posture), 1, 'approved posture block: ' + proc)
            body = body.replace(approved_posture, historical_posture)
            for approved, historical in crawl_deltas[proc]:
                self.assertEqual(body.count(approved), 1, 'approved crawl block: ' + proc)
                body = body.replace(approved, historical)
            prior = prior[:start] + body + prior[end:]
        self.assertEqual(hashlib.sha256(prior.rstrip('\n').encode()).hexdigest(),
                         '6de55f9ad85dd8351f39917eef2ec90732dd08544283814e24330ca8263f0882',
                         'entire prior click source')

    def test_disabled_trace_preserves_entire_prior_click_source(self):
        self.assert_disabled_trace_preserves_prior_source(self.clicks)

    def test_disabled_trace_rejects_changed_posture_guard(self):
        for proc in ('scramble', 'proning'):
            with self.subTest(proc=proc):
                start = self.clicks.index('/mob/proc/' + proc + '(var/turf/floor/F)\n')
                changed = self.clicks[:start] + self.clicks[start:].replace(
                    'subtile_human.human_subtile_offset_owned && (step_x || step_y)',
                    'FALSE', 1)
                self.assertNotEqual(changed, self.clicks)
                with self.assertRaisesRegex(AssertionError, 'approved posture block: ' + proc):
                    self.assert_disabled_trace_preserves_prior_source(changed)

    def test_disabled_trace_rejects_changed_crawl_block(self):
        for proc, old, new in (('scramble', '9*slowness, "scramble"', '9, "scramble"'),
                               ('proning', 'prone_delay, "prone"', 'prone_delay * 2, "prone"'),
                               ('proning', '\tif (!isturf(F))\n\t\treturn FALSE\n', '')):
            with self.subTest(proc=proc, old=old):
                start = self.clicks.index('/mob/proc/' + proc + '(var/turf/floor/F)\n')
                changed = self.clicks[:start] + self.clicks[start:].replace(old, new, 1)
                self.assertNotEqual(changed, self.clicks)
                with self.assertRaisesRegex(AssertionError, 'approved crawl block: ' + proc):
                    self.assert_disabled_trace_preserves_prior_source(changed)

    def test_disabled_trace_rejects_changed_posture_call(self):
        for proc in ('scramble', 'proning'):
            with self.subTest(proc=proc):
                start = self.clicks.index('/mob/proc/' + proc + '(var/turf/floor/F)\n')
                changed = self.clicks[:start] + self.clicks[start:].replace(
                    'subtile_human.human_subtile_posture_move(F)', 'Move(F)', 1)
                self.assertNotEqual(changed, self.clicks)
                with self.assertRaisesRegex(AssertionError, 'approved posture block: ' + proc):
                    self.assert_disabled_trace_preserves_prior_source(changed)

    def test_disabled_trace_rejects_missing_posture_block(self):
        start = self.clicks.index('/mob/proc/proning(var/turf/floor/F)\n')
        block_start = self.clicks.index('\tif (nloc == oloc)\n', start)
        block_end = self.clicks.index('\tscrambling = FALSE', block_start)
        changed = self.clicks[:block_start] + self.clicks[block_end:]
        with self.assertRaisesRegex(AssertionError, 'approved posture block: proning'):
            self.assert_disabled_trace_preserves_prior_source(changed)

    def test_disabled_trace_rejects_changed_click_gate(self):
        changed = self.clicks.replace('if (world.time <= next_click)', 'if (FALSE)', 1)
        self.assertNotEqual(changed, self.clicks)
        with self.assertRaisesRegex(AssertionError, 'entire prior click source'):
            self.assert_disabled_trace_preserves_prior_source(changed)

    def test_capture_never_changes_gameplay_clocks(self):
        self.assertNotRegex(self.source, r'\.(?:next_click|next_move|may_do_after|may_do_mob)\s*=(?!=)')
        saver=(ROOT/'code/modules/persistence/saving.dm').read_text()
        self.assertIn('if(!A || istype(A, /client))', saver)


if __name__ == '__main__':
    unittest.main()

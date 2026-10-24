"""Offline conditional selection and complete-body regression controls."""
import re
import unittest

from source_adapter import extract, project, read


PROBE = '''/proc/probe()
\ttrace.append("before")
#ifdef OPTIONAL
\ttrace.append("enabled")
#else
\ttrace.append("disabled")
#endif
\ttrace.append("after")
\treturn 731
/proc/next_proc()
\ttrace.append("wrong procedure")
'''


def historical_extract(source, declaration):
    """Frozen old boundary rule, retained only as the defect control."""
    match = re.search(r'^(\t*)' + re.escape(declaration) + r'\([^\n]*\)\n', source, re.M)
    base, result = len(match[1]), []
    for line in source[match.end():].splitlines():
        stripped = line.strip()
        if stripped.startswith('//'):
            continue
        if stripped and len(line)-len(line.lstrip('\t')) <= base:
            break
        result.append(line[base:])
    return '\n'.join(result)


class SourceAdapterTests(unittest.TestCase):
    def test_selected_branch_and_post_endif_sentinel_execute(self):
        for enabled in (False, True):
            with self.subTest(enabled=enabled):
                trace = []
                proc = project(PROBE, '/proc/probe', '', {'trace': trace}, defines={'OPTIONAL': enabled})
                self.assertEqual(proc(), 731)
                self.assertEqual(trace, ['before', 'enabled' if enabled else 'disabled', 'after'])

    def test_historical_truncation_fails_the_same_tail_sentinel(self):
        old = historical_extract(PROBE, '/proc/probe')
        with self.assertRaisesRegex(AssertionError, 'after'):
            self.assertIn('trace.append("after")', old)
        self.assertNotIn('return 731', old)
        self.assertIn('return 731', extract(PROBE, '/proc/probe', defines={'OPTIONAL': False}))

    def test_nested_ifndef_and_inactive_parent_do_not_leak(self):
        source = '''/proc/probe()
#ifdef OUTER
\ttrace.append("outer")
#ifndef INNER
\ttrace.append("inner absent")
#else
\ttrace.append("inner present")
#endif
#else
\ttrace.append("outer absent")
#endif
\ttrace.append("after")
'''
        for outer, inner, expected in ((False, False, ['outer absent']), (False, True, ['outer absent']),
                                      (True, False, ['outer', 'inner absent']), (True, True, ['outer', 'inner present'])):
            with self.subTest(outer=outer, inner=inner):
                trace=[]
                project(source, '/proc/probe', '', {'trace': trace}, defines={'OUTER':outer, 'INNER':inner})()
                self.assertEqual(trace, expected+['after'])

    def test_unknown_symbol_rejected_even_in_inactive_branch(self):
        source='/proc/probe()\n#ifdef OUTER\n#ifdef UNKNOWN\n\treturn 1\n#endif\n#endif\n\treturn 2\n'
        for outer in (False,True):
            with self.subTest(outer=outer), self.assertRaisesRegex(AssertionError, 'Unknown conditional symbol: UNKNOWN'):
                extract(source, '/proc/probe', defines={'OUTER':outer})
        with self.assertRaisesRegex(AssertionError, 'Unknown conditional symbol: OPTIONAL'):
            extract(PROBE, '/proc/probe')

    def test_unsupported_directives_are_never_silently_skipped(self):
        for directive in ('#if 0', '#elif OPTIONAL', '#define NEW 1', '#undef OPTIONAL', '#include "other.dm"', '#else junk', '#ifdef OPTIONAL extra'):
            for active in (False,True):
                source='/proc/probe()\n#ifdef OPTIONAL\n'+directive+'\n\treturn 1\n#endif\n\treturn 2\n'
                with self.subTest(directive=directive,active=active), self.assertRaisesRegex(AssertionError, 'Unsupported preprocessor directive'):
                    extract(source, '/proc/probe', defines={'OPTIONAL':active})

    def test_unmatched_duplicate_and_unclosed_directives_refuse(self):
        for body, reason in (('#else\n','Unmatched'), ('#endif\n','Unmatched'),
                             ('#ifdef OPTIONAL\n#else\n#else\n#endif\n','duplicate'),
                             ('#ifdef OPTIONAL\n\treturn 1\n','Unterminated'),
                             ('#ifdef OPTIONAL\n/proc/other()\n\treturn 1\n#endif\n','boundary')):
            with self.subTest(body=body), self.assertRaisesRegex(AssertionError, reason):
                extract('/proc/probe()\n'+body, '/proc/probe', defines={'OPTIONAL':False})

    def test_symbol_values_are_explicit_booleans(self):
        for value in (None,0,1,'False','True',[],{}):
            with self.subTest(value=value), self.assertRaisesRegex(AssertionError, 'explicit Boolean'):
                extract(PROBE, '/proc/probe', defines={'OPTIONAL':value})
        for key in (None,1,'INVALID SYMBOL','1INVALID'):
            with self.subTest(key=key), self.assertRaisesRegex(AssertionError, 'explicit Boolean'):
                extract(PROBE, '/proc/probe', defines={key:False})

    def test_comments_do_not_change_conditional_nesting(self):
        source=PROBE.replace('#ifdef OPTIONAL','#ifdef OPTIONAL // reviewed branch').replace('#endif','#endif // end')
        self.assertEqual(extract(source,'/proc/probe',defines={'OPTIONAL':False}), extract(PROBE,'/proc/probe',defines={'OPTIONAL':False}))

    def test_production_operation_tail_retained_in_both_declared_branches(self):
        source=read('code/modules/persistence/functions.dm')
        for enabled in (False,True):
            with self.subTest(enabled=enabled):
                body=extract(source,'/proc/begin_persistence_operation',defines={'CIV13_VARIABLE_OBSERVABILITY':enabled})
                self.assertIn('persistence_active_operation = operation',body)
                self.assertTrue(body.rstrip().endswith('return operation'))
                self.assertEqual('operation.observability_id' in body,enabled)
                finish=extract(source,'proc/finish',defines={'CIV13_VARIABLE_OBSERVABILITY':enabled})
                self.assertIn('persistence_active_operation = null',finish)
                self.assertTrue(finish.rstrip().endswith('return TRUE'))
                self.assertEqual('storage.variable_observability_finish' in finish,enabled)

    def test_default_selection_preserves_runtime_exclusion_continue(self):
        source=read('code/modules/persistence/functions.dm')
        body=extract(source,'/datum/proc/get_saved_vars')
        self.assertRegex(body,r'if \(persistence_runtime_var\(key\)\)\n\s+continue')
        self.assertIn('return to_save',body)
        self.assertNotIn('variable_observability_skipped',body)

    def test_unsupported_executable_syntax_still_fails_projection(self):
        with self.assertRaises(SyntaxError):
            project('/proc/probe()\n\tunknown >>> syntax\n', '/proc/probe', '', {})


if __name__=='__main__':
    unittest.main()

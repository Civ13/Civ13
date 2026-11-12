"""Offline source projection, not BYOND execution or a performance benchmark.

The frozen old fire() comes from the pre-change HEAD. The model treats a copied
current_list and -= as removing the last matching occurrence, matching documented
BYOND behavior. It simulates a forced budget after N entries, not actual tick time.
"""
from dataclasses import dataclass
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/processes/casings.dm').read_text()
ORIGINAL = (ROOT / 'tests/casing_scheduler/original_fire.dm').read_text(encoding='utf-8-sig')
DEFINES = (ROOT / 'code/processes/___defines.dm').read_text()
MACROS = (ROOT / 'code/_macros.dm').read_text()


@dataclass(eq=False)
class Casing:
    name: str
    loc: str | None = None
    deleted: bool = False


def remove_last(items, value):
    for i in range(len(items) - 1, -1, -1):
        if items[i] is value:
            del items[i]
            break


def project(source):
    """Accept only the narrowly modeled fire() vocabulary; fail on drift."""
    body = source.split('/process/casings/fire()', 1)[1].split('/process/casings/reset_current_list()', 1)[0]
    lines = []
    for line in body.splitlines():
        line = line.split('//', 1)[0].rstrip()
        if not line.strip():
            continue
        indent = len(line) - len(line.lstrip('\t'))
        lines.append((indent, line.strip()))
    allowed = {'var/list/turf2casings = list()', 'for (current in current_list)',
        'var/obj/item/ammo_casing/A = current', 'if (!isDeleted(A))',
        'if (isDeleted(A))', 'if (A.loc && isturf(A.loc))',
        'if (!turf2casings[A.loc])', 'turf2casings[A.loc] = 0',
        '++turf2casings[A.loc]', 'else', 'catchBadType(A)',
        'bullet_casings -= A', 'PROCESS_LIST_CHECK', 'PROCESS_TICK_CHECK'}
    for _, statement in lines:
        if statement not in allowed:
            raise AssertionError('Unsupported casing statement: ' + statement)
    return lines


def run(source, entries, budget):
    lines = project(source)
    registry, pending = list(entries), list(entries)
    diagnostics, visits, early, tally, snapshots = [], [], 0, {}, []
    loop = next(i for i, (_, s) in enumerate(lines) if s == 'for (current in current_list)')
    commands = lines[loop + 1:]
    while pending:
        # Model the native iteration in list order; PROCESS_LIST_CHECK consumes
        # the last equal occurrence, so duplicate identity is retained in traces.
        current = pending[0]
        visits.append(current)
        enabled = {1: True}
        branches = {}
        spent = False
        for indent, statement in commands:
            if indent <= 1:
                raise AssertionError('Unexpected loop boundary')
            parent = enabled.get(indent - 1, False)
            if statement.startswith('if ('):
                conditions = {
                    'if (!isDeleted(A))': current is not None and not current.deleted,
                    'if (isDeleted(A))': current is None or current.deleted,
                    'if (A.loc && isturf(A.loc))': current is not None and current.loc == 'turf',
                    'if (!turf2casings[A.loc])': current is not None and not tally.get(current.loc),
                }
                value = conditions[statement] if parent else False
                branches[indent] = value
                enabled[indent] = parent and value
                continue
            if statement == 'else':
                enabled[indent] = parent and not branches[indent]
                continue
            if not parent:
                continue
            if statement == 'catchBadType(A)':
                diagnostics.append(current)
            elif statement == 'bullet_casings -= A':
                remove_last(registry, current)
            elif statement == 'turf2casings[A.loc] = 0':
                tally[current.loc] = 0
            elif statement == '++turf2casings[A.loc]':
                tally[current.loc] += 1
            elif statement == 'PROCESS_LIST_CHECK':
                remove_last(pending, current)
            elif statement == 'PROCESS_TICK_CHECK':
                spent = True
                if len(visits) % budget == 0:
                    early += 1
                    snapshots.append(list(pending))
                    break
            elif statement != 'var/obj/item/ammo_casing/A = current':
                raise AssertionError('Unsupported command: ' + statement)
        if not spent or len(visits) > 100:
            raise AssertionError('Budget check missing or processing did not advance')
    return registry, diagnostics, visits, early, snapshots


class CasingSchedulerTests(unittest.TestCase):
    def test_scheduler_source_contract(self):
        self.assertIn('priority = PROCESS_PRIORITY_HIGH', SOURCE)
        self.assertIn('PROCESS_USE_FASTEST_LIST(bullet_casings)', SOURCE)
        self.assertIn('current_list -= current', DEFINES)
        self.assertRegex(DEFINES, r'#define PROCESS_TICK_CHECK if .*return PROCESS_TICK_CHECK_RETURNED_EARLY')
        self.assertIn('#define isDeleted(D) (!D || D:gcDestroyed)', MACROS)
        self.assertNotIn('turf2casings', SOURCE)

    def test_original_and_candidate_traces_match_for_resumes_and_locations(self):
        ground = Casing('ground', 'turf')
        contained = Casing('contained', 'gun')
        nullspace = Casing('nullspace')
        dead = Casing('retired', 'turf', True)
        for entries in ([ground, contained, nullspace, dead, None],
                        [dead, ground, dead, None, None, contained], []):
            for budget in (1, 2, 99):
                with self.subTest(entries=len(entries), budget=budget):
                    old, new = run(ORIGINAL, entries, budget), run(SOURCE, entries, budget)
                    self.assertEqual(old, new)
                    self.assertEqual(new[0], [item for item in entries if item is not None and not item.deleted])
                    self.assertEqual(new[1], [item for item in new[2] if item is None or item.deleted])
                    self.assertEqual(len(new[2]), len(entries))
                    self.assertEqual(new[3], len(entries) // budget)

    def test_negative_controls_detect_cleanup_and_scheduler_regressions(self):
        dead = Casing('retired', deleted=True)
        live = Casing('live', 'turf')
        entries = [dead, live]
        expected = run(SOURCE, entries, 1)
        no_cleanup = SOURCE.replace('bullet_casings -= A', '')
        self.assertNotEqual(expected[0], run(no_cleanup, entries, 1)[0])
        no_diagnostic = SOURCE.replace('catchBadType(A)', '')
        self.assertNotEqual(expected[1], run(no_diagnostic, entries, 1)[1])
        for macro in ('PROCESS_LIST_CHECK', 'PROCESS_TICK_CHECK'):
            with self.subTest(macro=macro), self.assertRaises(AssertionError):
                run(SOURCE.replace(macro, ''), entries, 1)
        swapped = SOURCE.replace('PROCESS_LIST_CHECK\n\t\tPROCESS_TICK_CHECK',
                                 'PROCESS_TICK_CHECK\n\t\tPROCESS_LIST_CHECK')
        with self.assertRaises(AssertionError):
            run(swapped, entries, 1)
        with self.assertRaises(AssertionError):
            run(SOURCE.replace('if (isDeleted(A))', 'if (A.loc)'), entries, 1)


if __name__ == '__main__':
    unittest.main()

"""Project the scheduler's actual guard and callback order; no BYOND runtime."""
import importlib.util
from pathlib import Path
from types import SimpleNamespace
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/processes/scheduler.dm').read_text(encoding='utf-8-sig')
MACROS = (ROOT / 'code/__defines/qdel.dm').read_text(encoding='utf-8-sig')
SPEC = importlib.util.spec_from_file_location('task_guard_adapter', ROOT / 'tests/save_movement/source_adapter.py')
ADAPTER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ADAPTER)
GUARD = '!QDELETED(scheduled_task)'
OLD_GUARD = 'scheduled_task && ' + GUARD


class Task:
    def __init__(self, events, trigger=9, retire=None, deleted=False, fail=None):
        self.events, self.trigger_time = events, trigger
        self.gc_destroyed, self.retire, self.fail = deleted, retire, fail
        self.null_ref = False
        self.truth_checks = 0

    def __bool__(self):
        self.truth_checks += 1
        return not self.null_ref

    def action(self, name):
        self.events.append(name)
        if self.fail == name:
            raise RuntimeError(name)
        if self.retire == name:
            self.gc_destroyed = True
        elif self.retire == name + '_null':
            self.null_ref = True

    def pre_process(self): self.action('pre')
    def process(self): self.action('process')
    def post_process(self): self.action('post')


def run(source, kind='active', trigger=9, retire=None, fail=None):
    events = []
    task = None if kind == 'null' else (0 if kind == 'zero' else ('invalid' if kind == 'invalid' else Task(events, trigger, retire, kind == 'deleted', fail)))
    source = source.replace('scheduled_tasks -= current', 'remove_failed(current)')
    source = source.replace('PROCESS_LIST_CHECK', 'snapshot_check(current)')
    source = source.replace('PROCESS_TICK_CHECK', 'budget_check(current)')
    def event(name): return lambda *args: events.append(name)
    def unschedule(value):
        events.append('unschedule')
        if fail == 'unschedule':
            raise RuntimeError('unschedule')
        if retire == 'unschedule':
            value.gc_destroyed = True
    env = {
        'current_list': [task], 'world': SimpleNamespace(time=10),
        'QDELETED': lambda x: not x or x.gc_destroyed,
        'unschedule': unschedule, 'catchException': event('exception'),
        'remove_failed': event('remove_failed'), 'snapshot_check': event('snapshot'),
        'budget_check': event('budget'),
    }
    ADAPTER.project(source, '/process/scheduler/fire', '', env)()
    return events, task.truth_checks if isinstance(task, Task) else None


class ScheduledTaskGuardTests(unittest.TestCase):
    def test_macro_and_all_callback_guards(self):
        self.assertIn('#define QDELING(X) (X.gc_destroyed)', MACROS)
        self.assertIn('#define QDELETED(X) (!X || QDELING(X))', MACROS)
        segment = SOURCE[SOURCE.index('/process/scheduler/fire()'):SOURCE.index('/process/scheduler/reset_current_list()')]
        self.assertEqual(segment.count(GUARD), 3)
        self.assertNotIn(OLD_GUARD, segment)
        self.assertIn('scheduled_task.pre_process()\n\t\t\t\tif (' + GUARD + ')', segment)
        self.assertIn('scheduled_task.process()\n\t\t\t\tif (' + GUARD + ')', segment)

    def test_previous_and_current_event_traces(self):
        before = SOURCE.replace(GUARD, OLD_GUARD)
        self.assertNotEqual(before, SOURCE)
        cases = [
            ('null', 9, None, None), ('zero', 9, None, None),
            ('invalid', 9, None, None),
            ('deleted', 9, None, None), ('active', 10, None, None),
            ('active', 11, None, None), ('active', 9, None, None),
            ('active', 9, 'unschedule', None), ('active', 9, None, 'unschedule'),
            ('active', 9, 'pre', None), ('active', 9, 'pre_null', None),
            ('active', 9, 'process', None), ('active', 9, 'process_null', None),
            ('active', 9, None, 'pre'), ('active', 9, None, 'process'),
            ('active', 9, None, 'post'),
        ]
        for kind, trigger, retire, fail in cases:
            with self.subTest(kind=kind, trigger=trigger, retire=retire, fail=fail):
                self.assertEqual(run(before, kind, trigger, retire, fail)[0],
                                 run(SOURCE, kind, trigger, retire, fail)[0])

    def test_mutations_detect_callback_deletion(self):
        bad = SOURCE.replace('if (' + GUARD + ')', 'if (TRUE)', 1)
        self.assertNotEqual(run(SOURCE, retire='pre')[0], run(bad, retire='pre')[0])
        bad = SOURCE.replace('if (' + GUARD + ')', 'if (TRUE)', 2)
        self.assertNotEqual(run(SOURCE, retire='process')[0], run(bad, retire='process')[0])

    def test_modeled_truth_check_counts(self):
        before = SOURCE.replace(GUARD, OLD_GUARD)
        for trigger, old_count, new_count in [(10, 2, 1), (9, 6, 3)]:
            with self.subTest(trigger=trigger):
                self.assertEqual(run(before, trigger=trigger)[1], old_count)
                self.assertEqual(run(SOURCE, trigger=trigger)[1], new_count)


if __name__ == '__main__':
    unittest.main()

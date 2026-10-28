"""Executes the actual finish_intent statements offline with injected hooks.

This is a source projection of completion-hook failure handling, not native DM
execution, client behavior or save/load acceptance.
"""
from pathlib import Path
import itertools
import re
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = 'code/game/mob/living/carbon/human/pull_pair_producer.dm'
# Candidate head that documented the held hook-failure finding.
DEFECT = 'b290932397345079881bc254d1b61eb18b9b87e9'
FIELDS = ('intent_running', 'native_inflight', 'completion_running', 'intent_completed',
          'intent_attempted', 'leader')


class HookFailure(Exception):
    pass


def finish_body(source):
    source = source.replace('\r\n', '\n')
    body = source[source.index('/datum/subtile_pull_pair/proc/finish_intent()\n'):]
    return body[body.index('\n') + 1:body.index('\n/datum/subtile_pull_pair/proc/settle_intent()')].rstrip()


def projected(source):
    """Translate the proc's small statement subset; reject anything else."""
    locals_seen = set()

    def expr(value):
        value = value.replace('&&', ' and ').replace('||', ' or ')
        value = re.sub(r'!(?!=)', ' not ', value)
        value = re.sub(r'(?<![.\w])(' + '|'.join(FIELDS) + r')\b', r's.\1', value)
        value = re.sub(r'\bTRUE\b', 'True', re.sub(r'\bFALSE\b', 'False', value))
        names = set(re.findall(r'(?<![.\w])[A-Za-z_]\w*', value))
        names -= {'s', 'not', 'and', 'or', 'True', 'False', 'isDeleted'} | locals_seen
        if names:
            raise ValueError('Unprojected name: ' + ', '.join(sorted(names)))
        return value.strip()

    output = ['def finish(s, isDeleted):']
    for line in finish_body(source).splitlines():
        indent = len(line) - len(line.lstrip('\t'))
        value = line.strip()
        if not value or value.startswith('//'):
            continue
        match = None
        if (match := re.fullmatch(r'if \((.*)\)', value)):
            value = 'if ' + expr(match.group(1)) + ':'
        elif value == 'try':
            value = 'try:'
        elif (match := re.fullmatch(r'catch \(var/exception/(\w+)\)', value)):
            locals_seen.add(match.group(1))
            value = 'except HookFailure as ' + match.group(1) + ':'
        elif (match := re.fullmatch(r'throw (\w+)', value)):
            value = 'raise ' + expr(match.group(1))
        elif (match := re.fullmatch(r'var/(\w+)', value)):
            locals_seen.add(match.group(1))
            value = match.group(1) + ' = None'
        elif value == 'return':
            pass
        elif (match := re.fullmatch(r'(\w+) = (.+)', value)):
            if match.group(1) not in FIELDS and match.group(1) not in locals_seen:
                raise ValueError('Unprojected assignment: ' + value)
            value = expr(match.group(1)) + ' = ' + expr(match.group(2))
        elif re.fullmatch(r'leader\.(living|human)_movement_completed\(\)', value):
            value = expr(value)
        elif value in ('settle_intent()', 'restore_follower_glide()'):
            value = 's.' + value
        else:
            raise ValueError('Unprojected finish_intent statement: ' + value)
        output.append('    ' * indent + value)
    namespace = {}
    exec(compile('\n'.join(output), '<actual-finish-intent>', 'exec'),
         {'__builtins__': {}, 'HookFailure': HookFailure}, namespace)
    return namespace['finish']


class Leader:
    def __init__(self, pair, living_fails, human_fails, living_deletes):
        self.pair, self.calls, self.deleted = pair, [], False
        self.living_fails, self.human_fails, self.living_deletes = living_fails, human_fails, living_deletes

    def living_movement_completed(self):
        self.calls.append(('living', self.pair.completion_running))
        if self.living_deletes:
            self.deleted = True
        if self.living_fails:
            raise HookFailure('living')

    def human_movement_completed(self):
        self.calls.append(('human', self.pair.completion_running))
        if self.human_fails:
            raise HookFailure('human')


class Pair:
    def __init__(self):
        self.intent_running = self.native_inflight = self.completion_running = self.intent_completed = False
        self.intent_attempted = True
        self.leader = None
        self.settled = []
        self.glide = 0

    def settle_intent(self):
        # release() refuses while completion_running; record what it would see.
        self.settled.append((self.completion_running, self.intent_completed))

    def restore_follower_glide(self):
        self.glide += 1


def deleted(atom):
    return getattr(atom, 'deleted', False)


def run(finish, living_fails, human_fails, living_deletes=False, attempted=True):
    pair = Pair()
    pair.intent_attempted = attempted
    leader = Leader(pair, living_fails, human_fails, living_deletes)
    pair.leader = leader
    raised = None
    try:
        finish(pair, deleted)
    except HookFailure as error:
        raised = str(error)
    return pair, leader, raised


def violations(finish):
    found = []
    for case in itertools.product((False, True), repeat=4):
        living_fails, human_fails, living_deletes, attempted = case
        pair, leader, raised = run(finish, *case)
        names = [name for name, _ in leader.calls]
        expected = [] if not attempted else ['living'] if living_deletes else ['living', 'human']
        if names != expected:
            found.append((case, 'hooks', names))
        if any(not running for _, running in leader.calls):
            found.append((case, 'hook ran outside completion_running'))
        # Every exit settles exactly once after hooks unwound, so an aligned
        # pair can release its lease and with it the save admission hold.
        if pair.settled != [(False, True)]:
            found.append((case, 'settle', pair.settled))
        if pair.completion_running or not pair.intent_completed or pair.glide != 1:
            found.append((case, 'final state'))
        first = None
        if attempted and living_fails:
            first = 'living'
        elif attempted and human_fails and not living_deletes:
            first = 'human'
        if raised != first:
            found.append((case, 'raised', raised))
    return found


class CompletionHookFailureContracts(unittest.TestCase):
    def test_hook_failure_runs_remaining_hook_then_settles_once_and_rethrows(self):
        finish = projected((ROOT / SOURCE).read_text(encoding='utf-8'))
        self.assertEqual(violations(finish), [])
        pair, leader, raised = run(finish, True, False)
        self.assertEqual([name for name, _ in leader.calls], ['living', 'human'])
        self.assertEqual(raised, 'living')
        self.assertEqual(pair.settled, [(False, True)])

    def test_reentry_is_refused_while_running_or_completed(self):
        finish = projected((ROOT / SOURCE).read_text(encoding='utf-8'))
        for field in ('intent_running', 'native_inflight', 'completion_running', 'intent_completed'):
            pair = Pair()
            pair.leader = Leader(pair, False, False, False)
            setattr(pair, field, True)
            finish(pair, deleted)
            self.assertEqual((pair.leader.calls, pair.settled, pair.glide), ([], [], 0), field)

    def test_documented_defect_head_skips_human_hook_after_living_failure(self):
        old = subprocess.check_output(['git', 'show', DEFECT + ':' + SOURCE], cwd=ROOT).decode()
        found = violations(projected(old))
        skipped = [item for item in found if item[1] == 'hooks' and item[0] == (True, False, False, True)]
        self.assertEqual(skipped, [((True, False, False, True), 'hooks', ['living'])], found)


if __name__ == '__main__':
    unittest.main(verbosity=2)

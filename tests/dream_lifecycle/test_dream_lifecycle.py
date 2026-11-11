"""Deterministic projection of the small production dream-loop subset, not DM execution."""

import heapq
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/modules/flufftext/Dreaming.dm'
LEGACY = Path(__file__).with_name('legacy_dream.dm.txt')


def project(source):
    """Read loop order and guards from DM; reject any unsupported source shape."""
    body = source.split('/mob/living/human/proc/dream()\n', 1)[1].split(
        '/mob/living/human/proc/handle_dreams()', 1)[0]
    lines = [line for line in body.splitlines() if line.strip()]
    if lines[:3] != ['\tdreaming = TRUE', '\tspawn(0)',
                     '\t\tfor (var/i = rand(1,4),i > 0, i--)']:
        raise ValueError('unsupported dream setup or loop')
    if lines[-1] != '\t\tdreaming = FALSE':
        raise ValueError('expected flag cleanup after loop')
    program = []
    loop = lines[3:-1]
    while loop:
        line = loop.pop(0)
        if line.startswith('\t\t\tto_chat(src, '):
            program.append(('message', None))
        elif line == '\t\t\tsleep(rand(40,70))':
            program.append(('sleep', None))
        elif line.startswith('\t\t\tif (') and line.endswith(')'):
            condition = line.strip()[4:-1]
            if not loop:
                raise ValueError('guard has no body')
            action = loop.pop(0)
            if action not in ('\t\t\t\tbreak', '\t\t\t\tdreaming = FALSE'):
                raise ValueError('unsupported guarded action: ' + action)
            if condition not in ('paralysis <= 0', '!sleeping || stat == DEAD || !client'):
                raise ValueError('unsupported condition: ' + condition)
            program.append(('guard', (condition, action.strip())))
        else:
            raise ValueError('unsupported loop statement: ' + line)
    if [op for op, _ in program].count('message') != 1 or [op for op, _ in program].count('sleep') != 1:
        raise ValueError('expected one message and one delay per iteration')
    handle = source.split('/mob/living/human/proc/handle_dreams()', 1)[1]
    if not re.search(r'\n\tif \(client && !dreaming && prob\(5\)\)\n\t\tdream\(\)', handle):
        raise ValueError('unsupported dream admission')
    return program


class Clock:
    def __init__(self, program):
        self.program = program
        self.now = 0
        self.queue = []
        self.serial = 0
        self.sleeping = True
        self.dead = False
        self.client = True
        self.paralysis = 0
        self.dreaming = False
        self.messages = []
        self.starts = 0

    def schedule(self, delay, task):
        self.serial += 1
        heapq.heappush(self.queue, (self.now + delay, self.serial, task))

    def start(self, count=3):
        # The random 5% admission is forced to succeed for this timing scenario.
        if not self.client or self.dreaming:
            return False
        self.dreaming = True
        self.starts += 1
        self.schedule(0, (self.starts, count, 0))
        return True

    def advance(self, target):
        while self.queue and self.queue[0][0] <= target:
            self.now, _, (identity, remaining, pc) = heapq.heappop(self.queue)
            while remaining:
                if pc == len(self.program):
                    remaining -= 1
                    pc = 0
                    continue
                op, arg = self.program[pc]
                pc += 1
                if op == 'message':
                    self.messages.append((self.now, identity))
                elif op == 'sleep':
                    self.schedule(40, (identity, remaining, pc))
                    break
                else:
                    condition, action = arg
                    active = (self.paralysis <= 0 if condition == 'paralysis <= 0'
                              else not self.sleeping or self.dead or not self.client)
                    if active and action == 'break':
                        remaining = 0
                    elif active:
                        self.dreaming = False
            else:
                self.dreaming = False
        self.now = target


def assert_single_sequence(test, program):
    clock = Clock(program)
    test.assertTrue(clock.start())
    clock.advance(40)
    test.assertTrue(clock.dreaming, 'active sequence must retain its admission lock')
    test.assertFalse(clock.start(), 'an active sequence must reject a new one')
    clock.advance(120)
    test.assertFalse(clock.dreaming, 'completed sequence must release its lock')
    test.assertEqual(clock.messages, [(0, 1), (40, 1), (80, 1)])
    test.assertTrue(clock.start(), 'another sequence can start after completion')


def assert_interrupted(test, program, state):
    clock = Clock(program)
    clock.start()
    clock.advance(0)
    setattr(clock, state, {'sleeping': False, 'dead': True, 'client': False}[state])
    clock.advance(40)
    test.assertEqual(clock.messages, [(0, 1)], 'no message after interruption')
    test.assertFalse(clock.dreaming, 'interrupted sequence must release its lock')


class DreamLifecycle(unittest.TestCase):
    def test_production_retains_lock_until_sequence_finishes(self):
        assert_single_sequence(self, project(SOURCE.read_text()))

    def test_production_stops_before_next_message_after_interruptions(self):
        for state in ('sleeping', 'dead', 'client'):
            with self.subTest(state=state):
                assert_interrupted(self, project(SOURCE.read_text()), state)

    def test_production_rechecks_before_first_message(self):
        for state in ('sleeping', 'dead', 'client'):
            with self.subTest(state=state):
                clock = Clock(project(SOURCE.read_text()))
                clock.start()
                setattr(clock, state, {'sleeping': False, 'dead': True, 'client': False}[state])
                clock.advance(0)
                self.assertEqual(clock.messages, [])
                self.assertFalse(clock.dreaming)

    def test_one_and_four_message_sequences_release_the_lock(self):
        for count in (1, 4):
            with self.subTest(count=count):
                clock = Clock(project(SOURCE.read_text()))
                clock.start(count=count)
                clock.advance(40 * count - 1)
                self.assertTrue(clock.dreaming)
                clock.advance(40 * count)
                self.assertFalse(clock.dreaming)
                self.assertEqual(len(clock.messages), count)

    def test_legacy_negative_controls_reproduce_both_defects(self):
        legacy = project(LEGACY.read_text())
        with self.assertRaisesRegex(AssertionError, 'admission lock'):
            assert_single_sequence(self, legacy)
        for state in ('sleeping', 'dead', 'client'):
            with self.subTest(state=state):
                with self.assertRaisesRegex(AssertionError, 'no message after interruption'):
                    assert_interrupted(self, legacy, state)

    def test_projected_repair_positive_control(self):
        legacy = LEGACY.read_text()
        message = '\t\t\tto_chat(src, '
        repaired = legacy.replace(message, '\t\t\tif (!sleeping || stat == DEAD || !client)\n\t\t\t\tbreak\n' + message, 1)
        repaired = repaired.replace('\t\t\tif (paralysis <= 0)\n\t\t\t\tdreaming = FALSE\n', '', 1)
        self.assertNotEqual(repaired, legacy)
        program = project(repaired)
        assert_single_sequence(self, program)
        for state in ('sleeping', 'dead', 'client'):
            with self.subTest(state=state):
                assert_interrupted(self, program, state)


if __name__ == '__main__':
    unittest.main()

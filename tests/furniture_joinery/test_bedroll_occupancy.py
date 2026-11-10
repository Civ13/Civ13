"""Offline projection of bedroll occupancy; scheduled waits are injected."""
from pathlib import Path
import importlib.util
import re
from types import SimpleNamespace
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('bedroll_occupancy_adapter', ROOT / 'tests/save_movement/source_adapter.py')
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)

PATH = ROOT / 'code/game/objects/items/weapons/nomadstuff.dm'
PROC = '/obj/structure/bed/bedroll/proc/check_use'


class BedrollOccupancy(unittest.TestCase):
    def setUp(self):
        self.person = object()
        self.bed = SimpleNamespace(loc=[self.person], buckled_mob=self.person,
                                   used=True, running=False, use_cycle=0)
        body = adapter.extract(PATH.read_text(encoding='utf-8-sig'), PROC)
        # DM's spawn owns the following statement at the same indentation;
        # indent that statement for the adapter's injected deferred boundary.
        lines = body.splitlines()
        spawn = next(i for i, line in enumerate(lines) if line.strip() == 'spawn(300)')
        end = spawn + 2
        while end < len(lines) and (not lines[end].strip() or lines[end].startswith('\t\t\t')):
            end += 1
        lines[spawn + 1:end] = ['\t' + line for line in lines[spawn + 1:end]]
        body = '\n'.join(lines)
        for field in ('buckled_mob', 'used', 'running', 'use_cycle'):
            body = re.sub(r'(?<![\w.])' + field + r'\b', 'src.' + field, body)
        self.env = dict(src=self.bed, update_icon=lambda: None,
                        deferred=lambda delay: False)
        self.check = adapter.project('/bedroll_probe()\n' + body + '\n', '/bedroll_probe',
                                     'H', self.env)
        self.env['check_use'] = self.check

    def test_rapid_unbuckle_and_rebuckle_preserves_occupancy(self):
        self.check(self.person)
        self.assertTrue(self.bed.running)
        self.bed.buckled_mob = None
        self.bed.used = False
        self.check(self.person)
        self.bed.buckled_mob = self.person
        self.bed.used = True
        self.check(self.person)
        self.assertTrue(self.bed.used)
        self.assertTrue(self.bed.running)

    def test_old_timer_cannot_clear_new_occupant(self):
        other = object()
        def wait_boundary(delay):
            self.bed.use_cycle += 1
            self.bed.buckled_mob = other
            self.bed.used = True
            self.bed.running = True
            return True
        self.env['deferred'] = wait_boundary
        self.check(self.person)
        self.assertIs(self.bed.buckled_mob, other)
        self.assertTrue(self.bed.used)
        self.assertTrue(self.bed.running)


if __name__ == '__main__':
    unittest.main()

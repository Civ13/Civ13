"""Offline source projection for the fire-smoke breathing guard.

The model covers control flow and effects at the breathing boundary; it is not
BYOND execution, native gameplay, or a runtime benchmark.
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/modules/1713/fire_smoke.dm'


def project(source):
    start = source.index('\t// Thin smoke cannot affect breathing;')
    end = source.index('\t// Clearing:', start)
    block = source[start:end].splitlines()[1:]
    operations = {
        'if (!(thickness < 2))': 'if not (ctx.thickness < 2):',
        'if (!(thickness <= 2))': 'if not (ctx.thickness <= 2):',
        'for (var/mob/living/human/H in here)': 'for human in ctx.humans:',
        'fire_smoke_breathe(H, thickness)': 'ctx.breathe(human, ctx.thickness)',
    }
    program = ['def run(ctx):']
    for line in block:
        if not line.strip():
            continue
        depth = len(line) - len(line.lstrip('\t'))
        statement = line.strip()
        if statement not in operations:
            raise AssertionError(f'Unsupported breathing statement: {statement}')
        program.append('    ' * depth + operations[statement])
    namespace = {}
    exec('\n'.join(program), namespace)
    return namespace['run']


class Context:
    def __init__(self, thickness, humans, change_after_first=None):
        self.thickness = thickness
        self.humans = humans
        self.change_after_first = change_after_first
        self.calls = []
        self.effects = []

    def breathe(self, human, thickness):
        self.calls.append((human['name'], thickness))
        if human['dead'] or thickness < 2 or human['masked']:
            return
        if thickness >= 3:
            self.effects.append((human['name'], 'oxygen', thickness - 2))
        # Deterministic stand-in for a successful cough roll.
        self.effects.append((human['name'], 'cough'))
        if self.change_after_first is not None:
            self.thickness = self.change_after_first
            self.change_after_first = None


def human(name, dead=False, masked=False):
    return {'name': name, 'dead': dead, 'masked': masked}


class SmokeBreathingTests(unittest.TestCase):
    def setUp(self):
        self.source = SOURCE.read_text(encoding='utf-8')
        helper = self.source.split('/proc/fire_smoke_breathe(', 1)[1]
        self.assertIn('if (!H || H.stat == DEAD || thickness < 2)\n\t\treturn', helper)
        self.assertIn('if (H.wear_mask && istype(H.wear_mask, /obj/item/clothing/mask/gas))', helper)
        self.assertIn('if (thickness >= 3)\n\t\tH.adjustOxyLoss(thickness - 2)', helper)
        self.assertIn('if (prob(10 * thickness))\n\t\tH.emote("cough")', helper)
        self.candidate = project(self.source)
        old = self.source.replace('\tif (!(thickness < 2))\n\t\tfor (var/mob/living/human/H in here)\n\t\t\tfire_smoke_breathe(H, thickness)',
                                  '\tfor (var/mob/living/human/H in here)\n\t\tfire_smoke_breathe(H, thickness)', 1)
        self.assertNotEqual(old, self.source)
        self.original = project(old)

    def run_pair(self, thickness, humans, change=None):
        before = Context(thickness, humans, change)
        after = Context(thickness, humans, change)
        self.original(before)
        self.candidate(after)
        self.assertEqual(after.effects, before.effects)
        self.assertEqual(after.thickness, before.thickness)
        return before, after

    def test_thin_smoke_skips_visits_without_effects(self):
        humans = [human('alive'), human('dead', dead=True), human('masked', masked=True)]
        for thickness in (0, 1):
            with self.subTest(thickness=thickness):
                before, after = self.run_pair(thickness, humans)
                self.assertEqual(len(before.calls), 3)
                self.assertEqual(after.calls, [])
                self.assertEqual(after.effects, [])

    def test_boundary_and_mixed_people_preserve_effects_and_calls(self):
        humans = [human('alive'), human('dead', dead=True), human('masked', masked=True)]
        for thickness in (2, 3, 5):
            with self.subTest(thickness=thickness):
                before, after = self.run_pair(thickness, humans)
                self.assertEqual(after.calls, before.calls)
                self.assertIn(('alive', 'cough'), after.effects)

    def test_callback_thins_smoke_but_remaining_people_are_still_checked(self):
        humans = [human('first'), human('second')]
        before, after = self.run_pair(3, humans, change=1)
        self.assertEqual(after.calls, [('first', 3), ('second', 1)])
        self.assertEqual(after.calls, before.calls)

    def test_wrong_boundary_control_changes_effects(self):
        mutant = project(self.source.replace('if (!(thickness < 2))', 'if (!(thickness <= 2))', 1))
        original = Context(2, [human('alive')])
        broken = Context(2, [human('alive')])
        self.original(original)
        mutant(broken)
        self.assertNotEqual(original.effects, broken.effects)


if __name__ == '__main__':
    unittest.main()

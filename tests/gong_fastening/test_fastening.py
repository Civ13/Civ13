"""Exercise the gong's wrench branch with controlled timed-action completion."""
import sys
import unittest
from pathlib import Path
from types import SimpleNamespace

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tests' / 'save_movement'))
import source_adapter


def wrench_action(wait):
    source = (ROOT / 'code/game/objects/structures/gong.dm').read_text()
    start = source.index('\t\tif (istype(I, /obj/item/weapon/wrench))\n')
    end = source.index('\t\tif (istype(I, /obj/item/weapon/hammer))', start)
    lines = source[start:end].splitlines()[1:]
    # Replace presentation-only effects, retaining all fastening control flow.
    body = []
    for line in lines:
        line = line[2:]
        if line.strip().startswith(('visible_message(', 'playsound(')):
            line = line[:len(line) - len(line.lstrip('\t'))] + 'notice()'
        body.append(line)
    fixture = '/gong/wrench()\n' + '\n'.join(body) + '\n'
    old_fields = source_adapter.FIELDS
    try:
        source_adapter.FIELDS += ('anchored',)
        return source_adapter.project(fixture, '/gong/wrench', 'src, H',
                                      {'do_after': wait, 'notice': lambda: None}, method=True)
    finally:
        source_adapter.FIELDS = old_fields


class GongFasteningTests(unittest.TestCase):
    def test_two_actors_cannot_reverse_each_others_completed_action(self):
        for initial in (True, False):
            with self.subTest(initial=initial):
                gong = SimpleNamespace(anchored=initial)
                def wait(actor, delay, target):
                    if actor == 'first':
                        action(target, 'second')
                    return True
                action = wrench_action(wait)
                action(gong, 'first')
                self.assertEqual(gong.anchored, not initial)

    def test_cancelled_action_does_not_change_fastening(self):
        gong = SimpleNamespace(anchored=True)
        wrench_action(lambda *args: False)(gong, 'actor')
        self.assertTrue(gong.anchored)


if __name__ == '__main__':
    unittest.main()

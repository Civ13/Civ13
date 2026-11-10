"""Exercise the production railing dismantle guard around a timed action."""
import sys
import unittest
from pathlib import Path
from types import SimpleNamespace

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tests' / 'save_movement'))
import source_adapter


def dismantle(wait, completed):
    source = (ROOT / 'code/game/objects/structures/railing.dm').read_text()
    start = source.index('\t\tif (do_after(user, 20, src))\n')
    end = source.index('\n\n\t// Install', start)
    lines = source[start:end].splitlines()
    # Keep the production wait and its guards; replace the salvage side effects.
    body = []
    for line in lines:
        if 'user.visible_message(' in line:
            body.append('\t\t\tcompleted()')
            break
        body.append(line)
    fixture = '/railing/dismantle()\n' + '\n'.join(line[1:] for line in body) + '\n'
    old_fields = source_adapter.FIELDS
    try:
        source_adapter.FIELDS += ('anchored',)
        return source_adapter.project(fixture, '/railing/dismantle', 'src, user',
                                      {'do_after': wait, 'completed': completed}, method=True)
    finally:
        source_adapter.FIELDS = old_fields


class RailingDismantleTests(unittest.TestCase):
    def test_fastened_during_wait_is_not_dismantled(self):
        rail = SimpleNamespace(anchored=False)
        results = []
        def wait(user, delay, target):
            target.anchored = True
            return True
        dismantle(wait, lambda: results.append('dismantled'))(rail, 'actor')
        self.assertEqual(results, [])

    def test_unfastened_completion_and_cancel(self):
        for finished in (True, False):
            results = []
            rail = SimpleNamespace(anchored=False)
            dismantle(lambda *args: finished, lambda: results.append('dismantled'))(rail, 'actor')
            self.assertEqual(results, ['dismantled'] if finished else [])


if __name__ == '__main__':
    unittest.main()

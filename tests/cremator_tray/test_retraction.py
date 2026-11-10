"""Project the cremator's close-tray branch using fake engine objects."""
import sys
import unittest
from pathlib import Path
from types import SimpleNamespace

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tests' / 'save_movement'))
import source_adapter


def close_tray():
    source = (ROOT / 'code/game/objects/structures/morgue.dm').read_text()
    start = source.index('\tif ((src.connected) && (src.locked == FALSE))',
                         source.index('/obj/structure/cremator/attack_hand('))
    end = source.index('\telse if (src.locked == FALSE)', start)
    branch = source[start:end].replace(
        'for (var/atom/movable/A as mob|obj in src.connected.loc)',
        'for (A in src.connected.loc)')
    lines = []
    for line in branch.splitlines():
        if line.lstrip().startswith('playsound('):
            line = line[:len(line) - len(line.lstrip('\t'))] + 'sound()'
        lines.append(line)
    fixture = '/cremator/close()\n' + '\n'.join(lines) + '\n'
    old = source_adapter.FIELDS
    try:
        source_adapter.FIELDS += ('connected',)
        return source_adapter.project(fixture, '/cremator/close', 'src',
                                      {'qdel': delete_tray, 'sound': lambda: None}, method=True)
    finally:
        source_adapter.FIELDS = old


def delete_tray(tray):
    if tray is None:
        return
    tray.deleted = True
    if tray.connected and tray.connected.connected is tray:
        tray.connected.connected = None
    tray.connected = None


class CrematorTrayTests(unittest.TestCase):
    def test_retraction_moves_contents_and_deletes_the_same_tray(self):
        cremator = SimpleNamespace(connected=None, locked=False, loc='cremator tile')
        patient = SimpleNamespace(anchored=False, forceMove=lambda target: moved.append(target))
        anchored = SimpleNamespace(anchored=True, forceMove=lambda target: self.fail('anchored item moved'))
        tray = SimpleNamespace(loc=[patient, anchored], connected=cremator, deleted=False)
        cremator.connected = tray
        moved = []
        close_tray()(cremator)
        self.assertEqual(moved, [cremator])
        self.assertTrue(tray.deleted)
        self.assertIsNone(tray.connected)
        self.assertIsNone(cremator.connected)

    def test_locked_cremator_keeps_tray(self):
        cremator = SimpleNamespace(connected=SimpleNamespace(deleted=False), locked=True)
        tray = cremator.connected
        close_tray()(cremator)
        self.assertIs(cremator.connected, tray)
        self.assertFalse(tray.deleted)


if __name__ == '__main__':
    unittest.main()

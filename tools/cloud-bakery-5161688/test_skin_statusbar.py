"""Explicit documented setting experiment, not native layout proof."""
from pathlib import Path
import unittest
ROOT=Path(__file__).parent

class StatusbarExperiment(unittest.TestCase):
    def test_only_main_statusbar_explicit_false(self):
        skin=(ROOT/'changed-source/filming/cloud.dmf').read_text()
        self.assertEqual(skin.count('statusbar = false'),1)
        self.assertIn('type = MAIN\n        statusbar = false',skin)
        self.assertEqual(skin.count('size = 480x480'),2)
        self.assertIn('can-resize = false',skin)
        self.assertIn('type = MAP\n        pos = 0,0\n        size = 480x480',skin)

    def test_parent_rectangle_still_exact_not_child_capture(self):
        source=(ROOT/'capture.py').read_text()
        self.assertIn('(client.left, client.top, client.right, client.bottom) != (0, 0, *size)',source)
        self.assertIn("GetAncestor', hwnd, 2) != hwnd",source)
        self.assertIn("error.evidence['direct_children'] = self.owned_child_geometry(hwnd, pid, tid)",source)
        controller=(ROOT/'run_scene.py').read_text()
        self.assertEqual(controller.count('TITLE, (480,480))'),2)
        self.assertNotIn('SetWindowPos',source)

if __name__=='__main__':unittest.main()

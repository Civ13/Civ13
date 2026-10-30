import tempfile, unittest
from pathlib import Path
from unittest.mock import patch
import installed_directx as probe

class InstalledDirectX(unittest.TestCase):
    def test_present_is_read_only_and_rechecked(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/'receipt.json'
            with patch.object(probe,'binding',return_value={'run':'1'}),patch.object(probe,'system_dlls',return_value={'d3dx':{'sha256':'fixed'}}):
                self.assertEqual(probe.probe(p)['status'],'AVAILABLE_PINNED_SYSTEM_COMPONENTS')
                self.assertFalse(probe.verify(p)['installed'])
                with self.assertRaisesRegex(RuntimeError,'fresh_dependency'):probe.probe(p)
    def test_missing_stops_without_install(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/'receipt.json'
            with patch.object(probe,'binding',return_value={'run':'1'}),patch.object(probe,'system_dlls',side_effect=FileNotFoundError):
                self.assertEqual(probe.probe(p)['status'],'BLOCKED_SYSTEM_COMPONENTS')
                with self.assertRaises(RuntimeError):probe.verify(p)
    def test_changed_components_fail_verification(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/'receipt.json'
            with patch.object(probe,'binding',return_value={'run':'1'}),patch.object(probe,'system_dlls',side_effect=[{'dll':'a'},{'dll':'b'}]):
                probe.probe(p)
                with self.assertRaisesRegex(RuntimeError,'not_exact_or_changed'):probe.verify(p)

if __name__=='__main__':unittest.main()

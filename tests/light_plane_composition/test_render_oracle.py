"""Synthetic oracle tests only, not native renderer acceptance."""
import json
from pathlib import Path
import tempfile
import unittest
from PIL import Image
from verify_render import compare_pixels, CASES, verify


class PixelOracle(unittest.TestCase):
    def test_weather_and_fullbright_counterexample_sizes_are_detected(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            a = Image.new('RGBA', (32, 32), (255, 255, 255, 255))
            a.save(root/'reference.png')
            for count in (1, 283, 1024):
                b = a.copy()
                for i in range(count):
                    b.putpixel((i % 32, i // 32), (0, 0, 0, 255))
                b.save(root/'candidate.png')
                self.assertEqual(compare_pixels(root/'reference.png', root/'candidate.png'), count)
            a.save(root/'candidate.png')
            self.assertEqual(compare_pixels(root/'reference.png', root/'candidate.png'), 0)

    def test_old_rejected_receipts_cannot_accept_new_source(self):
        with self.assertRaisesRegex(ValueError, 'New opt-in native capture'):
            verify(Path(__file__).with_name('render-results.json'), Path(__file__).resolve().parents[2])
        evidence = json.loads(Path(__file__).with_name('counterexamples.json').read_text())
        self.assertEqual(evidence['weather_proxy']['changed_pixels'], 283)
        self.assertEqual(evidence['intentional_mask_free_tile']['changed_pixels'], 1024)
        self.assertEqual(len(CASES), 9)


if __name__ == '__main__':
    unittest.main()

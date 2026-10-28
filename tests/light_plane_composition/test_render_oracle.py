"""Synthetic oracle tests only, not native renderer acceptance."""
import json
from pathlib import Path
import tempfile
import unittest
from PIL import Image
from verify_render import compare_pixels, CASES, verify, digest, SOURCES


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


    def test_lifecycle_and_weather_source_drift_rejects_existing_receipt(self):
        # Synthetic receipt checks checker behavior only, never rendering.
        missing_inputs = (
            'civ13.dme',
            'code/game/mob/living/life.dm',
            'code/game/mob/living/carbon/human/human_life.dm',
            'code/game/mob/observer/ghost/ghost.dm',
            'code/game/area/areas.dm',
            'code/game/area/caribbean.dm',
            'code/__defines/weather.dm',
            'code/modules/1713/weather.dm',
            'code/processes/time_of_day_change.dm',
            'icons/effects/weather.dmi',
        )
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            repo = root/'repo'
            for name in set(SOURCES) | set(missing_inputs):
                path = repo/name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(name.encode())
            Image.new('RGBA', (32, 32), (255, 255, 255, 255)).save(root/'synthetic.png')
            entry = {'path': 'synthetic.png', 'sha256': digest(root/'synthetic.png')}
            receipt = {'renderer': 'BYOND DreamSeeker 516.1681',
                       'composition_enabled': True,
                       'source_sha256': {name: digest(repo/name) for name in SOURCES},
                       'cases': [{'name': name, 'reference': entry, 'candidate': entry}
                                 for name in CASES]}
            packet = root/'synthetic-checker-only.json'
            packet.write_text(json.dumps(receipt))
            self.assertEqual(verify(packet, repo)['pixel_cases'], len(CASES))
            for name in missing_inputs:
                with self.subTest(changed_source=name):
                    path = repo/name
                    original = path.read_bytes()
                    path.write_bytes(original + b'\nsource drift')
                    try:
                        with self.assertRaisesRegex(ValueError, 'Captured source differs'):
                            verify(packet, repo)
                    finally:
                        path.write_bytes(original)



if __name__ == '__main__':
    unittest.main()

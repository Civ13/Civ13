"""Offline conversion and negative controls; no compiler or game process."""
from io import BytesIO
import json
from pathlib import Path
import shutil
import tempfile
import unittest
from unittest.mock import patch

from PIL import Image, PngImagePlugin

import humanity_wild_herbs as art


class ArtPortTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name)
        self.manifest, self.pictures = art.sources()

    def source_copy(self):
        source = self.path / 'sources'
        shutil.copytree(art.SOURCE, source)
        return source

    def update_source_hash(self, source, name):
        manifest = json.loads((source / 'manifest.json').read_text())
        data = (source / name).read_bytes()
        manifest['files'][name].update(sha256=art.sha256(data), git_blob=art.git_blob(data))
        (source / 'manifest.json').write_text(json.dumps(manifest))

    def test_committed_dmi_has_original_rgba_and_static_semantics(self):
        target = art.ROOT / self.manifest['target']
        result = art.verify(target, self.pictures)
        self.assertTrue(result['exact_rgba'])
        frames = list(art.dmi_frames(target.read_bytes()))
        self.assertEqual([f[0] for f in frames], [
            {'state': name, 'direction_index': 0, 'frame': 0} for name in art.STATES])
        self.assertEqual([p.tobytes() for _, p in frames], [p.tobytes() for p in self.pictures])

    def test_rebuild_is_reproducible_and_does_not_change_pixels(self):
        first = art.convert(self.pictures)
        self.assertEqual(first, art.convert(self.pictures))
        target = self.path / 'rebuilt.dmi'
        target.write_bytes(first)
        art.verify(target, self.pictures)

    def test_changed_source_bytes_rejected(self):
        source = self.source_copy()
        with (source / 'yarrow.png').open('ab') as stream:
            stream.write(b'changed')
        with self.assertRaisesRegex(ValueError, 'Source hash mismatch'):
            art.sources(source)

    def test_changed_license_rejected_even_with_updated_file_hash(self):
        source = self.source_copy()
        meta = json.loads((source / 'meta.json').read_text())
        meta['license'] = 'None'
        (source / 'meta.json').write_text(json.dumps(meta))
        self.update_source_hash(source, 'meta.json')
        with self.assertRaisesRegex(ValueError, 'Rights or dimensions changed'):
            art.sources(source)

    def test_animation_and_direction_changes_require_new_converter(self):
        for change in ({'delays': [[0.1, 0.1]]}, {'directions': 4}):
            with self.subTest(change=change):
                source = self.path / str(len(list(self.path.iterdir())))
                shutil.copytree(art.SOURCE, source)
                meta = json.loads((source / 'meta.json').read_text())
                next(s for s in meta['states'] if s['name'] == 'yarrow').update(change)
                (source / 'meta.json').write_text(json.dumps(meta))
                self.update_source_hash(source, 'meta.json')
                with self.assertRaisesRegex(ValueError, 'Unsupported RSI semantics'):
                    art.sources(source)

    def test_swapped_states_and_single_pixel_edit_rejected(self):
        for kind in ('swapped', 'pixel'):
            with self.subTest(kind=kind):
                changed = [p.copy() for p in self.pictures]
                if kind == 'swapped':
                    changed[0], changed[1] = changed[1], changed[0]
                else:
                    changed[0].putpixel((0, 0), (255, 0, 0, 255))
                target = self.path / f'{kind}.dmi'
                target.write_bytes(art.convert(changed))
                with self.assertRaisesRegex(ValueError, 'DMI pixel mismatch'):
                    art.verify(target, self.pictures)

    def test_wrong_target_direction_metadata_rejected(self):
        info = PngImagePlugin.PngInfo()
        info.add_text('Description', art.description().replace('dirs = 1', 'dirs = 4'), zip=True)
        target = self.path / 'wrong.dmi'
        Image.open(BytesIO(art.convert(self.pictures))).save(target, format='PNG', pnginfo=info)
        with self.assertRaisesRegex(ValueError, 'metadata changed'):
            art.verify(target, self.pictures)

    def test_audit_finds_renamed_translated_and_mirrored_duplicates(self):
        for kind in ('renamed', 'translated', 'mirrored'):
            with self.subTest(kind=kind):
                image = self.pictures[0].copy()
                if kind != 'renamed':
                    box = image.getchannel('A').getbbox()
                    image = image.crop(box)
                    if kind == 'mirrored':
                        image = image.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
                    shifted = Image.new('RGBA', (64, 64))
                    shifted.paste(image, (5, 5))
                    image = shifted
                stream = BytesIO()
                image.save(stream, format='PNG')
                with patch.object(art, 'git', side_effect=[b'icons/unrelated.png\n', stream.getvalue()]):
                    report = art.audit(self.path, 'fixture', self.pictures)
                self.assertEqual(report['candidates'][0]['same_state_name'], [])
                self.assertEqual(len(report['candidates'][0]['pixel_matches']), 1)
                self.assertEqual(report['candidates'][1]['pixel_matches'], [])

    def test_visible_comparison_ignores_hidden_rgb(self):
        image = self.pictures[0].copy()
        self.assertEqual(image.getpixel((0, 0))[3], 0)
        image.putpixel((0, 0), (123, 45, 67, 0))
        self.assertEqual(art.visible_hash(image), art.visible_hash(self.pictures[0]))
        self.assertNotEqual(image.tobytes(), self.pictures[0].tobytes())


if __name__ == '__main__':
    unittest.main()

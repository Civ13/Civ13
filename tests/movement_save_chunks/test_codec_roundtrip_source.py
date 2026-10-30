"""Source guards only: actual codec correctness requires native BYOND execution."""
from pathlib import Path
import unittest

SOURCE = Path(__file__).with_name('codec_roundtrip.dm').read_text()


class CodecRoundtripSourceTests(unittest.TestCase):
    def test_real_codec_disk_boundary_and_fresh_reader(self):
        self.assertIn('var/map_storage/writer = new', SOURCE)
        self.assertIn('var/map_storage/reader = new', SOURCE)
        self.assertIn('/proc/write_native_list_codec_fixture()', SOURCE)
        self.assertIn('/proc/verify_native_list_codec_fixture()', SOURCE)
        self.assertIn('writer.encode_saved_value(F, root)', SOURCE)
        self.assertIn('reader.decode_saved_value(F, reloaded_descriptor)', SOURCE)
        self.assertEqual(SOURCE.count('F = new("list-codec.sav")'), 2)
        self.assertIn('F.Flush()\n\t\tF = null', SOURCE)
        self.assertIn('F["/format_version"] << 3', SOURCE)
        self.assertIn('F["/root"] << encoded', SOURCE)
        self.assertIn('F["/root"] >> reloaded_descriptor', SOURCE)
        self.assertIn('fexists("list-codec.sav")', SOURCE)

    def test_identity_and_values_including_native_empty_handles(self):
        for label in ('equal_alias', 'empty_a', 'empty_b', 'self', 'cycle_a', 'cycle_b', 'assoc', 'overlays_alias', 'underlays', 'filters_alias'):
            self.assertIn(f'"{label}"', SOURCE)
        self.assertIn('nodes[i] == nodes[j]', SOURCE)
        self.assertIn('decoded_assoc[key] != assoc[key]', SOURCE)
        self.assertIn('decoded_self[1] != decoded_self', SOURCE)
        self.assertIn('decoded_a[1] != decoded_b', SOURCE)
        self.assertIn('writer.saving_list_pins.len > 19', SOURCE)

    def test_matrix_real_codec_alias_values_and_cycle(self):
        for marker in ('matrix(2, 3, 4, 5, 6, 7)', 'matrix_alias',
                       'matrix_graph[matrix_a]', 'matrix_a.a = 13',
                       'matrix_b.a != 2', 'matrix alias partition changed',
                       'matrix scalar components changed'):
            self.assertIn(marker, SOURCE)
        self.assertIn('restored.len != 18', SOURCE)

    def test_no_automatic_entry_or_production_files_cleanup_preserves_failure(self):
        for forbidden in ('/world/New', 'OpenPort(', 'sleep(', 'spawn(', 'map_saves/', 'map_backups/', 'fdel(', 'image(', 'filter('):
            self.assertNotIn(forbidden, SOURCE)
        self.assertIn('catch(var/exception/error)', SOURCE)
        self.assertIn('throw error', SOURCE)
        self.assertGreaterEqual(SOURCE.count('writer.clear_bookkeeping()'), 3)
        self.assertGreaterEqual(SOURCE.count('reader.clear_bookkeeping()'), 3)
        self.assertIn('clear_native_list_codec_cycles(restored)', SOURCE)


if __name__ == '__main__':
    unittest.main()

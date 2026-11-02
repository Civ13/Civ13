"""Mutation controls for the source-only guarded tile reset contract."""
from pathlib import Path
import unittest

from tile_restore_contract import DECLARATION, MARKER, RESTORE, validate_tile_restore

SOURCE = Path(__file__).resolve().parents[2] / 'code/game/mob/living/carbon/human/subtile_movement.dm'


class TileRestoreContracts(unittest.TestCase):
    def setUp(self):
        self.source = SOURCE.read_text(encoding='utf-8')

    def reject(self, source):
        with self.assertRaises(AssertionError):
            validate_tile_restore(source)

    def test_current_source(self):
        validate_tile_restore(self.source)

    def test_unknown_nested_preprocessor_branch(self):
        self.reject(self.source.replace(RESTORE, '#ifdef UNDEFINED_TEST_BRANCH\n' + RESTORE + '#endif\n', 1))

    def test_unknown_outer_preprocessor_branch(self):
        self.reject(self.source.replace(DECLARATION, '#ifdef UNDEFINED_TEST_BRANCH\n' + DECLARATION, 1))

    def test_each_ownership_cleanup_commented_out(self):
        for name in ('human_subtile_offset_owned', 'human_subtile_import_owned'):
            with self.subTest(name=name):
                mutated = RESTORE.replace('\t' + name + ' = FALSE\n', '\t// ' + name + ' = FALSE\n', 1)
                self.assertNotEqual(mutated, RESTORE)
                self.reject(self.source.replace(RESTORE, mutated, 1))

    def test_block_commented_cleanup(self):
        mutated = RESTORE.replace('\thuman_subtile_offset_owned = FALSE\n', '\t/* human_subtile_offset_owned = FALSE */\n', 1)
        self.assertNotEqual(mutated, RESTORE)
        self.reject(self.source.replace(RESTORE, mutated, 1))

    def test_guard_removed(self):
        self.reject(self.source.replace(RESTORE, RESTORE.split('\n', 1)[1], 1))

    def test_nonzero_reset(self):
        self.reject(self.source.replace('\tstep_x = 0\n', '\tstep_x = 2\n', 1))

    def test_outside_restore_write(self):
        self.reject(self.source.replace(DECLARATION, '\tstep_x = 0\n\n' + DECLARATION, 1))

    def test_additional_restore_write(self):
        self.reject(self.source.replace(RESTORE, RESTORE + '\tstep_y = 0\n', 1))

    def test_comment_markers_inside_quotes(self):
        validate_tile_restore(self.source.replace(DECLARATION, 'var/example = "// not a comment"\n' + DECLARATION, 1))


if __name__ == '__main__':
    unittest.main()

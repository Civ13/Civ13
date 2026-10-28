"""Focused source regression, not a replacement for BYOND compilation."""
import hashlib,re,unittest
from pathlib import Path

HERE=Path(__file__).resolve().parent
BEFORE_SHA='71d1259d2c97753d8a25961810cf6d953f23c27ca3850d3b336ef4f8396deaf7'
OLD=b'"cargo_bound" = intro_crate in intro_carriage.ontop_o'
NEW=b'"cargo_bound" = (intro_crate in intro_carriage.ontop_o)'

DIAGNOSTIC=b'\t\ttext2file(json_encode(list("schema" = 1, "phase" = "before_crop_guard", "maxx" = world.maxx, "maxy" = world.maxy, "maxz" = world.maxz, "map_file" = "filming/carriage.dmm", "expected_map_sha256" = "3dc49458a61577306df9aa51372810524f3d1fd1f36356e8d30af78719ec4907", "game_source" = "58404f5bd16e3fed80f1d9844c5db3edd144942c")), "intro-checks.txt")\n'
GUARD=b'\t\tintro_check(maxx == 15 && maxy == 15 && maxz == 1, "exact 225-cell crop")\n'

def cargo_value(source):
    rows=re.findall(rb'"cargo_bound"\s*=\s*(.*?),\s*"items"\s*=',source)
    if len(rows)!=1 or not re.fullmatch(rb'\(\s*intro_crate\s+in\s+intro_carriage\.ontop_o\s*\)',rows[0]):
        raise ValueError('Cargo membership list value must retain explicit grouping and operand order')

class SceneSyntax(unittest.TestCase):
    def test_scene_preserves_original_bytes_except_reviewed_fix_and_diagnostic(self):
        source=(HERE/'changed-source/filming/scene.dm').read_bytes()
        self.assertEqual(source.count(DIAGNOSTIC+GUARD),1)
        source=source.replace(DIAGNOSTIC,b'')
        cargo_value(source)
        self.assertEqual(source.count(NEW),1)
        self.assertEqual(hashlib.sha256(source.replace(NEW,OLD)).hexdigest(),BEFORE_SHA)
    def test_diagnostic_is_scalar_and_reuses_existing_bounded_log(self):
        self.assertLess(len(DIAGNOSTIC),1024)
        for field in (b'"maxx" = world.maxx',b'"maxy" = world.maxy',b'"maxz" = world.maxz'):
            self.assertEqual(DIAGNOSTIC.count(field),1)
        self.assertTrue(DIAGNOSTIC.endswith(b', "intro-checks.txt")\n'))
        self.assertNotIn(b'world.maxx =',DIAGNOSTIC)
        self.assertNotIn(b'world.maxy =',DIAGNOSTIC)
        self.assertNotIn(b'world.maxz =',DIAGNOSTIC)
    def test_original_failed_expression_is_rejected(self):
        with self.assertRaises(ValueError):cargo_value(OLD+b', "items" = items')
    def test_grouped_value_allows_whitespace(self):
        cargo_value(b'"cargo_bound" = ( intro_crate  in  intro_carriage.ontop_o ), "items" = items')
    def test_reversed_membership_is_rejected(self):
        with self.assertRaises(ValueError):cargo_value(b'"cargo_bound" = (intro_carriage.ontop_o in intro_crate), "items" = items')
    def test_missing_or_duplicate_cargo_witness_is_rejected(self):
        for source in [b'',(NEW+b', "items" = items')*2]:
            with self.subTest(source=source),self.assertRaises(ValueError):cargo_value(source)

if __name__=='__main__':unittest.main()

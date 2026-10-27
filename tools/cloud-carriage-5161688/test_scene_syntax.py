"""Focused source regression, not a replacement for BYOND compilation."""
import hashlib,re,unittest
from pathlib import Path

HERE=Path(__file__).resolve().parent
BEFORE_SHA='71d1259d2c97753d8a25961810cf6d953f23c27ca3850d3b336ef4f8396deaf7'
OLD=b'"cargo_bound" = intro_crate in intro_carriage.ontop_o'
NEW=b'"cargo_bound" = (intro_crate in intro_carriage.ontop_o)'

def cargo_value(source):
    rows=re.findall(rb'"cargo_bound"\s*=\s*(.*?),\s*"items"\s*=',source)
    if len(rows)!=1 or not re.fullmatch(rb'\(\s*intro_crate\s+in\s+intro_carriage\.ontop_o\s*\)',rows[0]):
        raise ValueError('Cargo membership list value must retain explicit grouping and operand order')

class SceneSyntax(unittest.TestCase):
    def test_actual_scene_and_only_two_added_parentheses(self):
        source=(HERE/'changed-source/filming/scene.dm').read_bytes()
        cargo_value(source)
        self.assertEqual(source.count(NEW),1)
        self.assertEqual(hashlib.sha256(source.replace(NEW,OLD)).hexdigest(),BEFORE_SHA)
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

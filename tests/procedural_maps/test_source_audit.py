import unittest
from tools.procedural_maps.source_audit import parse_classic


class SourceParserTests(unittest.TestCase):
    def test_native_y_order_and_layers(self):
        source='"aa" = (/turf/floor/dirt,/area/a)\n"ab" = (/turf/floor/grass,/area/a)\n\n(1,1,1) = {"\naaaa\nabab\n"}\n\n(1,1,2) = {"\nabab\naaaa\n"}\n'
        _,cells,dims=parse_classic(source)
        self.assertEqual([[2,2,1],[2,2,2]],dims)
        self.assertIn('/grass',cells[(2,1,1)])
        self.assertIn('/dirt',cells[(2,2,1)])
        self.assertIn('/grass',cells[(2,2,2)])

    def test_unknown_grid_key_rejected(self):
        source='"aa" = (/turf/floor/dirt,/area/a)\n(1,1,1) = {"\nzz\n"}\n(1,1,2) = {"\naa\n"}\n'
        with self.assertRaises(ValueError):parse_classic(source)


if __name__=="__main__":unittest.main(verbosity=2)

import copy
import unittest
from fixtures import surface,put
from tools.procedural_maps.metrics import fraction_distance,compare_semantic_ir


class MetricTests(unittest.TestCase):
    def test_fraction_distance(self):
        self.assertEqual(0,fraction_distance({"water":2,"land":8},{"water":20,"land":80}))
        self.assertEqual(1,fraction_distance({"water":10},{"land":10}))
        self.assertAlmostEqual(.1,fraction_distance({"water":2,"land":8},{"water":3,"land":7}))

    def test_fractions_are_not_structure(self):
        a=surface();b=copy.deepcopy(a)
        put(b,6,5,tree="NONE");put(b,6,4,tree="BROADLEAF")
        r=compare_semantic_ir(a,b)
        self.assertFalse(r["exact_ir"]);self.assertEqual(0,r["fraction_distance"])
        self.assertIn("UNAVAILABLE",r["structural_acceptance"])

    def test_versions_do_not_make_geometry_different(self):
        a=surface();b=copy.deepcopy(a);b["seed"]="another-fixture"
        self.assertTrue(compare_semantic_ir(a,b)["exact_ir"])

    def test_rejected_candidates_do_not_receive_similarity(self):
        a=surface();b=copy.deepcopy(a);b["ports"]=[]
        r=compare_semantic_ir(a,b);self.assertEqual("INVARIANT_REJECTED",r["status"])
        self.assertIsNone(r["fraction_distance"])

    def test_zero_total_rejected(self):
        with self.assertRaises(ValueError):fraction_distance({"water":0},{"land":1})


if __name__=="__main__":unittest.main(verbosity=2)

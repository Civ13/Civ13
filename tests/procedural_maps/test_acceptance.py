import copy
import unittest
from tools.procedural_maps.acceptance import evaluate
from fixtures import surface
from tools.procedural_maps.validator import stable_u64


class HarnessTests(unittest.TestCase):
    def test_rejection_budget_is_a_hard_bound(self):
        calls=[]
        def factory(seed):
            calls.append(seed);d=surface();d["seed"]=seed;d["ports"]=[];return d
        result=evaluate(["a","b","c"],factory,candidate_budget=2)
        self.assertEqual(["a","b"],calls)
        self.assertEqual("BUDGET_EXHAUSTED",result["status"])
        self.assertIsNone(result["document"])
        self.assertTrue(all(a["reasons"] for a in result["audit"]))

    def test_repair_budget_and_audit(self):
        d=surface();d["ports"]=[];before=copy.deepcopy(d);calls=[]
        def ineffective(doc,reasons,index):calls.append(index);return doc
        r=evaluate(["x"],lambda _:d,candidate_budget=1,repair_budget=2,repair=ineffective)
        self.assertEqual([0,1],calls);self.assertEqual(d,before)
        self.assertEqual(2,len(r["audit"][0]["repairs"]))
        self.assertEqual("BUDGET_EXHAUSTED",r["status"])

    def test_success_is_offline_only_and_repeatable(self):
        def factory(seed):d=surface();d["seed"]=seed;return d
        a=evaluate(["x","y"],factory,candidate_budget=2)
        self.assertEqual(a,evaluate(["x","y"],factory,candidate_budget=2))
        self.assertEqual("ACCEPTED_OFFLINE_IR",a["status"])
        self.assertEqual(1,len(a["audit"]))

    def test_candidate_and_repair_limits_rejected(self):
        for candidates,repairs in [(0,0),(1025,0),(1,4)]:
            with self.assertRaises(ValueError):evaluate([],lambda _:None,candidate_budget=candidates,repair_budget=repairs)

    def test_duplicate_seed_rejected(self):
        with self.assertRaises(ValueError):evaluate(["x","x"],lambda _:None,candidate_budget=2)

    def test_candidate_cannot_claim_another_seed(self):
        result=evaluate(["requested"],lambda _:surface(),candidate_budget=1)
        self.assertEqual("BUDGET_EXHAUSTED",result["status"])
        self.assertIn("SEED_IDENTITY",{e["code"] for e in result["audit"][0]["reasons"]})

    def test_repair_cannot_change_version(self):
        d=surface();d["seed"]="x";d["ports"]=[]
        def wrong_identity(doc,reasons,index):
            doc["ports"]=surface()["ports"];doc["algorithm_version"]="unreviewed/2";return doc
        result=evaluate(["x"],lambda _:d,candidate_budget=1,repair_budget=1,repair=wrong_identity)
        self.assertEqual("BUDGET_EXHAUSTED",result["status"])
        self.assertIn("REPAIR_IDENTITY",{e["code"] for e in result["audit"][0]["reasons"]})

    def test_successful_repair_retains_original_rejection(self):
        d=surface();d["seed"]="x";d["ports"]=[]
        def fix(doc,reasons,index):doc["ports"]=surface()["ports"];return doc
        result=evaluate(["x"],lambda _:d,candidate_budget=1,repair_budget=1,repair=fix)
        self.assertEqual("ACCEPTED_OFFLINE_IR",result["status"])
        self.assertTrue(result["audit"][0]["initial_reasons"])
        self.assertTrue(result["audit"][0]["repairs"][0]["trigger_reasons"])

    def test_stable_random_golden_vector(self):
        value=stable_u64("42","a/1","c/1","SURFACE/1","flora","SURFACE",0,0)
        # Literal value binds framing/endianness; not a matching map seed.
        self.assertEqual("588a81055b889362",f"{value:016x}")


if __name__=="__main__":unittest.main(verbosity=2)

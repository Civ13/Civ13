import copy
import unittest
from tools.procedural_maps.configuration import preset
from tools.procedural_maps.surface_generator import generate,ALGORITHM_VERSION
from tools.procedural_maps.validator import validate,canonical_hash


def small(seed="pilot-0"):
    c=preset(seed=seed);c["dimensions"].update(width=64,height=80);c["starts"]["count"]=4
    return c


class GeneratorTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):cls.generated=generate(small())
    def test_valid_generated_core_ir(self):
        r=self.generated;self.assertEqual("GENERATED_VALID_OFFLINE_IR",r["status"],r["reasons"])
        self.assertEqual([],validate(r["document"]))
        self.assertEqual(ALGORITHM_VERSION,r["document"]["algorithm_version"])
    def test_golden_small_ir_hash(self):
        self.assertEqual("8d797d48bb154abc867baa7c6d980f8fee9c3604980417d6c3c03cffd43a6f85",canonical_hash(self.generated["document"]))
    def test_reverse_traversal_equal(self):
        reverse=generate(small(),traversal="reverse")
        self.assertEqual(self.generated,reverse)
    def test_distinct_seeds_change_geography(self):
        other=generate(small("pilot-1"));self.assertEqual("GENERATED_VALID_OFFLINE_IR",other["status"])
        a=copy.deepcopy(self.generated["document"]);b=copy.deepcopy(other["document"])
        a["seed"]=b["seed"]="ignore-seed-field"
        self.assertNotEqual(canonical_hash(a),canonical_hash(b))
    def test_config_not_mutated(self):
        c=small();old=copy.deepcopy(c);generate(c);self.assertEqual(old,c)
    def test_full_configuration_is_bound(self):
        r=self.generated;m=r["manifest"]
        self.assertEqual(small(),m["configuration"])
        self.assertEqual(canonical_hash(small()),m["configuration_sha256"])
        self.assertEqual(canonical_hash(r["document"]),m["generation_result"]["ir_sha256"])
    def test_other_profile_rejected_before_generation(self):
        r=generate(preset("OCEANIC"));self.assertIsNone(r["document"])
        self.assertEqual("BACKEND_PROFILE",r["reasons"][0]["code"])
    def test_unsupported_biome_rejected(self):
        c=small();c["biome_mix_pct"]={"COAST":100};r=generate(c)
        self.assertEqual("BACKEND_BIOMES",r["reasons"][0]["code"])
    def test_invalid_config_rejected(self):
        c=small();c["disable_hard_rules"]=True
        self.assertEqual("CONFIG_REJECTED",generate(c)["reasons"][0]["code"])
    def test_dense_vegetation_preserves_recorded_routes(self):
        c=small();c["vegetation"]["suitable_site_density_pct"]=[70,70]
        r=generate(c);self.assertEqual("GENERATED_VALID_OFFLINE_IR",r["status"],r["reasons"])
        for x,y in r["manifest"]["reserved_route_cells"]:
            tile=r["document"]["layers"]["SURFACE"]["cells"][y][x]
            self.assertEqual("NONE",tile["tree"]);self.assertFalse(tile["blocked"])
    def test_mutated_dead_end_fails_oracle(self):
        d=copy.deepcopy(self.generated["document"]);d["rivers"][0]["sink"]["target"]="missing"
        self.assertIn("RIVER_ENDPOINT",{e["code"] for e in validate(d)})
    def test_mutated_mountain_speckle_fails_oracle(self):
        d=copy.deepcopy(self.generated["document"])
        # Find a clear land tile with no mountain neighbor to make a genuine singleton.
        cells=d["layers"]["SURFACE"]["cells"]
        for y in range(1,d["height"]-1):
            for x in range(1,d["width"]-1):
                if cells[y][x]["water"]=="NONE" and all(cells[yy][xx]["terrain"]!="MOUNTAIN" for xx,yy in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)]):
                    cells[y][x].update(terrain="MOUNTAIN",blocked=True,tree="NONE")
                    self.assertIn("MOUNTAIN_RANGE",{e["code"] for e in validate(d)});return
        self.fail("no mutation site")
    def test_zero_vegetation_control_changes_structure(self):
        c=small();c["vegetation"]["suitable_site_density_pct"]=[0,0];r=generate(c)
        self.assertEqual("GENERATED_VALID_OFFLINE_IR",r["status"],r["reasons"])
        self.assertTrue(all(tile["tree"]=="NONE" for row in r["document"]["layers"]["SURFACE"]["cells"] for tile in row))


if __name__=="__main__":unittest.main(verbosity=2)

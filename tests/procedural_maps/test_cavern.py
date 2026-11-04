import copy
import tempfile
import unittest
from pathlib import Path
from tools.procedural_maps.bundle import write_bundle,verify_bundle
from tools.procedural_maps.cavern_generator import ALGORITHM_VERSION
from tools.procedural_maps.configuration import preset
from tools.procedural_maps.dmm_export import project
from tools.procedural_maps.generator import generate
from tools.procedural_maps.validator import validate,canonical_hash


def small(seed="cave-0"):
    c=preset("UNDERGROUND_CAVERN",seed);c["dimensions"].update(width=64,height=80);c["starts"]["count"]=4
    return c


def codes(d):return {e["code"] for e in validate(d)}


class CavernGeneratorTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):cls.generated=generate(small())
    def doc(self):return copy.deepcopy(self.generated["document"])
    def test_valid_generated_cavern_ir(self):
        r=self.generated;self.assertEqual("GENERATED_VALID_OFFLINE_IR",r["status"],r["reasons"])
        d=r["document"];self.assertEqual([],validate(d))
        self.assertEqual(("UNDERGROUND_CAVERN","UNDERGROUND",ALGORITHM_VERSION),(d["profile"],d["active_layer"],d["algorithm_version"]))
        self.assertEqual(4,len(d["starts"]));self.assertTrue(all(p[2]=="UNDERGROUND" for p in d["starts"]))
    def test_golden_small_ir_hash(self):
        self.assertEqual("af5dd7708928edcaaf775299f86e243ac673c41aec1022b32bf0b90688bef22c",canonical_hash(self.generated["document"]))
    def test_reverse_traversal_equal(self):
        self.assertEqual(self.generated,generate(small(),traversal="reverse"))
    def test_distinct_seeds_change_layout(self):
        other=generate(small("cave-1"));self.assertEqual("GENERATED_VALID_OFFLINE_IR",other["status"],other["reasons"])
        a=self.doc();b=copy.deepcopy(other["document"]);a["seed"]=b["seed"]="ignore"
        self.assertNotEqual(canonical_hash(a),canonical_hash(b))
    def test_several_seeds_and_full_size_preset(self):
        for seed in ["cave-2","cave-3","x"]:
            r=generate(small(seed));self.assertEqual("GENERATED_VALID_OFFLINE_IR",r["status"],(seed,r["reasons"]))
        r=generate(preset("UNDERGROUND_CAVERN","full-0"));self.assertEqual("GENERATED_VALID_OFFLINE_IR",r["status"],r["reasons"])
    def test_config_not_mutated_and_bound(self):
        c=small();old=copy.deepcopy(c);r=generate(c);self.assertEqual(old,c)
        self.assertEqual(canonical_hash(c),r["manifest"]["configuration_sha256"])
        self.assertEqual(canonical_hash(r["document"]),r["manifest"]["generation_result"]["ir_sha256"])
    def test_pools_are_fresh_terminal_and_inside_water_budget(self):
        d=self.generated["document"];area=d["width"]*d["height"]
        cells=[c for row in d["layers"]["UNDERGROUND"]["cells"] for c in row]
        water=[c for c in cells if c["water"]!="NONE"]
        self.assertTrue(water);self.assertTrue(all(c["water"]=="LAKE" and c["salinity"]=="FRESH" for c in water))
        self.assertTrue(all(l["terminal_basin"] for l in d["lakes"]))
        lo,hi=small()["water"]["coverage_pct"];self.assertTrue(lo*area<=len(water)*100<=hi*area)
    def test_fungus_never_blocks_routes_or_exits(self):
        d=self.generated["document"];m=self.generated["manifest"];cells=d["layers"]["UNDERGROUND"]["cells"]
        self.assertGreater(m["fungus_pillars"],0)
        for x,y in m["reserved_route_cells"]:self.assertEqual("NONE",cells[y][x]["tree"])
        for portal in d["portals"]:
            x,y,_=portal["a"];self.assertEqual("NONE",cells[y][x]["tree"]);self.assertEqual("CAVE_FLOOR",cells[y][x]["terrain"])
    def test_surface_exits_pair_layers(self):
        d=self.generated["document"];self.assertGreaterEqual(len(d["portals"]),2)
        for portal in d["portals"]:
            self.assertEqual(("UNDERGROUND","SURFACE"),(portal["a"][2],portal["b"][2]))
    def test_rivers_and_wetlands_rejected_before_generation(self):
        c=small();c["water"]["river_networks"]=[1,2];self.assertEqual("BACKEND_RIVERS",generate(c)["reasons"][0]["code"])
        c=small();c["water"]["swamp_pct"]=[1,2];self.assertEqual("BACKEND_WATER",generate(c)["reasons"][0]["code"])
        # A cavern with no spring pool is refused, by config checks or by the backend.
        c=small();c["water"]["lake_count"]=[0,0];r=generate(c)
        self.assertIsNone(r["document"]);self.assertIn(r["reasons"][0]["code"],{"CONFIG_REJECTED","WATER_BUDGET"})
    def test_invalid_config_rejected(self):
        c=small();c["disable_hard_rules"]=True
        self.assertEqual("CONFIG_REJECTED",generate(c)["reasons"][0]["code"])
    def test_sealed_chamber_fails_oracle(self):
        d=self.doc();cells=d["layers"]["UNDERGROUND"]["cells"]
        # Wall off every tunnel tile so chambers no longer connect.
        for y,row in enumerate(cells):
            for x,c in enumerate(row):
                if c["terrain"]=="CAVE_FLOOR" and y==d["height"]//2:c.update(terrain="ROCK",blocked=True,tree="NONE",resource="NONE")
        self.assertIn("CAVERN_CONNECTIVITY",codes(d))
    def test_removed_exits_fail_oracle(self):
        d=self.doc();d["portals"]=[];self.assertIn("CAVERN_EXIT",codes(d))
    def test_fungus_on_start_fails_oracle(self):
        d=self.doc();x,y,_=d["starts"][0];d["layers"]["UNDERGROUND"]["cells"][y][x]["tree"]="FUNGUS"
        self.assertIn("START_SAFE",codes(d))
    def test_export_and_verify_bundle(self):
        r=self.generated;layout=project(r["document"])
        self.assertEqual(2*64*80,len(layout))
        self.assertNotIn("FUNGUS",",".join(layout.values()))
        with tempfile.TemporaryDirectory() as tmp:
            folder=Path(tmp);write_bundle(folder,r["document"],r["manifest"],preview=True,fresh=True)
            self.assertTrue(verify_bundle(folder)["static_native_layout_equal"])
            self.assertTrue((folder/"preview.png").read_bytes().startswith(b"\x89PNG"))


if __name__=="__main__":unittest.main()

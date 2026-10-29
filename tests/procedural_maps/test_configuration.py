import copy
import unittest
from tools.procedural_maps.configuration import preset,validate_config,seed_manifest
from tools.procedural_maps.validator import canonical_hash


class ConfigurationTests(unittest.TestCase):
    def has(self,d,code):self.assertIn(code,{e["code"] for e in validate_config(d)},validate_config(d))
    def test_presets_are_consistent(self):
        for p in ["SURFACE","OCEANIC","UNDERGROUND_CAVERN"]:
            self.assertEqual([],validate_config(preset(p)))
    def test_no_invariant_switch(self):
        d=preset();d["disable_river_rules"]=True;self.has(d,"CONFIG_SCHEMA")
    def test_bounds(self):
        d=preset();d["dimensions"]["width"]=513;self.has(d,"CONFIG_SCHEMA")
    def test_mixed_profile_preset(self):
        d=preset();d["preset"]="ARCHIPELAGO";self.has(d,"CONFIG_SCHEMA")
    def test_biome_sum(self):
        d=preset();d["biome_mix_pct"]["TEMPERATE"]=99;self.has(d,"CONFIG_SCHEMA")
    def test_water_budget(self):
        d=preset();d["water"]["sea_pct"]=[21,22];self.has(d,"CONFIG_WATER_BUDGET")
    def test_lake_count_area_conflict(self):
        d=preset();d["water"]["lake_count"]=[0,0];self.has(d,"CONFIG_LAKE_CONFLICT")
    def test_lush_desert_missing_transitions(self):
        d=preset();d["biome_mix_pct"]={"LUSH":50,"DESERT":50};self.has(d,"CONFIG_ECOTONE")
    def test_impossible_climate(self):
        d=preset();d["biome_mix_pct"]={"LUSH":100};d["climate"]["moisture_range"]=[0,30];self.has(d,"CONFIG_CLIMATE")
    def test_cavern_surface_biome_conflict(self):
        d=preset("UNDERGROUND_CAVERN");d["biome_mix_pct"]={"TEMPERATE":100};self.has(d,"CONFIG_PROFILE")
    def test_oceanic_dry_conflict(self):
        d=preset("OCEANIC");d["water"]["sea_pct"]=[20,30];self.has(d,"CONFIG_OCEANIC")
    def test_feature_scale(self):
        d=preset();d["dimensions"]["width"]=32;d["water"]["river_width_tiles"]=[16,16];self.has(d,"CONFIG_SCALE")
    def test_start_spacing_impossible(self):
        d=preset();d["dimensions"].update(width=32,height=32);d["starts"]["min_spacing_tiles"]=64;self.has(d,"CONFIG_START_CAPACITY")
    def test_exact_config_manifest_and_no_mutation(self):
        d=preset(seed="saved-seed");old=copy.deepcopy(d);m=seed_manifest(d,"algorithm/1","content/1","profile/1")
        self.assertEqual(old,d);self.assertEqual(d,m["configuration"])
        self.assertEqual(canonical_hash(d),m["configuration_sha256"])
        d["seed"]="changed";self.assertNotEqual(d,m["configuration"])
        self.assertIsNone(m["generation_result"])
    def test_invalid_manifest_not_created(self):
        d=preset();d["starts"]["count"]=0
        self.assertEqual("CONFIG_REJECTED",seed_manifest(d,"a","c","p")["status"])


if __name__=="__main__":unittest.main(verbosity=2)

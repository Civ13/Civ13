import copy
import unittest
from fixtures import surface, lake_surface, oceanic, cavern, all_fixtures, put, cell, water
from tools.procedural_maps.validator import validate, stable_u64, canonical_hash, dry_run_patch


class ValidatorTests(unittest.TestCase):
    def has(self,d,code):
        self.assertIn(code,{e["code"] for e in validate(d)},validate(d))

    def test_positive_profiles_and_lake_endings(self):
        for name,d in all_fixtures().items():
            with self.subTest(name=name):self.assertEqual([],validate(d))

    def test_no_mutation(self):
        d=surface(); before=copy.deepcopy(d);validate(d);self.assertEqual(before,d)

    def test_unknown_field_rejected(self):
        d=surface();d["ignore_failures"]=True;self.has(d,"SCHEMA")

    def test_boolean_coordinate_rejected(self):
        d=surface();d["starts"][0][0]=True;self.has(d,"SCHEMA")

    def test_ragged_grid_rejected(self):
        d=surface();d["layers"]["SURFACE"]["cells"][0].pop();self.has(d,"SCHEMA")

    def test_native_z_mapping_rejected(self):
        d=surface();d["layers"]["SURFACE"]["native_z"]=1;self.has(d,"SCHEMA")

    def test_unknown_species_rejected(self):
        d=surface();put(d,4,4,tree="imaginary");self.has(d,"SCHEMA")

    def test_negative_depth_rejected(self):
        d=surface();put(d,0,0,depth_cm=-1);self.has(d,"SCHEMA")

    def test_saline_river_rejected(self):
        d=surface();put(d,0,0,salinity="SALT");self.has(d,"SALINITY")

    def test_land_water_mismatch(self):
        d=surface();put(d,2,2,depth_cm=20);self.has(d,"WATER_TYPE")

    def test_swamp_requires_saturated_substrate(self):
        d=surface();water(d,3,3,"SWAMP","s1",moisture=30,soil="SAND");self.has(d,"SWAMP_SITE")

    def test_dead_end_rejected(self):
        d=surface();d["rivers"][0]["sink"]["target"]="missing";self.has(d,"RIVER_ENDPOINT")

    def test_false_edge_port_rejected(self):
        d=surface();d["ports"][0]["at"]=[3,3,"SURFACE"];self.has(d,"PORT_EDGE")

    def test_directional_port_rejected(self):
        d=surface();d["ports"][0]["role"]="OUTLET";self.has(d,"RIVER_ENDPOINT")

    def test_duplicate_ports_rejected(self):
        d=surface();d["ports"].append(copy.deepcopy(d["ports"][0]));self.has(d,"PORT_DUPLICATE")

    def test_unused_port_rejected(self):
        d=surface();d["ports"].append(dict(id="unused",at=[8,0,"SURFACE"],side="E",role="INLET",body="r1"));self.has(d,"PORT_UNUSED")

    def test_raster_gap_rejected(self):
        d=surface();put(d,0,4,**cell());self.has(d,"RIVER_RASTER");self.has(d,"RIVER_PATH")

    def test_disconnected_graph_only_river_rejected(self):
        d=surface();d["rivers"][0]["path"].pop(4);self.has(d,"RIVER_PATH")

    def test_repeated_path_rejected(self):
        d=surface();d["rivers"][0]["path"].insert(2,[0,8,"SURFACE"]);self.has(d,"RIVER_RASTER")

    def test_river_blob_rejected(self):
        d=surface()
        for x in [1,2,3]:water(d,x,4,"RIVER","r1")
        self.has(d,"RIVER_WIDTH")

    def test_uphill_flow_rejected(self):
        d=surface();put(d,0,3,elevation_m=50);self.has(d,"RIVER_UPHILL")

    def test_undeclared_river_rejected(self):
        d=surface();water(d,8,8,"RIVER","ghost");self.has(d,"RIVER_UNDECLARED")

    def test_false_lake_contact_rejected(self):
        d=lake_surface();d["rivers"][0]["sink"]["target"]="other";self.has(d,"RIVER_ENDPOINT")

    def test_through_lake_no_outlet(self):
        d=lake_surface();d["lakes"][0]["terminal_basin"]=False;self.has(d,"LAKE_OUTLET")

    def test_terminal_lake_with_outlet(self):
        d=lake_surface(False);d["lakes"][0]["terminal_basin"]=True;self.has(d,"LAKE_OUTLET")

    def test_lake_fragment_rejected(self):
        d=lake_surface();water(d,8,8,"LAKE","l1");self.has(d,"LAKE_RASTER")

    def test_cycle_rejected(self):
        d=surface();d["rivers"][0]["sink"]={"kind":"RIVER","target":"r1"};self.has(d,"RIVER_CYCLE")

    def test_network_without_edge_rejected(self):
        d=lake_surface();d["rivers"][0]["source"]={"kind":"LAKE","target":"l1"};self.has(d,"RIVER_NO_EDGE")

    def test_singleton_mountain_rejected(self):
        d=surface();put(d,8,3,terrain="MOUNTAIN",blocked=True);self.has(d,"MOUNTAIN_RANGE")

    def test_lush_desert_adjacency_rejected(self):
        d=surface();put(d,4,4,biome="LUSH",moisture=70);put(d,5,4,biome="DESERT",moisture=20);self.has(d,"ECOTONE")

    def test_climate_gradient_rejected(self):
        d=surface();put(d,4,4,temperature_c=-20);self.has(d,"CLIMATE_GRADIENT")

    def test_desert_wet_rejected(self):
        d=surface();put(d,4,4,biome="DESERT");self.has(d,"CLIMATE_SITE")

    def test_tree_in_water_rejected(self):
        d=surface();put(d,0,4,tree="BROADLEAF");self.has(d,"VEGETATION_SITE")

    def test_tree_on_blocked_site_rejected(self):
        d=surface();put(d,3,3,tree="PINE",blocked=True);self.has(d,"VEGETATION_SITE")

    def test_tree_above_envelope_rejected(self):
        d=surface();put(d,3,3,tree="BROADLEAF",elevation_m=4000);self.has(d,"VEGETATION_SITE")

    def test_palms_in_cold_rejected(self):
        d=surface();put(d,3,3,tree="PALM",temperature_c=0);self.has(d,"VEGETATION_SITE")

    def test_start_water_rejected(self):
        d=surface();d["starts"]=[[0,0,"SURFACE"]];self.has(d,"START_SAFE")

    def test_start_enclosed_resources_rejected(self):
        d=surface()
        for x,y in [(1,2),(3,2),(2,1),(2,3)]:put(d,x,y,blocked=True)
        self.has(d,"START_RESOURCE");self.has(d,"START_WATER")

    def test_resource_distance_rejected(self):
        d=surface();d["policy"]["max_resource_distance"]=0;self.has(d,"START_RESOURCE")

    def test_duplicate_starts_rejected(self):
        d=surface();d["starts"]*=2;self.has(d,"START_COUNT")

    def test_ocean_disconnected_rejected(self):
        d=oceanic()
        for y in range(11):put(d,6,y,**cell())
        self.has(d,"OCEAN_NAVIGATION")

    def test_no_ocean_ports_rejected(self):
        d=oceanic();d["ports"]=[];self.has(d,"OCEAN_PORTS")

    def test_no_islands_rejected(self):
        d=surface();d["profile"]="OCEANIC";self.has(d,"ISLANDS")

    def test_ship_clearance_rejected(self):
        d=oceanic()
        for y in range(11):
            if y!=5:put(d,6,y,**cell())
        d["policy"]["ship_radius"]=1;self.has(d,"OCEAN_NAVIGATION")

    def test_cavern_isolated_chamber_rejected(self):
        d=cavern()
        for y in range(1,8):put(d,4,y,"UNDERGROUND",terrain="ROCK",blocked=True)
        self.has(d,"CAVERN_CONNECTIVITY")

    def test_cavern_no_exit_rejected(self):
        d=cavern();d["portals"]=[];self.has(d,"CAVERN_EXIT")

    def test_portal_bad_destination_rejected(self):
        d=cavern();put(d,1,1,blocked=True);self.has(d,"PORTAL")

    def test_portal_same_layer_rejected(self):
        d=cavern();d["portals"][0]["b"]=[2,1,"UNDERGROUND"];self.has(d,"PORTAL")

    def test_stable_draw_order_and_domain_separation(self):
        args=("42","a/1","c/1","SURFACE/1","flora","SURFACE")
        xy=[(x,y) for x in range(3) for y in range(3)]
        forward={p:stable_u64(*args,*p) for p in xy}
        reverse={p:stable_u64(*args,*p) for p in reversed(xy)}
        self.assertEqual(forward,reverse)
        self.assertNotEqual(stable_u64(*args,0,0),stable_u64(*args,0,0,1))
        self.assertNotEqual(stable_u64(*args,0,0),stable_u64("43",*args[1:],0,0))
        self.assertEqual(16,len(f'{stable_u64(*args,0,0):016x}'))

    def test_hash_key_order_independent(self):
        self.assertEqual(canonical_hash({"a":1,"b":2}),canonical_hash({"b":2,"a":1}))

    def test_patch_no_player_overwrite_and_atomic_rejection(self):
        base={"a":{"owner":"GENERATOR","revision":1},"b":{"owner":"PLAYER","revision":2}}
        old=copy.deepcopy(base)
        result=dry_run_patch(base,[{"at":"a","expected_revision":1},{"at":"b","expected_revision":2}],"g1","g1")
        self.assertFalse(result["accepted"]);self.assertEqual([],result["plan"]);self.assertEqual(old,base)

    def test_patch_revision_and_generation_guards(self):
        base={"a":{"owner":"GENERATOR","revision":1}}
        self.assertFalse(dry_run_patch(base,[{"at":"a","expected_revision":0}],"g1","g1")["accepted"])
        self.assertFalse(dry_run_patch(base,[],"g1","g2")["accepted"])
        result=dry_run_patch(base,[{"at":"a","expected_revision":1}],"g1","g1")
        self.assertTrue(result["accepted"]);self.assertEqual("OFFLINE_PLAN_ONLY",result["reason"])


if __name__=="__main__":unittest.main(verbosity=2)

"""Oceanic generation and independent negative controls; no native engine."""
from copy import deepcopy
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from tools.procedural_maps.bundle import check_manifest,write_bundle,verify_bundle
from tools.procedural_maps.configuration import oceanic_preset,preset,validate_config
from tools.procedural_maps.dmm_export import emit,verify_roundtrip
from tools.procedural_maps.generator import generate
from tools.procedural_maps.ocean_generator import ALGORITHM_VERSION
from tools.procedural_maps.validator import canonical_hash,validate

ROOT=Path(__file__).resolve().parents[2]


class OceanicTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.config=oceanic_preset();cls.result=generate(cls.config)
        if cls.result['document'] is None:raise AssertionError(cls.result['reasons'])
    def changed(self,mutate,code):
        doc=deepcopy(self.result['document']);mutate(doc)
        self.assertIn(code,{e['code'] for e in validate(doc)})
    def test_generated_archipelago(self):
        d=self.result['document'];self.assertEqual([],validate(d));self.assertEqual('OCEANIC',d['profile'])
        self.assertEqual(ALGORITHM_VERSION,d['algorithm_version']);self.assertGreaterEqual(len(d['lakes']),2)
        self.assertEqual([],d['rivers']);self.assertEqual(4,len(d['ports']))
    def test_oceanic_golden_hash(self):
        self.assertEqual('f2799e5e1bb6622d2cd8a84429bc3910d46def5995bb9b1cc4b91a54ceeeb24c',canonical_hash(self.result['document']))
    def test_traversal_and_config_immutability(self):
        c=deepcopy(self.config);r=generate(c,traversal='reverse')
        self.assertEqual(c,self.config);self.assertEqual(self.result,r)
    def test_other_seed_changes_geometry(self):
        r=generate(oceanic_preset('ocean-1'));self.assertIsNotNone(r['document'],r['reasons'])
        a=deepcopy(self.result['document']);b=deepcopy(r['document']);a['seed']=b['seed']='ignored'
        self.assertNotEqual(canonical_hash(a),canonical_hash(b))
    def test_reference_dimensions(self):
        r=generate(oceanic_preset('ocean-reference-0',155,225));self.assertIsNotNone(r['document'],r['reasons'])
        self.assertEqual([],validate(r['document']));self.assertEqual(225,len(r['document']['layers']['SURFACE']['cells']))
    def test_no_template_or_native_resource_admission(self):
        m=self.result['manifest'];self.assertEqual('NOT_EVALUATED',m['reference_matching'])
        self.assertEqual('NOT_RUN',m['generation_result']['native_acceptance'])
        self.assertEqual('PENDING',m['native_resource_admission'])
    def test_reserved_routes_stay_clear_at_high_density(self):
        c=deepcopy(self.config);c['vegetation']['suitable_site_density_pct']=[70,70]
        r=generate(c);self.assertIsNotNone(r['document'],r['reasons'])
        for x,y in r['manifest']['reserved_route_cells']:
            tile=r['document']['layers']['SURFACE']['cells'][y][x]
            self.assertEqual('NONE',tile['tree']);self.assertFalse(tile['blocked']);self.assertEqual('NONE',tile['water'])
        self.assertEqual([],validate(r['document']))
    def test_route_witnesses(self):
        grid=self.result['document']['layers']['SURFACE']['cells']
        for record in self.result['manifest']['abstract_routes']:
            for label in ['coast_route','freshwater_bank_route']:
                route=record[label];self.assertEqual(record['start'],route[0])
                self.assertLessEqual(len(route)-1,self.config['starts']['max_route_tiles'])
                self.assertTrue(all(abs(a[0]-b[0])+abs(a[1]-b[1])==1 for a,b in zip(route,route[1:])))
            x,y=record['coast_route'][-1]
            self.assertTrue(any(grid[b][a]['water']=='SEA' for a,b in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)]))
    def test_mountains_form_ranges(self):
        c=deepcopy(self.config);c['mountains']['range_count']=[1,1]
        r=generate(c);self.assertIsNotNone(r['document'],r['reasons']);self.assertEqual([],validate(r['document']))
        self.assertEqual(1,r['manifest']['generated_topology']['ranges'])
    def test_zero_tree_control(self):
        c=deepcopy(self.config);c['vegetation']['suitable_site_density_pct']=[0,0]
        r=generate(c);self.assertIsNotNone(r['document'],r['reasons'])
        self.assertTrue(all(c['tree']=='NONE' for row in r['document']['layers']['SURFACE']['cells'] for c in row))
    def test_full_climate_sequence(self):
        c=oceanic_preset('ocean-climate-0')
        c['biome_mix_pct']={'COAST':20,'LUSH':15,'TEMPERATE':25,'STEPPE':20,'ARID':10,'DESERT':10}
        c['climate']['moisture_range']=[10,90]
        r=generate(c);self.assertIsNotNone(r['document'],r['reasons']);self.assertEqual([],validate(r['document']))
        biomes={tile['biome'] for row in r['document']['layers']['SURFACE']['cells'] for tile in row if tile['water']=='NONE'}
        self.assertEqual(set(c['biome_mix_pct']),biomes)
    def test_configurable_ship_footprint(self):
        c=deepcopy(self.config);c['ocean_layout'].update(island_count=[2,2],ship_radius=2,island_gap_tiles=8)
        c['water']['lake_count']=[2,2]
        r=generate(c);self.assertIsNotNone(r['document'],r['reasons']);self.assertEqual([],validate(r['document']))
        self.assertEqual(2,r['document']['policy']['ship_radius'])
    def test_config_count_conflict(self):
        c=deepcopy(self.config);c['ocean_layout']['island_count']=[4,5]
        self.assertEqual('CONFIG_OCEAN_LAYOUT',validate_config(c)[0]['code'])
    def test_config_gap_ship_conflict(self):
        c=deepcopy(self.config);c['ocean_layout']['ship_radius']=3
        self.assertTrue(validate_config(c))
    def test_config_rivers_rejected_before_generation(self):
        c=deepcopy(self.config);c['water']['river_networks']=[1,1]
        self.assertEqual('CONFIG_REJECTED',generate(c)['reasons'][0]['code'])
    def test_config_swamp_rejected(self):
        c=deepcopy(self.config);c['water']['swamp_pct']=[0,1];self.assertTrue(validate_config(c))
    def test_config_unknown_invariant_switch(self):
        c=deepcopy(self.config);c['disable_navigation']=True;self.assertTrue(validate_config(c))
    def test_config_profile_mismatch(self):
        c=deepcopy(self.config);c['profile']='SURFACE';self.assertTrue(validate_config(c))
    def test_cavern_and_legacy_ocean_do_not_fall_back(self):
        for profile in ['UNDERGROUND_CAVERN','OCEANIC']:
            r=generate(preset(profile));self.assertIsNone(r['document']);self.assertEqual('BACKEND_PROFILE',r['reasons'][0]['code'])
    def test_small_impossible_geometry_rejects_once(self):
        c=oceanic_preset('impossible',32,32);c['ocean_layout']['island_gap_tiles']=24
        r=generate(c);self.assertIsNone(r['document']);self.assertEqual(1,len(r['reasons']))
    def test_incorrect_island_count(self):
        self.changed(lambda d:d['ocean_policy'].update(island_count=6),'OCEAN_ISLAND_COUNT')
    def test_tiny_land_speckle(self):
        def mutate(d):
            from tools.procedural_maps.surface_generator import ground
            d['layers']['SURFACE']['cells'][1][1]=ground()
        self.changed(mutate,'OCEAN_ISLAND_AREA')
    def test_missing_island_start(self):
        def mutate(d):
            keep=self.result['manifest']['abstract_routes'][0]['island']
            d['starts']=[r['start']+['SURFACE'] for r in self.result['manifest']['abstract_routes'] if r['island']==keep]
            d['policy']['start_count']=len(d['starts'])
        self.changed(mutate,'OCEAN_ISLAND_START')
    def test_sea_body_identity(self):
        self.changed(lambda d:d['layers']['SURFACE']['cells'][0][0].update(body='unexplained-sea'),'OCEAN_SEA_BODY')
    def test_missing_ocean_port_cannot_lower_policy(self):
        def mutate(d):d['ports'].pop();d['policy']['ocean_ports_min']=1
        self.changed(mutate,'OCEAN_PORT_LAYOUT')
    def test_land_at_map_edge(self):
        def mutate(d):
            from tools.procedural_maps.surface_generator import ground
            d['layers']['SURFACE']['cells'][0][1]=ground()
        self.changed(mutate,'OCEAN_BOUNDARY')
    def test_lake_contact_with_salt_water(self):
        def mutate(d):
            grid=d['layers']['SURFACE']['cells']
            for y,row in enumerate(grid):
                for x,c in enumerate(row):
                    if c['water']=='LAKE':
                        for a,b in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)]:
                            if grid[b][a]['water']=='NONE':
                                grid[b][a].update(terrain='WATER',water='SEA',salinity='SALT',body='ocean',depth_cm=200,tree='NONE',resource='NONE');return
        self.changed(mutate,'OCEAN_INLAND_LAKE')
    def test_lake_requires_terminal_basin(self):
        self.changed(lambda d:d['lakes'][0].update(terminal_basin=False),'OCEAN_LAKE_ENDPOINT')
    def test_gap_rule_cannot_be_ignored(self):
        self.changed(lambda d:d['ocean_policy'].update(island_gap_tiles=24),'OCEAN_ISLAND_GAP')
    def test_start_spacing(self):
        def mutate(d):d['starts'][1]=[d['starts'][0][0]+1,d['starts'][0][1],'SURFACE']
        self.changed(mutate,'OCEAN_START_SPACING')
    def test_bounded_coast_route(self):
        def mutate(d):
            g=d['layers']['SURFACE']['cells']
            for y,row in enumerate(g):
                for x,c in enumerate(row):
                    if c['water']=='NONE' and any(g[b][a]['water']=='SEA' for a,b in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)]):c['hazard']=True
        self.changed(mutate,'OCEAN_START_COAST_BOUND')
    def test_tree_in_sea(self):
        self.changed(lambda d:d['layers']['SURFACE']['cells'][0][0].update(tree='PALM'),'VEGETATION_SITE')
    def test_deep_water_barrier(self):
        def mutate(d):
            for row in d['layers']['SURFACE']['cells']:
                if row[d['width']//2]['water']=='SEA':row[d['width']//2]['depth_cm']=30
        self.changed(mutate,'OCEAN_NAVIGATION')
    def test_undeclared_island_river(self):
        self.changed(lambda d:d['layers']['SURFACE']['cells'][0][0].update(water='RIVER',salinity='FRESH'),'OCEAN_HYDROLOGY_SLICE')
    def test_false_ocean_profile_schema(self):
        self.changed(lambda d:d.update(profile='UNDERGROUND_CAVERN'),'SCHEMA')
    def test_missing_surface_layer_rejects_cleanly(self):
        self.changed(lambda d:d['layers'].pop('SURFACE'),'SCHEMA')
    def test_export_roundtrip_keeps_semantics(self):
        d=self.result['document'];m=self.result['manifest'];text,sidecar=emit(d,m)
        self.assertEqual(d,sidecar['semantic_ir']);self.assertEqual(m,sidecar['manifest'])
        proof=verify_roundtrip(text,sidecar);self.assertTrue(proof['ir_plus_sidecar_semantics_equal'])
        self.assertNotIn('/obj/item/',text)
    def test_ocean_config_binding(self):
        d=self.result['document'];m=deepcopy(self.result['manifest'])
        m['configuration']['ocean_layout']['island_min_area']=65
        m['configuration_sha256']=canonical_hash(m['configuration'])
        with self.assertRaisesRegex(ValueError,'OCEAN_CONFIG_BINDING'):check_manifest(d,m)
    def test_profile_manifest_binding(self):
        m=deepcopy(self.result['manifest']);m['configuration']=preset(seed=self.config['seed'])
        m['configuration']['dimensions'].update(width=64,height=80)
        m['configuration_sha256']=canonical_hash(m['configuration'])
        with self.assertRaisesRegex(ValueError,'PROFILE_BINDING'):check_manifest(self.result['document'],m)
    def test_complete_bundle(self):
        with tempfile.TemporaryDirectory() as folder:
            p=Path(folder);write_bundle(p,self.result['document'],self.result['manifest'],preview=True)
            self.assertFalse(verify_bundle(p)['native_ready'])
    def test_cli_oceanic_preset_generate_verify(self):
        with tempfile.TemporaryDirectory() as folder:
            p=Path(folder);config=p/'config.json';output=p/'map'
            for args in [['preset','--profile','OCEANIC','--seed','ocean-0','--out',str(config)],
                         ['generate','--config',str(config),'--out',str(output),'--no-preview'],['verify',str(output)]]:
                r=subprocess.run([sys.executable,'-B','-m','tools.procedural_maps',*args],cwd=ROOT,capture_output=True,text=True)
                self.assertEqual(0,r.returncode,r.stdout+r.stderr)
            self.assertEqual('civ13-generation-config/3',json.loads(config.read_text())['schema'])
    def test_cli_surface_coast_control_rejected_for_ocean(self):
        with tempfile.TemporaryDirectory() as folder:
            config=Path(folder)/'config.json'
            r=subprocess.run([sys.executable,'-B','-m','tools.procedural_maps','preset','--profile','OCEANIC','--coast','E','--out',str(config)],cwd=ROOT,capture_output=True,text=True)
            self.assertEqual(2,r.returncode);self.assertIn('SURFACE-only',r.stdout);self.assertFalse(config.exists())


if __name__=='__main__':unittest.main(verbosity=2)

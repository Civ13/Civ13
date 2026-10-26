import copy
import unittest
from tools.procedural_maps.configuration import port_surface_preset,validate_config
from tools.procedural_maps.surface_generator import generate
from tools.procedural_maps.validator import validate,canonical_hash
from tools.procedural_maps.dmm_export import emit,verify_roundtrip


class PortTopologyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):cls.config=port_surface_preset('ports-0',64,80);cls.result=generate(cls.config)
    def mutant(self):return copy.deepcopy(self.result['document'])
    def has(self,d,code):self.assertIn(code,{e['code'] for e in validate(d)},validate(d))
    def test_positive_ports_graph_core(self):
        self.assertEqual('GENERATED_VALID_OFFLINE_IR',self.result['status'],self.result['reasons'])
        self.assertEqual([],validate(self.result['document']))
        self.assertEqual(3,len(self.result['document']['junctions'][0]['incoming']))
    def test_golden_ir2(self):
        self.assertEqual('333f2563084114e923b97876dc92728839fded10637a97763e7460e6f9d50d07',canonical_hash(self.result['document']))
    def test_reverse_traversal(self):self.assertEqual(self.result,generate(self.config,traversal='reverse'))
    def test_all_coast_sides_can_generate(self):
        for side in ['N','E','W']:
            with self.subTest(side=side):
                r=generate(port_surface_preset('ports-0',64,80,sea_side=side))
                self.assertEqual('GENERATED_VALID_OFFLINE_IR',r['status'],r['reasons'])
                self.assertEqual([],validate(r['document']))
    def test_direct_edge_outlet(self):
        c=port_surface_preset('ports-0',64,80);c['water']['sea_pct']=[0,0]
        c['surface_layout']['sea_side']='NONE';c['surface_layout']['inlets']=c['surface_layout']['inlets'][:2]
        c['surface_layout']['outlet'].update(kind='EDGE',side='E',span=[24,26])
        r=generate(c);self.assertEqual('GENERATED_VALID_OFFLINE_IR',r['status'],r['reasons'])
        self.assertEqual('OUTLET',r['document']['ports'][-1]['role'])
    def test_span_fully_typed(self):
        d=self.mutant();d['ports'][0]['span'][0]-=1;self.has(d,'PORT_SPAN_WATER')
    def test_unexplained_boundary_contact(self):
        d=self.mutant();c=d['layers']['SURFACE']['cells'][20][0]
        c.update(terrain='WATER',water='RIVER',salinity='FRESH',body=d['rivers'][1]['id'],depth_cm=30,tree='NONE',resource='NONE',blocked=False)
        self.has(d,'PORT_LEAK')
    def test_span_overlap(self):
        d=self.mutant();d['ports'].append(copy.deepcopy(d['ports'][0]));self.has(d,'PORT_SPAN_OVERLAP')
    def test_wrong_crossing_direction(self):
        d=self.mutant();r=d['rivers'][1];p=r['path'][0];r['path'][1]=[p[0],p[1]+1,p[2]]
        self.has(d,'PORT_DIRECTION')
    def test_junction_reference_missing_incoming(self):
        d=self.mutant();d['junctions'][0]['incoming'].pop();self.has(d,'JUNCTION_GRAPH')
    def test_junction_owned_raster_gap(self):
        d=self.mutant();x,y,_=d['junctions'][0]['footprint'][0]
        c=d['layers']['SURFACE']['cells'][y][x];c.update(terrain='PLAIN',water='NONE',salinity='NONE',depth_cm=0,body='')
        self.has(d,'JUNCTION_ZONE')
    def test_junction_disconnected_zone(self):
        d=self.mutant();d['junctions'][0]['footprint'].append([1,1,'SURFACE']);self.has(d,'JUNCTION_ZONE')
    def test_undeclared_body_contact(self):
        d=self.mutant();r=d['rivers'][1];p=r['path'][3];d['layers']['SURFACE']['cells'][p[1]][p[0]]['body']=d['rivers'][2]['id']
        self.has(d,'UNDECLARED_RIVER_CONTACT')
    def test_cycle_negative(self):
        d=self.mutant();d['junctions'][0]['outgoing']=d['junctions'][0]['incoming'][0];self.has(d,'RIVER_CYCLE')
    def test_config_span_bounds(self):
        c=copy.deepcopy(self.config);c['surface_layout']['inlets'][0]['span']=[-1,1]
        self.assertTrue(validate_config(c));self.assertEqual('CONFIG_REJECTED',generate(c)['reasons'][0]['code'])
    def test_config_overlapping_spans(self):
        c=copy.deepcopy(self.config);c['surface_layout']['inlets'][1]=dict(c['surface_layout']['inlets'][0],id='duplicate-location')
        self.assertTrue(validate_config(c))
    def test_config_bad_type_fails_closed(self):
        c=copy.deepcopy(self.config);c['surface_layout']['sea_side']=[];self.assertTrue(validate_config(c))
    def test_config_climate_axis_zero(self):
        c=copy.deepcopy(self.config);c['surface_layout']['climate_axis']=[0,0];self.assertTrue(validate_config(c))
    def test_route_expansion_bound(self):
        for r in self.result['manifest']['graph_to_raster']['bounded_route_stats']:self.assertLessEqual(r['expanded_cells'],64*80)
    def test_sidecar_retains_complete_graph(self):
        d=self.result['document'];text,sidecar=emit(d,self.result['manifest']);proof=verify_roundtrip(text,sidecar)
        self.assertTrue(proof['static_native_layout_equal']);self.assertTrue(proof['ir_plus_sidecar_semantics_equal'])
        self.assertEqual(d['junctions'],sidecar['semantic_ir']['junctions'])
        self.assertNotIn('junctions =',text);self.assertNotIn('span =',text)


if __name__=='__main__':unittest.main(verbosity=2)

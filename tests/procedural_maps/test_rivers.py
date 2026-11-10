"""Declared river graphs, island lake-to-sea rivers and underground streams."""
import contextlib
from copy import deepcopy
import io
import json
from pathlib import Path
import tempfile
import unittest
from tools.procedural_maps.__main__ import main
from tools.procedural_maps.bundle import write_bundle,verify_bundle
from tools.procedural_maps.configuration import oceanic_preset,preset,port_surface_preset,validate_config
from tools.procedural_maps.generator import generate
from tools.procedural_maps.river_graph import GRAPH_ALGORITHM_VERSION,river_graph_preset
from tools.procedural_maps.validator import canonical_hash,validate


def codes(d):return {e['code'] for e in validate(d)}


def layout_problem(c):
    errors=validate_config(c);return errors[0]['detail'] if errors else None


class RiverGraphTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):cls.config=river_graph_preset();cls.result=generate(cls.config)
    def doc(self):return deepcopy(self.result['document'])
    def test_preset_generates_two_networks(self):
        r=self.result;self.assertEqual('GENERATED_VALID_OFFLINE_IR',r['status'],r['reasons'])
        d=r['document'];self.assertEqual([],validate(d));self.assertEqual(GRAPH_ALGORITHM_VERSION,d['algorithm_version'])
        self.assertEqual(['confluence-west','confluence-east'],[j['id'] for j in d['junctions']])
        self.assertEqual({'lake-west':False,'lake-east':True},{l['id']:l['terminal_basin'] for l in d['lakes']})
        self.assertEqual(2,r['manifest']['generated_topology']['networks'])
        self.assertEqual(7,len(d['rivers']));self.assertEqual(4,sum(p['role']=='INLET' for p in d['ports']))
    def test_golden_graph_ir(self):
        self.assertEqual('16a7beb9c6ac7ebf4a44dc530625d716ee966e38750d8d70ef88c851a1cb168e',canonical_hash(self.result['document']))
    def test_reverse_traversal(self):self.assertEqual(self.result,generate(self.config,traversal='reverse'))
    def test_fixed_family_unchanged(self):
        d=generate(port_surface_preset('ports-0',64,80))['document']
        self.assertEqual('333f2563084114e923b97876dc92728839fded10637a97763e7460e6f9d50d07',canonical_hash(d))
    def test_several_seeds_and_reference_size(self):
        for seed in ['graph-1','graph-2','g']:
            with self.subTest(seed=seed):
                r=generate(river_graph_preset(seed));self.assertEqual([],validate(r['document']),r['reasons'])
        r=generate(river_graph_preset('graph-0',155,225));self.assertEqual([],validate(r['document']),r['reasons'])
    def test_edge_outlet_without_sea(self):
        c=deepcopy(self.config);layout=c['surface_layout'];c['water']['sea_pct']=[0,0]
        layout['sea_side']='NONE';layout['outlets'][0].update(kind='EDGE')
        r=generate(c);self.assertEqual('GENERATED_VALID_OFFLINE_IR',r['status'],r['reasons'])
        port=next(p for p in r['document']['ports'] if p['id']=='mouth')
        self.assertEqual(('OUTLET','river-lake-west'),(port['role'],port['body']))
    def test_bundle_round_trip(self):
        with tempfile.TemporaryDirectory() as tmp:
            folder=Path(tmp);write_bundle(folder,self.result['document'],self.result['manifest'],preview=False,fresh=True)
            self.assertTrue(verify_bundle(folder)['static_native_layout_equal'])
    def test_config_rejects_bad_graphs(self):
        def mutate(change):
            c=deepcopy(self.config);change(c['surface_layout'],c);return layout_problem(c)
        cases={
            'cycle':lambda l,c:l['segments'].__setitem__(3,{'from':'lake-west','to':'confluence-west'}),
            'one inflow':lambda l,c:l['segments'].__setitem__(1,{'from':'inlet-nw','to':'lake-west'}),
            'terminal outflow':lambda l,c:l['lakes'][1].update(terminal=False),
            'two outflows':lambda l,c:l['segments'].append({'from':'lake-west','to':'lake-east'}),
            'outlet unused':lambda l,c:l['outlets'].append({'id':'spare','kind':'SEA','side':'S','span':[50,52]}),
            'networks':lambda l,c:c['water'].update(river_networks=[1,1]),
            'lake count':lambda l,c:c['water'].update(lake_count=[1,1]),
            'sea outlet side':lambda l,c:l['outlets'][0].update(side='W',span=[10,12]),
            'inlet on sea':lambda l,c:l['inlets'][0].update(side='S',span=[50,52]),
            'unknown node':lambda l,c:l['segments'].append({'from':'nowhere','to':'mouth'}),
            'anchors close':lambda l,c:l['lakes'][0].update(at_pct=[27,68]),
            'extra key':lambda l,c:l.update(junction_pct=[40,40]),
        }
        for name,change in cases.items():
            with self.subTest(name):self.assertIsNotNone(mutate(change))
        self.assertIsNone(layout_problem(self.config))
    def test_validator_catches_broken_graph(self):
        d=self.doc();d['lakes'][1].update(terminal_basin=False,outflow='river-lake-east');self.assertIn('LAKE_OUTLET',codes(d))
        d=self.doc();d['junctions'][1]['outgoing']=d['junctions'][1]['incoming'][0];self.assertIn('RIVER_CYCLE',codes(d))
    def test_cli_preset(self):
        with tempfile.TemporaryDirectory() as tmp, contextlib.redirect_stdout(io.StringIO()):
            out=Path(tmp)/'graph.json'
            self.assertEqual(0,main(['preset','--river-graph','--out',str(out)]))
            self.assertEqual([],validate_config(json.loads(out.read_text(encoding='utf-8'))))
            self.assertEqual(2,main(['preset','--river-graph','--coast','E','--out',str(Path(tmp)/'bad.json')]))


class IslandRiverTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):cls.config=oceanic_preset(lake_rivers=True);cls.result=generate(cls.config)
    def doc(self):return deepcopy(self.result['document'])
    def test_lakes_drain_to_the_sea(self):
        r=self.result;self.assertEqual('GENERATED_VALID_OFFLINE_IR',r['status'],r['reasons'])
        d=r['document'];self.assertEqual([],validate(d));self.assertIn(len(d['rivers']),[1,2])
        self.assertEqual(len(d['rivers']),d['ocean_policy']['lake_rivers'])
        outflows={l['outflow'] for l in d['lakes'] if not l['terminal_basin']}
        self.assertEqual(outflows,{r['id'] for r in d['rivers']})
        for river in d['rivers']:
            self.assertEqual(('LAKE','SEA','ocean'),(river['source']['kind'],river['sink']['kind'],river['sink']['target']))
    def test_golden_island_river_ir(self):
        self.assertEqual('3463287343c881001cb6e1d0bbde775d38b881a2b6cca9923063550aeefb2ba5',canonical_hash(self.result['document']))
    def test_reverse_traversal(self):self.assertEqual(self.result,generate(self.config,traversal='reverse'))
    def test_several_seeds_and_reference_size(self):
        for seed in ['ocean-1','ocean-2','ocean-3']:
            with self.subTest(seed=seed):
                r=generate(oceanic_preset(seed,lake_rivers=True));self.assertEqual([],validate(r['document']),r['reasons'])
        r=generate(oceanic_preset('ocean-reference-0',155,225,lake_rivers=True));self.assertEqual([],validate(r['document']),r['reasons'])
    def test_config_controls(self):
        c=deepcopy(self.config);c['water']['river_networks']=[0,2];self.assertTrue(validate_config(c))
        c=deepcopy(self.config);c['ocean_layout']['lake_rivers']=[1,3];c['water']['river_networks']=[1,3];self.assertTrue(validate_config(c))
        c=deepcopy(self.config);c['water']['river_width_tiles']=[1,4];self.assertTrue(validate_config(c))
        c=deepcopy(self.config);c['water']['swamp_pct']=[0,1];self.assertTrue(validate_config(c))
    def test_validator_negatives(self):
        d=self.doc();d['ocean_policy']['lake_rivers']=0;self.assertIn('OCEAN_HYDROLOGY_SLICE',codes(d))
        d=self.doc();lake=next(l for l in d['lakes'] if l['outflow']);lake.update(terminal_basin=True,outflow='')
        self.assertIn('OCEAN_LAKE_ENDPOINT',codes(d))
        d=self.doc();d['rivers'][0]['sink']={'kind':'EDGE','target':'ocean-w'};self.assertIn('OCEAN_RIVER_ENDPOINT',codes(d))
    def test_cli_preset(self):
        with tempfile.TemporaryDirectory() as tmp, contextlib.redirect_stdout(io.StringIO()):
            out=Path(tmp)/'ocean.json'
            self.assertEqual(0,main(['preset','--profile','OCEANIC','--lake-rivers','--out',str(out)]))
            self.assertEqual([1,2],json.loads(out.read_text(encoding='utf-8'))['ocean_layout']['lake_rivers'])
            self.assertEqual(2,main(['preset','--lake-rivers','--out',str(Path(tmp)/'bad.json')]))


def cave(seed='cave-1',streams=(1,2)):
    c=preset('UNDERGROUND_CAVERN',seed);c['dimensions'].update(width=64,height=80);c['starts']['count']=4
    c['water']['river_networks']=list(streams);return c


class UndergroundStreamTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):cls.result=generate(cave())
    def test_streams_join_pools_through_rock(self):
        r=self.result;self.assertEqual('GENERATED_VALID_OFFLINE_IR',r['status'],r['reasons'])
        d=r['document'];self.assertEqual([],validate(d));self.assertTrue(d['rivers'])
        lakes={l['id']:l for l in d['lakes']};cells=d['layers']['UNDERGROUND']['cells']
        for river in d['rivers']:
            source,sink=lakes[river['source']['target']],lakes[river['sink']['target']]
            self.assertEqual((river['id'],False,True),(source['outflow'],source['terminal_basin'],sink['terminal_basin']))
            for x,y,layer in river['path']:
                self.assertEqual(('UNDERGROUND','RIVER','FRESH'),(layer,cells[y][x]['water'],cells[y][x]['salinity']))
        floor=sum(c['terrain']=='CAVE_FLOOR' for row in cells for c in row)
        self.assertEqual(floor,r['manifest']['floor_cells'])
    def test_golden_stream_ir(self):
        self.assertEqual('d89572b456172dd5d30291ae19348ba1ca40395795d7ea99925cc84b85d59556',canonical_hash(self.result['document']))
    def test_reverse_traversal(self):self.assertEqual(self.result,generate(cave(),traversal='reverse'))
    def test_preset_streams_are_optional(self):
        counts=set()
        for seed in ['cave-2','cave-3','cave-4','cave-5']:
            r=generate(cave(seed,(0,2)));self.assertEqual([],validate(r['document']),r['reasons']);counts.add(len(r['document']['rivers']))
        self.assertTrue(counts-{0})
        r=generate(preset('UNDERGROUND_CAVERN','full-0'));self.assertEqual([],validate(r['document']),r['reasons'])
        self.assertEqual(1,len(r['document']['rivers']))
    def test_more_streams_than_pools_rejects(self):
        c=cave(streams=(2,2));c['water']['lake_count']=[1,1]
        self.assertEqual('TOPOLOGY_BUDGET',generate(c)['reasons'][0]['code'])
    def test_closed_networks_only_where_declared(self):
        d=deepcopy(self.result['document']);d['rivers'][0]['sink']={'kind':'SEA','target':'nowhere'}
        self.assertIn('RIVER_NO_EDGE',codes(d))
    def test_bundle_round_trip(self):
        with tempfile.TemporaryDirectory() as tmp:
            folder=Path(tmp);write_bundle(folder,self.result['document'],self.result['manifest'],preview=True,fresh=True)
            self.assertTrue(verify_bundle(folder)['static_native_layout_equal'])


if __name__=='__main__':unittest.main(verbosity=2)

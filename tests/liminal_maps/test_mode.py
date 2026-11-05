"""Escape-bound DMM export and the source contract of the Liminal Facility round (slice 4)."""
from copy import deepcopy
import json
from pathlib import Path
import re
import tempfile
import unittest
from tools.liminal_maps.prototype import preset,generate
from tools.liminal_maps.native import (ESCAPE_TYPES,ExportError,build_cells,escape_cells,export,gated_cells,native_catalog,
                                       parse_dmm,verify_export)
from test_export import DEFAULT_MAP_SHA256,ROOT,defined_types

# Update together with an intended change to the layouts, native catalog, exporter or escape binding.
ESCAPE_MAP_SHA256='5e5981d11788278c7dd4ec1269d0da42a7923ab34c20c5d637ae3f9ad84f39f6'
ROUND_DM=ROOT/'code/modules/1713/liminal/liminal_round.dm'
META_DM=ROOT/'code/game/objects/map_metadata/liminal_facility.dm'


def dm_list(text,name):
    body=re.search(r'var/list/'+name+r' = list\((.*?)\)\n',text,re.S).group(1)
    return [p.strip() for p in body.split(',') if p.strip()]


class ModeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.doc=generate(preset())['document'];cls.tmp=tempfile.TemporaryDirectory();cls.root=Path(cls.tmp.name)
        cls.complete=export(cls.doc,cls.root/'escape',mode='escape')
        cls.side=json.loads((cls.root/'escape/sidecar.json').read_text())
        cls.grid,_,_=parse_dmm((cls.root/'escape/map.dmm').read_text())
    @classmethod
    def tearDownClass(cls):cls.tmp.cleanup()
    def test_escape_map_is_pinned_and_static_map_unchanged(self):
        self.assertEqual(ESCAPE_MAP_SHA256,self.complete['files']['map.dmm'])
        self.assertEqual('ESCAPE_DMM_EXPORTED',self.complete['status']);self.assertFalse(self.complete['mode_registered'])
        static=export(self.doc,self.root/'static')
        self.assertEqual(DEFAULT_MAP_SHA256,static['files']['map.dmm'])
    def test_verify_rebuilds_the_bound_map(self):
        report=verify_export(self.root/'escape',self.doc)
        self.assertEqual('VERIFIED_ESCAPE_DMM',report['status']);self.assertFalse(report['native_ready'])
        manifest=json.loads((self.root/'escape/export-manifest.json').read_text())
        self.assertEqual(('escape','LIMINAL_FACILITY'),(manifest['mode'],manifest['mode_adapter']))
    def test_anchors_carry_their_objects(self):
        def at(xy):return self.grid[(xy[0]-1,xy[1]-1)]
        self.assertEqual('ESCAPE_MODE_BOUND',self.side['status'])
        objective={o['grants_flag']:o['at'] for o in self.side['objectives']}
        self.assertIn(ESCAPE_TYPES['FOUND_MARKER'],at(objective['FOUND_MARKER']))
        self.assertIn(ESCAPE_TYPES['SERVICE_DONE'],at(objective['SERVICE_DONE']))
        self.assertIn(ESCAPE_TYPES['spawn'],at(self.side['spawns'][0]['at']))
        self.assertEqual(ESCAPE_TYPES['extraction'],at(self.side['exits'][0]['at'])[-1])
        self.assertEqual(ESCAPE_TYPES['metadata'],self.grid[(0,0)][0])
        self.assertEqual(1,sum(e.count(ESCAPE_TYPES['metadata']) for e in self.grid.values()))
    def test_only_the_gated_link_is_sealed(self):
        self.assertEqual({'service--exit'},set(self.side['gates']))
        gates=sorted(p for p,e in self.grid.items() if ESCAPE_TYPES['gate'] in e)
        self.assertEqual(sorted((x-1,y-1) for x,y in self.side['gates']['service--exit']),gates)
        self.assertEqual(3,len(gates))
        for p in gates:self.assertEqual((ESCAPE_TYPES['gate'],native_catalog()['turfs']['hall_floor'],ESCAPE_TYPES['extraction']),self.grid[p])
        self.assertEqual(['SEALED_UNTIL_FLAGS'],[l['native'] for l in self.side['links'] if l['requires_flags']])
    def test_extraction_area_is_the_exit_room(self):
        _,notes=build_cells(self.doc)
        exit_room=self.doc['exits'][0]['room']
        for p,entry in self.grid.items():
            self.assertEqual(ESCAPE_TYPES['extraction'] if notes['owner'].get(p)==exit_room else ESCAPE_TYPES['area'],entry[-1],p)
    def test_walkable_floor_gets_no_dense_mode_object(self):
        rows=self.doc['blueprint']['rows']
        for p,entry in self.grid.items():
            if rows[p[1]][p[0]]=='F' and ESCAPE_TYPES['gate'] not in entry:
                self.assertFalse({ESCAPE_TYPES['metadata']}&set(entry),p)
        self.assertNotIn('density = TRUE',ROUND_DM.read_text().split('/obj/structure/liminal_marker/service\n')[1].split('\n\n')[0])
    def test_mode_types_exist_in_code(self):
        known=defined_types()
        for key,path in ESCAPE_TYPES.items():self.assertIn(path.split('{')[0],known,key)
    def test_policy_props_cover_the_map_exactly(self):
        text=ROUND_DM.read_text()
        props=set(dm_list(text,'props'))
        used={part.split('{')[0] for entry in self.grid.values() for part in entry[:-2]}-{ESCAPE_TYPES['metadata'],ESCAPE_TYPES['spawn'].split('{')[0]}
        catalog={o['type'] for o in native_catalog()['objects'].values() if o['type']}
        self.assertEqual(props,catalog|{ESCAPE_TYPES['FOUND_MARKER'],ESCAPE_TYPES['SERVICE_DONE'],ESCAPE_TYPES['gate']})
        self.assertLessEqual(used,props)
    def test_issued_kit_is_on_the_equipment_allowlist(self):
        equipment=set(dm_list(ROUND_DM.read_text(),'equipment'))
        issued=set(re.findall(r'P\.issue\((/[a-z0-9_/]+)',META_DM.read_text()))
        self.assertTrue(issued);self.assertLessEqual(issued,equipment)
        self.assertNotIn('new /obj/item',META_DM.read_text())
    def test_mode_is_not_selectable_and_avoids_lights_out_hazards(self):
        users=sorted(str(p.relative_to(ROOT)) for p in (ROOT/'code').rglob('*.dm') if 'MAP_LIMINAL_FACILITY' in p.read_text(encoding='utf-8',errors='ignore'))
        self.assertEqual(['code/__defines/maps.dm','code/game/objects/map_metadata/liminal_facility.dm'],users)
        dme=(ROOT/'civ13.dme').read_text()
        selected=dme[dme.index('// BEGIN_SELECTED_MAP'):dme.index('// END_SELECTED_MAP')]
        self.assertNotIn('liminal',selected.lower())
        meta="\n".join(l for l in META_DM.read_text().splitlines() if not l.lstrip().startswith("//"))
        for hazard in ['spawn_canopy_stranglers','piranha','qdel(','extraction_timer++','gamemode_vote = TRUE']:self.assertNotIn(hazard,meta)
        self.assertIn('gamemode_vote = FALSE',meta)
        self.assertFalse((ROOT/'config/crafting/material_recipes_liminal.txt').exists())
    def test_timer_uses_elapsed_time(self):
        text=ROUND_DM.read_text()
        self.assertIn('now - hold_started >= hold_needed',text);self.assertIn('now - started_at >= deadline_length',text)
        self.assertIn('advance(world.time)',META_DM.read_text())
    def test_tampered_escape_map_is_refused(self):
        folder=self.root/'tampered';export(self.doc,folder,mode='escape')
        text=(folder/'map.dmm').read_text();(folder/'map.dmm').write_text(text.replace(ESCAPE_TYPES['gate']+',','',1))
        with self.assertRaises(ExportError):verify_export(folder,self.doc)
    def test_unknown_mode_is_refused(self):
        with self.assertRaises(ExportError) as caught:export(self.doc,self.root/'unknown',mode='survival')
        self.assertIn('MODE',str(caught.exception))
    def test_missing_objective_is_refused(self):
        doc=deepcopy(self.doc);doc['objectives']=[o for o in doc['objectives'] if o['grants_flag']!='FOUND_MARKER']
        cells,notes=build_cells(doc)
        with self.assertRaises(ExportError) as caught:escape_cells(doc,cells,notes)
        self.assertIn('OBJECTIVES',str(caught.exception))
    def test_blocked_gate_cell_is_refused(self):
        cells,notes=build_cells(self.doc)
        p=gated_cells(self.doc,notes)['service--exit'][0];cells[p]=('/obj/structure/closet',*cells[p])
        with self.assertRaises(ExportError) as caught:escape_cells(self.doc,cells,notes)
        self.assertIn('GATE',str(caught.exception))

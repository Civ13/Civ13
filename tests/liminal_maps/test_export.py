"""Static DMM export of the default chapter: determinism, parse-back and refusals."""
from copy import deepcopy
import json
from pathlib import Path
import re
import tempfile
import unittest
from tools.liminal_maps.prototype import preset,generate
from tools.liminal_maps.__main__ import write_bundle
from tools.liminal_maps.native import (ExportError,build_cells,dmm_text,export,native_catalog,parse_dmm,
                                       verify_export,NATIVE_CATALOG_PATH)

ROOT=Path(__file__).resolve().parents[2]
# Update together with an intended change to the layouts, native catalog or exporter.
DEFAULT_MAP_SHA256='53d85f4136c4dd969d3589f92f8bc0269c3459ae05617e789bdec17bc48a2652'


def defined_types():
    types=set()
    for path in (ROOT/'code').rglob('*.dm'):
        for line in path.read_text(encoding='utf-8',errors='ignore').splitlines():
            m=re.match(r'(/[A-Za-z0-9_/]+)\s*$',line)
            if m:types.add(m.group(1))
    return types


class ExportTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.doc=generate(preset())['document'];cls.tmp=tempfile.TemporaryDirectory();cls.root=Path(cls.tmp.name)
        cls.complete=export(cls.doc,cls.root/'export')
    @classmethod
    def tearDownClass(cls):cls.tmp.cleanup()
    def test_default_map_is_deterministic(self):
        self.assertEqual(DEFAULT_MAP_SHA256,self.complete['files']['map.dmm'])
        again=export(self.doc,self.root/'again')
        self.assertEqual(self.complete['files'],again['files'])
    def test_parse_back_and_verify(self):
        report=verify_export(self.root/'export',self.doc)
        self.assertEqual('VERIFIED_STATIC_DMM',report['status']);self.assertFalse(report['native_ready'])
        proof=json.loads((self.root/'export/parse-back.json').read_text())
        self.assertEqual('PARSED_BACK_EQUAL',proof['status']);self.assertEqual(53*20,proof['tiles']);self.assertEqual(30,proof['apertures'])
    def test_every_type_exists_in_the_codebase(self):
        catalog=native_catalog();known=defined_types()
        paths=[catalog['area'],*catalog['turfs'].values(),*(o['type'] for o in catalog['objects'].values() if o['type'])]
        self.assertEqual([],[p for p in paths if p not in known])
    def test_blocking_flags_match_code_density(self):
        # A walkable tile must never get a dense object; a solid tile may be more open than planned.
        self.assertEqual({'chair','computer','paper','noticeboard','sink'},
                         {k for k,o in native_catalog()['objects'].items() if not o['blocks'] and o['type']})
    def test_walkable_floor_stays_walkable(self):
        cells,_=build_cells(self.doc);rows=self.doc['blueprint']['rows'];wall=native_catalog()['turfs']['wall']
        dense={o['type'] for o in native_catalog()['objects'].values() if o['blocks'] and o['type']}
        for (x,y),entry in cells.items():
            if rows[y][x]=='F':
                self.assertNotEqual(wall,entry[-2],(x,y))
                self.assertFalse(any(part.split('{')[0] in dense for part in entry[:-2]),(x,y))
            if rows[y][x] in 'WV':self.assertEqual(wall,entry[-2],(x,y))
    def test_sidecar_anchors(self):
        side=json.loads((self.root/'export/sidecar.json').read_text())
        self.assertEqual('STATIC_EXPORT_ONLY_NO_MODE',side['status'])
        self.assertEqual(['find-marker','service-task'],[o['id'] for o in side['objectives']])
        self.assertEqual(['SERVICE_DONE'],side['exits'][0]['requires_flags'])
        grid,_,_=parse_dmm((self.root/'export/map.dmm').read_text())
        floors={t for t in native_catalog()['turfs'].values()}-{native_catalog()['turfs']['wall']}
        for anchor in side['spawns']+side['objectives']+side['exits']:
            x,y=anchor['at'];self.assertIn(grid[(x-1,y-1)][-2],floors,anchor['id'])
    def test_tampered_export_is_refused(self):
        folder=self.root/'tampered';export(self.doc,folder)
        text=(folder/'map.dmm').read_text();(folder/'map.dmm').write_text(text.replace('/turf/wall/cement','/turf/floor/plating/steel',1))
        with self.assertRaises(ExportError):verify_export(folder,self.doc)
    def test_existing_output_is_refused(self):
        with self.assertRaises(ValueError):export(self.doc,self.root/'export')
    def test_blocking_asset_on_walkable_floor_is_refused(self):
        catalog=native_catalog();catalog['objects']['chair']['blocks']=True
        with self.assertRaises(ExportError) as caught:build_cells(self.doc,catalog)
        self.assertIn('WALKABLE_BLOCKED',str(caught.exception))
    def test_unmapped_asset_is_refused(self):
        catalog=native_catalog();del catalog['objects']['locker']
        with self.assertRaises(ExportError) as caught:build_cells(self.doc,catalog)
        self.assertIn('UNMAPPED_ASSET',str(caught.exception))
    def test_parser_rejects_malformed_maps(self):
        cells,_=build_cells(self.doc);text=dmm_text(cells,53,20)
        for broken in [text.replace('/area/caribbean/roofed)','/area/caribbean/roofed,/obj/structure/sink)',1),
                       text.replace('(1,1,1) = {"\n','(1,1,1) = {"\nzz\n',1),
                       text.replace('"}\n','')]:
            with self.assertRaises(ExportError):parse_dmm(broken)
    def test_cli_bundle_round_trip(self):
        from tools.liminal_maps.__main__ import main
        import contextlib,io,sys
        chapter=self.root/'chapter';chapter.mkdir();write_bundle(chapter,generate(preset()))
        argv=sys.argv
        try:
            sys.argv=['liminal_maps','export',str(chapter),'--out',str(self.root/'cli')]
            with contextlib.redirect_stdout(io.StringIO()):self.assertEqual(0,main())
            sys.argv=['liminal_maps','verify-export',str(self.root/'cli'),'--chapter',str(chapter)]
            with contextlib.redirect_stdout(io.StringIO()):self.assertEqual(0,main())
        finally:sys.argv=argv
    def test_native_catalog_is_pinned(self):
        self.assertEqual('civ13-liminal-native-catalog/1',json.loads(NATIVE_CATALOG_PATH.read_text())['schema'])

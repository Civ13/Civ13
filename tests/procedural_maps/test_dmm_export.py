import copy
import hashlib
import os
import json
from pathlib import Path
import tempfile
import unittest
from tools.procedural_maps.dmm_export import emit,project,verify_roundtrip,verify_catalog,select_catalog,CATALOG_VERSION,HISTORICAL_VERSION,INTERMEDIATE_VERSION,V3_VERSION,COMMIT,HISTORICAL_COMMIT,INTERMEDIATE_COMMIT,V3_COMMIT
from tools.procedural_maps.bundle import write_bundle,verify_bundle
from tools.procedural_maps.io import json_text
from test_surface_generator import small
from tools.procedural_maps.surface_generator import generate
from tools.procedural_maps.source_audit import parse_classic
from tools.procedural_maps.validator import canonical_hash


class ExportTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        r=generate(small());cls.doc=r["document"];cls.manifest=r["manifest"]
        cls.text,cls.sidecar=emit(cls.doc,cls.manifest,catalog_version=CATALOG_VERSION)
    def test_pinned_catalog(self):self.assertTrue(verify_catalog())
    def test_source_delta_is_confined_to_flowers_and_additive_dme_includes(self):
        from tools.procedural_maps.dmm_export import V3_CATALOG,HISTORICAL_CATALOG
        from tools.procedural_maps.repo_source import read_pinned
        oldroot=Path(os.environ['CIV13_TEST_HISTORICAL_CATALOG_ROOT']);v3root=Path(os.environ['CIV13_TEST_V3_CATALOG_ROOT'])
        path='code/game/objects/structures/wild.dm'
        old=read_pinned(path,HISTORICAL_CATALOG[path],oldroot).decode()
        new=read_pinned(path,V3_CATALOG[path],v3root).decode()
        start='/obj/structure/wild/flowers\n';end='/obj/structure/wild/tallgrass/fire_act(temperature)'
        self.assertEqual(old.split(start,1)[0],new.split(start,1)[0])
        self.assertEqual(old.split(end,1)[1],new.split(end,1)[1])
        olddme=read_pinned('civ13.dme',HISTORICAL_CATALOG['civ13.dme'],oldroot).decode().splitlines()
        newdme=read_pinned('civ13.dme',V3_CATALOG['civ13.dme'],v3root).decode().splitlines()
        additions=[line for line in newdme if line not in olddme]
        self.assertEqual(5,len(additions));self.assertEqual(olddme,[line for line in newdme if line not in additions])
        self.assertTrue(all(line.startswith('#include ') for line in additions))
    def test_referenced_static_tree_and_ground_art_matches_historical(self):
        oldroot=Path(os.environ['CIV13_TEST_HISTORICAL_CATALOG_ROOT']);root=Path(__file__).resolve().parents[2]
        for path in ['icons/obj/flora/wild.dmi','icons/obj/flora/bigtrees.dmi','icons/obj/flora/pinetrees.dmi','icons/obj/flora/palm.dmi','icons/turf/floors.dmi']:
            with self.subTest(path=path):self.assertEqual((oldroot/path).read_bytes(),(root/path).read_bytes())
    def test_historical_and_current_static_output_matches_and_remains_bound(self):
        oldroot=Path(os.environ['CIV13_TEST_HISTORICAL_CATALOG_ROOT'])
        oldtext,oldside=emit(self.doc,self.manifest,oldroot,HISTORICAL_VERSION)
        self.assertEqual(self.text,oldtext)
        self.assertEqual((HISTORICAL_VERSION,HISTORICAL_COMMIT),(oldside['catalog_version'],oldside['source_commit']))
        self.assertEqual((CATALOG_VERSION,COMMIT),(self.sidecar['catalog_version'],self.sidecar['source_commit']))
        oldside['catalog_version']=CATALOG_VERSION;oldside['source_commit']=COMMIT
        oldside['manifest']['catalog_binding']=dict(catalog_version=CATALOG_VERSION,source_commit=COMMIT)
        self.assertEqual(self.sidecar,oldside)
    def test_v2_to_v3_source_delta_is_only_generic_flower_alias(self):
        from tools.procedural_maps.dmm_export import V3_CATALOG,INTERMEDIATE_CATALOG
        from tools.procedural_maps.repo_source import read_pinned
        v2root=Path(os.environ['CIV13_TEST_INTERMEDIATE_CATALOG_ROOT']);v3root=Path(os.environ['CIV13_TEST_V3_CATALOG_ROOT'])
        self.assertTrue(verify_catalog(v2root,INTERMEDIATE_VERSION))
        path='code/game/objects/structures/wild.dm'
        old=read_pinned(path,INTERMEDIATE_CATALOG[path],v2root).decode()
        new=read_pinned(path,V3_CATALOG[path],v3root).decode()
        before='\t\t\ticon_state = "flower[rand(1,14)]"\n'
        after=before+'\t\t\t// The original sheet has no flower3; reuse existing art without another roll.\n\t\t\tif (icon_state == "flower3")\n\t\t\t\ticon_state = "flower2"\n'
        self.assertEqual(1,old.count(before));self.assertEqual(new,old.replace(before,after))
        self.assertEqual({k:v for k,v in INTERMEDIATE_CATALOG.items() if k!=path},{k:v for k,v in V3_CATALOG.items() if k!=path})
    def test_v2_bundle_preserves_binding_and_matches_v3_static_layout(self):
        v2root=Path(os.environ['CIV13_TEST_INTERMEDIATE_CATALOG_ROOT'])
        text,side=emit(self.doc,self.manifest,v2root,INTERMEDIATE_VERSION)
        self.assertEqual(self.text,text)
        self.assertEqual((INTERMEDIATE_VERSION,INTERMEDIATE_COMMIT),(side['catalog_version'],side['source_commit']))
        with tempfile.TemporaryDirectory() as tmp:
            folder=Path(tmp);write_bundle(folder,self.doc,self.manifest,v2root,preview=False,catalog_version=INTERMEDIATE_VERSION)
            self.assertEqual('VERIFIED_OFFLINE_ONLY',verify_bundle(folder,v2root)['status'])
            with self.assertRaisesRegex(ValueError,'CATALOG_SOURCE_MISMATCH'):verify_bundle(folder)
    def test_v3_bundle_rejects_v2_and_current_checkouts(self):
        v2root=Path(os.environ['CIV13_TEST_INTERMEDIATE_CATALOG_ROOT']);v3root=Path(os.environ['CIV13_TEST_V3_CATALOG_ROOT'])
        with tempfile.TemporaryDirectory() as tmp:
            folder=Path(tmp);write_bundle(folder,self.doc,self.manifest,v3root,preview=False,catalog_version=V3_VERSION)
            self.assertEqual('VERIFIED_OFFLINE_ONLY',verify_bundle(folder,v3root)['status'])
            with self.assertRaisesRegex(ValueError,'CATALOG_SOURCE_MISMATCH'):verify_bundle(folder,v2root)
            with self.assertRaisesRegex(ValueError,'CATALOG_SOURCE_MISMATCH'):verify_bundle(folder)
    def test_v3_and_v4_static_output_matches(self):
        v3root=Path(os.environ['CIV13_TEST_V3_CATALOG_ROOT'])
        text,side=emit(self.doc,self.manifest,v3root,V3_VERSION)
        self.assertEqual(self.text,text)
        self.assertEqual((V3_VERSION,V3_COMMIT),(side['catalog_version'],side['source_commit']))
    def test_pinned_checkouts_keep_their_version_and_others_select_v4(self):
        for env,version in [('CIV13_TEST_HISTORICAL_CATALOG_ROOT',HISTORICAL_VERSION),('CIV13_TEST_INTERMEDIATE_CATALOG_ROOT',INTERMEDIATE_VERSION),('CIV13_TEST_V3_CATALOG_ROOT',V3_VERSION)]:
            with self.subTest(version=version):self.assertEqual(version,select_catalog(Path(os.environ[env])))
        self.assertEqual(CATALOG_VERSION,select_catalog())
    def test_v4_tolerates_unrelated_edits_but_not_missing_declarations_or_includes(self):
        root=Path(__file__).resolve().parents[2]
        files=['code/game/turfs/floor_types.dm','code/game/turfs/flooring/flooring_premade.dm','code/game/objects/structures/wild.dm',
               'code/game/objects/structures/rocks.dm','code/game/area/caribbean.dm','code/game/objects/effects/landmarks/normal.dm',
               'code/game/objects/map_metadata/nomads/nomads.dm','civ13.dme']
        with tempfile.TemporaryDirectory() as tmp:
            copy_root=Path(tmp)
            for path in files:(copy_root/path).parent.mkdir(parents=True,exist_ok=True);(copy_root/path).write_bytes((root/path).read_bytes().replace(b'\r\n',b'\n'))
            wild=copy_root/'code/game/objects/structures/wild.dm';dme=copy_root/'civ13.dme'
            original_wild=wild.read_bytes();original_dme=dme.read_bytes()
            wild.write_bytes(original_wild+b'\n/obj/structure/wild/unrelated_change\n');dme.write_bytes(original_dme+b'#include "code\\unrelated.dm"\n')
            self.assertTrue(verify_catalog(copy_root))
            with self.assertRaisesRegex(ValueError,'CATALOG_SOURCE_MISMATCH'):verify_catalog(copy_root,V3_VERSION)
            wild.write_bytes(original_wild.replace(b'\n/obj/structure/wild/palm\n',b'\n/obj/structure/wild/palm_renamed\n',1))
            with self.assertRaisesRegex(ValueError,'CATALOG_TYPE_MISSING: /obj/structure/wild/palm'):verify_catalog(copy_root)
            wild.write_bytes(original_wild)
            include=b'#include "code\\game\\objects\\structures\\wild.dm"\n'
            self.assertEqual(1,original_dme.count(include));dme.write_bytes(original_dme.replace(include,b'',1))
            with self.assertRaisesRegex(ValueError,'CATALOG_INCLUDE_MISSING: code/game/objects/structures/wild.dm'):verify_catalog(copy_root)
    def test_historical_bundle_requires_its_matching_catalog(self):
        oldroot=Path(os.environ['CIV13_TEST_HISTORICAL_CATALOG_ROOT'])
        with tempfile.TemporaryDirectory() as tmp:
            folder=Path(tmp);write_bundle(folder,self.doc,self.manifest,oldroot,preview=False,catalog_version=HISTORICAL_VERSION)
            self.assertEqual('VERIFIED_OFFLINE_ONLY',verify_bundle(folder,oldroot)['status'])
            with self.assertRaisesRegex(ValueError,'CATALOG_SOURCE_MISMATCH'):verify_bundle(folder)
    def test_v3_bundle_rejects_historical_catalog(self):
        oldroot=Path(os.environ['CIV13_TEST_HISTORICAL_CATALOG_ROOT']);v3root=Path(os.environ['CIV13_TEST_V3_CATALOG_ROOT'])
        with tempfile.TemporaryDirectory() as tmp:
            folder=Path(tmp);write_bundle(folder,self.doc,self.manifest,v3root,preview=False,catalog_version=V3_VERSION)
            with self.assertRaisesRegex(ValueError,'CATALOG_SOURCE_MISMATCH'):verify_bundle(folder,oldroot)
    def test_original_unbound_historical_bundle_still_verifies(self):
        oldroot=Path(os.environ['CIV13_TEST_HISTORICAL_CATALOG_ROOT'])
        with tempfile.TemporaryDirectory() as tmp:
            folder=Path(tmp);write_bundle(folder,self.doc,self.manifest,oldroot,preview=False,catalog_version=HISTORICAL_VERSION)
            m=json.loads((folder/'seed.manifest.json').read_text());m.pop('catalog_binding')
            side=json.loads((folder/'map.dmm.sidecar.json').read_text());side['manifest']=m
            (folder/'seed.manifest.json').write_text(json_text(m),encoding='utf-8',newline='\n')
            (folder/'map.dmm.sidecar.json').write_text(json_text(side,True),encoding='utf-8',newline='\n')
            marker=json.loads((folder/'complete.json').read_text())
            for name in ['seed.manifest.json','map.dmm.sidecar.json']:marker['files'][name]=hashlib.sha256((folder/name).read_bytes()).hexdigest()
            (folder/'complete.json').write_text(json_text(marker),encoding='utf-8',newline='\n')
            self.assertEqual('VERIFIED_OFFLINE_ONLY',verify_bundle(folder,oldroot)['status'])
            with self.assertRaisesRegex(ValueError,'CATALOG_SOURCE_MISMATCH'):verify_bundle(folder)
    def test_rejects_mixed_catalog_identity(self):
        side=copy.deepcopy(self.sidecar);side['source_commit']=HISTORICAL_COMMIT
        with self.assertRaisesRegex(ValueError,'SIDECAR_VERSION'):verify_roundtrip(self.text,side)
    def test_unbound_manifest_requires_explicit_version(self):
        with self.assertRaisesRegex(ValueError,'UNBOUND_MANIFEST_REQUIRES_CATALOG_VERSION'):emit(self.doc,self.manifest)
    def test_new_sidecar_cannot_carry_an_unbound_manifest(self):
        side=copy.deepcopy(self.sidecar);side['manifest'].pop('catalog_binding')
        with self.assertRaisesRegex(ValueError,'UNBOUND_MANIFEST_REQUIRES_HISTORICAL_CATALOG'):verify_roundtrip(self.text,side)
    def test_manifest_binding_cannot_be_silently_reinterpreted(self):
        bound=copy.deepcopy(self.manifest);bound['catalog_binding']={'catalog_version':HISTORICAL_VERSION,'source_commit':HISTORICAL_COMMIT}
        with self.assertRaisesRegex(ValueError,'CATALOG_BINDING_MISMATCH'):emit(self.doc,bound,catalog_version=CATALOG_VERSION)
    def test_static_layout_and_sidecar_roundtrip(self):
        r=verify_roundtrip(self.text,self.sidecar)
        self.assertTrue(r["static_native_layout_equal"])
        self.assertTrue(r["ir_plus_sidecar_semantics_equal"])
        self.assertFalse(r["dmm_alone_full_ir_semantics"])
    def test_native_coordinate_and_atom_order(self):
        _,parsed,dims=parse_classic(self.text)
        self.assertEqual(project(self.doc),parsed)
        self.assertEqual([[64,80,1],[64,80,2]],sorted(dims))
        self.assertTrue(parsed[(1,1,1)].startswith('/obj/structure/wild/rock/basalt,/obj/map_metadata/nomads,'))
        for recipe in parsed.values():
            self.assertLess(recipe.index('/turf/'),recipe.index('/area/'))
        self.assertEqual(4,sum('name = "JoinLateCiv"' in recipe for recipe in parsed.values()))
    def test_uniform_keys_and_deterministic_text(self):
        definitions,_,_=parse_classic(self.text)
        self.assertEqual({2},{len(k) for k in definitions})
        self.assertEqual((self.text,self.sidecar),emit(self.doc,self.manifest,catalog_version=CATALOG_VERSION))
    def test_tampered_dmm_rejected(self):
        with self.assertRaisesRegex(ValueError,"DMM_HASH_MISMATCH"):verify_roundtrip(self.text+'\n',self.sidecar)
    def test_wrong_turf_rejected_even_with_new_text_hash(self):
        text=self.text.replace('/turf/floor/grass','/turf/floor/beach/sand',1)
        side=copy.deepcopy(self.sidecar);side["dmm_sha256"]=hashlib.sha256(text.encode()).hexdigest()
        with self.assertRaisesRegex(ValueError,"NATIVE_LAYOUT_MISMATCH"):verify_roundtrip(text,side)
    def test_tampered_ir_sidecar_rejected(self):
        side=copy.deepcopy(self.sidecar);side["semantic_ir"]["seed"]="wrong"
        with self.assertRaisesRegex(ValueError,"IR_HASH_MISMATCH"):verify_roundtrip(self.text,side)
    def test_undefined_semantics_not_emitted_as_vars(self):
        for forbidden in ['biome =','elevation_m =','resource =','water_body =','seed =','moisture =']:
            self.assertNotIn(forbidden,self.text)
        self.assertTrue(any(c["resource"]!="NONE" for row in self.sidecar["semantic_ir"]["layers"]["SURFACE"]["cells"] for c in row))
    def test_unmapped_depth_rejected(self):
        d=copy.deepcopy(self.doc)
        for row in d["layers"]["SURFACE"]["cells"]:
            for c in row:
                if c["water"]=="LAKE":
                    c["depth_cm"]=150
                    with self.assertRaisesRegex(ValueError,"EXPORT_DEPTH_UNSUPPORTED"):project(d)
                    return
        self.fail("lake missing")
    def test_ir_invalid_rejected_before_emit(self):
        d=copy.deepcopy(self.doc);d["ports"]=[]
        with self.assertRaises(ValueError):project(d)


if __name__=="__main__":unittest.main(verbosity=2)

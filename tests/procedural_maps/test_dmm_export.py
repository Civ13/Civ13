import copy
import hashlib
import unittest
from tools.procedural_maps.dmm_export import emit,project,verify_roundtrip,verify_catalog
from test_surface_generator import small
from tools.procedural_maps.surface_generator import generate
from tools.procedural_maps.source_audit import parse_classic
from tools.procedural_maps.validator import canonical_hash


class ExportTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        r=generate(small());cls.doc=r["document"];cls.manifest=r["manifest"]
        cls.text,cls.sidecar=emit(cls.doc,cls.manifest)
    def test_pinned_catalog(self):self.assertTrue(verify_catalog())
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
        self.assertEqual((self.text,self.sidecar),emit(self.doc,self.manifest))
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

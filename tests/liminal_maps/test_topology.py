from copy import deepcopy
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from tools.liminal_maps.catalog import CATALOG,CATALOG_SHA256,HUBS,validate_catalog
from tools.liminal_maps.common import stable_u64,canonical_hash
from tools.liminal_maps.prototype import preset,generate,validate,validate_config,materialize
from tools.liminal_maps.__main__ import write_bundle,verify_bundle
from tools.liminal_maps.contracts import level_template,escape_scenario

ROOT=Path(__file__).resolve().parents[2]


class IndoorTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.result=generate(preset());assert cls.result['document'] is not None,cls.result
    def changed(self,mutate,code):
        d=deepcopy(self.result['document']);mutate(d);r=validate(d)
        self.assertFalse(r['accepted']);self.assertEqual(code,r['reasons'][0]['code'],r)
    def test_ten_original_families(self):
        self.assertEqual(10,len(CATALOG['archetypes']));self.assertEqual([],validate_catalog())
        self.assertTrue(all(a['authoring']=='ORIGINAL_ABSTRACT_MASK_NO_ASSET_COPY' and a['native_admission']=='PENDING' for a in CATALOG['archetypes'].values()))
    def test_catalog_golden(self):self.assertEqual('7ee6647de885a921746f9ac9d0ec5fa9e5140a30a8c06294cd4ff16c3d37c95b',CATALOG_SHA256)
    def test_design_catalog_mirror(self):
        design=json.loads((ROOT/'docs/liminal/room-archetypes-v1.json').read_text())
        self.assertEqual(CATALOG,design);self.assertEqual(CATALOG_SHA256,canonical_hash(design))
    def test_design_example_config(self):
        self.assertEqual(preset(),json.loads((ROOT/'tools/liminal_maps/example-config.json').read_text()))
        self.assertEqual(preset(),json.loads((ROOT/'docs/liminal/liminal-example-config.json').read_text()))
    def test_reused_helper_source_provenance(self):
        import ast
        package=ROOT/'tools/liminal_maps';proof=json.loads((package/'SOURCE-PROVENANCE.json').read_text());text=(package/'common.py').read_text()
        for node in ast.parse(text).body:
            if isinstance(node,ast.FunctionDef) and node.name in proof['copied_function_sha256']:
                self.assertEqual(proof['copied_function_sha256'][node.name],hashlib.sha256(ast.get_source_segment(text,node).encode()).hexdigest())
        self.assertEqual(proof['reused_io_sha256'],hashlib.sha256((package/'io.py').read_bytes()).hexdigest())
    def test_manifest_version_binding_after_rehashed_file(self):
        with tempfile.TemporaryDirectory() as path:
            folder=Path(path);write_bundle(folder,self.result)
            p=folder/'manifest.json';m=json.loads(p.read_text());m['profile_version']='wrong/1';p.write_text(json.dumps(m),encoding='utf-8')
            complete=json.loads((folder/'complete.json').read_text());complete['files']['manifest.json']=hashlib.sha256(p.read_bytes()).hexdigest()
            (folder/'complete.json').write_text(json.dumps(complete),encoding='utf-8')
            with self.assertRaisesRegex(ValueError,'VERSION_BINDING'):verify_bundle(folder)
    def test_existing_random_golden(self):self.assertEqual('588a81055b889362',f"{stable_u64('42','a/1','c/1','SURFACE/1','flora','SURFACE',0,0):016x}")
    def test_default_valid(self):
        p=validate(self.result['document']);self.assertTrue(p['accepted']);self.assertFalse(p['native_ready']);self.assertEqual([60],p['completed_exit_distances'])
    def test_plan_golden(self):self.assertEqual('6e4e1946ee62525bad82681d6b7cb5b0d2b8d8c03472b8856009108a93bcad40',canonical_hash(self.result['document']))
    def test_reverse_materialization_and_immutable_input(self):
        c=preset();old=deepcopy(c);r=generate(c,traversal='reverse');self.assertEqual(self.result,r);self.assertEqual(old,c)
        d=self.result['document'];self.assertEqual(materialize(d)[0],materialize(d,iteration='reverse')[0])
    def test_all_authored_hub_families(self):
        for hub in HUBS:
            c=preset();c['hub_allowlist']=[hub];r=generate(c);self.assertIsNotNone(r['document'],r)
            self.assertEqual(hub,next(x['archetype'] for x in r['document']['rooms'] if x['id']=='hub'))
    def test_optional_alcove_seals_unused_socket(self):
        c=preset();c['branch_alcove']=False;r=generate(c);self.assertIsNotNone(r['document'],r)
        self.assertEqual(5,len(r['document']['rooms']));self.assertEqual([dict(room='hub',socket='N')],r['document']['sealed_sockets'])
    def test_catalog_version_binding(self):
        c=preset();c['catalog_sha256']='0'*64;self.assertTrue(validate_config(c))
    def test_config_invariant_switch(self):
        c=preset();c['disable_exit_checks']=True;self.assertEqual('CONFIG_REJECTED',generate(c)['status'])
    def test_no_surface_profile_fallback(self):
        c=preset();c['profile']='SURFACE';self.assertEqual('CONFIG_REJECTED',generate(c)['status'])
    def test_config_room_budget(self):
        c=preset();c['max_rooms']=5;self.assertTrue(validate_config(c))
    def test_malformed_allowlist(self):
        c=preset();c['hub_allowlist']=[{}];self.assertTrue(validate_config(c))
    def test_state_search_budget_is_hard(self):
        c=preset();c.update(max_search_states=1,max_candidates=2);r=generate(c)
        self.assertIsNone(r['document']);self.assertEqual(2,len(r['ledger']))
        self.assertTrue(all(e['reasons'][0]['code']=='SEARCH_BUDGET' for e in r['ledger']))
    def test_area_budget_is_hard(self):
        c=preset();c.update(max_blueprint_tiles=256,max_candidates=2);r=generate(c)
        self.assertIsNone(r['document']);self.assertEqual(2,len(r['ledger']));self.assertTrue(all(x['reasons'][0]['code']=='TILE_BUDGET' for x in r['ledger']))
    def test_boolean_budget_rejected(self):
        c=preset();c['max_candidates']=True;self.assertTrue(validate_config(c))
    def test_native_z_not_inferred(self):self.changed(lambda d:d.update(native_z=2),'SCHEMA')
    def test_native_claim_rejected(self):self.changed(lambda d:d['links'][0].update(native_admission='APPROVED'),'SCHEMA')
    def test_wrong_plan_profile(self):self.changed(lambda d:d.update(profile='UNDERGROUND_CAVERN'),'SCHEMA')
    def test_malformed_plan_configuration_rejects_cleanly(self):self.changed(lambda d:d.update(configuration=[]),'CONFIG')
    def test_nonobject_plan_rejects_cleanly(self):self.assertEqual('SCHEMA',validate(None)['reasons'][0]['code'])
    def test_missing_socket(self):self.changed(lambda d:d['links'][0]['a'].update(socket='missing'),'SOCKET_UNKNOWN')
    def test_reused_socket(self):
        def mutate(d):
            link=deepcopy(d['links'][0]);link['id']='duplicate';d['links'].append(link)
        self.changed(mutate,'SOCKET_REUSED')
    def test_misaligned_room(self):
        def mutate(d):next(r for r in d['rooms'] if r['id']=='exit')['origin'][1]+=1
        self.changed(mutate,'SOCKET_ALIGNMENT')
    def test_wrong_facing(self):
        def mutate(d):next(l for l in d['links'] if l['id']=='service--exit')['b']['socket']='W';next(l for l in d['links'] if l['id']=='service--exit')['a']['socket']='W'
        self.changed(mutate,'SOCKET_MATE')
    def test_unapproved_portal_does_not_become_walk_edge(self):self.changed(lambda d:d['links'][0].update(kind='LEVEL_PORTAL'),'SOCKET_TYPE')
    def test_unknown_progress_flag(self):self.changed(lambda d:d['links'][0].update(requires_flags=['UNPRODUCED']),'FLAGS')
    def test_key_behind_its_lock(self):
        def mutate(d):next(l for l in d['links'] if l['id']=='hub--alcove')['requires_flags']=['FOUND_MARKER']
        self.changed(mutate,'OBJECTIVE_UNREACHABLE')
    def test_objective_dependency_cycle(self):self.changed(lambda d:d['objectives'][0].update(requires_flags=['SERVICE_DONE']),'OBJECTIVE_UNREACHABLE')
    def test_blocked_marker_anchor(self):self.changed(lambda d:d['spawns'][0].update(local_at=[0,0]),'MARKER_CLEARANCE')
    def test_duplicate_spawn(self):self.changed(lambda d:d['spawns'].append(dict(id='spawn-1',room='arrival',local_at=[4,4])),'SPAWN_DUPLICATE')
    def test_blueprint_cannot_smuggle_floor_or_wall(self):
        def mutate(d):d['blueprint']['rows'][0]='F'+d['blueprint']['rows'][0][1:]
        self.changed(mutate,'BLUEPRINT')
    def test_overlap(self):
        def mutate(d):
            by_id={r['id']:r for r in d['rooms']};by_id['exit']['origin']=by_id['arrival']['origin'][:]
        self.changed(mutate,'ROOM_OVERLAP')
    def test_unused_socket_must_be_sealed(self):
        c=preset();c['branch_alcove']=False;d=generate(c)['document'];d['sealed_sockets']=[]
        self.assertEqual('UNSEALED_SOCKET',validate(d)['reasons'][0]['code'])
    def test_broken_room_graph(self):
        def mutate(d):
            d['links']=[l for l in d['links'] if l['id']!='threshold--service']
            d['sealed_sockets']=[dict(room='service',socket='W'),dict(room='threshold',socket='E')]
            d['blueprint']=materialize(d)[0]
        self.changed(mutate,'ROOM_GRAPH')
    def test_zone_transition_requires_buffer(self):
        def mutate(d):
            rooms={r['id']:r for r in d['rooms']};x=1
            for rid in ['arrival','hub','service','threshold','exit']:
                rooms[rid]['origin'][0]=x;x+=CATALOG['archetypes'][rooms[rid]['archetype']]['width']
            for link in d['links']:
                if link['id']=='hub--threshold':link['b']['room']='service'
                elif link['id']=='threshold--service':link['a']['room']='service';link['b']['room']='threshold'
                elif link['id']=='service--exit':link['a']['room']='threshold'
            d['blueprint']=materialize(d)[0]
        self.changed(mutate,'ZONE_ADJACENCY')
    def test_catalog_clearance_failure(self):
        c=deepcopy(CATALOG);a=c['archetypes']['offset_office'];a['mask'][5]=a['mask'][5][:6]+'X'+a['mask'][5][7:]
        self.assertTrue(validate_catalog(c));self.assertEqual('CATALOG_REJECTED',generate(preset(),c)['status'])
    def test_catalog_never_carries_native_approval(self):
        c=deepcopy(CATALOG);c['native_approved']=True;self.assertTrue(validate_catalog(c))
    def test_catalog_weight_bounds(self):
        c=deepcopy(CATALOG);c['archetypes']['office_columns']['tags']['rarity_weight']=0;self.assertEqual(['CATALOG_TAGS'],validate_catalog(c))
    def test_invalid_config_cannot_relax_route_length(self):self.changed(lambda d:d['configuration'].update(min_spawn_exit_tiles=255),'EXIT_DISTANCE')
    def test_roundtrip_bundle(self):
        with tempfile.TemporaryDirectory() as path:
            folder=Path(path);write_bundle(folder,self.result);v=verify_bundle(folder)
            self.assertFalse(v['native_ready']);self.assertEqual({'plan.json','manifest.json','proof.json','level-template.json','escape-scenario.json','complete.json'},{p.name for p in folder.iterdir()})
    def test_shared_template_omits_escape_predicates(self):
        d=deepcopy(self.result['document']);a=level_template(d)
        next(e for e in d['links'] if e['id']=='service--exit')['requires_flags']=[]
        b=level_template(d);self.assertEqual(a['template_id'],b['template_id']);self.assertEqual(a['identity'],b['identity'])
        self.assertTrue(all('requires_flags' not in e for e in a['identity']['geometry']['links']))
    def test_template_is_not_inhabited_instance(self):
        template=level_template(self.result['document'])
        self.assertNotIn('instance_id',template);self.assertNotIn('inhabited',template);self.assertFalse(template['native_export']['native_ready'])
    def test_template_geometry_canonical_under_list_order(self):
        d=deepcopy(self.result['document']);before=level_template(d);d['rooms'].reverse();d['links'].reverse()
        after=level_template(d);self.assertEqual(before['template_id'],after['template_id'])
    def test_default_era_is1990_and_not_native_admission(self):
        d=self.result['document'];s=escape_scenario(d,level_template(d))
        self.assertEqual(1990,s['scenario_year']);self.assertEqual('PENDING_PERIOD_ALLOWLIST',s['era_policy']['native_admission'])
        self.assertFalse(s['native_ready']);self.assertEqual([],s['era_policy']['research_ids'])
    def test_year_changes_scenario_not_template(self):
        d=self.result['document'];t=level_template(d);a=escape_scenario(d,t);b=escape_scenario(d,t,1991)
        self.assertEqual(a['template_id'],b['template_id']);self.assertNotEqual(canonical_hash(a),canonical_hash(b))
    def test_later_year_and_boolean_refused(self):
        d=self.result['document'];t=level_template(d)
        for year in [2013,1989,True]:
            with self.assertRaisesRegex(ValueError,'SCENARIO_YEAR'):escape_scenario(d,t,year)
    def test_no_gateway_power_mechanics_in_escape_spec(self):
        d=self.result['document'];s=escape_scenario(d,level_template(d))
        self.assertEqual('LIMINAL_ESCAPE',s['scenario']);self.assertNotIn('gateway_power',s);self.assertNotIn('persistence',s)
    def test_template_tamper_rejected(self):
        d=self.result['document'];t=level_template(d);t['identity']['geometry_sha256']='0'*64
        with self.assertRaisesRegex(ValueError,'TEMPLATE_BINDING'):escape_scenario(d,t)
    def test_corrupt_bundle(self):
        with tempfile.TemporaryDirectory() as path:
            folder=Path(path);write_bundle(folder,self.result);(folder/'plan.json').write_text('{}')
            with self.assertRaisesRegex(ValueError,'BUNDLE_HASH'):verify_bundle(folder)
    def test_cli_generate_verify(self):
        with tempfile.TemporaryDirectory() as path:
            folder=Path(path);config=folder/'config.json';output=folder/'plan'
            for args in [['preset','--out',str(config)],['generate','--config',str(config),'--out',str(output)],['verify',str(output)]]:
                r=subprocess.run([sys.executable,'-B','-m','tools.liminal_maps',*args],cwd=ROOT,text=True,capture_output=True);self.assertEqual(0,r.returncode,r.stdout+r.stderr)
            self.assertFalse(any(p.suffix in {'.dmm','.png'} for p in output.iterdir()))
    def test_existing_destination_preserved(self):
        with tempfile.TemporaryDirectory() as path:
            target=Path(path)/'existing.json';target.write_text('keep')
            r=subprocess.run([sys.executable,'-B','-m','tools.liminal_maps','preset','--out',str(target)],cwd=ROOT,text=True,capture_output=True)
            self.assertEqual(2,r.returncode);self.assertEqual('keep',target.read_text())
    def test_native_save_input_refused(self):
        with tempfile.TemporaryDirectory() as path:
            source=Path(path)/'world.sav';source.write_text('{}')
            r=subprocess.run([sys.executable,'-B','-m','tools.liminal_maps','validate',str(source)],cwd=ROOT,text=True,capture_output=True)
            self.assertEqual(2,r.returncode);self.assertIn('native saves are not read',r.stdout)


if __name__=='__main__':unittest.main(verbosity=2)

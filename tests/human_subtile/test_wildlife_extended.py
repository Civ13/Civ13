"""Offline exact-anchor and receipt controls; never starts a native process."""
import copy
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import tarfile
import tempfile
import unittest

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('extended', HERE / 'cloud_wildlife_extended.py')
extended = importlib.util.module_from_spec(spec); spec.loader.exec_module(extended)
spec = importlib.util.spec_from_file_location('npc_runner', HERE / 'run-npc.py')
npc = importlib.util.module_from_spec(spec); spec.loader.exec_module(npc)
spec = importlib.util.spec_from_file_location('controller', HERE / 'cloud_npc_controller.py')
controller = importlib.util.module_from_spec(spec); spec.loader.exec_module(controller)
HEAD = 'a' * 40


def base(scope):
    return {'head':HEAD,'error':None,'port':0,'byond_version':516,'byond_build':1688,'scope':scope}


def extended_receipt():
    borders=[]
    for kind in ('mammoth','trex'):
        for variant in (0,64):
            borders.append({'classification':'expected_gap_characterization','animal':'/hostile/'+kind+'/large_border_observe','variant':variant,
                'baseline':1,'remote_result':1,'remote_calls':0,'anchor_result':0,'anchor_calls':1,
                'occupied':[{'x':1},{'x':2}]})
    rows=[{'case':'mosquito_life','life_calls':14,'contact_ticks':14,'settled_windows':2},
          {'case':'bat_life','life_calls':14,'contact_ticks':14,'settled_windows':3},
          {'case':'valid_recovery','flee_dispatches':1,'max_dx':2,'max_dy':0},
          {'case':'invalidated_recovery','flee_dispatches':0,'max_dx':2,'max_dy':0,
           'terminal_observed':1,'pending':0,'recovering':0,'position':{'sx':0,'sy':0}},
          {'case':'pursuit_ai_ticks','side_requests':1,'stuck_ticks':0,'owner_stable':1},
          {'case':'attack_handoff','attacks':1}]
    native=[]
    for kind in ('mammoth','trex'):
        for variant in (0,64):
            for direction in (4,8):
                for orthogonal in (0,1):
                    before={'x':7,'y':7,'z':1,'sx':30 if direction==4 else 2,'sy':2 if orthogonal else 0,
                            'dir':direction,'bound_x':variant,'bound_y':0,'bound_width':96,'bound_height':96,
                            'locs':[{'x':6,'y':7},{'x':7,'y':7}]}
                    after=dict(before,x=8 if direction==4 else 7,sx=0,locs=[{'x':7,'y':7}])
                    auth={'consumed':1,'restoring':0,'direction':direction,'bound_x':variant,'bound_y':0,
                          'destination_x':8 if direction==4 else 7,'destination_y':7,'sx':0,'sy':before['sy'],
                          'width':96,'height':96,'before':{k:before[k] for k in ('x','y','z','sx','sy')}}
                    for case in ('clear','remote','anchor'):
                        trace=[{'event':'Move:before'},{'event':'CheckExit'}] if case=='anchor' else [{'event':'Move:before'}]
                        trace.append({'event':'Move:after'})
                        native.append({'case':case,'animal':'/hostile/'+kind+'/large_native_observe',
                            'variant':variant,'direction':direction,'orthogonal':orthogonal,'edge_x':6,'edge_y':7,
                            'before':before,'after':after,'after_async':after,'auth':auth,'trace':trace})
                    entering_before=dict(before,sx=0)
                    entering_after=dict(entering_before,x=7 if direction==4 else 6,sx=2 if direction==4 else 30,
                                        locs=[{'x':6,'y':7},{'x':7,'y':7},{'x':8,'y':7}])
                    entering_auth=dict(auth,destination_x=entering_after['x'],sx=entering_after['sx'],
                        before={k:entering_before[k] for k in ('x','y','z','sx','sy')})
                    for case in ('clear_enter','anchor_enter'):
                        trace=[{'event':'Move:before'}, {'event':'Enter' if case=='clear_enter' else 'CheckExit'},
                               {'event':'Move:after'}]
                        native.append({'case':case,'animal':'/hostile/'+kind+'/large_native_observe',
                            'variant':variant,'direction':direction,'orthogonal':orthogonal,'edge_x':6,'edge_y':7,
                            'before':entering_before,'after':entering_after,'after_async':entering_after,
                            'auth':entering_auth,'trace':trace})
    return dict(base(extended.SCOPE),npc_checks=0,large_border_checks=20,large_border_rows=borders,
                large_native_checks=1,large_native_rows=native,wildlife_runtime_checks=58,wildlife_runtime_rows=rows)


class ExtendedContracts(unittest.TestCase):
    def test_turf_trace_only_inspects_known_fixture_types(self):
        source=(HERE/'large_native_observe.dm').read_text(encoding='utf-8')
        self.assertNotIn('mover.vars["fixture_native_trace"]',source)
        self.assertIn('istype(mover, /mob/living/simple_animal/hostile/mammoth/large_native_observe)',source)
        self.assertIn('istype(mover, /mob/living/simple_animal/hostile/dinosaur/trex/large_native_observe)',source)
        self.assertEqual(source.count('if (large_native_traced(mover))'),2)

    def test_geometry_observations_precede_full_source_daemon(self):
        source=(HERE/'cloud_npc_smoke.py').read_text(encoding='utf-8')
        suite=source.split('def run_extended(',1)[1].split('def run_production_compile(',1)[0]
        self.assertLess(suite.index("checkpoint('geometry-complete'"),
                        suite.index("checkpoint('extended-fixture-compile'"))
        self.assertLess(suite.index('ext.validate_geometry('),suite.index('ext.validate_extended('))

    def test_actual_staging_anchors_and_no_implicit_vendor_execution(self):
        with tempfile.TemporaryDirectory() as tmp:
            out=Path(tmp); stage=out/'stage'; testdir=stage/'tests/human_subtile';testdir.mkdir(parents=True)
            probe=(HERE/'probe.dm').read_text(encoding='utf-8')
            self.assertEqual(probe.count('\t\t\thuman_subtile_fixture_headless()'),1)
            probe=probe.replace('\t\t\thuman_subtile_fixture_headless()','\t\t\tnpc_subtile_fixture()')
            probe=probe.replace('"checks" = human_subtile_fixture_checks,',
                                '"checks" = human_subtile_fixture_checks, "npc_checks" = npc_subtile_checks, "npc_rows" = npc_subtile_rows,')
            (testdir/'probe.dm').write_text(probe,encoding='utf-8')
            for name in ('large_border_observe.dm','large_native_observe.dm','wildlife_runtime_observe.dm'):
                (testdir/name).write_bytes((HERE/name).read_bytes())
            (stage/'human_subtile.dme').write_text('// staged fixture\n',encoding='utf-8')
            manifest={'dme':'stage/human_subtile.dme','stage_files':{}}
            extended.adapt_extended(out,manifest,npc.current)
            adapted=(testdir/'probe.dm').read_text(encoding='utf-8')
            self.assertIn('if (world.params["wildlife_extended"])\n\t\t\t\tlarge_border_fixture()\n\t\t\t\tlarge_native_fixture()\n\t\t\t\twildlife_runtime_fixture()',adapted)
            self.assertEqual(adapted.count('\t\t\t\tnpc_subtile_fixture()'),1)
            self.assertIn('large_border_observe.dm',(stage/'human_subtile.dme').read_text(encoding='utf-8'))
            self.assertIn('wildlife_runtime_observe.dm',(stage/'human_subtile.dme').read_text(encoding='utf-8'))
            self.assertIn('human_subtile.dme',manifest['stage_files'])
            with self.assertRaises((RuntimeError,ValueError)):
                extended.adapt_extended(out,manifest,npc.current)

    def test_extended_receipt_rejects_missing_mixed_or_false_controls(self):
        good=extended_receipt(); extended.validate_extended(good,HEAD)
        variants=[]
        row=copy.deepcopy(good);row['large_border_rows'][0]['remote_calls']=1;variants.append(row)
        row=copy.deepcopy(good);row['large_border_rows'][0]['anchor_calls']=0;variants.append(row)
        row=copy.deepcopy(good);row['large_native_rows'][0]['auth']['restoring']=1;variants.append(row)
        row=copy.deepcopy(good);row['large_native_rows'][0]['edge_x']=7;variants.append(row)
        row=copy.deepcopy(good);row['large_native_rows'][4]['trace']=[{'event':'Move:before'},{'event':'Move:after'}];variants.append(row)
        row=copy.deepcopy(good);row['large_native_rows'][3]['after']['locs']=row['large_native_rows'][3]['before']['locs'];variants.append(row)
        row=copy.deepcopy(good);row['wildlife_runtime_rows'][0]['settled_windows']=1;variants.append(row)
        row=copy.deepcopy(good);row['wildlife_runtime_rows'][2]['max_dx']=3;variants.append(row)
        row=copy.deepcopy(good);row['wildlife_runtime_rows'][3]['flee_dispatches']=1;variants.append(row)
        row=copy.deepcopy(good);row['wildlife_runtime_rows'][3]['terminal_observed']=0;variants.append(row)
        row=copy.deepcopy(good);row['wildlife_runtime_rows'][3]['recovering']=1;variants.append(row)
        row=copy.deepcopy(good);row['wildlife_runtime_rows'][3]['pending']=1;variants.append(row)
        row=copy.deepcopy(good);row['wildlife_runtime_rows'][3]['position']['sx']=2;variants.append(row)
        row=copy.deepcopy(good);row['wildlife_runtime_rows'][3]['position']['sy']=2;variants.append(row)
        row=copy.deepcopy(good);row['npc_checks']=46;variants.append(row)
        row=copy.deepcopy(good);row['head']='b'*40;variants.append(row)
        for row in variants:
            with self.assertRaises(RuntimeError): extended.validate_extended(row,HEAD)

    def test_geometry_receipt_requires_all_cells_but_no_assumed_result(self):
        snap={'x':7,'y':7,'z':1,'sx':0,'sy':0,'bound_x':0,'bound_y':0,'bound_width':96,'bound_height':96,
              'pixel_x':0,'pixel_y':0,'pixel_w':None,'pixel_z':None,'dir':2,'locs':[{'x':7,'y':7,'z':1,'in_contents':1}]}
        other=dict(snap,bound_x=64)
        rows=[{'case':'same_anchor_bound_change','zero':snap,'sixtyfour':other}]
        for variant in (0,64):
            current=snap if variant==0 else other
            rows.append({'case':'east_2px_clear','variant':variant,'direction':4,'native_return':2,'bumps':0,
                         'before':current,'after':current})
        for variant in (0,64):
            for x in range(4,12):
                for y in range(5,12):
                    rows.append({'case':'east_2px_blocker','variant':variant,'blocker_x':x,'blocker_y':y,
                                 'before':snap if variant==0 else other,'after':snap if variant==0 else other,'native_return':0,'already_occupied':0,'direction':4,
                                 'before_distance':0,'after_distance':0,'bumps':0})
        row=dict(base(extended.GEOMETRY_SCOPE),observations=rows)
        extended.validate_geometry(row,HEAD)
        damaged=copy.deepcopy(row);damaged['observations'][-1]=copy.deepcopy(damaged['observations'][-2])
        with self.assertRaises(RuntimeError): extended.validate_geometry(damaged,HEAD)
        for change in ('bound','anchor','direction','infinite','clear'):
            damaged=copy.deepcopy(row)
            if change=='bound': damaged['observations'][0]['sixtyfour']['bound_x']=0
            elif change=='anchor': damaged['observations'][0]['sixtyfour']['x']=8
            elif change=='direction': damaged['observations'][3]['direction']=8
            elif change=='infinite': damaged['observations'][3]['before_distance']=float('inf')
            else: damaged['observations'][2]=copy.deepcopy(damaged['observations'][1])
            with self.subTest(change=change),self.assertRaises(RuntimeError): extended.validate_geometry(damaged,HEAD)


    def test_host_requires_both_full_receipts_and_compiler_evidence(self):
        snap={'x':7,'y':7,'z':1,'sx':0,'sy':0,'bound_x':0,'bound_y':0,'bound_width':96,'bound_height':96,
              'pixel_x':0,'pixel_y':0,'pixel_w':None,'pixel_z':None,'dir':2,'locs':[{'x':7,'y':7,'z':1,'in_contents':1}]}
        other=dict(snap,bound_x=64)
        rows=[{'case':'same_anchor_bound_change','zero':snap,'sixtyfour':other}]
        for variant in (0,64):
            current=snap if variant==0 else other
            rows.append({'case':'east_2px_clear','variant':variant,'direction':4,'native_return':2,'bumps':0,'before':current,'after':current})
            for x in range(4,12):
                for y in range(5,12):
                    rows.append({'case':'east_2px_blocker','variant':variant,'blocker_x':x,'blocker_y':y,'before':current,
                                 'after':current,'native_return':0,'already_occupied':0,'direction':4,
                                 'before_distance':0,'after_distance':0,'bumps':0})
        rows=[rows[0],rows[1],rows[58]]+rows[2:58]+rows[59:]
        geo=dict(base(extended.GEOMETRY_SCOPE),observations=rows)
        resource={'bytes':100,'sha256':'a'*64,'mode':0o600}
        states={'extended':{'before':resource,'after':dict(resource),'changed':False,'integrity_verified':True}}
        status={'head':HEAD,'outcome':'passed','phase':'complete','fixture_dme_only':True,'suite':'extended',
                'resource_copies_independent':True,'runtime_resources':states}
        ext_raw=json.dumps(extended_receipt()).encode();geo_raw=json.dumps(geo).encode()
        summary={'head':HEAD,'accepted':True,'suite':'extended','fixture_dme_only':True,'artifacts':{'human_subtile.rsc':resource},
                 'resource_states':states,'results':{'extended':{'receipt_sha256':hashlib.sha256(ext_raw).hexdigest()},
                 'geometry':{'receipt_sha256':hashlib.sha256(geo_raw).hexdigest()}}}
        files={'harness-status.json':json.dumps(status).encode(),'smoke-summary.json':json.dumps(summary).encode(),
               'npc-smoke/cloud-manifest.json':json.dumps({'head':HEAD}).encode(),
               'npc-smoke/geometry-stage/manifest.json':json.dumps({'head':HEAD}).encode(),
               'npc-smoke/runtime/receipt.json':ext_raw,'npc-smoke/geometry/receipt.json':geo_raw}
        for folder in ('runtime','geometry'):
            files['npc-smoke/'+folder+'/result.txt']=b'PASS\n';files['npc-smoke/'+folder+'/port-closed.txt']=b'closed\n'
        for folder,name in (('stage','human_subtile.dmb'),('geometry-stage','large_geometry.dmb')):
            files['npc-smoke/'+folder+'/compile-stdout.log']=('DM compiler version 516.1688\n'+name+' - 0 errors, 0 warnings\n').encode()
            files['npc-smoke/'+folder+'/compile-stderr.log']=b''
        def bundle(members):
            out=io.BytesIO()
            with tarfile.open(fileobj=out,mode='w') as tar:
                for name,data in members.items():
                    entry=tarfile.TarInfo(name);entry.size=len(data);tar.addfile(entry,io.BytesIO(data))
            return out.getvalue()
        controller.validate_extended_evidence(bundle(files),HEAD)
        for key in ('npc-smoke/geometry/receipt.json','npc-smoke/runtime/port-closed.txt','npc-smoke/geometry-stage/compile-stdout.log'):
            changed=dict(files);changed.pop(key)
            with self.subTest(missing=key),self.assertRaises((RuntimeError,KeyError)):
                controller.validate_extended_evidence(bundle(changed),HEAD)


if __name__=='__main__': unittest.main()

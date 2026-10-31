"""Host-side positive and negative contracts; these do not run BYOND."""
import copy
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import tarfile
import tempfile
import unittest

spec=importlib.util.spec_from_file_location('bridge',Path(__file__).with_name('cloud_wildlife_bridge.py'))
bridge=importlib.util.module_from_spec(spec);spec.loader.exec_module(bridge)
spec2=importlib.util.spec_from_file_location('controller',Path(__file__).with_name('cloud_npc_controller.py'))
controller=importlib.util.module_from_spec(spec2);spec2.loader.exec_module(controller)

def receipt():
    rows=[]
    for animal in ('mammoth','trex'):
        for variant in (0,64):
            for direction in (1,2,4,8):
                for orthogonal in (0,1):
                    sx=(30 if direction==4 else 2 if direction==8 else 2 if orthogonal else 0)
                    sy=(30 if direction==1 else 2 if direction==2 else 2 if orthogonal else 0)
                    b=dict(x=9,y=7,z=1,sx=sx,sy=sy,dir=direction,bound_x=variant,bound_y=0,
                           bound_width=96,bound_height=96,locs=[dict(x=6,y=6,z=1)])
                    if variant == 64:
                        # Native may re-anchor without changing world position.
                        b['x'] += 2; b['sx'] -= 64
                    dx,dy={1:(0,2),2:(0,-2),4:(2,0),8:(-2,0)}[direction]
                    qx,nx=divmod(b['sx']+dx,32); qy,ny=divmod(b['sy']+dy,32)
                    tx,ty=b['x']+qx,b['y']+qy
                    auth=dict(consumed=1,restoring=0,direction=direction,before=copy.deepcopy(b),bound_x=variant,
                              bound_y=0,width=96,height=96,destination_x=tx,destination_y=ty,sx=nx,sy=ny)
                    for allow in (0,1):
                        after=copy.deepcopy(b)
                        if allow: after.update(x=tx,y=ty,sx=nx,sy=ny,locs=[])
                        trace=[{'event':x} for x in ('Move:before','Uncross','CheckExit:bridge','Move:after')]
                        rows.append(dict(animal='/'+animal+'/fixture',variant=variant,direction=direction,
                                         orthogonal=orthogonal,allow=allow,edge_x=6,edge_y=6,before=copy.deepcopy(b),
                                         after=after,after_async=copy.deepcopy(after),auth=copy.deepcopy(auth),
                                         checks=1,exit_direction=direction,frame_cleared=1,trace=trace))
    p=dict(x=9,y=7,z=1,sx=0,sy=0)
    controls=[dict(case=k,before=copy.deepcopy(p),after=copy.deepcopy(p),result=0,trace=[]) for k in
              ('missing','stale','wrong_actor','unarmed','wrong_destination','nonintegral','replay')]
    ordinary=dict(p,bound_width=32,bound_height=32)
    controls.append(dict(case='ordinary_32',before=ordinary,after=dict(ordinary,sx=2),trace=[]))
    for name in ('callback_invalidate','callback_cancel','callback_finish','callback_delete','callback_blocker_delete','callback_incapacitate','callback_reassign','callback_control','callback_disable'):
        controls.append(dict(case=name,before=copy.deepcopy(p),after=copy.deepcopy(p),checks=1,trace=[dict(event='CheckExit:bridge')]))
    controls.append(dict(case='object_uncross_reject',before=copy.deepcopy(p),after=copy.deepcopy(p),checks=0,
                         trace=[dict(event='Uncross:fixture_reject')]))
    controls.append(dict(case='parent_uncross_reject',before=copy.deepcopy(p),after=copy.deepcopy(p),checks=0,
                         trace=[dict(event='Uncross:parent_reject')]))
    controls.append(dict(case='callback_nested',before=dict(p,sx=2),after=dict(p,sx=0),checks=1,nested_result=0,
                         trace=[dict(event='CheckExit:bridge')]))
    controls.append(dict(case='callback_throw',before=copy.deepcopy(p),after=copy.deepcopy(p),checks=1,caught=1,
                         caught_name='fixture_bridge_exception',throw_attempted=1,helper_returned=0,boundary_caught=1,
                         boundary_name='fixture_bridge_exception',auth=dict(consumed=1,actor_pulse_present=1,
                         actor_transaction_present=1,actor_frame_present=0),
                         trace=[dict(event='CheckExit:bridge'),dict(event='fixture_throw_attempt'),dict(event='Uncross:throw_catch')]))
    controls.append(dict(case='callback_actor_delete',before=copy.deepcopy(p),actor_deleted=1,pulse_consumed=1,
                         error=None,checks=1,retired_state=dict(exists=1,**{k:0 for k in ('active','valid','actor','pulse','transaction','intent','fault','start','destination','path_target','combat_target','following')}),
                         trace=[dict(event='CheckExit:bridge')]))
    controls.append(dict(case='callback_actor_delete_throw',before=copy.deepcopy(p),actor_deleted=1,pulse_consumed=1,
                         error=None,checks=1,retired_state=dict(exists=1,**{k:0 for k in ('active','valid','actor','pulse','transaction','intent','fault','start','destination','path_target','combat_target','following')}),
                         retired_after_throw=dict(exists=1,**{k:0 for k in ('active','valid','faulted','fault','actor','pulse','transaction','intent')}),
                         boundary_caught=1,boundary_name='fixture_bridge_exception',
                         trace=[dict(event='CheckExit:bridge'),dict(event='fixture_throw_attempt'),dict(event='Uncross:throw_catch')]))
    controls.append(dict(case='policy_mutation',before=copy.deepcopy(p),after=copy.deepcopy(p),mutator_checks=1,
                         subject_checks=1,subject_allow=0,trace=[dict(event='policy_mutated'),dict(event='CheckExit:policy_subject')]))
    for kind in ('window','railing','table'):
        for direction in (4,8):
            for allow in (0,1):
                controls.append(dict(case=f'real_/obj/structure/{kind}/bridge_fixture_{direction}_{allow}',allow=allow,
                    direction=direction,variant=64 if direction==4 else 0,before=dict(p,sx=2),
                    after=dict(p,sx=(2+(2 if direction==4 else -2)) if allow else 2),checks=1,exit_direction=direction,
                    trace=[dict(event='Uncross:'+kind),dict(event='CheckExit:'+kind)]))
    for name in ('first_fault','later_fault','ordinary_denial','replace_fault'):
        start=dict(p,sx=4 if name=='later_fault' else 2)
        end=dict(p,sx=2)
        controls.append(dict(case='lifecycle_'+name,before=start,at_callback=end,after=end,after_wait=end,
                             caught=0 if name=='ordinary_denial' else 1,
                             caught_name=None if name=='ordinary_denial' else 'fixture_bridge_exception',
                             pulse_consumed=1,owner_preserved=1,pulse_preserved=1,frame_cleared=1,
                             finished=1,attempted=1,arrived=0,glide_valid=1,distance=2 if name=='later_fault' else 0,
                             checks=0 if name=='replace_fault' else 1))
    controls.append(dict(case='retirement_ownership',preserved=1,cleared=1,plain_deleted=1))
    for control in controls: control['frame_cleared']=1
    return dict(head='a'*40,error=None,port=0,byond_version=516,byond_build=1688,scope=bridge.SCOPE,
                npc_checks=0,large_bridge_checks=4482,large_bridge_exception_sentinel=dict(caught=1,name='fixture_bridge_exception'),
                large_bridge_rows=rows,large_bridge_controls=controls)

class BridgeReceiptTests(unittest.TestCase):
    def test_axis_normalization_preserves_world_coordinate(self):
        for axis in ('x', 'y'):
            for raw in (-65, -64, -33, -32, -1, 0, 31, 32, 63, 64, 65):
                for delta in (-2, -1, 1, 2):
                    with self.subTest(axis=axis, raw=raw, delta=delta):
                        anchor = 11
                        quotient, residual = divmod(raw + delta, 32)
                        self.assertGreaterEqual(residual, 0)
                        self.assertLess(residual, 32)
                        self.assertEqual((anchor + quotient) * 32 + residual, anchor * 32 + raw + delta)
        self.assertEqual((11 + divmod(-62 + 2, 32)[0], divmod(-62 + 2, 32)[1]), (9, 4))

    def test_complete_fixture(self):
        bridge.validate_bridge(receipt(),'a'*40)

    def test_negative_receipts(self):
        mutations = [
            lambda r: r['large_bridge_rows'].pop(),
            lambda r: r['large_bridge_rows'][0].update(exit_direction=8),
            lambda r: r['large_bridge_rows'][0]['after'].update(sx=1),
            lambda r: r['large_bridge_rows'][0]['trace'].reverse(),
            lambda r: r['large_bridge_rows'][0]['auth'].update(sx=99),
            lambda r: r['large_bridge_rows'][0]['auth'].update(sx=1.5),
            lambda r: r['large_bridge_rows'][0]['auth'].update(sx=-1),
            lambda r: r['large_bridge_rows'][0]['auth'].update(destination_x=9.5),
            lambda r: r['large_bridge_controls'][0].update(result=1),
            lambda r: next(c for c in r['large_bridge_controls'] if c['case'].startswith('real_')).update(checks=0),
            lambda r: next(c for c in r['large_bridge_controls'] if c['case']=='callback_actor_delete').update(actor_deleted=0),
            lambda r: next(c for c in r['large_bridge_controls'] if c['case']=='callback_actor_delete').update(frame_cleared=0),
            lambda r: next(c for c in r['large_bridge_controls'] if c['case']=='callback_actor_delete').update(pulse_consumed=0),
            lambda r: next(c for c in r['large_bridge_controls'] if c['case']=='callback_actor_delete')['retired_state'].update(actor=1),
            lambda r: next(c for c in r['large_bridge_controls'] if c['case']=='retirement_ownership').update(preserved=0),
            lambda r: next(c for c in r['large_bridge_controls'] if c['case']=='retirement_ownership').update(cleared=0),
            lambda r: next(c for c in r['large_bridge_controls'] if c['case']=='callback_actor_delete_throw')['retired_after_throw'].update(faulted=1),
            lambda r: next(c for c in r['large_bridge_controls'] if c['case']=='callback_actor_delete_throw')['retired_after_throw'].update(fault=1),
            lambda r: next(c for c in r['large_bridge_controls'] if c['case']=='callback_throw').update(throw_attempted=0),
            lambda r: next(c for c in r['large_bridge_controls'] if c['case']=='callback_throw')['auth'].update(actor_frame_present=1),
            lambda r: r.update(large_bridge_checks=4120),
            lambda r: next(c for c in r['large_bridge_controls'] if c['case']=='lifecycle_first_fault').update(caught=0),
            lambda r: next(c for c in r['large_bridge_controls'] if c['case']=='lifecycle_later_fault').update(distance=0),
            lambda r: next(c for c in r['large_bridge_controls'] if c['case']=='lifecycle_later_fault').update(glide_valid=0),
            lambda r: next(c for c in r['large_bridge_controls'] if c['case']=='lifecycle_first_fault').update(arrived=1),
            lambda r: next(c for c in r['large_bridge_controls'] if c['case']=='lifecycle_replace_fault').update(owner_preserved=0),
            lambda r: next(c for c in r['large_bridge_controls'] if c['case']=='lifecycle_ordinary_denial').update(caught=1),
            lambda r: r['large_bridge_exception_sentinel'].update(caught=0),
        ]
        for mutate in mutations:
            row=receipt(); mutate(row)
            with self.assertRaises(RuntimeError): bridge.validate_bridge(row,'a'*40)

    def test_exact_source_staging(self):
        class Adapter:
            @staticmethod
            def adapt(out, manifest, relative, before, after):
                p=Path(out)/'stage'/relative
                text=p.read_text()
                if text.count(before) != 1: raise RuntimeError('Ambiguous source replacement')
                p.write_text(text.replace(before,after))
        with tempfile.TemporaryDirectory() as temp:
            out=Path(temp); stage=out/'stage'; fixture=stage/'tests/human_subtile'; fixture.mkdir(parents=True)
            (fixture/'probe.dm').write_text('\t\t\tnpc_subtile_fixture()\n"npc_checks" = npc_subtile_checks,\n'
                                           '"scope" = "actual human/codec; headless authority adapter"')
            for name in ('large_native_observe.dm','large_bridge_fixture.dm','large_bridge_lifecycle_draft.dm'): (fixture/name).write_text('// fixture')
            (stage/'human_subtile.dme').write_text('// dme')
            manifest=dict(dme='stage/human_subtile.dme',stage_files={},head='a'*40)
            bridge.adapt_bridge(out,manifest,Adapter())
            self.assertIn('large_bridge_fixture()', (fixture/'probe.dm').read_text())
            self.assertIn('large_bridge_fixture.dm', (stage/'human_subtile.dme').read_text())
            self.assertEqual(json.loads((out/'bridge-manifest.json').read_text())['bridge_scope'],bridge.SCOPE)
            self.assertEqual(set(manifest['stage_files']),{'tests/human_subtile/probe.dm','human_subtile.dme'})

    def test_manual_selector_is_exclusive(self):
        workflow=(Path(__file__).resolve().parents[2]/'.github/workflows/moving-save-chunks.yml').read_text()
        self.assertIn('wildlife_bridge:\n',workflow)
        self.assertIn("inputs.wildlife_bridge == true && inputs.wildlife_smoke != true && inputs.wildlife_extended != true && inputs.wildlife_production_compile != true",workflow)
        self.assertIn("inputs.wildlife_bridge != true && inputs.wildlife_production_compile != true",workflow)
        self.assertIn("inputs.wildlife_bridge == true && 'bridge'",workflow)

    def test_host_evidence_validation_and_hash_rejection(self):
        head='a'*40; raw=json.dumps(receipt()).encode()
        resource=dict(bytes=1,sha256='b'*64,mode=0o600)
        states={'bridge':dict(before=resource,after=resource,changed=False,integrity_verified=True)}
        status=dict(head=head,outcome='passed',phase='complete',fixture_dme_only=True,suite='bridge',
                    resource_copies_independent=True,runtime_resources=states)
        summary=dict(head=head,accepted=True,suite='bridge',fixture_dme_only=True,resource_states=states,
                     artifacts={'human_subtile.rsc':resource},results={'bridge':dict(receipt_sha256=hashlib.sha256(raw).hexdigest())})
        def make_archive(summary_value):
            contents={'harness-status.json':json.dumps(status).encode(),'smoke-summary.json':json.dumps(summary_value).encode(),
                      'npc-smoke/runtime/result.txt':b'PASS\n','npc-smoke/runtime/port-closed.txt':b'closed\n',
                      'npc-smoke/runtime/receipt.json':raw,'npc-smoke/cloud-manifest.json':json.dumps(dict(head=head)).encode(),
                      'npc-smoke/stage/compile-stdout.log':b'DM compiler version 516.1688\nhuman_subtile.dmb - 0 errors, 0 warnings\n',
                      'npc-smoke/stage/compile-stderr.log':b''}
            out=io.BytesIO()
            with tarfile.open(fileobj=out,mode='w:') as package:
                for name,data in contents.items():
                    item=tarfile.TarInfo(name);item.size=len(data);package.addfile(item,io.BytesIO(data))
            return out.getvalue()
        controller.validate_bridge_evidence(make_archive(summary),head)
        corrupt=copy.deepcopy(summary);corrupt['results']['bridge']['receipt_sha256']='c'*64
        with self.assertRaises(RuntimeError): controller.validate_bridge_evidence(make_archive(corrupt),head)

if __name__ == '__main__': unittest.main()

"""File-only fixture preparation and CI selection; no native execution."""
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from types import SimpleNamespace as N
from unittest.mock import patch

ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('root_tree_prepare',Path(__file__).with_name('prepare.py'))
prepare=importlib.util.module_from_spec(spec);spec.loader.exec_module(prepare)
spec=importlib.util.spec_from_file_location('preparation_support',Path(__file__).with_name('support.py'))
support=importlib.util.module_from_spec(spec);spec.loader.exec_module(support)
spec=importlib.util.spec_from_file_location('fixture_projection',Path(__file__).with_name('test_contract.py'))
projection=importlib.util.module_from_spec(spec);spec.loader.exec_module(projection)


class Preparation(unittest.TestCase):
    def test_named_renderer_controls_change_only_the_bound_presenter_input(self):
        with tempfile.TemporaryDirectory() as temp, patch.object(prepare.provenance,'revision',side_effect=lambda requested:support.snapshot(prepare.provenance)):
            normal,base=prepare.provenance.plan(support.HEAD)
            for control in prepare.provenance.RENDERER_CONTROLS:
                out=Path(temp)/control;manifest=prepare.prepare(out,support.HEAD,renderer_control=control)
                _,files=prepare.provenance.plan(support.HEAD,control)
                self.assertEqual(manifest['source_objects'],normal['source_objects'])
                self.assertEqual([p for p in files if files[p]!=base[p]],['root_tree_presenter.dm'])
                self.assertEqual(prepare.provenance.validate_stage(out,support.HEAD)['renderer_control'],control)
                text=files['root_tree_presenter.dm'].decode()
                if control=='neighbor':
                    env=projection.environment();f=projection.compile_proc(text,'/proc/root_tree_set_frame(','I, T, frame',env)
                    t=projection.tree();t.appearance=t;i=N(appearance_flags=0);f(i,t,object())
                    self.assertEqual(i.plane,env['GAME_PLANE'])
                    self.assertIn('context.decision_snapshot(T, S, "visual")',text)
                else:
                    self.assertIn('if(FALSE)',text)
                    self.assertNotIn('context.decision_snapshot(',text)
                    self.assertIn('S = context.capture()',text);self.assertIn('I.plane = ROOT_TREE_PLANE',text)
                    env=projection.environment();env.update(LOS_DENY=0)
                    c=N(decision_snapshot=lambda *a:0)
                    t=projection.tree()
                    original=next(l.strip() for l in base['root_tree_presenter.dm'].decode().splitlines() if l.startswith('\t\tif(context.decision_snapshot(T, S'))
                    def admitted(condition):
                        source='/proc/control_guard()\n\t'+condition+'\n\t\treturn FALSE\n\treturn TRUE\n'
                        return projection.compile_proc(source,'/proc/control_guard(','context, T, S',env)(c,t,object())
                    self.assertFalse(admitted(original));self.assertTrue(admitted('if(FALSE)'))
                metadata=json.loads((out/'source-manifest.json').read_text());metadata['renderer_control']=None
                (out/'source-manifest.json').write_text(json.dumps(metadata))
                with self.assertRaises(prepare.provenance.Invalid):prepare.provenance.validate_stage(out,support.HEAD)

    def test_unknown_or_changed_anchor_cannot_create_an_unreviewed_variant(self):
        p=prepare.provenance;data=(ROOT/'code/modules/visibility/root_tree_presenter.dm').read_bytes().replace(b'\r\n',b'\n')
        self.assertEqual(p.renderer_variant(data,None),data)
        for control in p.RENDERER_CONTROLS:
            with self.assertRaises(p.Invalid):p.renderer_variant(data+b'\n'+data,control)
            with self.assertRaises(p.Invalid):p.renderer_variant(b'changed',control)
        with self.assertRaises(p.Invalid):p.renderer_variant(data,'arbitrary')

    def test_exact_source_and_art_staged_without_processes(self):
        with tempfile.TemporaryDirectory() as temp, patch('subprocess.Popen',side_effect=AssertionError('No process')), \
             patch.object(prepare.provenance,'revision',side_effect=lambda requested:support.snapshot(prepare.provenance)):
            out=Path(temp)/'fresh';manifest=prepare.prepare(out,support.HEAD)
            self.assertEqual(json.loads((out/'source-manifest.json').read_text()),manifest)
            _,files=prepare.provenance.plan(support.HEAD)
            for path,entry in manifest['files'].items():
                target=out/path
                self.assertEqual(target.read_bytes(),files[path])
                self.assertEqual(hashlib.sha256(target.read_bytes()).hexdigest(),entry['sha256'])
            light=(out/'production-light-update.dm').read_text()
            self.assertIn('/atom/movable/lighting_overlay/proc/update_overlay()',light)
            self.assertIn('/obj/screen/plane_master/light_mask/backdrop(',light)
            self.assertIn('/turf/proc/needs_fullbright_coverage()',light)
            self.assertEqual(hashlib.sha256(light.encode()).hexdigest(),manifest['files']['production-light-update.dm']['sha256'])
            self.assertIn('fixture.dme',manifest['files']);self.assertIn('fixture.dmf',manifest['files'])
            with self.assertRaises(FileExistsError):prepare.prepare(out,support.HEAD)

    def test_fixture_contains_separate_native_controls_and_no_production_startup(self):
        source=(Path(__file__).with_name('fixture.dm')).read_text()
        for phase in range(1,10):self.assertIn('phase == '+str(phase),source)
        self.assertIn('No game startup, live state or credentials',source)
        self.assertIn('opacity = TRUE',source)
        self.assertNotIn('opacity = FALSE',source)
        self.assertIn('M.client.view = "15x15"',source)
        self.assertIn('new /obj/hidden_witness',source)
        self.assertIn('T.sync_fullbright_coverage()',source)
        self.assertIn('if(!fixture_client_allowed(client))',source)
        # Immutable per-phase publication avoids delete/read sharing races.
        self.assertNotIn('fdel("phase.ready.json")',source)
        self.assertIn('"phase-[phase].ready.json"',source)
        client_del=source.split('/client/Del()',1)[1].split('/proc/',1)[0]
        self.assertLess(client_del.index('los_context.retire()'),client_del.index('root_tree_presenter.retire()'))
        self.assertNotIn('civ13.dmb',source)
        self.assertIn('/atom/movable\n\tplane = GAME_PLANE',source)
        caller=source.split('spawn(1)',1)[1].split('/proc/fixture_phase',1)[0]
        self.assertLess(caller.index('fixture_phase(phase, src) != TRUE'),caller.index('fixture_publish(phase, witness)'))
        self.assertIn('fixture_failed || !witness',caller)
        self.assertIn('phase == 9 && !fixture_failed',caller)
        self.assertIn('closed = (fixture_presenter.shutter in M.client.screen)',source)
        error=source.split('/world/Error(',1)[1].split('/proc/',1)[0]
        self.assertIn('fixture_fail("native_runtime")',error)
        for name in ('tree_identity','plane_identity','plane_constructor_identity','plane_refresh_identity',
                     'plane_constructor_[name]','plane_refresh_[name]'):
            self.assertIn('"'+name+'"',source)

    def test_actual_publisher_never_deletes_or_appends_an_existing_ack(self):
        source=Path(__file__).with_name('fixture.dm').read_text();env=projection.environment();files={};failures=[]
        def write(data,path):files[path]=files.get(path,'')+data+'\n';return True
        env.update(fixture_failed=False,islist=lambda x:isinstance(x,dict),fexists=lambda path:path in files,
                   json_encode=json.dumps,text2file=write,fixture_fail=lambda why:failures.append(why) or False)
        publish=projection.compile_proc(source,'/proc/fixture_publish(','phase, witness',env)
        self.assertTrue(publish(7,{'phase':7}));self.assertTrue(publish(8,{'phase':8}))
        self.assertEqual(json.loads(files['phase-7.ready.json'])['phase'],7)
        self.assertEqual(json.loads(files['phase-8.ready.json'])['phase'],8)
        old=dict(files);self.assertFalse(publish(7,{'phase':7}));self.assertEqual(files,old)
        self.assertEqual(failures,['duplicate_ack'])
        env['fixture_failed']=True;self.assertFalse(publish(9,{'phase':9}));self.assertNotIn('phase-9.ready.json',files)

    def test_fixture_loopback_guest_and_explicit_exact_session_admission(self):
        source=Path(__file__).with_name('fixture.dm').read_text();env=projection.environment()
        env.update(fixture_authorized_session=False,fixture_authorized_identity='fixtureuser',copytext=lambda x,a,b:x[a-1:b-1])
        allowed=projection.compile_proc(source,'/proc/fixture_client_allowed(','C',env)
        guest=N(key='Guest-123',ckey='guest123',address='127.0.0.1')
        account=N(key='Fixture User',ckey='fixtureuser',address='127.0.0.1')
        self.assertTrue(allowed(guest));self.assertFalse(allowed(account))
        env['fixture_authorized_session']=True;self.assertTrue(allowed(account))
        account.ckey='anotheruser';self.assertFalse(allowed(account))
        guest.address='192.0.2.1';self.assertFalse(allowed(guest))

    def test_ci_registers_offline_files_only(self):
        spec=importlib.util.spec_from_file_location('root_ci',ROOT/'scripts/ci_baseline.py')
        ci=importlib.util.module_from_spec(spec);spec.loader.exec_module(ci)
        self.assertEqual(ci.SUITES['root_tree_presentation']['files'],(
            'tests/root_tree_presentation/test_contract.py',
            'tests/root_tree_presentation/test_noop_refresh.py',
            'tests/root_tree_presentation/test_preparation.py',
            'tests/root_tree_presentation/test_protocol.py'))
        for path in ['code/modules/visibility/root_tree_presenter.dm',
                     'tests/root_tree_presentation/fixture.dm','code/__defines/_planes+layers.dm',
                     'tests/save_movement/source_adapter.py']:
            self.assertTrue(ci.impact([path])['suites']['root_tree_presentation']['selected'])
        for path in ['code/modules/lighting/lighting_overlay.dm','code/game/mob/mob_movement.dm']:
            self.assertEqual(set(k for k,v in ci.impact([path])['suites'].items() if v['selected']),set(ci.SUITES))


if __name__=='__main__':unittest.main()

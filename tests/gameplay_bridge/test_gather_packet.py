"""Typed fixture/packet/control tests with inert filesystem/Git; no native calls."""
import copy
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/"scripts/gameplay_bridge"))
import prepare_gather as prep
from check_gather_packet import ORDINARY,TYPED,STATE,verify_packet,verify_result,verify_results,verify_sockets
from gather_context import CLIENT_FILES,isolate_client_new,project


def external():
    return {"adapter":{name:{"path":"synthetic/"+name,"sha256":value} for name,value in prep.ADAPTER_HASHES.items()},
            "reference_driver":{"sha256":prep.DRIVER_HASH},"limits":prep.LIMITS,"binaries":prep.BINARIES}


def result(profile):
    names=sorted(ORDINARY|(TYPED if profile=="enabled" else set()))
    failed=prep.FAILURES.get(profile)
    if failed:names+=['typed_gather_setup',failed]
    return {"commit":"a"*40,"profile":profile,"byond_version":516,"byond_build":1681,
            "dimensions":[9,9,1],"port":0,"runtime_error":False,"positive_client_acceptance":False,
            "passed":not failed,"failed_assertion":failed or "", "ordinary_state":copy.deepcopy(STATE),
            "metrics":{"ordinary_gather_ticks":30,"explicit_gather_ticks":30,"entry_ticks":0,
                       "final_ticks":0,"final_wait_ticks":30,"first_wake_ticks":1,"wake_ticks":2,
                       "old_new_ticks":2,"canonical_cancel_ticks":2},
            "checks":[{"assertion":name,"passed":name!=failed,"tick":i} for i,name in enumerate(names)]}


class GatherPacketTests(unittest.TestCase):
    def setUp(self):
        self.helper=(ROOT/"code/_helpers/mobs.dm").read_text(encoding="utf-8")
        self.grass=(ROOT/"code/game/turfs/floor_attackby.dm").read_text(encoding="utf-8")

    def test_each_mutation_is_specific_and_disabled_stock_text_is_preserved(self):
        original=(self.helper,self.grass)
        ordinary=prep.variants(*original,"stock")
        for profile in prep.PROFILES:
            h,g=prep.variants(*original,profile)
            self.assertEqual(project(h,set())[0],project(ordinary[0],set())[0])
            self.assertEqual(project(g,set())[0],project(ordinary[1],set())[0])
            self.assertEqual(h.split('/mob/var/may_do_after = TRUE')[0],self.helper.split('/mob/var/may_do_after = TRUE')[0])
            self.assertEqual((h,g)!=ordinary,profile in prep.FAILURES)
        self.assertEqual((self.helper,self.grass),original)
        with self.assertRaises(ValueError):prep.variants(self.helper+'drift',self.grass,'enabled')
        with self.assertRaises(ValueError):prep.variants(self.helper,self.grass.replace('return user && user.client','changed'),'enabled')

    def test_reacquisition_and_ambient_controls_are_actual_unsafe_captures(self):
        h,_=prep.variants(self.helper,self.grass,'reacquire')
        self.assertEqual(h.count('gameplay_lease = gameplay_bridge.action_lease'),1)
        h,_=prep.variants(self.helper,self.grass,'ambient')
        self.assertIn('if (isnull(gameplay_context))\n\t\tgameplay_context = gameplay_bridge.action_lease',h)
        _,g=prep.variants(self.helper,self.grass,'omit_forward')
        self.assertNotIn('var/completed = grass_cutting_wait(user, gameplay_context)',g)

    def test_all_dmes_use_real_fixture_and_explicit_generated_source_only(self):
        dme=(ROOT/"civ13.dme").read_text()
        for profile in prep.PROFILES:
            value=prep.fixture_dme(dme,profile)
            self.assertIn('#include "tests/gameplay_bridge/native/gather_probe.dm"',value)
            self.assertNotIn('compile_probe.dm',value)
            self.assertIn('gather_generated/'+profile+'_mobs.dm',value)
            self.assertIn('gather_generated/'+profile+'_grass.dm',value)
            self.assertEqual('#define CIV13_GAMEPLAY_BRIDGE' in value,profile not in ('stock','disabled'))
            self.assertEqual('code/modules/gameplay_bridge/bridge.dm' in value,profile!='stock')
            self.assertNotIn('.dmm"',value)

    def test_fixture_uses_paid_real_handlers_callbacks_and_named_control_routes(self):
        source=(ROOT/'tests/gameplay_bridge/native/gather_probe.dm').read_text()
        for anchor in ('G.gather_grass_cuttings(H,F,L)','G.gather_grass_cuttings(H,F)',
                       'elapsed >= 30','sleep(35)','var/forged = list(',
                       'H.survival_actions','H.survival_rest_since','check_for_repeats=FALSE',
                       'L.cancelled = TRUE'):
            self.assertIn(anchor,source)
        self.assertNotIn('new /obj/item/stack/grass_cuttings',source)
        self.assertEqual(source.count('/client/New(TopicData)\n\treturn FALSE'),1)
        self.assertNotIn('.Life(',source)
        self.assertEqual(source.count('starts++\n\t. = ..()'),1)
        self.assertEqual(source.count('finishes++\n\t. = ..()'),1)
        for name in prep.FAILURES.values():self.assertIn('"'+name+'"',source)

    def test_mutations_require_exact_failed_oracle_and_full_successful_setup(self):
        for profile in prep.FAILURES:
            good=result(profile);verify_result(good,profile,'a'*40)
            for field,value in (('runtime_error',True),('failed_assertion','unrelated'),
                                ('passed',True),('positive_client_acceptance',True),('port',1234)):
                bad=copy.deepcopy(good);bad[field]=value
                with self.assertRaises(ValueError):verify_result(bad,profile,'a'*40)
            bad=copy.deepcopy(good);bad['checks']=bad['checks'][-2:]
            with self.assertRaises(ValueError):verify_result(bad,profile,'a'*40)
            bad=copy.deepcopy(good);bad['ordinary_state']['cuttings_added']=0
            with self.assertRaises(ValueError):verify_result(bad,profile,'a'*40)

    def test_positive_missing_assertions_duplicates_ticks_and_false_claims_refuse(self):
        good=result('enabled');verify_result(good,'enabled','a'*40)
        for rows in (good['checks'][:-1],good['checks']+[good['checks'][-1]],[],
                     [{**r,'tick':801} for r in good['checks']]):
            bad=copy.deepcopy(good);bad['checks']=rows
            with self.assertRaises(ValueError):verify_result(bad,'enabled','a'*40)
        with self.assertRaises(ValueError):verify_result(good,'enabled','b'*40)
        for key,value in (('ordinary_gather_ticks',0),('explicit_gather_ticks',29),('wake_ticks',30),('entry_ticks',1)):
            bad=copy.deepcopy(good);bad['metrics'][key]=value
            with self.assertRaises(ValueError):verify_result(bad,'enabled','a'*40)
        bad=copy.deepcopy(good);bad['passed']='true'
        with self.assertRaises(ValueError):verify_result(bad,'enabled','a'*40)

    def test_packet_preparation_is_source_only_and_validator_binds_every_file(self):
        files={p:(ROOT/p).read_text(encoding='utf-8') for p in ('code/_helpers/mobs.dm','code/game/turfs/floor_attackby.dm','civ13.dme',prep.NAMES_SOURCE)}
        names=prep.name_dependencies(files[prep.NAMES_SOURCE])
        def git(root,*args):
            if args[0]=='show':
                path=args[1].split(':',1)[1]
                if path in names:return b'synthetic public name\n'
                return b'synthetic-library-never-executed' if path=='rust_g.dll' else files[path].encode()
            if args[0]=='rev-parse':return b'a'*40
            if args[0]=='status':return b''
            raise AssertionError(args)
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp)/'checkout';root.mkdir();out=Path(temp)/'packet'
            def closure(*args):
                source=out/'source';source.mkdir(parents=True)
                f=source/'tests/gameplay_bridge/native/gather_probe.dm';f.parent.mkdir(parents=True);f.write_text('inert fixture')
                f=source/prep.NAMES_SOURCE;f.parent.mkdir(parents=True);f.write_text(files[prep.NAMES_SOURCE])
                return source
            with patch('prepare_gather.bindings',return_value=external()),patch('prepare_gather.git',side_effect=git),patch('prepare_gather.prepare_closure',side_effect=closure):
                manifest=prep.prepare(root,out,'a'*40,root,root)
            raw=(out/'manifest.json').read_bytes();sha=hashlib.sha256(raw).hexdigest()
            verify_packet(out,'a'*40,sha)
            self.assertEqual([p['name'] for p in manifest['profiles']],list(prep.PROFILES))
            self.assertIsNone(manifest['native_lease'])
            self.assertFalse(any(p.suffix in ('.dmb','.rsc') for p in out.rglob('*')))
            self.assertEqual(set(manifest['runtime_dependencies']),set(names)|{'rust_g.dll'})
            key='runtime/stock/'+names[0]
            dependency=out/key;data=dependency.read_bytes()
            dependency.unlink()
            with self.assertRaisesRegex(ValueError,'file binding drift'):verify_packet(out,'a'*40,sha)
            dependency.write_bytes(data+b'changed')
            with self.assertRaisesRegex(ValueError,'file binding drift'):verify_packet(out,'a'*40,sha)
            dependency.write_bytes(data)
            # A self-consistent manifest cannot omit a required preload and its hash.
            altered=copy.deepcopy(manifest);del altered['sha256'][key]
            (out/'manifest.json').write_text(json.dumps(altered))
            with self.assertRaisesRegex(ValueError,'only exact public name dictionaries'):
                verify_packet(out,'a'*40,hashlib.sha256((out/'manifest.json').read_bytes()).hexdigest())
            (out/'manifest.json').write_bytes(raw)
            unexpected=out/'runtime/stock/config/config.txt';unexpected.write_text('synthetic forbidden config')
            with self.assertRaisesRegex(ValueError,'unbound or missing runtime config'):verify_packet(out,'a'*40,sha)
            unexpected.unlink()
            altered=copy.deepcopy(manifest);del altered['runtime_dependencies'][names[0]]
            (out/'manifest.json').write_text(json.dumps(altered))
            with self.assertRaisesRegex(ValueError,'exact public runtime dependency closure'):
                verify_packet(out,'a'*40,hashlib.sha256((out/'manifest.json').read_bytes()).hexdigest())
            altered=copy.deepcopy(manifest);del altered['runtime_dependencies']
            (out/'manifest.json').write_text(json.dumps(altered))
            with self.assertRaisesRegex(ValueError,'exact public runtime dependency closure'):
                verify_packet(out,'a'*40,hashlib.sha256((out/'manifest.json').read_bytes()).hexdigest())
            (out/'manifest.json').write_bytes(raw)
            unexpected=out/'source/config';unexpected.mkdir()
            with self.assertRaisesRegex(ValueError,'source server config forbidden'):verify_packet(out,'a'*40,sha)
            unexpected.rmdir()
            with self.assertRaises(ValueError):verify_packet(out,'a'*40,'0'*64)
            altered=copy.deepcopy(manifest)
            altered['profiles'][0]['daemon_argv_after_separate_grant'][4]='0.0.0.0'
            (out/'manifest.json').write_text(json.dumps(altered))
            with self.assertRaisesRegex(ValueError,'argument boundary'):
                verify_packet(out,'a'*40,hashlib.sha256((out/'manifest.json').read_bytes()).hexdigest())
            (out/'manifest.json').write_bytes(raw)
            target=out/'source/gather_enabled.dme';target.write_text('tampered')
            with self.assertRaises(ValueError):verify_packet(out,'a'*40,sha)

    def test_public_preload_closure_is_literal_bounded_complete_and_frozen(self):
        source=(ROOT/prep.NAMES_SOURCE).read_text(encoding='utf-8')
        paths=prep.name_dependencies(source)
        self.assertEqual(len(paths),146)
        self.assertTrue(all((ROOT/p).is_file() for p in paths))
        sample='var/list/names = file2list("config/names/first_male.txt")\n'
        self.assertEqual(prep.name_dependencies(sample+'// file2list("private")\n'),('config/names/first_male.txt',))
        for bad in (sample.replace('config/names/','config/'),sample.replace('first_male','../private'),
                    sample.replace('"config/names/first_male.txt"','dynamic_path'),
                    sample+'var/private = file2text("config/config.txt")\n',sample*193,''):
            with self.assertRaises(ValueError):prep.name_dependencies(bad)
        calls=[]
        def read(path):calls.append(path);return b'synthetic public blob'
        data=prep.runtime_inputs(read,source)
        self.assertEqual(set(data),set(paths)|{'rust_g.dll'})
        self.assertEqual(calls,[*paths,'rust_g.dll'])
        for missing in (paths[0],'rust_g.dll'):
            def read(path):
                if path==missing:raise FileNotFoundError(path)
                return b'public'
            with self.assertRaises(FileNotFoundError):prep.runtime_inputs(read,source)
        for raw in (b'',b' ',b'x'*(prep.NAME_FILE_LIMIT+1)):
            with self.assertRaises(ValueError):prep.runtime_inputs(lambda p:raw,source)
        with self.assertRaisesRegex(ValueError,'exceeds bound'):
            prep.runtime_inputs(lambda p:b'x'*20000,source)

    def test_existing_adapter_is_only_hashed_never_imported_or_replaced(self):
        source=(ROOT/'scripts/gameplay_bridge/prepare_gather.py').read_text()
        self.assertNotIn('import windows',source)
        self.assertNotIn('Popen(',source)
        self.assertNotIn('subprocess.run(',source)
        self.assertIn('create suspended; assign and verify Job before resume',source)
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp)
            for name in prep.ADAPTER_HASHES:(root/name).write_bytes(b'drift')
            with self.assertRaisesRegex(ValueError,'adapter drift'):prep.bindings(root,root)

    def test_original_client_entries_removed_without_changing_other_procedures(self):
        source='/client/Other()\n\treturn 1\n/client/New(TopicData)\n\tunsafe_login()\n/client/Last()\n\treturn 2\n'
        self.assertEqual(isolate_client_new(source),'/client/Other()\n\treturn 1\n/client/Last()\n\treturn 2\n')
        for bad in ('missing entry',source+source):
            with self.assertRaises(ValueError):isolate_client_new(bad)
        for relative in CLIENT_FILES:
            result=isolate_client_new((ROOT/relative).read_text(encoding='utf-8'))
            self.assertNotIn('/client/New(',result)
        for profile in prep.PROFILES:
            dme=prep.fixture_dme((ROOT/'civ13.dme').read_text(),profile)
            for index,relative in enumerate(CLIENT_FILES):
                self.assertNotIn(relative.replace('/','\\'),dme)
                self.assertIn('compile_generated/client_'+str(index)+'.dm',dme)

    def test_fixed_loopback_socket_gate_rejects_widened_or_compiler_listeners(self):
        allowed={'state':'listen','address':'127.0.0.1','port':prep.PORT}
        verify_sockets([allowed],True)
        for row,runtime in ((allowed,False),({**allowed,'address':'0.0.0.0'},True),
                            ({**allowed,'address':'::1'},True),({**allowed,'port':prep.PORT+1},True)):
            with self.assertRaises(ValueError):verify_sockets([row],runtime)
        verify_sockets([{'state':'other','address':'remote','port':0}],True) # Recorded residual, not isolation.
        self.assertEqual(prep.LIMITS['runtime_private_bytes'],512*1024**2)
        self.assertEqual(prep.LIMITS['compile_private_bytes'],1024**3)


if __name__=='__main__':unittest.main()

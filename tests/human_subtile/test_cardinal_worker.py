"""Exercise worker sequencing and deadlines with fakes; no native calls."""
import importlib.util
import json
from pathlib import Path
import tempfile
import time
import types
import unittest
from unittest.mock import patch

HERE=Path(__file__).resolve().parent
def load(name):
    spec=importlib.util.spec_from_file_location(name,HERE/(name+'.py'))
    result=importlib.util.module_from_spec(spec);spec.loader.exec_module(result);return result
worker=load('cardinal_worker'); contract=load('cardinal_contract')


class WorkerTests(unittest.TestCase):
    def test_registration_is_manual_only_and_serialized(self):
        text=(HERE.parents[1]/'.github/workflows/wildlife-cardinal-cadence.yml').read_text(encoding='utf-8')
        self.assertIn('on:\n  workflow_dispatch:',text)
        self.assertNotIn('\n  push:',text)
        self.assertNotIn('\n  pull_request:',text)
        self.assertIn('options: [transition]',text)
        self.assertIn('suite: [transition05]',text)
        self.assertIn('test "$EXPERIMENT" = transition',text)
        self.assertIn('test "$WILDLIFE_SUITE" = transition05',text)
        self.assertIn('max-parallel: 1',text)
        self.assertIn('cancel-in-progress: false',text)
        self.assertIn('test "$EXPECTED_HEAD" = "$GITHUB_SHA"',text)
        self.assertIn('persist-credentials: false',text)

    def test_one_compile_two_fresh_modes_and_two_rates(self):
        for suite,tick in (('cardinal05',.5),('cardinal10',1.0)):
            with self.subTest(suite=suite), tempfile.TemporaryDirectory() as td:
                root=Path(td);calls=[];head='a'*40
                def require(ok,message):
                    if not ok: raise RuntimeError(message)
                def prepare(out):
                    (out/'stage').mkdir(parents=True); (out/'stage/human_subtile.dme').write_text('fixture')
                    return {'head':head,'dme':'stage/human_subtile.dme','stage_files':{}}
                def compile_phase(_legacy,_group,cmd,stage,name,limit):
                    calls.append(('compile',limit));(stage/'compile-stdout.log').write_text('ok');(stage/'compile-stderr.log').write_text('')
                    return {'seconds':0}
                def linked(out,stage,dme,name):
                    folder=out/name;folder.mkdir();return folder,folder/'human_subtile.dmb',{'human_subtile.rsc':{'mode':384}}
                def daemon(_legacy,_group,cmd,folder,dme,peer,artifacts,peer_expected,mode,states,timeout):
                    calls.append(('daemon',mode,timeout,cmd[cmd.index('-params')+1]))
                    states[mode]={'after':{'mode':384}}
                    (folder/'port-closed.txt').write_bytes(b'closed\n');(folder/'result.txt').write_bytes(b'PASS\n')
                    (folder/'receipt.json').write_text(json.dumps({'mode':mode}))
                    return {'seconds':0}
                fake_contract=types.SimpleNamespace(SCOPE='scope',MODES=('legacy','smooth'),number=contract.number,
                    validate_source=lambda git,env,h:(require(h==head and git[0]=='git','wrong binding'),calls.append(('source',))),
                    validate_receipt=lambda row,h,m,t: require(row['mode']==m and h==head and t==tick,'wrong receipt'),
                    compare=lambda receipts,h,t:{'tick':t,'parity_established':False})
                fake_stage=types.SimpleNamespace(adapt=lambda *args:calls.append(('adapt',)))
                shared=types.SimpleNamespace(HERE=HERE,ROOT=root,load_module=lambda name,_path:{'cardinal_stage':fake_stage,
                    'cardinal_contract':fake_contract,'random_contract':object()}[name],require=require,
                    checkpoint=lambda *args,**kwargs:None,run_owned_phase=compile_phase,
                    prepare_linked_runtime=linked,run_checked_runtime=daemon,file_hash=lambda p:'b'*64)
                npc=types.SimpleNamespace(prepare=prepare,current=object())
                runtime=types.SimpleNamespace(verify_linux=lambda *_:None)
                legacy=types.SimpleNamespace(validate_compile=lambda *_:None,inspect_logs=lambda *_:None)
                args=types.SimpleNamespace(suite=suite,head=head,work_deadline=time.monotonic()+400)
                with patch.object(worker.os.path,'samefile',return_value=False):
                    worker.run(shared,args,root,root,root,None,{}, {}, {},time.monotonic(),npc,runtime,legacy)
                self.assertEqual([x[:2] for x in calls],[('source',),('adapt',),('compile',90),('daemon','legacy'),('daemon','smooth')])
                self.assertTrue(all(item[2]==60 for item in calls if item[0]=='daemon'))
                for item in calls:
                    if item[0]=='daemon': self.assertIn('cardinal_tick='+str(tick),item[3])
                summary=json.loads((root/'smoke-summary.json').read_text())
                self.assertFalse(summary['parity_established']);self.assertEqual(summary['tick'],tick)

    def test_insufficient_work_budget_prevents_staging(self):
        shared=types.SimpleNamespace(HERE=HERE,load_module=lambda name,_path:{'cardinal_stage':object(),
              'cardinal_contract':types.SimpleNamespace(),'random_contract':object()}[name],
              require=lambda ok,msg:None if ok else (_ for _ in ()).throw(RuntimeError(msg)))
        args=types.SimpleNamespace(suite='cardinal05',work_deadline=time.monotonic()+1)
        with self.assertRaisesRegex(RuntimeError,'Insufficient cardinal'):
            worker.run(shared,args,None,None,None,None,None,None,None,None,None,None,None)


if __name__=='__main__': unittest.main()

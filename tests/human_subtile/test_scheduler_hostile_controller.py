"""Offline checks for the single-case selector and existing archive boundary."""
import hashlib
import importlib.util
import io
from pathlib import Path
import tarfile
import unittest
from types import SimpleNamespace
from unittest.mock import patch

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
def module(name):
    spec=importlib.util.spec_from_file_location(name,HERE/(name+'.py'))
    value=importlib.util.module_from_spec(spec);spec.loader.exec_module(value);return value
controller=module('cloud_npc_controller')


def archive(names):
    buf=io.BytesIO()
    with tarfile.open(fileobj=buf,mode='w') as t:
        for name in names:
            raw=b'{}';info=tarfile.TarInfo(name);info.size=len(raw);t.addfile(info,io.BytesIO(raw))
    data=buf.getvalue()
    return data,{'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()}


def allowed():
    result={'harness-status.json','smoke-summary.json','npc-smoke/cloud-manifest.json',
            'npc-smoke/stage/compile-stdout.log','npc-smoke/stage/compile-stderr.log'}
    result.update('npc-smoke/runtime/'+x for x in ('receipt.json','result.txt','port-closed.txt',
                  'runtime.log','daemon-stdout.log','daemon-stderr.log'))
    result.update(f'abi/abi-{i}-{part}.log' for i in range(6) for part in ('stdout','stderr'))
    return sorted(result)


class HostileController(unittest.TestCase):
    def test_one_runtime_exact_archive_and_rejections(self):
        names=allowed();self.assertEqual(len(names),23)
        data,meta=archive(names);self.assertEqual(controller.validate_package(data,meta,'hostile05'),data)
        for bad in (names+['npc-smoke/runtime-wildlife/receipt.json'],
                    names+['../../outside'],names+[names[0]]):
            data,meta=archive(bad)
            with self.subTest(bad=bad[-1]),self.assertRaises(RuntimeError):
                controller.validate_package(data,meta,'hostile05')

    def test_selector_and_bounds_remain_explicit(self):
        workflow=(ROOT/'.github/workflows/wildlife-cardinal-cadence.yml').read_text()
        for token in ('options: [hostile]','suite: [hostile05]',
                      'test "$EXPERIMENT" = hostile','test "$WILDLIFE_SUITE" = hostile05',
                      'timeout-minutes: 12', 'civ13-wildlife-random-cadence-exclusive',
                      'test_scheduler_hostile_controller.py'):
            self.assertIn(token,workflow)
        args=controller.create_args('n','a'*32,'b'*40,'/s','/b','/a','1000:1000','hostile05',10.0)
        for token in ('none','3g','64','2','/work:rw,noexec,nosuid,nodev,size=1073741824,mode=1777',
                      'hostile05','--work-deadline'):
            self.assertIn(token,args)
        with self.assertRaises(RuntimeError):
            controller.create_args('n','a'*32,'b'*40,'/s','/b','/a','1000:1000','hostile05',None)

    def test_exact_source_guard_rejects_changed_and_extra_inputs(self):
        binding=module('scheduler_hostile_binding')
        head='b'*40
        state={'bad_pin':False,'extra':False,'base':True,'ancestor':True}
        def output(command, **kwargs):
            if command[1:3]==['rev-parse',binding.BASE_COMMIT+'^{tree}']:
                return (binding.BASE_TREE if state['base'] else '0'*40).encode()
            if len(command)>2 and command[1]=='rev-parse' and command[2].startswith(head+':'):
                path=command[2].split(':',1)[1]
                expected={**binding.PINNED,**binding.SOURCE_PINS}[path]
                return ('0'*40 if state['bad_pin'] else expected).encode()
            if len(command)>1 and command[1]=='diff':
                paths=sorted(binding.ALLOWED_DELTA)
                if state['extra']:paths.append('code/unreviewed.dm')
                return ('\0'.join(paths)+'\0').encode()
            raise AssertionError(command)
        def run(command, **kwargs):
            return SimpleNamespace(returncode=0 if state['ancestor'] else 1)
        with patch.object(binding.subprocess,'check_output',side_effect=output),patch.object(binding.subprocess,'run',side_effect=run):
            self.assertTrue(binding.validate_source(['git'],None,head))
            for key,value in (('bad_pin',True),('extra',True),('base',False),('ancestor',False)):
                old=state[key];state[key]=value
                with self.subTest(key=key),self.assertRaises(ValueError):
                    binding.validate_source(['git'],None,head)
                state[key]=old

    def test_worker_one_daemon_and_host_guard(self):
        worker=(HERE/'scheduler_hostile_worker.py').read_text()
        self.assertEqual(worker.count('shared.run_checked_runtime('),1)
        self.assertIn('compile_limit, daemon_limit, setup_limit, work_limit = 120, 90, 60, 490',worker)
        self.assertIn('binding.validate_source(',worker)
        self.assertIn('contract.validate_receipt(',worker)
        evidence=(HERE/'scheduler_hostile_evidence.py').read_text()
        self.assertIn("binding.validate_source(",evidence)
        self.assertIn('len(allowed) == 23',evidence)
        self.assertIn('set(names) == allowed',evidence)
        self.assertIn('contract.validate_receipt(',evidence)
        self.assertIn('stage.adapted_probe(',evidence)
        self.assertIn('stage.adapted_dme(',evidence)
        self.assertIn('expected[stage.FIXTURE] = source(stage.FIXTURE)',evidence)
        self.assertIn('for path in (*binding.PINNED, stage.FIXTURE):',evidence)


if __name__=='__main__':unittest.main()
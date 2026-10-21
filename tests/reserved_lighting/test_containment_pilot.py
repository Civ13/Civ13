"""Pure/injected controls only: never invoke Docker, forks, sockets or memory probes."""
import copy
import errno
import io
import json
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

import containment_pilot as p

HEAD='a'*40
CID='b'*64


def info(script, name='owned', owner='owner', running=True):
    return {'Id':CID,'Name':'/'+name,'Image':p.IMAGE_ID,
            'Config':{'Image':p.IMAGE,'Labels':{'scope':p.SCOPE,'owner':owner,'head':HEAD},
                      'User':'65534:65534','Entrypoint':['/usr/local/bin/python3']},
            'HostConfig':{'Memory':p.MEMORY,'MemorySwap':p.MEMORY,'PidsLimit':p.PIDS,'NanoCpus':250000000,
                          'NetworkMode':'none','ReadonlyRootfs':True,'Privileged':False,'CgroupnsMode':'private',
                          'IpcMode':'private','PidMode':'','CapDrop':['ALL'],'SecurityOpt':['no-new-privileges'],
                          'PortBindings':{},'Devices':[],'Binds':[],
                          'Tmpfs':{'/work':f'rw,noexec,nosuid,nodev,size={p.SCRATCH},mode=1777'},'ShmSize':1048576},
            'Mounts':[{'Type':'bind','Source':str(script),'Destination':'/pilot.py','RW':False}],
            'State':{'Running':running,'Pid':123 if running else 0,'OOMKilled':False}}


class FakeDocker:
    def __init__(self, output=None):
        self.calls=[];self.value=None

    def call(self,args,**kwargs):
        self.calls.append(args)
        if args[0]=='pull':return 0,'pulled',''
        if args[:2]==['image','inspect']:
            return 0,json.dumps([{'Id':p.IMAGE_ID,'Os':'linux','Architecture':'amd64','RepoDigests':[p.IMAGE]}]),''
        if args[0]=='create':
            name=args[args.index('--name')+1]
            owner=next(x.split('=',1)[1] for x in args if x.startswith('owner='))
            mount=args[args.index('--mount')+1]
            script=mount.split('src=',1)[1].split(',dst=',1)[0]
            self.value=info(script,name,owner,running=False)
            raise ValueError('Injected uncertain create completion')
        if args[0]=='inspect':return 0,json.dumps([self.value]),''
        if args[0]=='kill':self.value['State'].update(Running=False,Pid=0);return 0,CID,''
        if args[0]=='wait':return 0,'137',''
        if args[0]=='rm':return 0,CID,''
        if args[:2]==['container','ls']:return 0,'',''
        raise AssertionError(args)


class Pilot(unittest.TestCase):
    def test_docker_failure_retains_bounded_stderr_and_optional_behavior(self):
        payload=b'discard-this-prefix'+b'x'*600+b'failure-cause'
        def child(*args,**kwargs):
            kwargs['stderr'].write(payload)
            kwargs['stderr'].flush()
            return SimpleNamespace(returncode=17,poll=lambda:17)
        with tempfile.TemporaryDirectory() as temporary, patch.object(p.subprocess,'Popen',side_effect=child):
            docker=p.Docker(Path(temporary))
            with self.assertRaises(ValueError) as caught:docker.call(['create'])
            message=str(caught.exception)
            self.assertIn('rc=17',message);self.assertIn('failure-cause',message)
            self.assertNotIn('discard-this-prefix',message);self.assertLess(len(message),600)
            self.assertEqual(docker.call(['inspect'],optional=True)[0],17)

    def test_missing_create_reconciliation_preserves_original_error_and_incomplete_cleanup(self):
        class Missing(FakeDocker):
            def call(self,args,**kwargs):
                if args[0]=='inspect':
                    self.calls.append(args)
                    return 1,'','No such container'
                return super().call(args,**kwargs)
        fake=Missing()
        with tempfile.TemporaryDirectory() as temporary:
            target=Path(temporary)/'receipt'
            with patch.object(p,'hosted_guard'),patch.dict(p.os.environ,{'RUNNER_TEMP':temporary}), \
                 patch.object(p.subprocess,'check_output',side_effect=[HEAD,'']),patch.object(p,'Docker',return_value=fake):
                with self.assertRaisesRegex(ValueError,'Injected uncertain create completion'):p.execute(HEAD,target)
            report=json.loads((target/'pilot.json').read_text())
        self.assertIn('Injected uncertain create completion',report['error'])
        self.assertFalse(report['complete']);self.assertFalse(report['runs'][0]['cleanup']['all_exited'])
        self.assertNotIn('start',[call[0] for call in fake.calls])
        self.assertNotIn('kill',[call[0] for call in fake.calls])
        self.assertNotIn('rm',[call[0] for call in fake.calls])
        self.assertEqual(sum(call[0]=='create' for call in fake.calls),1)

    def test_default_is_inert_and_manual_host_identity_fails_closed(self):
        with patch.object(p.subprocess,'Popen',side_effect=AssertionError('No subprocess')), \
             patch.object(p.sys,'argv',['pilot']),patch('sys.stdout',new_callable=io.StringIO) as output:
            p.main()
        self.assertFalse(json.loads(output.getvalue())['default'].startswith('ON'))
        env={'GITHUB_ACTIONS':'true','RUNNER_ENVIRONMENT':'github-hosted','RUNNER_OS':'Linux','RUNNER_ARCH':'X64',
             'GITHUB_REPOSITORY':'Civ13/Civ13','GITHUB_REPOSITORY_ID':'141349998','GITHUB_EVENT_NAME':'workflow_dispatch',
             'CIV13_REPOSITORY_VISIBILITY':'public','CIV13_CONTAINMENT_CONFIRMED':'true','GITHUB_SHA':HEAD}
        p.hosted_guard(env,HEAD,platform='linux')
        for key,value in (('RUNNER_ENVIRONMENT','self-hosted'),('CIV13_REPOSITORY_VISIBILITY','private'),
                          ('CIV13_CONTAINMENT_CONFIRMED','false'),('GITHUB_EVENT_NAME','pull_request'),('GITHUB_SHA','c'*40)):
            bad=dict(env);bad[key]=value
            with self.subTest(key=key),self.assertRaises(ValueError):p.hosted_guard(bad,HEAD,platform='linux')
        with self.assertRaises(ValueError):p.hosted_guard(env,HEAD,platform='win32')

    def test_container_contract_and_readback_drift(self):
        script=Path('public-pilot.py').resolve()
        args=p.container_args('owned','owner',HEAD,script,'guard',Path('owned.cid'))
        self.assertIn('--read-only',args)
        self.assertEqual(args[args.index('--network')+1],'none')
        self.assertEqual(args[args.index('--memory')+1],str(p.MEMORY))
        self.assertEqual(args[args.index('--memory-swap')+1],str(p.MEMORY))
        self.assertNotIn('--privileged',args);self.assertNotIn('--publish',args)
        baseline=info(script)
        p.owned(baseline,CID,'owned','owner',HEAD);p.inspect_settings(baseline,script)
        for key,value in (('Memory',0),('MemorySwap',-1),('NetworkMode','host'),('Privileged',True),
                          ('ReadonlyRootfs',False),('PidsLimit',0),('CgroupnsMode','host'),('Tmpfs',{})):
            bad=copy.deepcopy(baseline);bad['HostConfig'][key]=value
            with self.subTest(key=key),self.assertRaises(ValueError):p.inspect_settings(bad,script)
        bad=copy.deepcopy(baseline);bad['Mounts'][0]['RW']=True
        with self.assertRaises(ValueError):p.inspect_settings(bad,script)
        bad=copy.deepcopy(baseline);bad['Mounts'].append({'Source':'/var/run/docker.sock'})
        with self.assertRaises(ValueError):p.inspect_settings(bad,script)

    def test_causal_control_evidence_rejects_pass_without_actual_limits(self):
        counters={'memory.max':str(p.MEMORY),'memory.swap.max':'0','pids.max':str(p.PIDS),'cpu.max':'25000 100000'}
        examples={'guard':{'egress_errno':errno.ENETUNREACH,'readonly_errno':errno.EROFS,'scratch_positive':True},
                  'output':{'errno':errno.ENOSPC,'written':p.SCRATCH},
                  'pids':{'errno':errno.EAGAIN,'children':p.PIDS-1,'events_before':0,'events_after':1,'all_reaped':True}}
        for case,observations in examples.items():
            result={'case':case,'passed':True,'enforced':counters,'observations':observations}
            p.validate_result(case,result)
            bad=copy.deepcopy(result);bad['enforced']['memory.swap.max']='max'
            with self.subTest(case=case),self.assertRaises(ValueError):p.validate_result(case,bad)
            bad=copy.deepcopy(result)
            if case=='guard':bad['observations']['scratch_positive']=False
            elif case=='output':bad['observations']['errno']=errno.EACCES
            else:bad['observations']['events_after']=0
            with self.subTest(case=case),self.assertRaises(ValueError):p.validate_result(case,bad)

    def test_cleanup_uses_only_owned_id_and_never_signals_changed_owner(self):
        fake=FakeDocker();fake.value=info(Path('pilot'))
        result=p.retire(fake,CID,'owned','owner',HEAD,{})
        self.assertTrue(result['all_exited'] and result['owned_container_absent'])
        self.assertIn(['kill',CID],fake.calls);self.assertIn(['rm',CID],fake.calls)
        fake=FakeDocker();fake.value=info(Path('pilot'));fake.value['Config']['Labels']['owner']='different'
        with self.assertRaisesRegex(ValueError,'ownership'):p.retire(fake,CID,'owned','owner',HEAD,{})
        self.assertEqual([call[0] for call in fake.calls],['inspect'])

    def test_descendant_and_cgroup_retirement_identity_checks(self):
        row={'pid':123,'start_ticks':100}
        with patch.object(p,'proc_identity',return_value=row):
            with self.assertRaisesRegex(ValueError,'descendant'):p.validate_retirement({'processes':[row]})
        with patch.object(p,'proc_identity',return_value={'pid':123,'start_ticks':101}):
            p.validate_retirement({'processes':[row]})
        with tempfile.TemporaryDirectory() as temporary:
            group=Path(temporary);(group/'cgroup.procs').write_text('123\n')
            proof={'cgroup':str(group),'cgroup_inode':group.stat().st_ino}
            with self.assertRaises(ValueError):p.validate_retirement(proof)
            (group/'cgroup.procs').write_text('');p.validate_retirement(proof)
            proof['cgroup_inode']+=1
            with self.assertRaises(ValueError):p.validate_retirement(proof)

    def test_uncertain_create_is_reconciled_and_cleaned_without_start_or_retry(self):
        fake=FakeDocker()
        with tempfile.TemporaryDirectory() as temporary:
            target=Path(temporary)/'receipt'
            with patch.object(p,'hosted_guard'),patch.dict(p.os.environ,{'RUNNER_TEMP':temporary}), \
                 patch.object(p.subprocess,'check_output',side_effect=[HEAD,'']),patch.object(p,'Docker',return_value=fake):
                with self.assertRaisesRegex(ValueError,'uncertain create'):p.execute(HEAD,target)
            report=json.loads((target/'pilot.json').read_text())
        self.assertFalse(report['complete'])
        self.assertTrue(report['runs'][0]['cleanup']['all_exited'])
        self.assertEqual(sum(call[0]=='create' for call in fake.calls),1)
        self.assertNotIn('start',[call[0] for call in fake.calls])


if __name__=='__main__':unittest.main()

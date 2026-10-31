"""Injected controller tests. No Docker, native process or network is launched."""
import hashlib
import importlib.util
import io
import contextlib
import json
import os
from pathlib import Path
import tarfile
import tempfile
import time
import unittest
from unittest.mock import patch

HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('wildlife_controller',HERE/'cloud_npc_controller.py')
controller=importlib.util.module_from_spec(spec);spec.loader.exec_module(controller)
spec2=importlib.util.spec_from_file_location('wildlife_smoke',HERE/'cloud_npc_smoke.py')
smoke=importlib.util.module_from_spec(spec2);spec2.loader.exec_module(smoke)

CID='a'*64
OWNER='b'*32
HEAD='c'*40
NAME='civ13-wildlife-'+OWNER


def info(running=True):
    return {'Id':CID,'Name':'/'+NAME,'Config':{'Labels':{'scope':controller.SCOPE,'owner':OWNER,'head':HEAD}},
            'State':{'Status':'running' if running else 'exited','Running':running,'Pid':321 if running else 0,
                     'ExitCode':137 if not running else 0,'OOMKilled':False,'Error':''}}


class FakeDocker:
    def __init__(self, initial=None, stuck=False):
        self.state=initial or info(); self.calls=[]; self.stuck=stuck; self.end=time.monotonic()+60
    def call(self,args,timeout=10,maximum=None,optional=False):
        self.calls.append(args)
        if args[0]=='inspect':
            return (1,b'',b'not found') if self.state is None else (0,json.dumps([self.state]).encode(),b'')
        if args[0]=='kill':
            if not self.stuck: self.state=info(False)
        elif args[0]=='rm': self.state=None
        elif args[:2]==['container','ls']:
            return 0,(CID.encode() if self.state else b''),b''
        return 0,b'',b''


def tar_bytes(entries):
    out=io.BytesIO()
    with tarfile.open(fileobj=out,mode='w') as tar:
        for name,data,kind in entries:
            row=tarfile.TarInfo(name); row.type=kind; row.size=len(data) if kind==tarfile.REGTYPE else 0
            tar.addfile(row,io.BytesIO(data) if row.isfile() else None)
    return out.getvalue()


class ControllerContracts(unittest.TestCase):
    def test_log_transport_survives_exit_and_rejects_corruption_or_missing_parts(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp); (root/'harness-status.json').write_text('{"phase":"fixture-compile"}')
            out=io.StringIO()
            with contextlib.redirect_stdout(out): smoke.emit_package(root,'failed',{'samples':1})
            log=out.getvalue().encode(); lines=log.splitlines()
            marker=json.loads(lines[-1].split(b' ',1)[1])
            self.assertTrue(marker['package']['complete'])
            data=controller.package_from_logs(log,marker)
            with tarfile.open(fileobj=io.BytesIO(data)) as archive:
                self.assertEqual(json.load(archive.extractfile('harness-status.json'))['phase'],'fixture-compile')
            for bad in (b'\n'.join(lines[1:]), b'\n'.join([lines[0],*lines]),
                        log.replace(b'HARNESS_EVIDENCE_PART 1/',b'HARNESS_EVIDENCE_PART 2/',1)):
                with self.subTest(bad=bad[:40]), self.assertRaises((RuntimeError, ValueError)):
                    controller.package_from_logs(bad,marker)
            wrong=dict(marker, package=dict(marker['package'],sha256='0'*64))
            with self.assertRaises(RuntimeError): controller.package_from_logs(log,wrong)

    def test_large_incompressible_failure_keeps_status_and_marks_partial(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp); (root/'harness-status.json').write_text('{"phase":"fixture-compile","outcome":"failed"}')
            path=root/'npc-smoke/stage/compile-stdout.log'; path.parent.mkdir(parents=True)
            path.write_bytes(os.urandom(500000))
            out=io.StringIO()
            with contextlib.redirect_stdout(out): smoke.emit_package(root,'failed',{'samples':1})
            log=out.getvalue().encode(); marker=json.loads(log.splitlines()[-1].split(b' ',1)[1])
            self.assertFalse(marker['package']['complete'])
            data=controller.package_from_logs(log,marker)
            with tarfile.open(fileobj=io.BytesIO(data)) as archive:
                self.assertEqual(json.load(archive.extractfile('harness-status.json'))['outcome'],'failed')
                self.assertEqual(archive.getmember('npc-smoke/stage/compile-stdout.log').size,8192)

    def test_checkpoint_is_logged_even_when_no_package_can_be_written(self):
        out=io.StringIO()
        with patch.object(smoke,'RUN_ROOT',None), patch.object(smoke,'RUN_STATE',{'history':[]}), \
             contextlib.redirect_stdout(out):
            smoke.checkpoint('fixture-compile',outcome='failed',error_type='RuntimeError',error_message='compile failed')
        row=json.loads(out.getvalue().split(' ',1)[1])
        self.assertEqual(row,{'phase':'fixture-compile','outcome':'failed',
                              'error_type':'RuntimeError','error_message':'compile failed'})

    def test_controller_does_not_copy_from_tmpfs_or_accept_partial_as_pass(self):
        source=(HERE/'cloud_npc_controller.py').read_text(encoding='utf-8')
        self.assertNotIn("docker.call(['cp'",source)
        self.assertIn("report['outcome'] == 'passed' and package['complete']",source)

    def test_owned_removal_and_verified_absence(self):
        fake=FakeDocker()
        result=controller.retire(fake,CID,NAME,OWNER,HEAD)
        self.assertTrue(result['absent'])
        self.assertEqual([x[0] for x in fake.calls],['inspect','kill','wait','inspect','rm','container'])
        self.assertFalse(result['before']['OOMKilled'])

    def test_mismatched_or_still_running_container_is_never_removed(self):
        bad=info();bad['Config']['Labels']['owner']='other'
        fake=FakeDocker(initial=bad)
        with self.assertRaises(RuntimeError): controller.retire(fake,CID,NAME,OWNER,HEAD)
        self.assertEqual([x[0] for x in fake.calls],['inspect'])
        fake=FakeDocker(stuck=True)
        with self.assertRaises(RuntimeError): controller.retire(fake,CID,NAME,OWNER,HEAD)
        self.assertNotIn('rm',[x[0] for x in fake.calls])

    def test_already_absent_requires_successful_list(self):
        fake=FakeDocker();fake.state=None
        self.assertTrue(controller.retire(fake,CID,NAME,OWNER,HEAD)['already_absent'])
        self.assertEqual([x[0] for x in fake.calls],['inspect','container'])

    def test_evidence_exact_hash_and_allowlist(self):
        data=tar_bytes([('harness-status.json',b'{}',tarfile.REGTYPE)])
        expected={'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()}
        self.assertEqual(controller.validate_package(data,expected),data)
        with self.assertRaises(RuntimeError): controller.validate_package(data,dict(expected,sha256='0'*64))
        bad=tar_bytes([('harness-status.json',b'{}',tarfile.REGTYPE),('stolen.txt',b'x',tarfile.REGTYPE)])
        with self.assertRaises(RuntimeError): controller.validate_package(bad,{'bytes':len(bad),'sha256':hashlib.sha256(bad).hexdigest()})
        symlink=tar_bytes([('harness-status.json',b'',tarfile.SYMTYPE)])
        with self.assertRaises(RuntimeError): controller.validate_package(symlink,{'bytes':len(symlink),'sha256':hashlib.sha256(symlink).hexdigest()})

    def test_only_restricted_direct_container_arguments(self):
        args=controller.create_args(NAME,OWNER,HEAD,Path('/reviewed'),Path('/bin-by'),Path('/by.zip'),'1001:1001')
        for pair in (('--network','none'),('--read-only','--user'),('--cap-drop','ALL'),('--pids-limit','64'),('--memory','3g'),('--memory-swap','3g'),('--cpus','2'),('--platform','linux/386')):
            self.assertIn(pair[0],args)
            if pair[0] != '--read-only': self.assertEqual(args[args.index(pair[0])+1],pair[1])
        self.assertNotIn('--privileged',args)
        self.assertNotIn('host',args)
        self.assertNotIn('exec',args)
        self.assertEqual(args.count('--mount'),3)

    def test_watchdog_reconciles_fresh_name_and_removes_owned_container(self):
        fake=FakeDocker()
        captured=[]
        with patch.object(controller.time,'sleep'), patch.object(controller,'save',side_effect=lambda path,row: captured.append(row)), \
             patch.object(controller,'save_container_logs',return_value={'bytes':0,'truncated':False}), \
             contextlib.redirect_stdout(io.StringIO()):
            controller.watchdog(fake,None,NAME,OWNER,HEAD,0,Path('unused'))
        self.assertTrue(captured[0]['cleanup']['absent'])
        self.assertEqual(captured[0]['cid'],CID)
        self.assertEqual([x[0] for x in fake.calls],['inspect','inspect','kill','wait','inspect','rm','container'])

    def test_diagnostics_never_precede_owned_stop_and_skip_when_time_is_short(self):
        fake=FakeDocker(); calls=[]
        with patch.object(controller,'save_container_logs',side_effect=lambda *a,**kw: calls.append(list(fake.calls))):
            controller.retire(fake,CID,NAME,OWNER,HEAD,log_path=Path('unused'))
        self.assertEqual([x[0] for x in calls[0]],['inspect','kill','wait','inspect'])
        fake=FakeDocker();fake.end=time.monotonic()+11
        with patch.object(controller,'save_container_logs') as logs:
            controller.retire(fake,CID,NAME,OWNER,HEAD,log_path=Path('unused'))
            logs.assert_not_called()

    def test_marker_alone_cannot_validate_missing_receipts(self):
        data=tar_bytes([('harness-status.json',b'{}',tarfile.REGTYPE)])
        with self.assertRaises((RuntimeError,KeyError)):
            controller.validate_pass_evidence(data,HEAD)

    def test_container_settings_reject_network_credentials_and_extra_mounts(self):
        image='sha256:'+'d'*64
        mounts=((Path('/reviewed'),'/source'),(Path('/bin-by'),'/opt/byond/bin'),(Path('/by.zip'),'/inputs/byond.zip'))
        cmd=['-I','-B','/source/tests/human_subtile/cloud_npc_smoke.py','--head',HEAD,
             '--byond-bin','/opt/byond/bin','--byond-archive','/inputs/byond.zip',
             '--scratch-root','/work','--reviewed-cloud-envelope']
        row={'Image':image,'Config':{'Image':controller.IMAGE,'User':'1001:1001',
             'Entrypoint':['/usr/local/bin/python3.12'],'Cmd':cmd,'Env':['LANG=C.UTF-8']},
             'HostConfig':{'Memory':3*1024**3,'MemorySwap':3*1024**3,'PidsLimit':64,'NanoCpus':2000000000,
             'NetworkMode':'none','ReadonlyRootfs':True,'Privileged':False,'CgroupnsMode':'private',
             'IpcMode':'private','PidMode':'','CapDrop':['ALL'],'SecurityOpt':['no-new-privileges'],
             'PortBindings':None,'Devices':None,'Binds':None,
             'Tmpfs':{'/work':'rw,noexec,nosuid,nodev,size=1073741824,mode=1777'},'ShmSize':1048576,
             'LogConfig':{'Type':'local','Config':{'max-size':'1m','max-file':'1','compress':'false'}}},
             'Mounts':[{'Source':str(src),'Destination':dest,'RW':False,'Type':'bind'} for src,dest in mounts]}
        controller.inspect_settings(row,image,mounts,'1001:1001',HEAD)
        row['HostConfig']['NetworkMode']='host'
        with self.assertRaises(RuntimeError): controller.inspect_settings(row,image,mounts,'1001:1001',HEAD)
        row['HostConfig']['NetworkMode']='none'; row['Config']['Env'].append('GITHUB_TOKEN=hidden')
        with self.assertRaises(RuntimeError): controller.inspect_settings(row,image,mounts,'1001:1001',HEAD)
        row['Config']['Env'].pop(); row['Mounts'].append({'Source':'/var/run/docker.sock','Destination':'/sock','RW':True,'Type':'bind'})
        with self.assertRaises(RuntimeError): controller.inspect_settings(row,image,mounts,'1001:1001',HEAD)


if __name__=='__main__': unittest.main()

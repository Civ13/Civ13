"""Synthetic Docker contract tests. No Docker command, process or network."""
from pathlib import Path
import copy
import importlib.util
import unittest
ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('sleep_outer_contract',ROOT/'outer_container_contract.py')
c=importlib.util.module_from_spec(spec);spec.loader.exec_module(c)

def fixture():
    image=c.IMAGE_ID; token='b'*32
    s=c.command(image,token,1001,1001,'/tmp/fixture/source','/tmp/fixture/runtime','/tmp/fixture/tmp')
    i={'Id':'c'*64,'Name':'/'+s['name'],'Image':image,'State':{'Status':'created','Running':False},
       'Config':{'Labels':{c.LABEL:token},'User':s['user'],'Entrypoint':['/usr/local/bin/python3.12'],'Cmd':s['entry'],'Env':['PATH=/usr/bin:/bin','LANG=C','LC_ALL=C'],'Healthcheck':{'Test':['NONE']}},
       'HostConfig':{'NetworkMode':'none','Privileged':False,'ReadonlyRootfs':True,'PortBindings':{},'PublishAllPorts':False,'Links':None,
          'CapDrop':['ALL'],'CapAdd':None,'SecurityOpt':['no-new-privileges'],'PidsLimit':32,'Memory':c.MEMORY,'MemorySwap':c.MEMORY,'NanoCpus':c.NANOCPUS,
          'PidMode':'','IpcMode':'private','Devices':None,'DeviceRequests':None},
       'NetworkSettings':{'Networks':{'none':{'IPAddress':'','GlobalIPv6Address':''}}},
       'Mounts':[{'Type':'bind','Destination':d,'Source':src,'RW':rw} for d,(src,rw) in s['mounts'].items()]}
    return s,i
class Tests(unittest.TestCase):
    def test_image_and_command_pins(self):
        s,i=fixture();self.assertTrue(c.validate_image({'Id':s['image'],'Os':'linux','Architecture':'386','Config':{'Volumes':None,'Env':['PATH=/usr/bin']}},s['image']))
        self.assertIn('--pull=never',s['argv']);self.assertIn('--no-healthcheck',s['argv']);self.assertIn('none',s['argv'])
        self.assertIn('linux/386',s['argv']); self.assertIn('/usr/local/bin/python3.12',s['argv'])
        with self.assertRaises(ValueError):c.validate_image({'Id':s['image'],'Os':'linux','Architecture':'amd64','Config':{'Volumes':None}},s['image'])
        with self.assertRaises(ValueError):c.command('sha256:'+'a'*64,'b'*32,1001,1001,'/tmp/a','/tmp/b','/tmp/c')
        with self.assertRaises(ValueError):c.command('ubuntu:latest','b'*32,1001,1001,'/tmp/a','/tmp/b','/tmp/c')
        with self.assertRaises(ValueError):c.command(s['image'],'b'*32,0,1001,'/tmp/a','/tmp/b','/tmp/c')
        with self.assertRaises(ValueError):c.validate_image({'Id':s['image'],'Os':'linux','Architecture':'386','Config':{'Volumes':{'/data':{}}}},s['image'])
    def test_exit_requires_exact_clean_status(self):
        s,original=fixture()
        original['State']={'Status':'exited','Running':False,'ExitCode':0,'OOMKilled':False,'Error':''}
        self.assertTrue(c.validate_inspect(original,s,'c'*64,expected_state='exited'))
        for key,value in [('ExitCode',1),('ExitCode',False),('OOMKilled',True),('Error','daemon error')]:
            i=copy.deepcopy(original);i['State'][key]=value
            with self.subTest(key=key,value=value),self.assertRaises(ValueError):c.validate_inspect(i,s,'c'*64,expected_state='exited')
        for key in ('ExitCode','OOMKilled','Error'):
            i=copy.deepcopy(original);del i['State'][key]
            with self.subTest(missing=key),self.assertRaises(ValueError):c.validate_inspect(i,s,'c'*64,expected_state='exited')
    def test_valid_inspect_and_mutated_guards(self):
        s,original=fixture();self.assertTrue(c.validate_inspect(original,s,'c'*64))
        mutations=[('HostConfig','NetworkMode','host'),('HostConfig','Privileged',True),('HostConfig','ReadonlyRootfs',False),
                   ('HostConfig','CapDrop',[]),('HostConfig','PidsLimit',0),('HostConfig','Memory',0),('HostConfig','PidMode','host'),
                   ('Config','User','0:0'),('Config','Entrypoint',['/bin/sh']),('Config','Healthcheck',{'Test':['CMD','bad']})]
        for group,key,value in mutations:
            i=copy.deepcopy(original);i[group][key]=value
            with self.subTest(key=key),self.assertRaises(ValueError):c.validate_inspect(i,s,'c'*64)
        i=copy.deepcopy(original);i['State']={'Status':'running','Running':True}
        with self.assertRaises(ValueError):c.validate_inspect(i,s,'c'*64)
        i=copy.deepcopy(original);i['NetworkSettings']['Networks']['bridge']={}
        with self.assertRaises(ValueError):c.validate_inspect(i,s,'c'*64)
        i=copy.deepcopy(original);i['Mounts'][0]['RW']=True
        with self.assertRaises(ValueError):c.validate_inspect(i,s,'c'*64)
        i=copy.deepcopy(original);i['Config']['Labels'][c.LABEL]='other'
        with self.assertRaises(ValueError):c.validate_inspect(i,s,'c'*64)
        i=copy.deepcopy(original);i['Config']['Env'].append('LD_PRELOAD=/tmp/x')
        with self.assertRaises(ValueError):c.validate_inspect(i,s,'c'*64)
if __name__=='__main__':unittest.main()

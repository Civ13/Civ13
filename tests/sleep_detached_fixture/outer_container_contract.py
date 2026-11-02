"""Pure Docker-create and inspect contract. No process or network is started."""
from pathlib import Path
from datetime import datetime
import re

LABEL='org.civ13.sleep-fixture'
MEMORY=1536*1024**2
PIDS=32
NANOCPUS=1_000_000_000
CONTROLLER_SHA='81c94ce35fd85ac48d2eaaaacf0b0fd9b48f9fd2f64b6a63e1b5f1eda687f5dc'
IMAGE_ID='sha256:4690e6bc50d08b799d527398716478f164832b5a9dddb8eb0588c88ba5cd40bc'

def require(value,message):
    if not value:raise ValueError(message)

def valid_path(value):
    text=str(value)
    return text.startswith('/') and not any(x in text for x in (',','\n','\r','\x00')) and '..' not in Path(text).parts

def command(image,token,uid,gid,source,runtime,tmp):
    require(image==IMAGE_ID,'reviewed image ID required')
    require(re.fullmatch(r'[0-9a-f]{32}',token or '') is not None,'invalid ownership token')
    require(type(uid) is int and type(gid) is int and uid>0 and gid>0,'nonroot numeric identity required')
    require(all(valid_path(p) for p in (source,runtime,tmp)) and len({str(source),str(runtime),str(tmp)})==3,'invalid mount path')
    name='civ13-sleep-'+token
    entry=['-I','/src/controller_linux.py',
           '--run-native','--output','/tmp/sleep-fixture/run','--isolated-root','/tmp/sleep-fixture',
           '--byond-bin','/runtime/bin','--byond-archive','/runtime/archive.zip','--controller-sha256',CONTROLLER_SHA]
    args=['create','--pull=never','--platform','linux/386','--name',name,'--label',LABEL+'='+token,'--network','none',
          '--cap-drop','ALL','--security-opt','no-new-privileges','--read-only','--no-healthcheck','--user',f'{uid}:{gid}',
          '--memory',str(MEMORY),'--memory-swap',str(MEMORY),'--pids-limit',str(PIDS),'--cpus','1',
          '--env','PATH=/usr/bin:/bin','--env','LANG=C','--env','LC_ALL=C',
          '--workdir','/tmp/sleep-fixture','--entrypoint','/usr/local/bin/python3.12',
          '--mount',f'type=bind,src={source},dst=/src,readonly',
          '--mount',f'type=bind,src={runtime},dst=/runtime,readonly',
          '--mount',f'type=bind,src={tmp},dst=/tmp',image,*entry]
    return {'name':name,'token':token,'image':image,'user':f'{uid}:{gid}','entry':entry,
            'mounts':{'/src':(str(source),False),'/runtime':(str(runtime),False),'/tmp':(str(tmp),True)},'argv':args}

def validate_image(info,image):
    require(image==IMAGE_ID and type(info) is dict and info.get('Id')==image and info.get('Os')=='linux' and info.get('Architecture')=='386','image identity or platform')
    cfg=info.get('Config')
    require(type(cfg) is dict and cfg.get('Volumes') in (None,{}),'image declares anonymous volumes')
    env=cfg.get('Env')
    require(type(env) is list and all(isinstance(item,str) and '=' in item and not item.split('=',1)[0].startswith('LD_') for item in env),'unsafe image environment')
    return True

def validate_terminal_state(state,expected_exit_code=0):
    require(type(expected_exit_code) is int and 0<=expected_exit_code<=255,'invalid expected exit code')
    require(type(state) is dict and state.get('Status')=='exited' and state.get('Running') is False and
            type(state.get('ExitCode')) is int and state['ExitCode']==expected_exit_code and
            state.get('OOMKilled') is False and state.get('Error')=='','container terminal status mismatch')
    times=[]
    for key in ('StartedAt','FinishedAt'):
        value=state.get(key)
        require(type(value) is str and re.fullmatch(r'\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,9})?Z',value) is not None,'invalid container timestamp')
        try: parsed=datetime.fromisoformat(value[:-1]+'+00:00')
        except ValueError:raise ValueError('invalid container timestamp') from None
        require(parsed.year>=1970,'container never started')
        times.append(parsed)
    require(times[1]>=times[0],'container finish precedes start')
    return True

def validate_inspect(info,spec,container_id,expected_state="created",expected_exit_code=0):
    require(type(info) is dict and re.fullmatch(r'[0-9a-f]{64}',container_id or '') is not None,'invalid container ID')
    require(info.get('Id')==container_id and info.get('Name')=='/'+spec['name'] and info.get('Image')==spec['image'],'container identity mismatch')
    state=info.get('State')
    require(expected_state in ('created','exited') and type(state) is dict and state.get('Status')==expected_state and state.get('Running') is False,'container state mismatch')
    if expected_state=='exited':
        validate_terminal_state(state,expected_exit_code)
    cfg=info.get('Config');host=info.get('HostConfig');net=info.get('NetworkSettings')
    require(type(cfg) is dict and type(host) is dict and type(net) is dict,'inspect shape')
    require(type(cfg.get('Labels')) is dict and cfg['Labels'].get(LABEL)==spec['token'],'label mismatch')
    require(cfg.get('User')==spec['user'] and cfg.get('Entrypoint')==['/usr/local/bin/python3.12'] and cfg.get('Cmd')==spec['entry'],'entrypoint mismatch')
    env=cfg.get('Env'); require(type(env) is list and all(isinstance(x,str) and '=' in x for x in env),'environment shape')
    pairs=[x.split('=',1) for x in env]; keys=[x[0] for x in pairs]
    require(len(keys)==len(set(keys)) and not any(x.startswith('LD_') for x in keys),'unsafe environment')
    values=dict(pairs); require(values.get('PATH')=='/usr/bin:/bin' and values.get('LANG')=='C' and values.get('LC_ALL')=='C','environment binding')
    require(cfg.get('Healthcheck') in (None,{'Test':['NONE']}),'unexpected healthcheck')
    require(host.get('NetworkMode')=='none' and host.get('Privileged') is False and host.get('ReadonlyRootfs') is True,'network or privilege mismatch')
    require(host.get('PortBindings') in (None,{}) and host.get('PublishAllPorts') is False and host.get('Links') in (None,[]),'published port or host link')
    require(host.get('CapDrop')==['ALL'] and host.get('CapAdd') in (None,[]) and host.get('SecurityOpt') in (['no-new-privileges'],['no-new-privileges:true']),'capability mismatch')
    require(host.get('PidsLimit')==PIDS and host.get('Memory')==MEMORY and host.get('MemorySwap')==MEMORY and host.get('NanoCpus')==NANOCPUS,'resource mismatch')
    require(host.get('PidMode') in ('',None) and host.get('IpcMode') in ('','private',None) and host.get('Devices') in (None,[]) and host.get('DeviceRequests') in (None,[]),'host namespace or device mismatch')
    networks=net.get('Networks')
    require(type(networks) is dict and set(networks)<= {'none'},'unexpected network attachment')
    for endpoint in networks.values():
        require(type(endpoint) is dict and not endpoint.get('IPAddress') and not endpoint.get('GlobalIPv6Address'),'unexpected network address')
    mounts=info.get('Mounts')
    require(type(mounts) is list and len(mounts)==len(spec['mounts']),'mount count')
    seen=set()
    for item in mounts:
        require(type(item) is dict and item.get('Type')=='bind','unexpected mount type')
        dest=item.get('Destination')
        require(dest in spec['mounts'] and dest not in seen,'unexpected mount destination')
        source,rw=spec['mounts'][dest]
        require(item.get('Source')==source and item.get('RW') is rw,'mount binding mismatch')
        seen.add(dest)
    return True

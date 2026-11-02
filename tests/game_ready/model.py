"""Restricted complete-source projections; all clocks, Export and objects are fake."""
import hashlib
import importlib.util
import json
from pathlib import Path
import re
from types import MethodType, SimpleNamespace
from urllib.parse import quote, parse_qs, urlsplit

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT/'code/modules/webhooks/game_ready.dm').read_text(encoding='utf-8-sig')
SPEC = importlib.util.spec_from_file_location('ready_private_adapter', ROOT/'tests/save_movement/source_adapter.py')
A = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(A)
CLASS = SOURCE.split('\n/datum/game_ready_startup\n', 1)[1].split('\n// Same authenticated', 1)[0]
HEADERS = list(re.finditer(r'^\tproc/(\w+)\(([^)]*)\)\n', CLASS, re.M))
METHODS = {}
for index, match in enumerate(HEADERS):
    body = CLASS[match.end():HEADERS[index+1].start() if index+1 < len(HEADERS) else len(CLASS)]
    METHODS[match[1]] = (match[2], '\n'.join(line[1:] if line.startswith('\t') else line for line in body.splitlines()))
DEFAULTS = {}
for name, value in re.findall(r'^\tvar/(?:\w+/)*(\w+)(?: = (.*))?$', CLASS[:HEADERS[0].start()], re.M):
    if value not in ('', 'FALSE', 'TRUE', '0'):
        raise AssertionError('unreviewed default: '+name)
    DEFAULTS[name] = {'':None, 'FALSE':False, 'TRUE':True, '0':0}[value]
TICKET = SOURCE.split('\n/datum/game_ready_load_ticket\n',1)[1].split('\n/datum/game_ready_startup\n',1)[0]
TICKET_DEFAULTS = {name:False if value=='FALSE' else None for name,value in
    re.findall(r'^\tvar/(?:\w+/)*(\w+)(?: = (.*))?$', TICKET, re.M)}
A.FIELDS += tuple(set(DEFAULTS)|set(METHODS))


class DMDict(dict):
    def __missing__(self, key):
        return None


class DMList(list):
    def __getitem__(self, key):
        return super().__getitem__(key-1) if isinstance(key, int) and 1 <= key <= len(self) else None


def assoc(*items):
    return DMDict(zip(items[::2], items[1::2]))


def lexical(body):
    body = re.sub(r'for\(var/i = 1, i <= (length\(value\)|\d+), i\+\+\)',
                  r'for(i in numeric_range(1, \1))', body)
    body = re.sub(r'(?m)^(\t*)catch$', r'\1catch(error)', body)
    body = body.replace('"fresh:[boot]"', '("fresh:" + boot)')
    body = re.sub(r"(?m)^(\s*)var/(?:\w+/)*(\w+)$", r"\1var/\2 = null", body)
    lines = []
    for line in body.splitlines():
        m = re.fullmatch(r'(\s*(?:var/(?:\w+/)*)?\w+ = )(.+) \? (.+) : (.+)', line)
        if m:
            line = m[1]+'('+m[3]+' if '+m[2]+' else '+m[4]+')'
        m = re.fullmatch(r'(\s*)var/list/payload = list\((.*)\)', line)
        if m:
            parts=[]
            for entry in m[2].split(', '):
                key, value = entry.split(' = ',1)
                parts += [key,value]
            line=m[1]+'var/list/payload = assoc('+', '.join(parts)+')'
        lines.append(line)
    body='\n'.join(lines)
    body=re.sub(r'(\d+) SECONDS', r'(\1*10)', body)
    body=re.sub(r'(?m)^(\t+)spawn\(([^)]*)\)\n\1\tattempt\(\)',
                r'\1schedule(src, \2)', body)
    body=body.replace('response = game_ready_export(payload_json)',
                      'response = yield game_ready_export(payload_json)')
    return body


def project(body, args, env, method=False):
    return A.project('/proc/ready_projection()\n'+lexical(body)+'\n',
                     '/proc/ready_projection', args, env, method=method)


def wire_ack(data):
    return hashlib.md5('\n'.join(data[name] for name in
        ('schema','event','server','boot','round','generation_kind','generation')).encode('ascii')).hexdigest()


class Model:
    pass


class Harness:
    def __init__(self, enabled=True):
        self.clock=SimpleNamespace(time=0)
        self.storage=SimpleNamespace(round_restored=False,last_error=None,
                                     dimension_recovery_required=False,dimension_budget_hold=False)
        self.restart=SimpleNamespace(startup_hold=False,busy=False,import_complete=False,
            players_ready=False,expected_generation=None,last_error=None,intent=False)
        self.restart.exists=lambda:self.restart.intent
        self.lifecycle=SimpleNamespace(session='a'*32,busy=False)
        self.lifecycle.boot_session=lambda:self.lifecycle.session
        self.config=SimpleNamespace(webhook_game_ready=enabled,webhook_game_ready_server='nomads',
            webhook_can_fire=True,webhook_address='http://synthetic.invalid/webhook/nomads',
            webhook_key='synthetic-key')
        self.queue=[];self.requests=[];self.pending=[];self.results=[];self.export_error=False
        self.area=object()
        self.env=dict(config=self.config,map_storage=self.storage,persistence_restart=self.restart,ticker=SimpleNamespace(),
            nomads_lifecycle=self.lifecycle,world_z_budget=SimpleNamespace(active=False),world=self.clock,
            game_id='A1b-2_C',persistence_active_operation=None,persistence_save_in_progress=False,
            persistence_load_recovery_required=False,persistence_startup_recovery_status=None,
            persistence_player_restore_ready=False,
            istext=lambda x:isinstance(x,str),length=len,
            islist=lambda x:isinstance(x,(list,dict)),list=lambda *x:DMList(x),assoc=assoc,
            findtextEx=lambda hay,needle:hay.find(needle)+1,
            copytext=lambda x,a,b=None:x[a-1:None if b is None else b-1],
            lowertext=lambda x:x.lower(),numeric_range=lambda a,b:range(a,b+1),
            json_encode=lambda x:json.dumps(x,separators=(',',':'),ensure_ascii=True),
            md5=lambda x:hashlib.md5(x.encode('ascii')).hexdigest(),
            jointext=lambda values,separator:separator.join(values),
            url_encode=lambda x:quote(x,safe=''),schedule=self.schedule,
            new_operation=lambda:SimpleNamespace(**TICKET_DEFAULTS))
        self.clock.Export=self.export
        for name in ('game_ready_identifier','game_ready_hex'):
            body=A.extract(SOURCE,'/proc/'+name)
            parameters='value,maximum' if name.endswith('identifier') else 'value'
            self.env[name]=project(body,parameters,self.env)
        export_body=A.extract(SOURCE,'/proc/game_ready_export')
        query='var/query = "[config.webhook_address]?key=[url_encode(config.webhook_key)]&method=game_ready&data=[url_encode(payload_json)]"'
        assert export_body.count(query)==1
        export_body=export_body.replace(query,
            'var/query = export_url(config.webhook_address, config.webhook_key, payload_json)')
        self.env['export_url']=lambda address,key,data:address+'?key='+quote(key,safe='')+'&method=game_ready&data='+quote(data,safe='')
        self.env['game_ready_export']=project(export_body,'payload_json',self.env)
        self.obj=Model()
        for name,value in DEFAULTS.items():setattr(self.obj,name,value)
        self.env['game_ready_startup']=self.obj
        for name,(parameters,body) in METHODS.items():
            names=[p.strip().split('/')[-1] for p in parameters.split(',') if p.strip()]
            function=project(body,','.join(['src']+names),self.env,method=True)
            setattr(self.obj,name,MethodType(function,self.obj))
        dispatch=A.extract(SOURCE,'/proc/game_ready_startup_event')
        dispatch=dispatch.replace('\tswitch(event)','\tif(TRUE)',1)
        dispatch=re.sub(r'(?m)^\t\tif\("([a-z_]+)"\)',r'\t\tif(event == "\1")',dispatch)
        self.dispatch=project(dispatch,'event,first=None,second=None,third=None,fourth=None,fifth=None,sixth=None',self.env)

    def schedule(self,obj,delay):
        self.queue.append((self.clock.time+delay,obj))

    def export(self,url):
        if self.export_error:raise RuntimeError('injected Export failure')
        request=SimpleNamespace(url=url,data=json.loads(parse_qs(urlsplit(url).query)['data'][0]))
        self.requests.append(request)
        return request

    def start_attempt(self,obj=None):
        generator=(obj or self.obj).attempt()
        try:
            request=next(generator)
        except StopIteration as done:
            self.results.append(done.value);return
        if request is None:
            self.settle(None,generator)
        else:
            self.pending.append((generator,request))

    def settle(self,response=None,generator=None,error=False):
        if generator is None:
            generator,request=self.pending.pop(0)
            if response is None:
                response={'STATUS':'202 Accepted','X-Civ13-Game-Ready':wire_ack(request.data)}
        if isinstance(response, dict):response=DMDict(response)
        elif isinstance(response, list):response=DMList(response)
        try:
            event=generator.throw(RuntimeError('injected request error')) if error else generator.send(response)
        except StopIteration as done:
            self.results.append(done.value);return
        raise AssertionError('unexpected second Export yield: '+repr(event))

    def run_next(self):
        self.queue.sort(key=lambda row:row[0])
        due,obj=self.queue.pop(0);self.clock.time=max(self.clock.time,due)
        self.start_attempt(obj)

    def begin(self):
        self.context=self.dispatch('begin',self.area)
        return self.context

    def initialized(self,success=True):
        return self.dispatch('initialization_complete',self.context,success)

    def fresh(self):
        return self.dispatch('fresh',self.context,self.env['game_id'])

    def reserve(self,restart=False):
        if restart:self.restart.startup_hold=True;self.restart.busy=True;self.restart.intent=True
        return self.dispatch('reserve_restore',self.context,self.restart if restart else None)

    def operation(self):
        op=SimpleNamespace(storage=self.storage,kind='load',restart_transaction=None,mutation_started=False)
        op.current=lambda storage,kind:self.env['persistence_active_operation'] is op and op.storage is storage and op.kind==kind
        self.env['persistence_active_operation']=op
        return op

    def restored(self,ticket,op,restart=False,round_id='saved-round',generation='round-v2:'+'b'*32):
        tx=self.restart if restart else None
        op.restart_transaction=tx
        claimed=self.dispatch('claim_load',ticket,op,self.storage,tx)
        self.env['game_id']=round_id
        self.storage.round_restored=True
        self.env['persistence_player_restore_ready']=True
        op.mutation_started=True
        self.env['persistence_active_operation']=None
        self.dispatch('loaded',claimed,op,self.storage,tx,round_id,generation)
        return claimed

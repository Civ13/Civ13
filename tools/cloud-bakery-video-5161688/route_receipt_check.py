"""Offline validator for a future bounded route receipt; never executes DM."""
import json
import hashlib
import math
from pathlib import Path

REVISION = '58404f5bd16e3fed80f1d9844c5db3edd144942c'
MAP_SHA = '7d67c4bc869859bcfdaf549a7922497517cd573556731d43365570bf85961dd5'
CROP_SHA = '6f361982bb0c8dd5822d0aae840651e7826db69eda91fa63dc12665a134597ae'
ROUTES_SHA = '8319a28af417b2eada9f2b1e23e3f84d50c205a6e719c40cfa29b2ac99503cbf'

def check(receipt, routes):
    def require(condition, reason):
        if not condition:
            raise ValueError(reason)
    require(hashlib.sha256(json.dumps(routes,separators=(',',':')).encode()).hexdigest()==ROUTES_SHA, 'pinned route identity')
    require(type(receipt) is dict and receipt.get('schema') == 1, 'schema')
    require(receipt.get('source_revision') == REVISION and receipt.get('map_sha256') == MAP_SHA and receipt.get('crop_sha256') == CROP_SHA, 'source identity')
    yes=lambda value: value is True or (type(value) is int and value == 1)
    no=lambda value: value is False or (type(value) is int and value == 0)
    require(yes(receipt.get('scripted_actors')) and no(receipt.get('capture_performed')), 'scope')
    courier=receipt.get('courier'); wheat=receipt.get('wheat'); flour=receipt.get('flour'); baker=receipt.get('baker')
    require(all(type(v) is str and 0<len(v)<=128 for v in (courier,wheat,flour,baker)), 'object identities')
    require(courier != baker and wheat != flour, 'actor or transformation identity')
    timeline=receipt.get('events')
    require(type(timeline) is list and 1<=len(timeline)<=256, 'bounded event list')
    times=[]
    for event in timeline:
        require(type(event) is dict and type(event.get('time_ds')) in (int,float) and math.isfinite(event['time_ds']) and event['time_ds']>=0, 'event time')
        times.append(event['time_ds'])
    require(times==sorted(times), 'event ordering')
    required=['harvest','route_to_mill','mill_start','mill_finish','route_to_bakery','flour_handoff']
    require([e.get('phase') for e in timeline] == required, 'phases')
    h,walk1,start,finish,walk2,handoff=timeline
    require(h.get('actor')==courier and h.get('output')==wheat and yes(h.get('ready_harvest')) and yes(h.get('normal_handler')), 'harvest')
    require(start.get('actor')==courier and start.get('input')==wheat and yes(start.get('normal_handler')), 'mill input')
    require(finish.get('input')==wheat and finish.get('output')==flour and yes(finish.get('completed')) and finish['time_ds']-start['time_ds']>=10, 'mill output and timer')
    require(handoff.get('from')==courier and handoff.get('to')==baker and handoff.get('object')==flour and yes(handoff.get('normal_handler')), 'flour handoff')
    for walk,expected,item in ((walk1,routes[0],wheat),(walk2,routes[1],flour)):
        require(walk.get('actor')==courier and walk.get('object')==item, 'route custody')
        steps=walk.get('steps')
        require(type(steps) is list and len(steps)==len(expected), 'route length')
        previous=None
        for row,coord in zip(steps,expected):
            require(type(row) is dict and row.get('xy')==coord and row.get('actor')==courier and row.get('object')==item and yes(row.get('held')), 'route step')
            if coord in ([85,95],[74,147]):
                require(yes(row.get('door_open')), 'door state at crossing')
            t=row.get('time_ds')
            require(type(t) in (int,float) and math.isfinite(t) and t<=walk['time_ds'] and (previous is None or t>previous), 'route step timing')
            previous=t
    require(walk1['steps'][0]['time_ds']>=h['time_ds'] and walk1['steps'][-1]['time_ds']<=start['time_ds'], 'mill route ordering')
    require(walk2['steps'][0]['time_ds']>=finish['time_ds'] and walk2['steps'][-1]['time_ds']<=handoff['time_ds'], 'bakery route ordering')
    return {'valid':True,'scope':'scripted route/production witness contract only; not native acceptance or footage'}

def load_routes(path):
    data=json.loads(Path(path).read_text(encoding='utf-8'))
    if data.get('source_sha256') != MAP_SHA: raise ValueError('route source')
    segments=data.get('segments')
    if type(segments) is not list or len(segments)!=2: raise ValueError('route segments')
    return [s['path'] for s in segments]

"""Small finite authored-chapter topology prototype, not a native generator.

It proves typed socket assembly and monotone abstract progression on an authored
mask raster. It does not model native doors, sound, lighting, enemies or art.
"""
from collections import Counter,deque
from copy import deepcopy
from .catalog import CATALOG,CATALOG_SHA256,HUBS,socket_cells,validate_catalog
from .common import canonical_hash,stable_u64

CONFIG='civ13-liminal-config/1';IR='civ13-liminal-topology/1'
ALGORITHM='liminal-authored-chapter/0.1.0';PROFILE='INDOOR_LIMINAL-offline/1'
CONFIG_KEYS={'schema','profile','seed','catalog_version','catalog_sha256','hub_allowlist','branch_alcove','actor_radius_tiles','min_spawn_exit_tiles','max_rooms','max_blueprint_tiles','max_candidates','max_search_states'}
ZONES={frozenset(p) for p in [('OFFICE','BUFFER'),('BUFFER','UTILITY'),('UTILITY','EGRESS')]}
OPPOSITE={'N':'S','S':'N','E':'W','W':'E'}


class Reject(ValueError):
    def __init__(self,code,detail):self.code=code;self.detail=detail;super().__init__(detail)


def preset(seed='liminal-0'):
    return dict(schema=CONFIG,profile='INDOOR_LIMINAL',seed=seed,catalog_version=CATALOG['version'],catalog_sha256=CATALOG_SHA256,
                hub_allowlist=list(HUBS),branch_alcove=True,actor_radius_tiles=1,min_spawn_exit_tiles=16,
                max_rooms=6,max_blueprint_tiles=4096,max_candidates=3,max_search_states=20000)


def _validate_config(config,catalog=CATALOG):
    def bad(detail):return [dict(code='CONFIG',detail=detail)]
    if type(config) is not dict or set(config)!=CONFIG_KEYS:return bad('exact keys required; no invariant switches')
    c=config
    if c['schema']!=CONFIG or c['profile']!='INDOOR_LIMINAL':return bad('indoor schema/profile only; no terrain fallback')
    if type(c['seed']) is not str or not c['seed'].isascii() or not 1<=len(c['seed'])<=128:return bad('ASCII seed1..128')
    if c['catalog_version']!=catalog.get('version') or c['catalog_sha256']!=canonical_hash(catalog):return bad('catalog version/hash binding')
    if type(c['hub_allowlist']) is not list or not c['hub_allowlist'] or len(c['hub_allowlist'])!=len(set(c['hub_allowlist'])) or any(type(v) is not str or v not in HUBS for v in c['hub_allowlist']):return bad('nonempty unique authored HUB allowlist')
    if type(c['branch_alcove']) is not bool:return bad('branch_alcove must be boolean')
    for key,lo,hi in [('actor_radius_tiles',0,1),('min_spawn_exit_tiles',1,256),('max_rooms',5,8),('max_blueprint_tiles',256,16384),('max_candidates',1,4),('max_search_states',1,100000)]:
        if type(c[key]) is not int or not lo<=c[key]<=hi:return bad(key+' bounds')
    if c['max_rooms']<5+int(c['branch_alcove']):return bad('authored chapter cannot fit max_rooms')
    return []


def validate_config(config,catalog=CATALOG):
    try:return _validate_config(config,catalog)
    except (KeyError,TypeError,ValueError):return [dict(code='CONFIG',detail='malformed typed configuration/catalog')]


def world(room,local):return (room['origin'][0]+local[0],room['origin'][1]+local[1])


def materialize(plan,catalog=CATALOG,*,iteration='forward'):
    """Reconstruct from authored masks; no evaluation of engine code or assets."""
    c=plan['configuration'];rooms={r['id']:r for r in plan['rooms']};definitions=catalog['archetypes']
    width=max(r['origin'][0]+definitions[r['archetype']]['width'] for r in rooms.values())+1
    height=max(r['origin'][1]+definitions[r['archetype']]['height'] for r in rooms.values())+1
    if width*height>c['max_blueprint_tiles']:raise Reject('TILE_BUDGET','finite authored layout exceeds configured tile cap')
    cells={};owner={}
    room_order=sorted(rooms.items(),reverse=iteration=='reverse')
    for rid,r in room_order:
        a=definitions[r['archetype']]
        for y,row in enumerate(a['mask']):
            for x,tile in enumerate(row):
                p=world(r,(x,y))
                if p in cells:raise Reject('ROOM_OVERLAP','room rectangles overlap')
                cells[p]='F' if tile=='.' else 'B' if tile=='X' else 'W';owner[p]=rid
    gates={};used=set();adjacency={rid:set() for rid in rooms}
    for link in (plan['links'] if iteration=='forward' else list(reversed(plan['links']))):
        endpoints=[];specs=[]
        for name in ['a','b']:
            e=link[name];key=(e['room'],e['socket'])
            if key in used:raise Reject('SOCKET_REUSED','each physical socket can have one mate')
            used.add(key);r=rooms[e['room']];a=definitions[r['archetype']]
            if e['socket'] not in a['sockets']:raise Reject('SOCKET_UNKNOWN','socket absent from archetype')
            s=a['sockets'][e['socket']];specs.append(s);endpoints.append([world(r,p) for p in socket_cells(a,e['socket'])])
        a,b=specs
        if link['kind']!='HUMAN_DOOR' or a['kind']!=link['kind'] or b['kind']!=link['kind']:raise Reject('SOCKET_TYPE','prototype accepts paired human door sockets only')
        if OPPOSITE[a['facing']]!=b['facing'] or a['width']!=b['width'] or link['width']!=a['width']:raise Reject('SOCKET_MATE','facing/width mismatch')
        if link['width']<2*c['actor_radius_tiles']+1:raise Reject('DOOR_CLEARANCE','door width below actor footprint')
        for p,q in zip(*endpoints):
            if abs(p[0]-q[0])+abs(p[1]-q[1])!=1:raise Reject('SOCKET_ALIGNMENT','paired socket apertures are not adjacent')
            cells[p]=cells[q]='F';gates[frozenset((p,q))]=frozenset(link['requires_flags'])
        ra,rb=link['a']['room'],link['b']['room'];adjacency[ra].add(rb);adjacency[rb].add(ra)
    sealed=sorted([dict(room=rid,socket=s) for rid,r in rooms.items() for s in definitions[r['archetype']]['sockets'] if (rid,s) not in used],key=lambda e:(e['room'],e['socket']))
    if sealed!=plan['sealed_sockets']:raise Reject('UNSEALED_SOCKET','every unused socket must be explicitly sealed')
    for p,tile in cells.items():
        if tile!='F':continue
        for q in [(p[0]+1,p[1]),(p[0],p[1]+1)]:
            if cells.get(q)=='F' and owner[q]!=owner[p] and frozenset((p,q)) not in gates:raise Reject('UNDECLARED_OPENING','cross-room floor adjacency has no typed link')
    raster=dict(schema='civ13-liminal-blueprint/1',width=width,height=height,row_zero='SOUTH',semantics={'V':'VOID_BLOCKED','W':'WALL_INTENT','B':'SOLID_PROP_INTENT','F':'WALKABLE_FLOOR'},
                rows=[''.join(cells.get((x,y),'V') for x in range(width)) for y in range(height)])
    return raster,cells,owner,gates,adjacency


def _schema(plan,catalog):
    keys={'schema','profile','algorithm_version','profile_version','content_version','catalog_sha256','seed','logical_layer','native_z','configuration','rooms','links','sealed_sockets','spawns','objectives','exits','blueprint'}
    if type(plan) is not dict or set(plan)!=keys:raise Reject('SCHEMA','exact indoor topology keys required')
    if plan['schema']!=IR or plan['profile']!='INDOOR_LIMINAL' or plan['logical_layer']!='INDOOR_0' or plan['native_z'] is not None:raise Reject('SCHEMA','indoor logical layer has no admitted native z mapping')
    if plan['algorithm_version']!=ALGORITHM or plan['profile_version']!=PROFILE or plan['content_version']!=catalog['version'] or plan['catalog_sha256']!=canonical_hash(catalog):raise Reject('VERSION','algorithm/profile/catalog identity mismatch')
    errors=validate_config(plan['configuration'],catalog)
    if errors or plan['seed']!=plan['configuration']['seed']:raise Reject('CONFIG','configuration identity/schema mismatch')
    for name,cap in [('rooms',8),('links',12),('sealed_sockets',32),('spawns',4),('objectives',8),('exits',4)]:
        if type(plan[name]) is not list or not (0 if name=='sealed_sockets' else 1)<=len(plan[name])<=cap:raise Reject('SCHEMA',name+' list bounds')
    if len(plan['rooms'])>plan['configuration']['max_rooms']:raise Reject('ROOM_BUDGET','too many rooms')
    room_ids=set();definitions=catalog['archetypes']
    def pair(v):return type(v) is list and len(v)==2 and all(type(i) is int and 0<=i<256 for i in v)
    def name(v):return type(v) is str and v.isascii() and 1<=len(v)<=64
    for r in plan['rooms']:
        if type(r) is not dict or set(r)!={'id','archetype','origin','rotation','zone'} or not name(r['id']) or r['id'] in room_ids or r['archetype'] not in definitions or not pair(r['origin']) or type(r['rotation']) is not int or r['rotation']!=0:raise Reject('SCHEMA','room identity/placement; prototype rotation must be zero')
        room_ids.add(r['id'])
    ids=set()
    for e in plan['sealed_sockets']:
        if type(e) is not dict or set(e)!={'room','socket'} or e['room'] not in room_ids or not name(e['socket']):raise Reject('SCHEMA','sealed socket')
    for link in plan['links']:
        if type(link) is not dict or set(link)!={'id','a','b','kind','width','requires_flags','native_admission'} or not name(link['id']) or link['id'] in ids or type(link['width']) is not int or not 1<=link['width']<=7 or link['native_admission']!='PENDING':raise Reject('SCHEMA','link keys/id/width/admission')
        ids.add(link['id'])
        for k in ['a','b']:
            e=link[k]
            if type(e) is not dict or set(e)!={'room','socket'} or e['room'] not in room_ids or not name(e['socket']):raise Reject('SCHEMA','link endpoint')
        if link['a']['room']==link['b']['room']:raise Reject('SCHEMA','room cannot link to itself')
    for group,extras in [('spawns',set()),('objectives',{'requires_flags','grants_flag','native_admission'}),('exits',{'requires_flags','native_admission'})]:
        ids=set()
        for marker in plan[group]:
            if type(marker) is not dict or set(marker)!={'id','room','local_at'}|extras or not name(marker['id']) or marker['id'] in ids or marker['room'] not in room_ids or not pair(marker['local_at']):raise Reject('SCHEMA',group+' marker')
            ids.add(marker['id'])
            if extras and marker['native_admission']!='PENDING':raise Reject('SCHEMA','native interaction not admitted')
    flag_sources={o['grants_flag'] for o in plan['objectives'] if type(o.get('grants_flag')) is str}
    if len(flag_sources)!=len(plan['objectives']) or any(not name(f) for f in flag_sources):raise Reject('FLAGS','objective flags must be unique and bounded')
    for obj in plan['links']+plan['objectives']+plan['exits']:
        flags=obj['requires_flags']
        if type(flags) is not list or len(flags)!=len(set(flags)) or any(type(f) is not str or f not in flag_sources for f in flags):raise Reject('FLAGS','missing/duplicate/unknown prerequisite flag')


def validate(plan,catalog=CATALOG):
    """Independent graph, authored raster, footprint and stateful route acceptance."""
    try:
        errors=validate_catalog(catalog)
        if errors:raise Reject('CATALOG',';'.join(errors))
        _schema(plan,catalog);c=plan['configuration'];rooms={r['id']:r for r in plan['rooms']};definitions=catalog['archetypes']
        raster,cells,owner,gates,adjacency=materialize(plan,catalog)
        if raster!=plan['blueprint']:raise Reject('BLUEPRINT','stored blueprint differs from authored room/socket assembly')
        for rid,r in rooms.items():
            if r['zone']!=definitions[r['archetype']]['zone']:raise Reject('ZONE','zone must agree with authored archetype')
            for other in adjacency[rid]:
                if r['zone']!=rooms[other]['zone'] and frozenset((r['zone'],rooms[other]['zone'])) not in ZONES:raise Reject('ZONE_ADJACENCY','unbuffered zone transition')
        roles=Counter(definitions[r['archetype']]['role'] for r in rooms.values())
        expected=Counter({'ARRIVAL':1,'HUB':1,'TRANSITION':1,'SERVICE':1,'EXIT':1})
        if c['branch_alcove']:expected['ALCOVE']=1
        if roles!=expected:raise Reject('ROOM_PROGRAM','prototype requires exact authored chapter roles, not arbitrary corridor nodes')
        reached=set();todo=[plan['spawns'][0]['room']]
        while todo:
            rid=todo.pop()
            if rid not in reached:reached.add(rid);todo.extend(adjacency[rid]-reached)
        if reached!=set(rooms):raise Reject('ROOM_GRAPH','all room instances must be structurally connected')
        radius=c['actor_radius_tiles'];floor={p for p,t in cells.items() if t=='F'}
        nav={p for p in floor if all((p[0]+dx,p[1]+dy) in floor for dx in range(-radius,radius+1) for dy in range(-radius,radius+1))}
        markers={}
        for group,anchor in [('spawns','spawn'),('objectives','objective'),('exits','exit')]:
            markers[group]=[]
            for marker in plan[group]:
                r=rooms[marker['room']];a=definitions[r['archetype']];p=world(r,marker['local_at'])
                if marker['local_at'] not in a['anchors'][anchor] or p not in nav:raise Reject('MARKER_CLEARANCE',group+' marker not on authored clear anchor')
                markers[group].append((p,marker))
        if len({p for p,_ in markers['spawns']})!=len(markers['spawns']):raise Reject('SPAWN_DUPLICATE','spawn locations must be unique')
        objectives={p:[] for p,_ in markers['objectives']}
        for p,o in markers['objectives']:objectives[p].append(o)
        objective_positions={o['id']:p for p,o in markers['objectives']}
        def collect(p,flags):
            flags=set(flags);changed=True
            while changed:
                changed=False
                for o in objectives.get(p,[]):
                    if set(o['requires_flags'])<=flags and o['grants_flag'] not in flags:flags.add(o['grants_flag']);changed=True
            return frozenset(flags)
        required={o['grants_flag'] for o in plan['objectives']};total_states=0;exit_distances=[]
        for spawn,_ in markers['spawns']:
            state=(spawn,collect(spawn,()));queue=deque([(state,0)]);seen={state};visited_rooms=set();completed=set();goals=[]
            while queue:
                (p,flags),distance=queue.popleft();total_states+=1
                if total_states>c['max_search_states']:raise Reject('SEARCH_BUDGET','state exploration bound exhausted; no acceptance proof')
                visited_rooms.add(owner[p]);completed|=set(flags)
                for q,e in markers['exits']:
                    if p==q and set(e['requires_flags'])|required<=flags:goals.append(distance)
                for q in [(p[0]-1,p[1]),(p[0]+1,p[1]),(p[0],p[1]-1),(p[0],p[1]+1)]:
                    if q not in nav or not gates.get(frozenset((p,q)),frozenset())<=flags:continue
                    nxt=(q,collect(q,flags))
                    if nxt not in seen:seen.add(nxt);queue.append((nxt,distance+1))
            if not required<=completed:raise Reject('OBJECTIVE_UNREACHABLE','required objective or prerequisite is behind an unavailable lock')
            if visited_rooms!=set(rooms):raise Reject('CLEARANCE_REACHABILITY','some authored rooms lack a traversable clearance route')
            if not goals:raise Reject('EXIT_UNREACHABLE','no exit reachable with all required progress flags')
            shortest=min(goals);exit_distances.append(shortest)
            if shortest<c['min_spawn_exit_tiles']:raise Reject('EXIT_DISTANCE','completed escape route shorter than configured minimum')
        return dict(accepted=True,scope='OFFLINE_SMALL_AUTHORED_CHAPTER_ONLY',native_ready=False,rooms=len(rooms),blueprint_tiles=raster['width']*raster['height'],
                    nav_cells=len(nav),explored_states=total_states,completed_exit_distances=exit_distances,native_assets='PENDING_NATIVE_CATALOG')
    except Reject as e:return dict(accepted=False,scope='OFFLINE_SMALL_AUTHORED_CHAPTER_ONLY',native_ready=False,reasons=[dict(code=e.code,detail=e.detail)])
    except (KeyError,TypeError,ValueError,IndexError) as e:return dict(accepted=False,scope='OFFLINE_SMALL_AUTHORED_CHAPTER_ONLY',native_ready=False,reasons=[dict(code='SCHEMA',detail=str(e))])


def candidate(config,index,catalog=CATALOG,*,traversal='forward'):
    """Authored chapter grammar, deliberately not a general maze/level generator."""
    definitions=catalog['archetypes'];cfg_hash=canonical_hash(config)
    weights=[(name,definitions[name]['tags']['rarity_weight']) for name in sorted(config['hub_allowlist'])]
    value=stable_u64(config['seed'],ALGORITHM,catalog['version'],PROFILE+':'+cfg_hash,'hub-choice','INDOOR_0',0,0,index)%sum(w for _,w in weights)
    hub=None
    for name,weight in weights:
        if value<weight:hub=name;break
        value-=weight
    types=['arrival_vestibule',hub,'threshold_buffer','utility_gallery','extraction_airlock'];ids=['arrival','hub','threshold','service','exit']
    axis=max(definitions[t]['height']//2 for t in types)+1;x=1;rooms=[]
    for rid,archetype in zip(ids,types):
        a=definitions[archetype];rooms.append(dict(id=rid,archetype=archetype,origin=[x,axis-a['height']//2],rotation=0,zone=a['zone']));x+=a['width']
    links=[]
    for a,b in zip(ids,ids[1:]):links.append(dict(id=a+'--'+b,a=dict(room=a,socket='E'),b=dict(room=b,socket='W'),kind='HUMAN_DOOR',width=3,requires_flags=['SERVICE_DONE'] if b=='exit' else [],native_admission='PENDING'))
    if config['branch_alcove']:
        r=rooms[1];a=definitions[hub];n=a['sockets']['N'];alcove=definitions['maintenance_alcove']
        rooms.append(dict(id='alcove',archetype='maintenance_alcove',origin=[r['origin'][0]+n['offset']-alcove['sockets']['S']['offset'],r['origin'][1]+a['height']],rotation=0,zone='OFFICE'))
        links.append(dict(id='hub--alcove',a=dict(room='hub',socket='N'),b=dict(room='alcove',socket='S'),kind='HUMAN_DOOR',width=3,requires_flags=[],native_admission='PENDING'))
    by_id={r['id']:r for r in rooms};used={(e['room'],e['socket']) for link in links for e in [link['a'],link['b']]}
    sealed=sorted([dict(room=r['id'],socket=s) for r in rooms for s in definitions[r['archetype']]['sockets'] if (r['id'],s) not in used],key=lambda e:(e['room'],e['socket']))
    first='alcove' if config['branch_alcove'] else 'hub'
    def anchor(rid,kind):return deepcopy(definitions[by_id[rid]['archetype']]['anchors'][kind][0])
    plan=dict(schema=IR,profile='INDOOR_LIMINAL',algorithm_version=ALGORITHM,profile_version=PROFILE,content_version=catalog['version'],catalog_sha256=canonical_hash(catalog),
              seed=config['seed'],logical_layer='INDOOR_0',native_z=None,configuration=deepcopy(config),rooms=rooms,links=links,sealed_sockets=sealed,
              spawns=[dict(id='spawn-0',room='arrival',local_at=anchor('arrival','spawn'))],
              objectives=[dict(id='find-marker',room=first,local_at=anchor(first,'objective'),requires_flags=[],grants_flag='FOUND_MARKER',native_admission='PENDING'),
                          dict(id='service-task',room='service',local_at=anchor('service','objective'),requires_flags=['FOUND_MARKER'],grants_flag='SERVICE_DONE',native_admission='PENDING')],
              exits=[dict(id='escape-0',room='exit',local_at=anchor('exit','exit'),requires_flags=['SERVICE_DONE'],native_admission='PENDING')],blueprint=None)
    plan['blueprint']=materialize(plan,catalog,iteration=traversal)[0];return plan


def generate(config,catalog=CATALOG,*,traversal='forward'):
    catalog_errors=validate_catalog(catalog)
    if catalog_errors:return dict(status='CATALOG_REJECTED',document=None,manifest=None,ledger=[],reasons=[dict(code='CATALOG',detail=';'.join(catalog_errors))])
    errors=validate_config(config,catalog)
    if errors:return dict(status='CONFIG_REJECTED',document=None,manifest=None,ledger=[],reasons=errors)
    if traversal not in {'forward','reverse'}:raise ValueError('traversal')
    ledger=[]
    for index in range(config['max_candidates']):
        try:
            doc=candidate(deepcopy(config),index,catalog,traversal=traversal)
            doc['rooms'].sort(key=lambda r:r['id']);doc['links'].sort(key=lambda r:r['id'])
            proof=validate(doc,catalog)
            if proof['accepted']:
                ledger.append(dict(candidate=index,status='ACCEPTED',ir_sha256=canonical_hash(doc),proof=proof))
                return dict(status='VALID_OFFLINE_AUTHORED_TOPOLOGY',document=doc,
                            manifest=dict(schema='civ13-liminal-manifest/1',configuration=deepcopy(config),configuration_sha256=canonical_hash(config),algorithm_version=ALGORITHM,
                                          content_version=catalog['version'],catalog_sha256=canonical_hash(catalog),profile_version=PROFILE,ir_sha256=canonical_hash(doc),
                                          native_integration='PENDING',native_dmm_emitted=False,assets_copied=[],candidate_ledger=deepcopy(ledger)),ledger=ledger,reasons=[])
            ledger.append(dict(candidate=index,status='REJECTED',ir_sha256=canonical_hash(doc),reasons=proof['reasons']))
        except Reject as e:ledger.append(dict(candidate=index,status='REJECTED',reasons=[dict(code=e.code,detail=e.detail)]))
    return dict(status='BOUNDED_REJECTION',document=None,manifest=None,ledger=ledger,reasons=[dict(code='CANDIDATE_BUDGET',detail='all declared candidates rejected without relaxation')])

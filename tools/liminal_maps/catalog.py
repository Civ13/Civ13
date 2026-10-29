"""Original authored-room catalog and collision/anchor authoring checks."""
import json
from pathlib import Path
from .common import canonical_hash

CATALOG=json.loads(Path(__file__).with_name("room-archetypes-v1.json").read_text(encoding="utf-8"))
CATALOG_SHA256=canonical_hash(CATALOG)
HUBS=tuple(sorted(k for k,v in CATALOG["archetypes"].items() if v["role"]=="HUB"))

def socket_cells(archetype,socket):
    s=archetype['sockets'][socket];r=s['width']//2;w,h=archetype['width'],archetype['height']
    return [(v,h-1) if s['facing']=='N' else (v,0) if s['facing']=='S' else (w-1,v) if s['facing']=='E' else (0,v) for v in range(s['offset']-r,s['offset']+r+1)]

def validate_catalog(catalog=CATALOG,radius=1):
    try:
        if type(catalog) is not dict or set(catalog)!={'schema','version','native_approved','archetypes'} or catalog['schema']!='civ13-liminal-room-catalog/1' or catalog['native_approved'] is not False:return ['CATALOG_SCHEMA']
        if type(catalog['version']) is not str or not catalog['version'].isascii() or not 1<=len(catalog['version'])<=128:return ['CATALOG_VERSION']
        if type(catalog['archetypes']) is not dict or not 8<=len(catalog['archetypes'])<=12:return ['CATALOG_FAMILY_COUNT']
        for name,a in catalog['archetypes'].items():
            if type(name) is not str or not name.isascii() or not 1<=len(name)<=64:return ['CATALOG_NAME']
            if set(a)!={'width','height','mask','role','zone','sockets','anchors','tags','native_admission','authoring'} or a['native_admission']!='PENDING' or a['authoring']!='ORIGINAL_ABSTRACT_MASK_NO_ASSET_COPY':return ['CATALOG_ADMISSION']
            w,h=a['width'],a['height']
            role_zones={'ARRIVAL':'OFFICE','HUB':'OFFICE','ALCOVE':'OFFICE','TRANSITION':'BUFFER','SERVICE':'UTILITY','EXIT':'EGRESS'}
            if a['role'] not in role_zones or a['zone']!=role_zones[a['role']]:return ['CATALOG_ZONE']
            tags=a['tags']
            if set(tags)!={'light_intent','sound_intent','rarity_weight','material_intent'} or type(tags['rarity_weight']) is not int or not 1<=tags['rarity_weight']<=100 or any(type(tags[k]) is not str or not tags[k].isascii() or not 1<=len(tags[k])<=64 for k in ['light_intent','sound_intent','material_intent']):return ['CATALOG_TAGS']
            if type(w) is not int or type(h) is not int or not 5<=w<=64 or not 5<=h<=64:return ['CATALOG_SIZE']
            if len(a['mask'])!=h or any(type(row) is not str or len(row)!=w or set(row)-set('#.X') for row in a['mask']):return ['CATALOG_MASK']
            floor={(x,y) for y,row in enumerate(a['mask']) for x,t in enumerate(row) if t=='.'}
            if any(a['mask'][y][x]!='#' for y in range(h) for x in range(w) if x in {0,w-1} or y in {0,h-1}):return ['CATALOG_BOUNDARY']
            anchors=[]
            if set(a['anchors'])!={'spawn','objective','exit'}:return ['CATALOG_ANCHORS']
            for values in a['anchors'].values():
                for p in values:
                    if type(p) is not list or len(p)!=2 or any(type(v) is not int for v in p):return ['CATALOG_ANCHORS']
                    anchors.append(tuple(p))
            if not a['sockets']:return ['CATALOG_SOCKETS']
            for socket,s in a['sockets'].items():
                if set(s)!={'facing','offset','width','kind','clearance'} or s['facing'] not in {'N','S','E','W'} or s['kind']!='HUMAN_DOOR' or s['clearance']!='HUMAN' or type(s['width']) is not int or s['width']!=3 or type(s['offset']) is not int:return ['CATALOG_SOCKET_TYPE']
                edge=socket_cells(a,socket)
                out_of_bounds=any(not 0<x<w-1 for x,y in edge) if s['facing'] in {'N','S'} else any(not 0<y<h-1 for x,y in edge)
                if out_of_bounds:return ['CATALOG_SOCKET_BOUNDS']
                floor.update(edge);x,y=edge[len(edge)//2]
                anchors.append((x,y-1) if s['facing']=='N' else (x,y+1) if s['facing']=='S' else (x-1,y) if s['facing']=='E' else (x+1,y))
            nav={p for p in floor if all((p[0]+dx,p[1]+dy) in floor for dx in range(-radius,radius+1) for dy in range(-radius,radius+1))}
            if not anchors or any(p not in nav for p in anchors):return ['CATALOG_ANCHOR_CLEARANCE']
            seen={anchors[0]};todo=[anchors[0]]
            while todo:
                x,y=todo.pop()
                for q in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)]:
                    if q in nav and q not in seen:seen.add(q);todo.append(q)
            if seen!=nav:return ['CATALOG_INNER_CONNECTIVITY']
        return []
    except (KeyError,TypeError,ValueError,IndexError):return ['CATALOG_SCHEMA']

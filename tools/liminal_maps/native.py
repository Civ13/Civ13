"""DMM export of a verified chapter bundle using existing Civ13 types.

Slice 3 of docs/liminal/SOURCE-AND-ACCEPTANCE.md writes a static map.dmm, a
semantic sidecar, pins and a parse-back proof, with complete.json last; doors are
open apertures and objectives exist only in the sidecar. With mode='escape'
(slice 4) the same layout is bound to the Liminal Facility round: the map
metadata, start landmarks, route marker, service panel, sealed egress gate and
extraction area are placed from the plan's anchors and links.
"""
import hashlib
import importlib.util
import json
from pathlib import Path
import re
from .common import canonical_hash
from .io import read_json,new_output,json_text

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
NATIVE_CATALOG_PATH=HERE/'native-catalog-v2.json'
LAYOUTS_MODULE=ROOT/'docs/liminal/room_layouts_v2.py'
EXPORTER_VERSION='liminal-dmm-export/0.1.0'
KEY_LETTERS='abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'
EXPORT_FILES=('map.dmm','sidecar.json','export-manifest.json','parse-back.json')
MODE_VERSION='liminal-escape-mode/0.1.0'
# Types defined in code/game/objects/map_metadata/liminal_facility.dm and
# code/modules/1713/liminal/liminal_round.dm.
ESCAPE_TYPES=dict(metadata='/obj/map_metadata/liminal_facility',spawn='/obj/effect/landmark{name = "JoinLateLiminal"}',
                  area='/area/caribbean/liminal',extraction='/area/caribbean/liminal/extraction',gate='/obj/structure/liminal_gate',
                  FOUND_MARKER='/obj/structure/liminal_marker',SERVICE_DONE='/obj/structure/liminal_marker/service')


class ExportError(ValueError):
    def __init__(self,code,detail):self.code=code;super().__init__(code+': '+detail)


def native_catalog(path=NATIVE_CATALOG_PATH):
    catalog=read_json(path)
    if catalog.get('schema')!='civ13-liminal-native-catalog/1':raise ExportError('NATIVE_CATALOG','schema')
    for value in [catalog['area'],*catalog['turfs'].values(),*(o['type'] for o in catalog['objects'].values() if o['type'])]:
        if not re.fullmatch(r'(/[a-z0-9_]+)+',value):raise ExportError('NATIVE_CATALOG','bad type path '+repr(value))
    return catalog


def furnishing():
    spec=importlib.util.spec_from_file_location('liminal_room_layouts_v2',LAYOUTS_MODULE)
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    layouts=module.load();catalog,furnished=module.derive(layouts)
    return layouts['version'],catalog,furnished


def _object_text(path,direction=2):
    # Only dir is overridden: tables and other joined furniture pick their own icon state.
    overrides=[]
    if direction!=2:overrides.append(f'dir = {direction}')
    return path+('{'+'; '.join(overrides)+'}' if overrides else '')


def build_cells(doc,catalog=None):
    """Return {(x, y): (object texts..., turf, area)} for the blueprint, plus semantic notes."""
    native=catalog or native_catalog()
    version,derived,furnished=furnishing()
    if version!=doc['content_version'] or version!=native['layouts_version']:raise ExportError('VERSION','layouts, plan and native catalog disagree')
    blueprint=doc['blueprint'];width,height=blueprint['width'],blueprint['height']
    if blueprint.get('row_zero')!='SOUTH' or len(blueprint['rows'])!=height or any(len(r)!=width for r in blueprint['rows']):raise ExportError('BLUEPRINT','shape')
    owner={};floor={};objects={}
    for room in doc['rooms']:
        if room['rotation']!=0:raise ExportError('ROTATION','only unrotated rooms are exported')
        a=derived['archetypes'][room['archetype']];f=furnished[room['archetype']];ox,oy=room['origin']
        for lx in range(a['width']):
            for ly in range(a['height']):
                p=(ox+lx,oy+ly)
                if p in owner:raise ExportError('OVERLAP',f'{p} claimed by {owner[p]} and {room["id"]}')
                owner[p]=room['id']
                if f'{lx},{ly}' in f['floor']:floor[p]=f['floor'][f'{lx},{ly}']
        for o in f['objects']:
            objects.setdefault((ox+o['position'][0],oy+o['position'][1]),[]).append(o)
    turfs=native['turfs'];kinds=native['objects'];area=native['area'];cells={};apertures=[]
    for y in range(height):
        for x in range(width):
            sem=blueprint['rows'][y][x];here=objects.get((x,y),[]);p=(x,y)
            for o in here:
                if o['asset'] not in kinds:raise ExportError('UNMAPPED_ASSET',o['asset'])
            texts=[];turf=None
            if sem=='V':
                if here or p in owner:raise ExportError('VOID','room content on a void cell '+str(p))
                turf=turfs['void']
            elif sem=='W':
                for o in here:
                    if not kinds[o['asset']].get('wall_mounted'):raise ExportError('WALL_CONTENT',f'{o["asset"]} on wall {p}')
                    texts.append(_object_text(kinds[o['asset']]['type'],o['direction']))
                turf=turfs['wall']
            elif sem=='F':
                if any(kinds[o['asset']]['blocks'] or kinds[o['asset']].get('turf') for o in here):raise ExportError('WALKABLE_BLOCKED','blocking asset on walkable '+str(p))
                if p not in floor:
                    if p not in owner:raise ExportError('UNOWNED_FLOOR',str(p))
                    apertures.append(p)
                texts=[_object_text(kinds[o['asset']]['type'],o['direction']) for o in here]
                turf=turfs[floor.get(p,'hall_floor')]
            elif sem=='B':
                if not here:raise ExportError('UNMAPPED_SOLID','solid cell without an asset '+str(p))
                if any(kinds[o['asset']].get('turf') for o in here):
                    if len(here)!=1:raise ExportError('SOLID_TURF','column shares a cell '+str(p))
                    turf=turfs[kinds[here[0]['asset']]['turf']]
                else:
                    texts=[_object_text(kinds[o['asset']]['type'],o['direction']) for o in here]
                    turf=turfs[floor[p]]
            else:raise ExportError('BLUEPRINT','unknown cell '+repr(sem))
            cells[p]=(*texts,turf,area)
    return cells,dict(apertures=sorted(apertures),owner=owner)


def gated_cells(doc,notes):
    """Aperture cells on the far side of each flag-gated link: one sealed line per link."""
    owner=notes['owner'];apertures=set(notes['apertures']);out={}
    for link in doc['links']:
        if not link['requires_flags']:continue
        a,b=link['a']['room'],link['b']['room']
        line=sorted(p for p in apertures if owner.get(p)==b and any(owner.get(q)==a and q in apertures
                    for q in [(p[0]+1,p[1]),(p[0]-1,p[1]),(p[0],p[1]+1),(p[0],p[1]-1)]))
        if len(line)!=link['width']:raise ExportError('GATE','gated link '+link['id']+' has no sealable aperture')
        out[link['id']]=line
    return out


def escape_cells(doc,cells,notes):
    """Bind the static cells to the Liminal Facility escape round."""
    rows=doc['blueprint']['rows'];owner=notes['owner'];added={}
    def place(p,what,label):
        if rows[p[1]][p[0]]!='F':raise ExportError('ANCHOR',label+' not on walkable floor '+str(p))
        if p in added and what!=ESCAPE_TYPES['spawn']:raise ExportError('ANCHOR',label+' shares a cell '+str(p))
        added.setdefault(p,[]).append(what)
    for s in doc['spawns']:
        r=next(r for r in doc['rooms'] if r['id']==s['room']);place((r['origin'][0]+s['local_at'][0],r['origin'][1]+s['local_at'][1]),ESCAPE_TYPES['spawn'],s['id'])
    flags=[o['grants_flag'] for o in doc['objectives']]
    if sorted(flags)!=['FOUND_MARKER','SERVICE_DONE']:raise ExportError('OBJECTIVES','escape needs exactly one marker and one service objective')
    for o in doc['objectives']:
        r=next(r for r in doc['rooms'] if r['id']==o['room']);place((r['origin'][0]+o['local_at'][0],r['origin'][1]+o['local_at'][1]),ESCAPE_TYPES[o['grants_flag']],o['id'])
    gates=gated_cells(doc,notes)
    if [l['requires_flags'] for l in doc['links'] if l['requires_flags']]!=[['SERVICE_DONE']]:raise ExportError('GATE','escape needs one SERVICE_DONE gate')
    for line in gates.values():
        for p in line:
            if len(cells[p])!=2:raise ExportError('GATE','gate cell is not clear '+str(p))
            place(p,ESCAPE_TYPES['gate'],'gate')
    if len(doc['exits'])!=1:raise ExportError('EXIT','escape needs one exit')
    exit_room=doc['exits'][0]['room']
    out={}
    for p,entry in cells.items():
        area=ESCAPE_TYPES['extraction'] if owner.get(p)==exit_room else ESCAPE_TYPES['area']
        out[p]=(*added.get(p,[]),*entry[:-1],area)
    out[(0,0)]=(ESCAPE_TYPES['metadata'],*out[(0,0)])
    return out,dict(gates={k:[[x+1,y+1] for x,y in v] for k,v in gates.items()},extraction_room=exit_room)


def dmm_text(cells,width,height):
    entries=sorted(set(cells.values()))
    size=1
    while len(KEY_LETTERS)**size<len(entries):size+=1
    def key(i):
        out=''
        for _ in range(size):out=KEY_LETTERS[i%len(KEY_LETTERS)]+out;i//=len(KEY_LETTERS)
        return out
    keys={entry:key(i) for i,entry in enumerate(entries)}
    lines=[f'"{keys[e]}" = ({",".join(e)})' for e in entries]
    lines.append('');lines.append('(1,1,1) = {"')
    for y in range(height-1,-1,-1):lines.append(''.join(keys[cells[(x,y)]] for x in range(width)))
    lines.append('"}')
    return '\n'.join(lines)+'\n'


def parse_dmm(text):
    """Parse the exporter's own DMM back into {(x, y): entry tuple} (0-based, y south first)."""
    head,sep,body=text.partition('(1,1,1) = {"\n')
    if not sep or not body.endswith('\n"}\n'):raise ExportError('PARSE','map block')
    entries={}
    for line in head.splitlines():
        if not line:continue
        m=re.fullmatch(r'"([A-Za-z]+)" = \((.*)\)',line)
        if not m or m.group(1) in entries:raise ExportError('PARSE','entry '+repr(line))
        parts=re.findall(r'/[a-z0-9_/]+(?:\{[^{}]*\})?',m.group(2))
        if ','.join(parts)!=m.group(2):raise ExportError('PARSE','entry body '+repr(line))
        if len(parts)<2 or not parts[-1].startswith('/area/') or not parts[-2].startswith('/turf/') or any(not p.startswith('/obj/') for p in parts[:-2]):
            raise ExportError('PARSE','object-turf-area order '+repr(line))
        entries[m.group(1)]=tuple(parts)
    widths={len(k) for k in entries}
    if len(widths)!=1:raise ExportError('PARSE','key widths')
    size=widths.pop();rows=body[:-len('\n"}\n')].split('\n')
    if any(len(r)!=len(rows[0]) or len(r)%size for r in rows):raise ExportError('PARSE','row sizes')
    height=len(rows);width=len(rows[0])//size;grid={}
    for i,row in enumerate(rows):
        for x in range(width):
            k=row[x*size:(x+1)*size]
            if k not in entries:raise ExportError('PARSE','undefined key '+k)
            grid[(x,height-1-i)]=entries[k]
    return grid,width,height


def sidecar(doc,notes,z):
    def native(room_id,local):
        r=next(r for r in doc['rooms'] if r['id']==room_id);return [r['origin'][0]+local[0]+1,r['origin'][1]+local[1]+1]
    _,derived,_=furnishing();archetypes=derived['archetypes']
    rooms=[]
    for r in doc['rooms']:
        a=archetypes[r['archetype']];x,y=r['origin']
        rooms.append(dict(id=r['id'],archetype=r['archetype'],role=a['role'],zone=r['zone'],tags=a['tags'],
                          bounds=[x+1,y+1,x+a['width'],y+a['height']]))
    return dict(schema='civ13-liminal-sidecar/1',status='STATIC_EXPORT_ONLY_NO_MODE',logical_layer=doc['logical_layer'],native_z=z,
                coordinates='native BYOND x,y (1-based, y north); cells are tiles of map.dmm',
                rooms=rooms,
                links=[dict(id=l['id'],kind=l['kind'],width=l['width'],requires_flags=l['requires_flags'],a=l['a'],b=l['b'],native='OPEN_APERTURE') for l in doc['links']],
                aperture_cells=[[x+1,y+1] for x,y in notes['apertures']],
                spawns=[dict(id=s['id'],at=native(s['room'],s['local_at'])) for s in doc['spawns']],
                objectives=[dict(id=o['id'],at=native(o['room'],o['local_at']),requires_flags=o['requires_flags'],grants_flag=o['grants_flag'],native='PENDING_MODE_ADAPTER') for o in doc['objectives']],
                exits=[dict(id=e['id'],at=native(e['room'],e['local_at']),requires_flags=e['requires_flags'],native='PENDING_MODE_ADAPTER') for e in doc['exits']])


def mode_cells(doc,catalog=None,mode=None):
    cells,notes=build_cells(doc,catalog)
    if mode is None:return cells,notes,None
    if mode!='escape':raise ExportError('MODE','unknown mode '+repr(mode))
    cells,binding=escape_cells(doc,cells,notes)
    return cells,notes,binding


def export(doc,folder,z=1,catalog=None,mode=None):
    """Write the export into a new directory. doc must already be a verified plan."""
    if type(z) is not int or not 1<=z<=16:raise ExportError('Z','native z must be 1..16')
    native=catalog or native_catalog()
    cells,notes,binding=mode_cells(doc,native,mode)
    width,height=doc['blueprint']['width'],doc['blueprint']['height']
    text=dmm_text(cells,width,height)
    grid,pw,ph=parse_dmm(text)
    if (pw,ph)!=(width,height) or grid!=cells:raise ExportError('PARSE_BACK','parsed map differs from the intended layout')
    side=sidecar(doc,notes,z)
    if binding:
        side.update(status='ESCAPE_MODE_BOUND',mode=MODE_VERSION,gates=binding['gates'],extraction_room=binding['extraction_room'])
        for item in side['links']:
            if item['requires_flags']:item['native']='SEALED_UNTIL_FLAGS'
        for item in side['objectives']+side['exits']:item['native']='MODE_OBJECT'
    for s in side['spawns']+side['objectives']+side['exits']:
        x,y=s['at']
        if doc['blueprint']['rows'][y-1][x-1]!='F':raise ExportError('ANCHOR','anchor not on walkable floor '+s['id'])
    layouts_hash=hashlib.sha256((ROOT/'docs/liminal/room-layouts-v2.json').read_bytes()).hexdigest()
    manifest=dict(schema='civ13-liminal-export-manifest/1',exporter_version=EXPORTER_VERSION,plan_sha256=canonical_hash(doc),
                  seed=doc['seed'],content_version=doc['content_version'],native_catalog_version=native['version'],
                  native_catalog_sha256=canonical_hash(native),room_layouts_sha256=layouts_hash,native_z=z,
                  width=width,height=height,mode_adapter='PENDING')
    if binding:manifest.update(mode='escape',mode_version=MODE_VERSION,mode_adapter='LIMINAL_FACILITY')
    used=sorted({part.split('{')[0] for entry in cells.values() for part in entry})
    proof=dict(schema='civ13-liminal-parse-back/1',status='PARSED_BACK_EQUAL',tiles=width*height,distinct_entries=len(set(cells.values())),
               types_used=used,apertures=len(notes['apertures']),
               blocking_cells=sum(1 for row in doc['blueprint']['rows'] for c in row if c in 'WBV'),
               map_sha256=hashlib.sha256(text.encode()).hexdigest())
    folder=new_output(folder,True)
    (folder/'map.dmm').write_text(text,encoding='utf-8',newline='\n')
    for name,value in [('sidecar.json',side),('export-manifest.json',manifest),('parse-back.json',proof)]:
        (folder/name).write_text(json_text(value),encoding='utf-8',newline='\n')
    complete=dict(schema='civ13-liminal-export/1',status='ESCAPE_DMM_EXPORTED' if binding else 'STATIC_DMM_EXPORTED',native_ready=False,mode_registered=False,
                  files={n:hashlib.sha256((folder/n).read_bytes()).hexdigest() for n in EXPORT_FILES})
    (folder/'complete.json').write_text(json_text(complete),encoding='utf-8',newline='\n')
    return complete


def verify_export(folder,doc=None):
    folder=Path(folder);complete=read_json(folder/'complete.json')
    if complete.get('schema')!='civ13-liminal-export/1' or set(complete.get('files',{}))!=set(EXPORT_FILES):raise ExportError('EXPORT_MARKER','complete.json')
    for name,digest in complete['files'].items():
        if hashlib.sha256((folder/name).read_bytes()).hexdigest()!=digest:raise ExportError('EXPORT_HASH',name)
    manifest=read_json(folder/'export-manifest.json')
    text=(folder/'map.dmm').read_text(encoding='utf-8')
    grid,width,height=parse_dmm(text)
    if (width,height)!=(manifest['width'],manifest['height']):raise ExportError('EXPORT_SIZE','map size')
    if doc is not None:
        if manifest['plan_sha256']!=canonical_hash(doc):raise ExportError('EXPORT_BINDING','plan')
        cells,_,_=mode_cells(doc,None,manifest.get('mode'))
        if cells!=grid:raise ExportError('EXPORT_DRIFT','map no longer matches the plan')
    return dict(status='VERIFIED_ESCAPE_DMM' if manifest.get('mode') else 'VERIFIED_STATIC_DMM',native_ready=False,tiles=width*height,map_sha256=hashlib.sha256(text.encode()).hexdigest())

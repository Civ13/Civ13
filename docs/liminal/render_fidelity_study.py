"""Bounded sprite-composition audit, not a room generator or native renderer."""
import argparse
from collections import deque
import hashlib
import json
from pathlib import Path
import re
import subprocess
from PIL import Image, ImageDraw, ImageFont, ImageChops, __version__ as pillow_version

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
DIRS={1:(0,1),2:(0,-1),4:(1,0),8:(-1,0)}
ORDER={1:[2],4:[2,1,4,8],8:[2,1,4,8,6,10,5,9]}
digest=lambda b:hashlib.sha256(b).hexdigest()
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT)
def save_json(p,v):p.write_text(json.dumps(v,indent=2)+'\n',encoding='utf-8')


class Frames:
    def __init__(self):self.sheets={};self.used={}
    def get(self,path,state,direction=2):
        if path not in self.sheets:
            im=Image.open(ROOT/path);meta=im.info['Description']
            w=int(re.search(r'width = (\d+)',meta)[1]);h=int(re.search(r'height = (\d+)',meta)[1])
            states={};offset=0
            for m in re.finditer(r'state = "([^"]*)"(.*?)(?=\nstate =|\Z)',meta,re.S):
                dirs=int(re.search(r'dirs = (\d+)',m[2])[1]);frames=int(re.search(r'frames = (\d+)',m[2])[1])
                assert m[1] not in states, ('ambiguous duplicate state',path,m[1])
                states[m[1]]=(offset,dirs,frames);offset+=dirs*frames
            self.sheets[path]=(im.convert('RGBA'),w,h,states)
        im,w,h,states=self.sheets[path]
        assert state in states, ('missing state',path,state)
        offset,dirs,frames=states[state];assert dirs in ORDER
        effective=2 if dirs==1 else direction
        assert effective in ORDER[dirs],('unsupported direction',path,state,direction)
        frame_index=offset+ORDER[dirs].index(effective)
        x=(frame_index%(im.width//w))*w;y=(frame_index//(im.width//w))*h
        sprite=im.crop((x,y,x+w,y+h));assert sprite.getchannel('A').getbbox()
        self.used[(path,state,effective)]=dict(icon=path,state=state,direction=effective,frame=0,
            dirs=dirs,frames=frames,crop=[x,y,w,h],rgba_sha256=digest(sprite.tobytes()))
        return sprite


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
    assert not a.output.exists(),'Existing output is preserved'
    scene=json.loads((HERE/'fidelity-study-scene.json').read_text())
    original=json.loads(git('show',scene['catalog_revision']+':docs/liminal/room-archetypes-v1.json'))['archetypes'][scene['room']]
    assert scene['room']=='office_columns' and (original['width'],original['height'])==(11,11), 'Bounded pinned renderer study only'
    assets=scene['assets'];f=Frames();walls=set();floor=set();carpet=set()
    for y,row in enumerate(original['mask']):
        for x,c in enumerate(row):
            (walls if c in '#X' else floor).add((x,y))
    # Instantiate existing declared sockets into explicit contextual hall stubs.
    openings={}
    for sid in scene['open_sockets']:
        s=original['sockets'][sid];assert s['width']==3
        if sid in ('W','E'):
            x=0 if sid=='W' else original['width']-1
            cells=[(x,y) for y in range(s['offset']-1,s['offset']+2)]
            xs=range(-3,0) if sid=='W' else range(11,14)
            for xx in xs:
                for yy in range(3,8):(walls if yy in (3,7) else floor).add((xx,yy))
        else:
            assert sid=='N';cells=[(x,10) for x in range(s['offset']-1,s['offset']+2)]
            for yy in range(11,14):
                for xx in range(3,8):(walls if xx in (3,7) else floor).add((xx,yy))
        assert all(c in walls for c in cells)
        walls.difference_update(cells);floor.update(cells);openings[sid]=cells
    carpet={p for p in floor if 0<=p[0]<=10 and 0<=p[1]<=10}
    assert not walls&floor
    # Concrete native junction rule, including the external hall wall context.
    junctions={p:sum(bit for bit,(dx,dy) in DIRS.items() if (p[0]+dx,p[1]+dy) in walls) for p in walls}
    assert junctions[(1,10)]==12 and junctions[(0,1)]==3
    assert junctions[(0,10)]==6 and junctions[(3,3)]==0 and junctions[(7,7)]==0
    minx,maxx,miny,maxy=-3,13,0,13
    image=Image.new('RGBA',((maxx-minx+1)*32,(maxy-miny+1)*32),'#111820');layers=[]
    def place(x,y,asset,state=None,direction=2,role='',color=None):
        item=assets[asset];state=state or item.get('state')
        spr=f.get(item['icon'],state,direction)
        if color:spr=ImageChops.multiply(spr,Image.new('RGBA',spr.size,color))
        image.alpha_composite(spr,((x-minx)*32,(maxy-y)*32))
        layers.append(dict(x=x,y=y,asset=asset,state=state,direction=direction,role=role,color=color))
    for x,y in sorted(floor):
        if (x,y) not in carpet:place(x,y,'hall_floor');continue
        place(x,y,'carpet')
        border=sum(bit for bit,(dx,dy) in DIRS.items() if (x+dx,y+dy) not in carpet)
        for bit in DIRS:
            if border&bit:place(x,y,'carpet','sblucarpet_edges',bit,role='carpet edge')
        for v,h in ((1,4),(1,8),(2,4),(2,8)):
            dx,dy=DIRS[h][0],DIRS[v][1];diag=v|h
            if border&v and border&h:place(x,y,'carpet','sblucarpet_edges',diag,role='outer carpet corner')
            elif not border&v and not border&h and (x+dx,y+dy) not in carpet:
                place(x,y,'carpet','sblucarpet_corners',diag,role='concave carpet corner')
    for (x,y),j in sorted(junctions.items()):place(x,y,'wall',f'cement_wall{j}',role='native compatible-wall junction')
    desks={tuple(o['position']) for o in scene['objects'] if o['asset']=='desk'}
    dense={tuple(o['position']) for o in scene['objects'] if o['asset'] in ('desk','cabinet','shelf','plant')}
    # Maintain a protected three-cell cross for circulation and the old anchor.
    reserve={(x,y) for x in range(11) for y in (4,5,6) if (x,y) in floor}
    reserve|={(x,y) for x in (4,5,6) for y in range(5,11) if (x,y) in floor}
    assert not dense&reserve
    assert all(tuple(p) not in dense for pp in original['anchors'].values() for p in pp)
    for o in scene['objects']:
        x,y=o['position'];asset=o['asset'];direction=o.get('direction',2);state=None
        assert (x,y) in floor or asset=='noticeboard' and (x,y) in walls
        if asset in ('paper','computer'):assert (x,y) in desks
        if asset=='chair':assert (x,y+1) in desks and direction==1
        if asset=='desk':
            neighbors=[bit for bit,(dx,dy) in DIRS.items() if (x+dx,y+dy) in desks]
            assert len(neighbors)<=1,'Only standalone or paired desk states audited'
            if neighbors:state='woodtable_1tileendtable';direction=neighbors[0]
        place(x,y,asset,state,direction,o['role'])
    # Conservative radius-1 traversal through real openings, with dense furniture.
    walk=floor-dense
    centers={p for p in walk if all((p[0]+dx,p[1]+dy) in walk for dx in (-1,0,1) for dy in (-1,0,1))}
    targets=[(-2,5),(12,5),(5,12),(5,5)];assert set(targets)<=centers
    reached={targets[0]};q=deque(reached)
    while q:
        x,y=q.popleft()
        for dx,dy in DIRS.values():
            pp=x+dx,y+dy
            if pp in centers and pp not in reached:reached.add(pp);q.append(pp)
    assert set(targets)<=reached
    a.output.mkdir(parents=True)
    # Image-first composition. No entrance letters, objective markers or collision
    # colors cover the actual room. Captions remain outside the scene raster.
    canvas=Image.new('RGB',(1740,1580),'#17212b');draw=ImageDraw.Draw(canvas)
    draw.text((40,22),'Office columns / instantiated renderer study',font=ImageFont.load_default(size=34),fill='#f1efe6')
    draw.text((40,68),'Static actual-asset preview. Furnishing study only; revised catalog design and native acceptance pending.',font=ImageFont.load_default(size=21),fill='#c4cdd4')
    canvas.paste(image.convert('RGB').resize((1632,1344),Image.Resampling.NEAREST),(54,122))
    draw.text((40,1490),'Connected concrete walls / open three-cell hall connections / grouped desks, seats, storage and corner plants',font=ImageFont.load_default(size=22),fill='#e7d9b6')
    draw.text((40,1528),'Civ13 + upstream SS13 asset contributors. No private reference image, HUD/chat, AI art, native runtime or gate behavior.',font=ImageFont.load_default(size=19),fill='#c4cdd4')
    canvas.save(a.output/'representative-room.png')
    # Correct source-selected single-cell door states, kept separate because the
    # authored sockets span three cells and no full-width native gate is approved.
    swatch=Image.new('RGB',(1040,330),'#17212b');dd=ImageDraw.Draw(swatch)
    dd.text((20,15),'Native door-state audit / one-cell asset, not a three-cell gate',font=ImageFont.load_default(size=24),fill='white')
    for i,state in enumerate(('wood','woodopen')):
        spr=f.get(assets['door_sample']['icon'],state)
        spr=ImageChops.multiply(spr,Image.new('RGBA',spr.size,assets['door_sample']['color']))
        bg=f.get(assets['hall_floor']['icon'],'floor');bg.alpha_composite(spr)
        swatch.paste(bg.convert('RGB').resize((192,192),Image.Resampling.NEAREST),(30+i*270,65))
        dd.text((30+i*270,270),state,font=ImageFont.load_default(size=22),fill='white')
    dd.text((585,80),'Closed: state=0, density=1, opacity=1\nOpen: state=1, density=0, opacity=0\nNative state change is delayed 10 ticks.\n\nSprite has dirs=1. No invented rotation.\nNo stretching or single-leaf gate claim.',font=ImageFont.load_default(size=19),fill='#c4cdd4',spacing=8)
    swatch.save(a.output/'door-state-audit.png')
    sources={}
    for path in sorted({a['icon'] for a in assets.values()}|{a['source'] for a in assets.values()}|{'code/game/turfs/wall_types.dm','code/modules/materials/materials.dm','code/game/turfs/flooring/flooring.dm','code/predefines.dm','LICENSE'}):
        blob=git('show',scene['asset_revision']+':'+path)
        assert git('diff',scene['asset_revision'],'--',path)==b'',('modified source',path)
        sources[path]=dict(canonical_sha256=digest(blob),git_blob=git('rev-parse',scene['asset_revision']+':'+path).decode().strip())
    manifest=dict(schema='civ13-renderer-fidelity-study-result/1',status=scene['status'],
        asset_revision=scene['asset_revision'],catalog_revision=scene['catalog_revision'],catalog_family=scene['room'],
        original_mask=original['mask'],opened_instance_sockets=openings,original_anchors=original['anchors'],
        explicit_context=scene['context'],furnishing_semantics=scene['objects'],layers=layers,
        wall_junctions=[dict(x=x,y=y,junction=j) for (x,y),j in sorted(junctions.items())],
        dmi_frames=list(f.used.values()),source_files=sources,
        checks=dict(connected_wall_controls='PASS',surface_props_on_desks='PASS',chairs_face_desks='PASS',
                    dense_props_outside_cross_reserve='PASS',anchor_empty='PASS',radius1_hall_to_hall_via_anchor='PASS'),
        unresolved=['Revised catalog/furnishing approval','Three-cell-wide native gate ownership','Dynamic light/audio','Runtime constructor/rendering parity','Missing officechair_dark_over source state'],
        native_execution=False,private_reference_copied=False,pillow=pillow_version,
        scene_sha256=digest((HERE/'fidelity-study-scene.json').read_bytes()),renderer_sha256=digest(Path(__file__).read_bytes()),
        credit='Existing Civ13 and upstream SS13 asset contributors; retain root LICENSE. No individual authors invented.',
        files={p.name:dict(sha256=digest(p.read_bytes()),bytes=p.stat().st_size) for p in a.output.iterdir()})
    save_json(a.output/'manifest.json',manifest)
    print(json.dumps(dict(status='PASS',output=str(a.output),wall_states=sorted(set(junctions.values())),radius1_targets=targets)))


if __name__=='__main__':main()

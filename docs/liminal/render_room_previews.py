"""Render the ten authored rooms using existing DMI frames. No generator/runtime.

Reuse the existing animal_harvest preview's DMI reader, including its nonempty
alpha check. This renderer preserves sealed catalog geometry and emits no DMM.
"""
import argparse
from collections import Counter, deque
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import textwrap

from PIL import Image, ImageDraw, ImageFont, __version__ as pillow_version

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
BG, PANEL, INK, MUTED = '#141c24', '#202c37', '#f1efe6', '#b9c4cd'
CYAN, GREEN, AMBER = '#67d7ec', '#82e9b5', '#f2c36c'


def sha(data):
    return hashlib.sha256(data).hexdigest()


def dump(path, obj):
    path.write_text(json.dumps(obj, indent=2, ensure_ascii=True) + '\n', encoding='utf-8')


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT)


def font(size, bold=False):
    # Use Pillow's bundled font for portable rendering, with an optional exact
    # font supplied on the CLI for byte-for-byte reproduction of this proposal.
    if FONT:
        return ImageFont.truetype(str(FONT), size)
    return ImageFont.load_default(size=size)


def text(draw, xy, value, size=18, color=INK):
    draw.text(xy, value, font=font(size), fill=color)


def socket_cells(room, socket, inward=0):
    w, h = room['width'], room['height']
    o, r, face = socket['offset'], socket['width']//2, socket['facing']
    if face in ('E', 'W'):
        return [(w-1-inward if face == 'E' else inward, y) for y in range(o-r, o+r+1)]
    return [(x, h-1-inward if face == 'N' else inward) for x in range(o-r, o+r+1)]


def audit(name, room):
    w, h, mask = room['width'], room['height'], room['mask']
    assert len(mask) == h and all(len(row) == w for row in mask), name
    assert set(''.join(mask)) <= set('#.X'), name
    floor = {(x,y) for y,row in enumerate(mask) for x,c in enumerate(row) if c == '.'}
    # The radius-1 reserve is the exact set of centers whose 3x3 footprint is
    # authored floor. Socket mouths stay sealed in the actual asset image.
    centers = {p for p in floor if all((p[0]+dx,p[1]+dy) in floor
               for dx in (-1,0,1) for dy in (-1,0,1))}
    anchors = [(kind,tuple(p)) for kind,points in room['anchors'].items() for p in points]
    assert all(p in centers for _,p in anchors), (name, 'anchor clearance')
    approaches, apertures = {}, {}
    for sid,s in room['sockets'].items():
        assert sid == s['facing'] and s['kind'] == 'HUMAN_DOOR' and s['width'] == 3
        cells = socket_cells(room,s)
        assert all(mask[y][x] == '#' for x,y in cells), (name, 'sealed mouth')
        assert all((x,y) in floor for k in (1,2,3) for x,y in socket_cells(room,s,k)), (name,'approach')
        approach = socket_cells(room,s,2)[1]
        assert approach in centers
        approaches[sid] = list(approach)
        apertures[sid] = [list(p) for p in cells]
    start = next(iter(centers))
    reached, queue = {start}, deque([start])
    while queue:
        x,y = queue.popleft()
        for p in ((x+1,y),(x-1,y),(x,y+1),(x,y-1)):
            if p in centers and p not in reached:
                reached.add(p); queue.append(p)
    assert len(reached) == len(centers), (name, 'disconnected reserve')
    assert all(tuple(p) in reached for p in approaches.values())
    return dict(width=w,height=h,mask_south_first=mask,counts=dict(Counter(''.join(mask))),
                sockets=room['sockets'],anchors=room['anchors'],tags=room['tags'],
                conditional_apertures=apertures,radius1_approach_centers=approaches,
                radius1_centers=[list(p) for p in sorted(centers)],
                static_checks='PASS: exact dimensions, sealed mouths, 3x3 anchor/approach clearance, connected reserve')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True, help='New output folder; never overwrites')
    parser.add_argument('--font', type=Path, help='Optional TTF used for labels; recorded by hash')
    args = parser.parse_args()
    global FONT
    FONT = args.font
    assert not args.output.exists(), 'Output must be new'
    palette_path, catalog_path = HERE/'preview-palette-v1.json', HERE/'room-archetypes-v1.json'
    palette = json.loads(palette_path.read_text())
    # Git canonical LF bytes bind the authored catalog independently of Windows
    # checkout line endings. No alteration or new catalog version is made.
    canonical_catalog = git('show', palette['design_revision']+':docs/liminal/room-archetypes-v1.json')
    catalog_digest = sha(json.dumps(json.loads(canonical_catalog),sort_keys=True,separators=(',',':'),ensure_ascii=True).encode())
    assert catalog_digest == palette['catalog_sha256']
    catalog = json.loads(catalog_path.read_text())
    assert catalog == json.loads(canonical_catalog)
    assert catalog['native_approved'] is False and set(catalog['archetypes']) == set(palette['rooms'])
    spec = importlib.util.spec_from_file_location('civ13_dmi_preview', ROOT/'tests/animal_harvest/preview.py')
    reader = importlib.util.module_from_spec(spec); spec.loader.exec_module(reader)
    frames, provenance = {}, {}
    for aid, a in palette['assets'].items():
        paths = [a['icon'], a['source'], *a.get('related_source', [])]
        for path in paths:
            baseline = git('rev-parse',palette['source_revision']+':'+path).decode().strip()
            assert baseline == git('rev-parse',palette['design_revision']+':'+path).decode().strip()
            subprocess.run(['git','diff','--exit-code',palette['source_revision'],'--',path],cwd=ROOT,check=True,stdout=subprocess.DEVNULL)
            provenance[path] = dict(git_blob=baseline,sha256=sha((ROOT/path).read_bytes()),
                canonical_sha256=sha(git('show',palette['source_revision']+':'+path)))
        frame = reader.state(ROOT/a['icon'], a['state'])
        assert frame.size == (32,32), (aid,'unexpected sprite extent')
        frames[aid] = frame
    provenance['LICENSE'] = dict(git_blob=git('rev-parse',palette['source_revision']+':LICENSE').decode().strip(),
                                sha256=sha((ROOT/'LICENSE').read_bytes()))
    records = {name:audit(name,room) for name,room in catalog['archetypes'].items()}
    args.output.mkdir(parents=True)
    tilemaps = {}
    sheet = Image.new('RGB',(1440,2940),BG); sd=ImageDraw.Draw(sheet)
    text(sd,(30,22),'CIV13  /  TEN ORIGINAL ROOM FAMILIES',30)
    text(sd,(30,65),'Static asset/layout previews - sealed catalog sockets; no game runtime or working mode',20)
    text(sd,(30,100),'1990-era palette proposal 0.1.0  |  Source 10d264e  |  Design 26c05cd',18,MUTED)
    text(sd,(30,130),'Cyan = conditional socket span; green = spawn; amber = objective/exit. Colored marks are editorial.',17,MUTED)
    for index,(name,room) in enumerate(catalog['archetypes'].items()):
        w,h = room['width'],room['height']; choice=palette['rooms'][name]
        image = Image.new('RGBA',(w*32,h*32))
        tiles=[]
        for y,row in enumerate(room['mask']):
            for x,c in enumerate(row):
                floor_id = choice.get('east_half_floor',choice['floor']) if x >= w//2 else choice['floor']
                layers=[floor_id]
                if c == '#': layers=['concrete_wall']
                elif c == 'X': layers=['concrete_wall'] if choice['solid']=='concrete_wall' else [floor_id,choice['solid']]
                px,py=x*32,(h-1-y)*32
                for aid in layers:
                    image.alpha_composite(frames[aid],(px,py))
                tiles.append(dict(x=x,y=y,mask=c,layers=layers))
        tilemaps[name]=tiles
        # Every original cell occupies exactly one unrotated 32px source tile.
        # Surface remains unannotated here; marks are on a separate presentation.
        records[name]['raw_asset_rgba_sha256']=sha(image.tobytes())
        presentation=image.convert('RGB'); draw=ImageDraw.Draw(presentation)
        for sid,cells in records[name]['conditional_apertures'].items():
            xs=[p[0] for p in cells]; ys=[h-1-p[1] for p in cells]
            draw.rectangle((min(xs)*32+2,min(ys)*32+2,(max(xs)+1)*32-3,(max(ys)+1)*32-3),outline=CYAN,width=2)
            x,y=cells[1]; text(draw,(x*32+9,(h-1-y)*32+6),sid,15,CYAN)
        for kind,coords in room['anchors'].items():
            for x,y in coords:
                left,top=x*32,(h-1-y)*32
                color=GREEN if kind=='spawn' else AMBER
                draw.rectangle((left+6,top+6,left+25,top+25),outline=color,width=2)
                text(draw,(left+10,top+6),{'spawn':'S','objective':'O','exit':'E'}[kind],14,color)
        canvas=Image.new('RGB',(1320,1160),BG); d=ImageDraw.Draw(canvas)
        title=f'{index+1:02d}  {name.replace("_"," ").title()}'
        text(d,(32,22),title,34)
        text(d,(32,68),f'{w} x {h} authored cells  |  {room["role"]} / {room["zone"]}  |  North is up',21,MUTED)
        text(d,(32,102),'STATIC ASSET/LAYOUT PREVIEW - no in-game screenshot or working mode',20,CYAN)
        # Constant 64px cells across every individual image; no room is stretched.
        left,top=32+(960-w*64)//2,160+(832-h*64)//2
        canvas.paste(presentation.resize((w*64,h*64),Image.Resampling.NEAREST),(left,top))
        text(d,(1020,168),'CATALOG CHECK',21)
        labels=[f'{w} columns / {h} rows',f'{records[name]["counts"].get("X",0)} authored solid cells',
                'Sockets: '+','.join(room['sockets']), 'Every socket: 3 cells',
                'Cyan spans stay SEALED', 'No mate/door asserted',
                f'{len(records[name]["radius1_centers"])} radius-1 centers', 'Connected 3x3 reserve',
                'S = spawn annotation', 'O = objective annotation','E = exit annotation',
                'All anchor sites empty']
        for i,line in enumerate(labels): text(d,(1020,208+29*i),line,17,MUTED)
        yy=600
        text(d,(1020,yy),'KEY FEATURE',20)
        for line in textwrap.wrap(choice['feature'],27):
            yy+=26;text(d,(1020,yy),line,17,MUTED)
        yy+=50;text(d,(1020,yy),'LIMITS',20)
        for line in ['Palette proposal only','Full-bright base sprites', 'No native wall smoothing','No light/audio simulation', 'No functional anchor prop']:
            yy+=26;text(d,(1020,yy),line,16,MUTED)
        text(d,(32,1030),'Source assets: Civ13 contributors / upstream SS13 contributors. See manifest and root LICENSE.',18,MUTED)
        text(d,(32,1062),'Design 26c05cd8f85821c3ce76dcc72e3f0e61378c7ac4; assets 10d264e5896221b34949ee4b67c0fd2b94bde249',16,MUTED)
        text(d,(32,1094),'Masks and anchors unchanged. Conditional apertures are annotations; unused sockets remain walls.',18,MUTED)
        filename=name+'.png';canvas.save(args.output/filename)
        records[name]['png']=filename
        records[name]['png_sha256']=sha((args.output/filename).read_bytes())
        records[name]['png_dimensions']=list(canvas.size)
        # Contact sheet gets its own readable labels and 1x tiles, not tiny
        # downscaled captions from the individual images.
        cx=24+(index%2)*708;cy=190+(index//2)*545
        sd.rounded_rectangle((cx,cy,cx+684,cy+525),radius=10,fill=PANEL)
        text(sd,(cx+18,cy+12),title,25)
        text(sd,(cx+18,cy+48),f'{w} x {h} | {room["zone"]} | sockets '+','.join(room['sockets']),18,MUTED)
        sheet.paste(presentation,(cx+(684-w*32)//2,cy+82+(416-h*32)//2))
        text(sd,(cx+18,cy+498),'Sealed source mask / conditional spans annotated / anchor sites empty',16,MUTED)
    sheet.save(args.output/'contact-sheet.png')
    dump(args.output/'tile-mapping.json',dict(schema='civ13-liminal-preview-tiles/1',
        coordinate_system=palette['coordinate_system'],rooms=tilemaps))
    manifest=dict(schema='civ13-liminal-static-asset-preview/1',
        claim='Static asset/layout previews, not in-game screenshots, native appearance acceptance or a working mode.',
        source_revision=palette['source_revision'],design_revision=palette['design_revision'],
        environment=dict(python=sys.version.split()[0],pillow=pillow_version,platform=sys.platform),
        catalog_sha256=catalog_digest,catalog_blob_sha256=sha(canonical_catalog),palette_version=palette['version'],
        palette_sha256=sha(palette_path.read_bytes()),renderer_sha256=sha(Path(__file__).read_bytes()),
        dmi_reader=dict(path='tests/animal_harvest/preview.py',sha256=sha((ROOT/'tests/animal_harvest/preview.py').read_bytes())),
        font=dict(file_name=FONT.name,sha256=sha(FONT.read_bytes())) if FONT else dict(name='Pillow bundled Aileron'),
        scale=dict(dmi_tile=[32,32],individual_nearest_neighbor=2,contact_sheet=1,first_frame=True,first_direction=True),
        aperture_policy=palette['aperture_policy'],native_approved=False,native_tools_run=False,
        source_files=provenance,rooms=records,unmapped_roles=palette['unmapped_roles'],attribution=palette['attribution'])
    manifest['files']={p.name:dict(sha256=sha(p.read_bytes()),bytes=p.stat().st_size)
                       for p in sorted(args.output.iterdir()) if p.is_file()}
    dump(args.output/'manifest.json',manifest)
    print(json.dumps(dict(rooms=len(records),checks='PASS',pngs=11,output=str(args.output))))


FONT=None
if __name__=='__main__':
    main()

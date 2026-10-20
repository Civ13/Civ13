"""Manifest-backed static source diagram, never a native/gameplay render."""
from pathlib import Path
import sys
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_map import ROOT, WIDTH, LENGTH, PALETTE, manifest, train_levels

OUTPUT = ROOT / 'docs/images/dagger-train-map-preview.png'
BG, PANEL, TEXT, MUTED = '#101b24', '#192934', '#edf4f4', '#a6b9c3'
TEAL, AMBER, STRUCTURE, STAIR = '#57c9ba', '#e9b85d', '#afc2ce', '#b3b4fa'


def font(size, bold=False):
    return ImageFont.truetype(str(Path('C:/Windows/Fonts') / ('segoeuib.ttf' if bold else 'segoeui.ttf')), size)


def main():
    layout, tiles = manifest(), train_levels()
    im = Image.new('RGB', (3000, 2250), BG)
    d = ImageDraw.Draw(im)

    def text(x, y, value, size=24, color=TEXT, bold=False):
        d.text((x, y), value, font=font(size, bold), fill=color)

    def card(bounds):
        d.rounded_rectangle(bounds, radius=22, fill=PANEL)

    def lines(x, y, values, size=24, color=MUTED, step=37):
        for value in values:
            text(x, y, value, size, color)
            y += step

    text(55, 25, 'DAGGER / FOUR-DECK MAP STUDY', 23, TEAL, True)
    text(55, 65, 'Dagger train home - enlarged draft', 54, bold=True)
    text(55, 139, 'STATIC SOURCE DIAGRAM  |  North up on every plan  |  Not a native sprite render or gameplay capture', 25, MUTED)
    card((35, 205, 1700, 1515))
    card((1730, 205, 2965, 1045))
    card((1730, 1070, 2965, 2015))
    card((35, 1540, 1700, 2015))
    c, top = 11, 330
    starts = [95, 505, 915, 1325]

    def cellbox(x, y, start):
        a, b = start + x*c, top + (LENGTH-1-y)*c
        return (a, b, a+c-1, b+c-1)

    def rectbox(bounds, start):
        x0, y0, x1, y1 = bounds
        a, b, _, _ = cellbox(x0, y1, start)
        _, _, e, f = cellbox(x1, y0, start)
        return a, b, e, f

    core = layout['protected']
    px0, py0, px1, py1 = core['bounds']
    deck_names = ['GROUND', 'UPPER 1', 'UPPER 2', 'ROOF']
    for level in layout['levels']:
        z, start = level['local_z'], starts[level['local_z']]
        text(start, 228, f'{z+1:02}  {deck_names[z]}', 27, bold=True)
        rooms = [r for r in layout['rooms'] if r['local_z'] == z]
        pads = [p for p in layout['build_pads'] if p['local_z'] == z]
        text(start, 271, f'{len(rooms)} zones / {len(pads)} build pads', 20, MUTED)
        text(start, 302, 'N  ^', 18, TEAL, True)
        for (x, y, dz), kind in tiles.items():
            if dz != z:
                continue
            a, b, e, f = cellbox(x, y, start)
            party = z == core['local_z'] and px0 <= x <= px1 and py0 <= y <= py1
            base = '#28544f' if party else '#665335'
            if kind in ('hull', 'pillar'):
                base = '#607784' if kind == 'hull' else '#b2c5d0'
            elif kind in ('door', 'gate', 'inner_gate'):
                base = '#f6d17c'
            elif kind.startswith('stair_'):
                base = STAIR
            d.rectangle((a, b, e, f), fill=base, outline='#273843')
            ink = '#dfefe8' if party else '#f5dfb4'
            if kind == 'bed':
                d.rectangle((a+2,b+2,e-2,f-2), outline=ink)
                d.line((a+2,b+4,e-2,b+4),fill=ink)
            elif kind == 'crate':
                d.rectangle((a+2,b+2,e-2,f-2),outline=ink)
                d.line((a+2,b+2,e-2,f-2),fill=ink)
            elif kind == 'rack':
                for yy in (3,5,7): d.line((a+2,b+yy,e-2,b+yy),fill=ink)
            elif kind in ('table','chair','anvil','sink','toilet'):
                d.rectangle((a+3,b+3,e-3,f-3),fill=ink)
            elif kind in ('helm_control','engine_mount'):
                d.rectangle((a,b,e,f),fill=PALETTE[kind][1])
            elif kind.startswith('stair_'):
                d.line((a+2,b+3,e-2,b+3),fill=BG)
                d.line((a+2,b+6,e-2,b+6),fill=BG)
        for pad in pads:
            d.rectangle(rectbox(pad['bounds'], start), outline=AMBER, width=2)
        for clear in layout['keep_clear']:
            if clear['local_z'] == z:
                d.rectangle(rectbox(clear['bounds'], start), outline='#86aab3', width=1)
        if z == core['local_z']:
            d.rectangle(rectbox(core['bounds'],start),outline=TEAL,width=3)
            d.rectangle(rectbox(core['airlock']['interior_bounds'],start),outline=TEAL,width=2)
        for i, room in enumerate(rooms,1):
            a,b,e,f = rectbox(room['bounds'],start)
            cx,cy=(a+e)//2,(b+f)//2
            label=str(i)
            tw=d.textlength(label,font=font(17,True))
            d.rounded_rectangle((cx-tw/2-4,cy-12,cx+tw/2+4,cy+12),radius=4,fill=BG)
            text(cx-tw/2,cy-12,label,17,TEAL if room['protected'] else AMBER,True)
        for stair in layout['stairs']:
            for end in ('lower','upper'):
                x,y,dz=stair[end]
                if dz == z:
                    a,b,e,f=cellbox(x,y,start)
                    direction='+' if end=='lower' else '-'
                    # Pair identity is visible alongside the actual endpoint tile.
                    anchor=start-44 if stair['id'].startswith('a') else start+WIDTH*c+3
                    text(anchor,b-4,stair['id'].upper()+direction,13,STAIR,True)
                    d.line((anchor+30 if anchor<start else anchor-2,b+5,(a+e)//2,b+5),fill=STAIR,width=1)
        d.rectangle((start,top,start+WIDTH*c-1,top+LENGTH*c-1),outline=STRUCTURE,width=2)
        text(start, 1468, f'Local z {z}  |  {WIDTH} x {LENGTH}', 20, MUTED)

    text(65,1564,'GROUND DIRECTORY',25,bold=True)
    ground=[r for r in layout['rooms'] if r['local_z']==0]
    for i,r in enumerate(ground):
        col,row=divmod(i,5)
        text(65+col*350,1610+row*37,f'{i+1:02}  {r["name"]}',20,TEAL if r['protected'] else AMBER)
    text(1155,1564,'UPPER / ROOF DIRECTORY',22,bold=True)
    lines(1155,1610,['Upper 1 and 2 share numbering:', '1-5 west: rear / mid / workshop /', 'utility / forward; 6-10 east same.', '11 sorting and stair landing.', '', 'Roof: 1-3 west rear / centre /', 'forward; 4-6 east same.'],19,step=30)
    text(65,1830,'SOURCE SYMBOLS',23,bold=True)
    lines(65,1870,['Teal: owning-party core     Amber: exposed / player build pads', 'Grey: permanent wall or pillar     Lavender: stair endpoints A0-A2 / B0-B2', 'Bed, crate, rack and furniture marks are schematic; numbers locate source room bounds.'],21,step=34)

    text(1760,230,'TWO HEIGHT BANKS / ONE SHARED RAID PLATFORM',26,bold=True)
    world=layout['world']
    text(1760,276,f'Staging: {world["width"]} x {world["height"]} x {world["levels"]} | Train: {WIDTH} x {LENGTH} x {len(layout["levels"])}',24,MUTED)
    scale=2
    for idx,(kind,title) in enumerate((('home','HOME BANK / WORLD Z 1-4'),('raid','RAID BANK / WORLD Z 5-8'))):
        bx,by=1785+idx*580,370
        text(bx,326,title,23,TEAL if kind=='home' else AMBER,True)
        def wb(bounds):
            x0,y0,x1,y1=bounds
            return bx+x0*scale,by+(world['height']-1-y1)*scale,bx+(x1+1)*scale-1,by+(world['height']-y0)*scale-1
        d.rectangle((bx,by,bx+world['width']*scale,by+world['height']*scale),fill='#111e27',outline='#45606e')
        if kind=='raid':
            for access in layout['shared_access']: d.rectangle(wb(access['bounds']),fill='#a08a50')
        for slot in layout['slots']:
            if slot['kind'] != ('raid_berth' if kind == 'raid' else kind): continue
            d.rectangle(wb(slot['reserved_bounds']),outline='#607b89',width=2)
            x,y,z=slot['origin']
            box=wb([x,y,x+WIDTH-1,y+LENGTH-1])
            d.rectangle(box,fill='#284d49' if slot['id']==layout['prototype']['slot'] else '#354754',outline=TEAL if kind=='home' else AMBER,width=2)
            text(box[0]+4,box[1]+8,slot['id'].split('_')[-1].upper(),13,TEXT,True)
            text(box[0]+4,box[1]+32,f'z{slot["reserved_z"][0]}-{slot["reserved_z"][1]}',13,MUTED)
            if kind=='raid':
                for cell in slot.get('bridge_cells',[]):
                    if len(cell)>=2: d.rectangle(wb([cell[0],cell[1],cell[0],cell[1]]),fill='#c9b87c')
        text(bx,900,'N ^  |  Southwest world origin',19,MUTED)
    lines(1760,948,['Only home west contains the source prototype. Other slots are placeholders.', 'Platform and concourse exist on raid ground z5; upper layers have no shared bridge.'],22,step=34)

    text(1760,1100,'SPACE, ACCESS AND PROTECTION CONTRACT',28,bold=True)
    lines(1760,1154,[
        'Scale: original 15 x 51 -> 30 x 102 XY; four decks now support building.',
        'Staging: original 128 x 128 x 2 -> 256 x 256 x 8.',
        'Home and raid each use a four-level bank with the same local deck order.',
        '',
        'One party reserves only its selected berth and its full four-deck footprint.',
        'The second raid berth stays available; the pair is a geometry group only.',
        'Ground boarding uses three-wide routes from the common platform.',
        'Six stair pairs connect adjacent decks at separate XY endpoints.',
        '',
        'PARTY CORE / GROUND ONLY',
        'Required in home and raid; implementation pending.',
        'Protected engine and helm are inside the core and are upgradeable.',
        'A 4 x 5 party-only airlock requires an interlock and safe egress.',
        'Core isolation includes floor and ceiling boundaries against entry above.',
        'Safe sustenance restores nutrition / hydration to healthy caps;',
        'recovery rate is unselected. Occupancy and party checks are required.',
        '',
        'PERMANENT STRUCTURE / ALL FOUR DECKS',
        'Floors, walls, pillars, stairs and doors must be invincible.',
        'Deny damage, deconstruction, forced entry, removal and replacement.',
        'Player-built contents remain distinct and do not inherit this protection.',
        'Fuel, passes, upgrades, movement and saved state are design contracts.'
    ],23,step=35)
    d.line((55,2050,2945,2050),fill='#46616e',width=2)
    text(55,2080,'PROTOTYPE ONLY / RUNTIME IMPLEMENTATION PENDING',30,TEAL,True)
    lines(55,2130,['Diagram reads generator geometry and manifest metadata. It proves static layout only; it does not prove native loading, stair travel, access enforcement or invincibility.',
                   'Demo slots do not establish a production party cap. Reserve, save, move, restore and retire each entire four-level train atomically.'],23,step=36)
    OUTPUT.parent.mkdir(parents=True,exist_ok=True)
    im.save(OUTPUT)
    print(OUTPUT)


if __name__ == '__main__':
    main()

"""Static source diagram of the current draft; never a gameplay or sprite render."""
from pathlib import Path
import sys
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_map import ROOT, WIDTH, LENGTH, PALETTE, build, train

OUTPUT = ROOT / 'docs/images/dagger-train-map-preview.png'
BG, PANEL, TEXT, MUTED = '#101b24', '#192934', '#edf4f4', '#9eb1bc'
TEAL, AMBER = '#57c9ba', '#e9b85d'


def font(size, bold=False):
    return ImageFont.truetype(str(Path('C:/Windows/Fonts') / ('segoeuib.ttf' if bold else 'segoeui.ttf')), size)


def main():
    grid, layout = build()
    tiles = train()
    world = layout['world']
    im = Image.new('RGB', (2200, 1900), BG)
    d = ImageDraw.Draw(im)

    def text(x, y, value, size=23, color=TEXT, bold=False):
        d.text((x,y), value, font=font(size,bold), fill=color)

    def line(points,color=MUTED,width=2):
        d.line(points,fill=color,width=width)

    def card(box):
        d.rounded_rectangle(box,radius=22,fill=PANEL)

    text(60,30,'DAGGER / MAP STUDY 02',21,TEAL,True)
    text(60,69,'Dagger train home - enlarged draft',50,bold=True)
    text(60,137,'Static source diagram | North up | Original prototype geometry | Runtime integration disabled',24,MUTED)
    card((40,202,1210,1715))
    card((1240,202,2160,894))
    card((1240,919,2160,1715))
    text(70,222,'01  EXPANDED TRAIN',26,bold=True)
    text(70,262,f'15 x 51 -> {WIDTH} x {LENGTH} tiles',23,MUTED)
    text(646,222,'ROOM DIRECTORY',25,bold=True)
    text(646,263,'Numbers locate the actual source bounds.',21,MUTED)
    ox,oy,c=140,305,13

    def box(x,y,cell=c,start=(ox,oy),length=LENGTH):
        px,py=start[0]+x*cell,start[1]+(length-1-y)*cell
        return px,py,px+cell-1,py+cell-1

    def drawtile(x,y,kind,cell=c,start=(ox,oy),length=LENGTH,details=True):
        a,b,e,f=box(x,y,cell,start,length)
        protected=y<=layout['protected']['bounds'][3]
        base='#264d4d' if protected else '#695334'
        if kind=='hull': base='#667c87'
        elif kind in ('door','gate','inner_gate'): base='#f4ce77'
        d.rectangle((a,b,e,f),fill=base,outline='#243742')
        if not details: return
        color='#d8e5df' if protected else '#f4d7a5'
        pad=max(2,cell//5)
        if kind=='bed':
            d.rectangle((a+pad,b+pad,e-pad,f-pad),outline=color,width=1)
            line([(a+pad,b+pad+2),(e-pad,b+pad+2)],color,1)
        elif kind=='crate':
            d.rectangle((a+pad,b+pad,e-pad,f-pad),outline=color,width=1)
            line([(a+pad,b+pad),(e-pad,f-pad)],color,1)
        elif kind=='rack':
            for fraction in (.3,.5,.7):
                yy=b+int(cell*fraction)
                line([(a+pad,yy),(e-pad,yy)],color,1)
        elif kind=='table': d.rectangle((a+pad,b+pad,e-pad,f-pad),fill=color)
        elif kind=='chair': d.arc((a+pad,b+pad,e-pad,f-pad),0,300,fill=color,width=2)
        elif kind in ('anvil','sink','toilet'):
            text(a+1,b-2,{'anvil':'A','sink':'S','toilet':'T'}[kind],max(10,cell-2),color,True)
        elif kind=='dirt': d.ellipse((a+3,b+4,a+5,b+6),fill='#a59069')

    for (x,y),kind in tiles.items(): drawtile(x,y,kind)
    for pad in layout['build_pads']:
        x0,y0,x1,y1=pad['bounds']
        a,b,_,_=box(x0,y1)
        _,_,e,f=box(x1,y0)
        d.rectangle((a+1,b+1,e-1,f-1),outline=AMBER,width=2)
        text(a+10,b+12,f'{x1-x0+1} x {y1-y0+1}',18,AMBER,True)
    for i,room in enumerate(layout['rooms'],1):
        x0,y0,x1,y1=room['bounds']
        a,b,_,_=box((x0+x1)/2,(y0+y1)/2)
        # High-contrast badges identify rooms without replacing source furniture.
        color=TEAL if room['protected'] else AMBER
        d.ellipse((a-11,b-8,a+19,b+22),fill=BG,outline=color,width=2)
        text(a-5,b-9,f'{i:02}',16,color,True)
        yy=315+(i-1)*48
        text(646,yy,f'{i:02}',22,color,True)
        text(696,yy,room['name'],22,TEXT)
    text(76,346,'N',23,TEAL,True)
    line([(88,338),(88,308)],TEAL,3)
    d.polygon([(88,301),(81,314),(95,314)],fill=TEAL)
    text(646,1005,'4-wide central aisle',23,AMBER,True)
    text(646,1041,'3-wide boarding passages remain clear.',21,MUTED)

    airlock=layout['protected']['airlock']
    ax0,ay0,ax1,ay1=airlock['bounds']
    card((626,1110,1178,1537))
    text(650,1133,'PARTY-ONLY AIRLOCK',24,TEAL,True)
    zoom=32
    zx,zy=658,1190
    for yy in range(ay0,ay1+1):
        for xx in range(ax0,ax1+1):
            drawtile(xx-ax0,yy-ay0,tiles[xx,yy],zoom,(zx,zy),ay1-ay0+1,False)
    for name,label in (('outer_door','Outer'),('inner_door','Inner')):
        xx,yy=airlock[name]
        a,b,_,_=box(xx-ax0,yy-ay0,zoom,(zx,zy),ay1-ay0+1)
        line([(a+zoom/2,b+zoom/2),(903,b+zoom/2)],TEAL,2)
        text(920,b+3,label,20,TEAL,True)
    ix0,iy0,ix1,iy1=airlock['interior_bounds']
    text(888,1261,f'{ix1-ix0+1} x {iy1-iy0+1}',24,TEAL,True)
    text(888,1295,'interior',19,MUTED)
    text(650,1434,'Two-door interlock + party authorization',20,TEXT,True)
    text(650,1470,'Required; runtime implementation pending.',19,MUTED)
    sustenance=layout['protected']['sustenance']['bounds']
    text(646,1570,f'SAFE SUSTENANCE / Y{sustenance[1]}..{sustenance[3]}',23,TEAL,True)
    text(646,1604,'Nutrition + hydration recover to healthy caps.',20,TEXT)
    text(646,1637,'Recovery rate unselected; implementation pending.',19,MUTED)
    text(140,1656,'Full rectangular footprint includes every coupling corner.',20,MUTED)

    def stage(x,y,z,scale=2):
        for (wx,wy,wz),(kind,area) in grid.items():
            if wz!=z: continue
            px,py=x+(wx-1)*scale,y+(world['height']-wy)*scale
            d.rectangle((px,py,px+scale-1,py+scale-1),fill=PALETTE[kind][1])
        for slot in layout['slots']:
            if slot['origin'][2]!=z: continue
            sx,sy,_=slot['origin']
            a,b=x+(sx-1)*scale,y+(world['height']-(sy+LENGTH-1))*scale
            d.rectangle((a,b,a+WIDTH*scale-1,b+LENGTH*scale-1),outline=TEAL if z==1 else AMBER,width=2)
        return lambda wx,wy:(x+(wx-1)*scale+scale/2,y+(world['height']-wy)*scale+scale/2)

    text(1275,226,'02  SEPARATED HOMES / Z1',27,bold=True)
    text(1275,268,'One furnished prototype; second home slot empty.',22,MUTED)
    stage(1440,318,1)
    text(1450,844,'Home west',22,TEAL,True)
    text(1770,844,'Home east',22,TEAL,True)
    text(1275,944,'03  PARALLEL RAID BERTHS / Z2',27,bold=True)
    text(1275,986,'Two independent arrivals + common boarding platform',22,MUTED)
    project=stage(1440,1035,2)
    for slot in layout['slots']:
        if slot['kind']!='raid_berth': continue
        sx,sy,_=slot['origin']
        portx=sx+WIDTH-1 if slot['platform_side']=='east' else sx
        for ax,ay,az in slot['platform_anchors']:
            line([project(portx,ay),project(ax,ay)],'#fff0bd',4)
            px,py=project(ax,ay)
            d.ellipse((px-4,py-4,px+4,py+4),fill='#fff0bd')
    text(1415,1568,'West berth',22,AMBER,True)
    text(1818,1568,'East berth',22,AMBER,True)
    text(1275,1611,'Reserve selected berth + own full footprint only.',22,TEXT,True)
    text(1275,1649,'Other berth stays available; pair group is geometry only.',21,MUTED)

    text(60,1742,'Protected intent',24,TEAL,True)
    text(305,1742,'Exposed carriage',24,AMBER,True)
    text(600,1742,'Furniture: outlined bunk / crossed crate / rack / table / A anvil / S sink / T toilet',21,MUTED)
    text(60,1787,f'Staging 128 x 128 x 2 -> {world["width"]} x {world["height"]} x {world["levels"]} | 4x tiles per level; no z-level added.',25,TEXT,True)
    text(60,1830,'PROTOTYPE ONLY - Protection, airlock interlock, sustenance, movement and persistence remain unimplemented.',23,TEXT,True)
    text(60,1868,'Demo slots and furnishings do not define a production party cap. Static source diagram, not native rendering or gameplay evidence.',20,MUTED)
    OUTPUT.parent.mkdir(parents=True,exist_ok=True)
    im.save(OUTPUT)
    print(OUTPUT)


if __name__=='__main__': main()

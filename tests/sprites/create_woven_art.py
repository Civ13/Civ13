# Hand-coded pixel art for Civ13 weaving (Pillow, pixels placed procedurally). No image generation.
import json, math, os, re, sys
from PIL import Image, ImageDraw, PngImagePlugin
OUT=(sys.argv[1] if len(sys.argv)>1 else '.').rstrip('/')+'/'  # then copy <format>.dmi to icons/obj/woven_<format>.dmi
REPO=os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))+'/'
CREAM=(232,220,190,255); CREAM_D=(204,188,152,255); CREAM_DD=(170,152,116,255)
BIND=(188,166,124,255); BIND_D=(150,128,90,255); BIND_L=(210,192,152,255)
OUTL=(58,38,24,255)
ROD_L=(158,108,60,255); ROD_M=(122,78,42,255); ROD_D=(86,54,30,255)
CORD=(140,52,40,255); CORD_D=(98,34,28,255)

FORMATS={
 'rug_small':   dict(icon_w=32,icon_h=32,left=2,top=5,w=28,h=22),
 'rug_runner':  dict(icon_w=64,icon_h=32,left=6,top=4,w=52,h=24),
 'rug_large':   dict(icon_w=64,icon_h=64,left=3,top=7,w=58,h=50),
 'tapestry':    dict(icon_w=32,icon_h=32,left=5,top=7,w=22,h=19),
 'tapestry_wide':dict(icon_w=64,icon_h=32,left=6,top=7,w=52,h=19),
}
FRINGE={'rug_small':'v','rug_runner':'h','rug_large':'v'}

def new(f): return Image.new('RGBA',(f['icon_w'],f['icon_h']),(0,0,0,0))
def P(im,x,y,c):
    if 0<=x<im.width and 0<=y<im.height: im.putpixel((x,y),c)

def rug_edge(name):
    f=FORMATS[name]; im=new(f); L,T,W,H=f['left'],f['top'],f['w'],f['h']; R=L+W-1; B=T+H-1
    # weave texture inside the art rect: faint alternating rows + sparse warp flecks
    for y in range(T,B+1):
        for x in range(L,R+1):
            a=0; col=(0,0,0)
            if (y-T)%2==1: a=20
            elif (x+y)%4==0: col=(255,255,255); a=12
            # darker border, 2 px falloff
            d=min(x-L,R-x,y-T,B-y)
            if d==0: col=(0,0,0); a=max(a,0)+44
            elif d==1: 
                if col==(255,255,255): a=0
                col=(0,0,0); a+=16
            if a: P(im,x,y,col+(a,))
    # 1 px binding around the art
    for x in range(L-1,R+2):
        P(im,x,T-1,BIND_L if x%2 else BIND); P(im,x,B+1,BIND_D if x%2 else BIND)
    for y in range(T-1,B+2):
        P(im,L-1,y,BIND_L if y%2 else BIND); P(im,R+1,y,BIND_D if y%2 else BIND)
    for (x,y) in ((L-1,T-1),(R+1,T-1),(L-1,B+1),(R+1,B+1)): P(im,x,y,BIND_D)
    # fringe (undyed cream wool), 3 px, at the short ends
    if FRINGE[name]=='v':
        for x in range(L-1,R+2):
            ln=3 if (x*7)%5 else 2
            for i in range(1,4):
                for y,last in ((T-1-i,i==ln),(B+1+i,i==ln)):
                    if i>ln: continue
                    if x%2==0: P(im,x,y,CREAM_D if last and i==3 else CREAM)
                    elif i==1: P(im,x,y,CREAM_DD)
        for x in range(L-1,R+2): P(im,x,B+2,CREAM_D if x%2==0 else CREAM_DD)   # underside knots slightly darker
        for x in range(L,R+3): P(im,x,B+5,(0,0,0,38)) if x%2==0 else None
    else:
        for y in range(T-1,B+2):
            ln=3 if (y*7)%5 else 2
            for i in range(1,4):
                if i>ln: continue
                for x in (L-1-i,R+1+i):
                    if y%2==0: P(im,x,y,CREAM_D if i==3 else CREAM)
                    elif i==1: P(im,x,y,CREAM_DD)
        for x in range(L,R+2): P(im,x,B+2,(0,0,0,48))   # contact shadow on the floor
    if FRINGE[name]=='v':
        for y in range(T,B+2): P(im,R+2,y,(0,0,0,40))
    return im

def tap_edge(name):
    f=FORMATS[name]; im=new(f); L,T,W,H=f['left'],f['top'],f['w'],f['h']; R=L+W-1; B=T+H-1
    period=11.0
    for y in range(T,B+1):
        for x in range(L,R+1):
            s=math.sin((x-L+2)*2*math.pi/period)
            dark=0; light=0
            if s<-0.55: dark=26
            elif s<-0.1: dark=12
            elif s>0.7: light=20
            if (y-T)%2==1: dark+=14
            if y==T: dark+=46          # shadow cast by rod / casing
            elif y==T+1: dark+=20
            if x==L or x==R: dark+=30
            if y==B: dark+=26
            if dark: P(im,x,y,(0,0,0,min(dark,110)))
            elif light: P(im,x,y,(255,255,255,light))
    # side selvedge + casing + hem
    for y in range(T-1,B+2):
        P(im,L-1,y,BIND_L if y%2 else BIND); P(im,R+1,y,BIND_D if y%2 else BIND)
    for x in range(L-1,R+2):
        P(im,x,T-1,BIND if x%2 else BIND_L)
        P(im,x,B+1,BIND if x%2 else BIND_D)
    # tassel fringe under the hem
    for x in range(L-1,R+2):
        if x%2==0:
            P(im,x,B+2,CREAM); P(im,x,B+3,CREAM_D if (x//2)%3 else CREAM)
            if (x//2)%3==0: P(im,x,B+4,CREAM_D)
        else: P(im,x,B+2,CREAM_DD)
    # hanging loops over the rod
    ry=T-5   # rod rows ry..ry+2
    x=L
    step=5 if W<30 else 6
    xs=list(range(L+1,R-1,step))
    # spread loops symmetric
    n=len(xs); span=(n-1)*step+2; x0=L+(W-span)//2
    for i in range(n):
        lx=x0+i*step
        for yy in range(ry-1,T-1):
            P(im,lx,yy,CREAM if yy<ry+2 else CREAM_D); P(im,lx+1,yy,CREAM_D if yy<ry+2 else CREAM_DD)
        P(im,lx,ry-1,BIND_L); P(im,lx+1,ry-1,BIND)
    loops=set()
    for i in range(n): loops|={x0+i*step,x0+i*step+1}
    # wooden rod with finials
    for x in range(L-3,R+4):
        if x in loops: continue
        P(im,x,ry,ROD_L); P(im,x,ry+1,ROD_M); P(im,x,ry+2,ROD_D)
    for fx,sgn in ((L-4,-1),(R+4,1)):
        for yy,c in ((ry-1,ROD_L),(ry,ROD_L),(ry+1,ROD_M),(ry+2,ROD_D),(ry+3,ROD_D)):
            P(im,fx,yy,c)
        P(im,fx+sgn,ry,ROD_M); P(im,fx+sgn,ry+1,ROD_M); P(im,fx+sgn,ry+2,ROD_D)
        P(im,fx,ry-1,OUTL) if False else None
    P(im,L-4,ry,(196,146,88,255)); P(im,R+4,ry,(196,146,88,255))
    # rod shadow on wall + cloth drop shadow
    for x in range(L-3,R+4):
        if im.getpixel((x,ry+3))[3]==0: P(im,x,ry+3,(0,0,0,50))
    for y in range(T,B+3): P(im,R+2,y,(0,0,0,44))
    return im

def roll(f,length,rad,ties):
    """Rolled rug lying on its side: undyed wool back showing, spiral end at the right."""
    im=new(f); cx=f['icon_w']//2; cy=f['icon_h']//2
    x0=cx-length//2; x1=x0+length-1; y0=cy-rad; y1=cy+rad
    shades=[CREAM,CREAM,CREAM_D,CREAM_D,CREAM_DD]
    hgt=y1-y0+1
    for y in range(y0,y1+1):
        t=(y-y0)/(hgt-1)
        c=(240,230,204,255) if t<0.12 else CREAM if t<0.45 else CREAM_D if t<0.75 else CREAM_DD
        inset=1 if y in (y0,y1) else 0
        for x in range(x0+inset,x1+1-inset):
            cc=c
            if (x+y)%3==0 and y not in (y0,):  # weave fleck
                cc=tuple(max(0,v-14) for v in c[:3])+(255,)
            P(im,x,y,cc)
    # outline
    for x in range(x0+1,x1): P(im,x,y0-1,OUTL); P(im,x,y1+1,OUTL)
    for y in range(y0+1,y1): P(im,x0-1,y,OUTL)
    P(im,x0,y0,OUTL); P(im,x0,y1,OUTL)
    # spiral end cap (ellipse, 4 wide)
    ex=x1-1
    for y in range(y0,y1+1):
        t=abs((y-cy)/(rad+0.5))
        wdt=2 if t<0.75 else 1
        for dx in range(-wdt,wdt+1): P(im,ex+dx,y,BIND_L if dx<=0 else BIND)
        P(im,ex+wdt+1,y,OUTL); 
    P(im,ex,y0-1,OUTL);P(im,ex+1,y0-1,OUTL);P(im,ex,y1+1,OUTL);P(im,ex+1,y1+1,OUTL)
    P(im,ex-1,y0-1,OUTL);P(im,ex-1,y1+1,OUTL)
    # spiral lines
    for y in range(y0+1,y1): P(im,ex-2 if abs(y-cy)<rad-1 else ex-1,y,BIND_D)
    for y in range(cy-max(1,rad-2),cy+max(1,rad-2)+1): P(im,ex+1,y,BIND_D)
    P(im,ex,cy-max(1,rad-2),BIND_D); P(im,ex,cy+max(1,rad-2),BIND_D) if rad>3 else None
    P(im,ex,cy,CREAM_DD) if rad<=3 else P(im,ex,cy,OUTL)
    # fringe peeking from the loose flap along the bottom-left
    for x in range(x0+2,ex-4,2): P(im,x,y1,CREAM); 
    # tie cords
    for tx in ties:
        X=x0+tx
        for y in range(y0,y1+1): P(im,X,y,CORD if y<cy+1 else CORD_D)
        P(im,X,y0-1,CORD_D); P(im,X,y1+1,CORD_D)
    # ground shadow
    for x in range(x0+1,x1+2): P(im,x,y1+2,(0,0,0,46))
    return im

def folded(f,wd,with_rod_len):
    """Folded tapestry: stacked cloth layers with the rod laid on top."""
    im=new(f); cx=f['icon_w']//2; cy=f['icon_h']//2+1
    x0=cx-wd//2; x1=x0+wd-1; top=cy-5; 
    # top face (parallelogram-ish, 3/4 view): rows top..top+5
    for y in range(top,top+6):
        for x in range(x0,x1+1):
            c=CREAM if (x+y)%4 else (240,230,204,255)
            if y==top: c=(240,230,204,255)
            P(im,x,y,c)
    # dyed stripe hint is not assumed: keep undyed, add woven band lines
    for x in range(x0+2,x1-1): P(im,x,top+2,CREAM_D) if x%2 else None
    # front face: 3 folded layers, 2 px each
    for i in range(3):
        yy=top+6+i*2
        for x in range(x0,x1+1):
            P(im,x,yy,CREAM_D); P(im,x,yy+1,CREAM_DD)
        P(im,x1,yy,CREAM_DD); P(im,x0,yy,CREAM)
    bot=top+11
    # fringe at right edge of top layer
    for y in range(top+1,top+6,2): P(im,x1+1,y,CREAM)
    # outline
    for x in range(x0,x1+1): P(im,x,top-1,OUTL); P(im,x,bot+1,OUTL)
    for y in range(top,bot+1): P(im,x0-1,y,OUTL); P(im,x1+1,y,OUTL) if im.getpixel((x1+1,y))[3]==0 else None
    for y in range(top+1,top+6,2): P(im,x1+2,y,OUTL)
    # rod on top, diagonal-free: horizontal, overhanging both sides
    rl=with_rod_len; rx0=cx-rl//2; ry=top+3
    for x in range(rx0,rx0+rl):
        P(im,x,ry,ROD_L); P(im,x,ry+1,ROD_D)
    P(im,rx0-1,ry,ROD_M);P(im,rx0-1,ry+1,ROD_D);P(im,rx0-1,ry-1,ROD_L)
    P(im,rx0+rl,ry,ROD_M);P(im,rx0+rl,ry+1,ROD_D);P(im,rx0+rl,ry-1,ROD_L)
    for x in range(x0,x1+1): P(im,x,ry+2,(0,0,0,50)) if True else None
    # tie cord
    for y in range(top,bot+1): P(im,cx,y,CORD if y<top+6 else CORD_D)
    for x in range(x0,x1+2): P(im,x,bot+2,(0,0,0,46))
    return im

def write_dmi(name,states):
    f=FORMATS[name]; w,h=f['icon_w'],f['icon_h']
    sheet=Image.new('RGBA',(w*len(states),h),(0,0,0,0))
    d='# BEGIN DMI\nversion = 4.0\n\twidth = %d\n\theight = %d\n'%(w,h)
    for i,(s,im) in enumerate(states):
        sheet.paste(im,(i*w,0)); d+='state = "%s"\n\tdirs = 1\n\tframes = 1\n'%s
    d+='# END DMI\n'
    info=PngImagePlugin.PngInfo(); info.add_text('Description',d,zip=True)
    sheet.save(OUT+name+'.dmi',format='PNG',pnginfo=info)

ITEMS={
 'rug_small':  lambda f: roll(f,20,3,[5,13]),
 'rug_runner': lambda f: roll(f,26,4,[6,12,18]),
 'rug_large':  lambda f: roll(f,30,6,[6,14,22]),
 'tapestry':   lambda f: folded(f,14,18),
 'tapestry_wide': lambda f: folded(f,20,26),
}
SPR={}
for n,f in FORMATS.items():
    edge=rug_edge(n) if n.startswith('rug') else tap_edge(n)
    item=ITEMS[n](f)
    SPR[n]=(new(f),edge,item)
    write_dmi(n,[('blank',SPR[n][0]),('edge',edge),('item',item)])
json.dump(FORMATS,open(OUT+'formats.json','w'),indent=1)

# ---------- preview ----------
def state(dmi,st):
    im=Image.open(REPO+dmi); d=im.info['Description']
    names=re.findall(r'state = "(.*?)"\n\tdirs = (\d+)\n\tframes = (\d+)',d)
    w=int(re.search(r'width = (\d+)',d).group(1)); h=int(re.search(r'height = (\d+)',d).group(1))
    i=0
    for nm,dr,fr in names:
        if nm==st: break
        i+=int(dr)*int(fr)
    cols=im.width//w
    return im.convert('RGBA').crop(((i%cols)*w,(i//cols)*h,(i%cols)*w+w,(i//cols)*h+h))
FLOOR=state('icons/turf/floors.dmi','wood'); WALL=state('icons/turf/walls.dmi','stone_brick')
RED=(150,44,36,255); IND=(40,58,110,255); OCH=(206,160,62,255); IV=(230,218,188,255); GRN=(58,104,70,255)
def kilim(w,h):
    im=Image.new('RGBA',(w,h),RED)
    for y in range(h):
        for x in range(w):
            d=min(x,w-1-x,y,h-1-y)
            if d==0: c=IND
            elif d==1: c=OCH if (x+y)%2 else IND
            elif d==2: c=IND
            else:
                u=abs((x-2)%12-5.5)+abs((y-2)%12-5.5)   # repeating diamonds
                k=int(u)
                c=IV if k in(0,) else IND if k in(1,2) else OCH if k==3 else RED if k<8 else GRN if k<10 else IV
            im.putpixel((x,y),c)
    return im
def stripes(w,h):
    im=Image.new('RGBA',(w,h),IND)
    for y in range(h):
        for x in range(w):
            if (y//3)%2: im.putpixel((x,y),OCH)
    return im
def comp(n,art):
    f=FORMATS[n]; base=SPR[n][0].copy()
    base.paste(art,(f['left'],f['top']))          # art rectangle first
    return Image.alpha_composite(base,SPR[n][1])  # edge on top
Z=4; PAD=8
rows=[]
for n,f in FORMATS.items():
    bg=FLOOR if n.startswith('rug') else WALL
    cells=[]
    for lab,im in (('kilim',comp(n,kilim(f['w'],f['h']))),('stripe',comp(n,stripes(f['w'],f['h']))),('item',SPR[n][2]),('edge only',SPR[n][1])):
        cw,ch=f['icon_w']+2*PAD,f['icon_h']+2*PAD
        c=Image.new('RGBA',(cw,ch))
        for ty in range(-1,ch//32+2):
            for tx in range(-1,cw//32+2): c.paste(bg,(PAD-32+tx*32,PAD-32+ty*32))
        if lab=='edge only':
            c=Image.new('RGBA',(cw,ch),(60,60,66,255))
            for y in range(ch):
                for x in range(cw):
                    if (x//4+y//4)%2: c.putpixel((x,y),(76,76,84,255))
        c.alpha_composite(im,(PAD,PAD))
        cells.append((lab,c.resize((cw*Z,ch*Z),Image.NEAREST)))
    rows.append((n,f,cells))
Wd=40+sum(c.width+16 for _,c in max(rows,key=lambda r:r[1]['icon_w'])[2]); Ht=40+sum(r[2][0][1].height+34 for r in rows)
pv=Image.new('RGBA',(Wd,Ht),(34,32,36,255)); dr=ImageDraw.Draw(pv)
dr.text((16,10),'Civ13 weaving - 4x preview: art rectangle, then edge on top; item = carried state',fill=(240,236,224))
y=34
for n,f,cells in rows:
    dr.text((16,y),'%s.dmi  %dx%d  art rect left=%d top=%d w=%d h=%d'%(n,f['icon_w'],f['icon_h'],f['left'],f['top'],f['w'],f['h']),fill=(250,214,130))
    x=16
    for lab,c in cells:
        pv.paste(c,(x,y+14)); dr.text((x+4,y+16),lab,fill=(255,255,255),stroke_width=1,stroke_fill=(0,0,0)); x+=c.width+16
    y+=cells[0][1].height+34
pv.save(OUT+'weaving-preview.png')
print(pv.size)

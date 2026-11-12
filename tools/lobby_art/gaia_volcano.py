"""Builds icons/lobby/gaia_volcano.dmi: the Gaia volcano crater as the lobby picture.
State "lobby" is the still backdrop; state "lobby_particles" is a looping, mostly
transparent ember animation the lobby screen adds on top (BLEND_ADD).
Input: a byond-devtools render of maps/nomads/nomads_gaia.dmm, z1, tiles x378-467 y160-239, 32 px/tile.
Render it with byond-devtools:
  node src/cli.js render --root <Civ13> --map maps/nomads/nomads_gaia.dmm --dme civ13.dme --tree tree.xml --z 1 --x1 378 --y1 160 --x2 467 --y2 239 --icon-size 32 --out gaia.png
Then:
  python3 tools/lobby_art/gaia_volcano.py gaia.png icons/lobby/gaia_volcano.dmi [preview.gif]
Only game sprites, scaled and lit; the embers are plain pixels placed by a seeded loop."""
import sys, math, random
import numpy as np
from PIL import Image
from PIL.PngImagePlugin import PngInfo
SRC, OUT = sys.argv[1], sys.argv[2]
N=480; FRAMES=48; EMBERS=44
G=Image.open(SRC).convert('RGB')
a=np.asarray(G).astype(int); m=(a[...,0]>180)&(a[...,2]<90)&(a[...,1]<140)   # lava pixels
ys,xs=np.where(m); cx=int((xs.min()+xs.max())/2)//32*32+16; cy=int((ys.min()+ys.max())/2)//32*32+16
crop=G.crop((cx-N,cy-N,cx+N,cy+N)); lava=Image.fromarray((m[cy-N:cy+N,cx-N:cx+N]*255).astype(np.uint8)).resize((N,N),Image.NEAREST)
im=np.asarray(crop.resize((N,N),Image.BOX)).astype(np.float32)   # exact 2:1 reduction, 16 px tiles
yy,xx=np.mgrid[0:N,0:N]; d=np.hypot(xx-N/2,yy-N/2)
im*= (0.16+0.84*np.clip(1-d/(N*0.74),0,1)**1.3)[...,None]                       # night falls off from the crater
im+= (np.clip(1-d/(N*0.52),0,1)**2*0.42)[...,None]*np.array([255,110,30],np.float32)   # lava light
back=Image.fromarray(im.clip(0,255).astype(np.uint8)).convert('RGBA')
lv=np.argwhere(np.asarray(lava)>0)
r=random.Random(13); E=[]
for i in range(EMBERS):
    y0,x0=lv[r.randrange(len(lv))]
    E.append(dict(x=float(x0),y=float(y0),ph=r.random(),c=r.choice([1,1,2]),rise=r.uniform(70,170),amp=r.uniform(3,9),m=r.choice([1,2,3]),sp=r.random()*math.tau,
                  drift=r.uniform(-18,18),big=r.random()<0.3,tw=r.choice([5,7,9,11]),tp=r.random()*math.tau,col=r.choice([(255,190,80),(255,150,50),(255,220,130)])))
def frame(f):
    buf=np.zeros((N,N,4),np.float32); t=f/FRAMES
    for e in E:
        life=(e['c']*t+e['ph'])%1.0
        x=e['x']+e['drift']*life+e['amp']*math.sin(math.tau*e['m']*t+e['sp']); y=e['y']-e['rise']*life
        b=math.sin(math.pi*life)**0.6*(0.75+0.25*math.sin(math.tau*e['tw']*t+e['tp']))
        xi,yi=int(round(x)),int(round(y))
        cells=[(0,0,1.0)]+[(dx,dy,0.28) for dx,dy in ((1,0),(-1,0),(0,1),(0,-1))]
        if e['big']: cells=[(0,0,1.0),(1,0,1.0),(0,1,1.0),(1,1,1.0)]+[(dx,dy,0.3) for dx,dy in ((-1,0),(-1,1),(2,0),(2,1),(0,-1),(1,-1),(0,2),(1,2))]
        for dx,dy,w in cells:
            px,py=xi+dx,yi+dy
            if 0<=px<N and 0<=py<N:
                al=b*w
                if al>buf[py,px,3]: buf[py,px]=(*e['col'],al)
    buf[...,3]*=255; return Image.fromarray(buf.clip(0,255).astype(np.uint8),'RGBA')
frames=[frame(f) for f in range(FRAMES)]
cols=7; rows=math.ceil((1+FRAMES)/cols); sheet=Image.new('RGBA',(cols*N,rows*N),(0,0,0,0))
for i,c in enumerate([back]+frames): sheet.paste(c,((i%cols)*N,(i//cols)*N))
desc='# BEGIN DMI\nversion = 4.0\n\twidth = %d\n\theight = %d\nstate = "lobby"\n\tdirs = 1\n\tframes = 1\nstate = "lobby_particles"\n\tdirs = 1\n\tframes = %d\n\tdelay = %s\n# END DMI\n'%(N,N,FRAMES,','.join(['1']*FRAMES))
info=PngInfo(); info.add_text('Description',desc,zip=True)
sheet.save(OUT,'PNG',pnginfo=info,optimize=True)
if len(sys.argv)>3:
    out=[]
    for fr in frames:   # preview composites the embers additively, as BLEND_ADD does in the client
        b=np.asarray(back).astype(np.float32); e=np.asarray(fr).astype(np.float32)
        b[...,:3]+=e[...,:3]*e[...,3:4]/255; out.append(Image.fromarray(b.clip(0,255).astype(np.uint8)).convert('RGB').resize((N*2,N*2),Image.NEAREST) if 'x2' in sys.argv else Image.fromarray(b.clip(0,255).astype(np.uint8)).convert('RGB'))
    out[0].save(sys.argv[3],save_all=True,append_images=out[1:],duration=100,loop=0)
    out[10].save(sys.argv[3].replace('.gif','-still.png'))

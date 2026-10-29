"""Dependency-free typed IR preview. Not a Civ13 screenshot or gameplay rendering."""
import struct
import zlib
from pathlib import Path
from .validator import canonical_hash

FONT={
'A':'01110/10001/10001/11111/10001/10001/10001','B':'11110/10001/10001/11110/10001/10001/11110',
'C':'01111/10000/10000/10000/10000/10000/01111','D':'11110/10001/10001/10001/10001/10001/11110',
'E':'11111/10000/10000/11110/10000/10000/11111','F':'11111/10000/10000/11110/10000/10000/10000',
'G':'01111/10000/10000/10111/10001/10001/01111','H':'10001/10001/10001/11111/10001/10001/10001',
'I':'11111/00100/00100/00100/00100/00100/11111','J':'00111/00010/00010/00010/10010/10010/01100',
'K':'10001/10010/10100/11000/10100/10010/10001','L':'10000/10000/10000/10000/10000/10000/11111',
'M':'10001/11011/10101/10101/10001/10001/10001','N':'10001/11001/10101/10011/10001/10001/10001',
'O':'01110/10001/10001/10001/10001/10001/01110','P':'11110/10001/10001/11110/10000/10000/10000',
'Q':'01110/10001/10001/10001/10101/10010/01101','R':'11110/10001/10001/11110/10100/10010/10001',
'S':'01111/10000/10000/01110/00001/00001/11110','T':'11111/00100/00100/00100/00100/00100/00100',
'U':'10001/10001/10001/10001/10001/10001/01110','V':'10001/10001/10001/10001/10001/01010/00100',
'W':'10001/10001/10001/10101/10101/10101/01010','X':'10001/10001/01010/00100/01010/10001/10001',
'Y':'10001/10001/01010/00100/00100/00100/00100','Z':'11111/00001/00010/00100/01000/10000/11111',
'0':'01110/10011/10101/10101/11001/10001/01110','1':'00100/01100/00100/00100/00100/00100/01110',
'2':'01110/10001/00001/00010/00100/01000/11111','3':'11110/00001/00001/01110/00001/00001/11110',
'4':'00010/00110/01010/10010/11111/00010/00010','5':'11111/10000/10000/11110/00001/00001/11110',
'6':'01110/10000/10000/11110/10001/10001/01110','7':'11111/00001/00010/00100/01000/01000/01000',
'8':'01110/10001/10001/01110/10001/10001/01110','9':'01110/10001/10001/01111/00001/00001/01110',
'-':'00000/00000/00000/11111/00000/00000/00000',':':'00000/00100/00100/00000/00100/00100/00000',
'.':'00000/00000/00000/00000/00000/00100/00100','/':'00001/00010/00010/00100/01000/01000/10000',
' ':'00000/00000/00000/00000/00000/00000/00000'}
COLORS={"TEMPERATE":(121,162,93),"COAST":(134,174,117),"LUSH":(69,143,76),"STEPPE":(177,177,98),"ARID":(206,173,110),
        "DESERT":(222,196,139),"HILL":(170,143,105),"MOUNTAIN":(72,77,71),"BEACH":(227,210,159),
        "RIVER":(48,140,210),"LAKE":(45,110,176),"SEA":(24,66,112),"SWAMP":(96,146,143),
        "TREE":(25,69,47),"START":(255,219,72),"RESOURCE":(239,242,221),"PORT":(255,153,66),"JUNCTION":(221,109,255)}


def render(doc,path):
    tile=4 if doc["width"]>100 else 6
    mw,mh=doc["width"]*tile,doc["height"]*tile
    ocean=doc['profile']=='OCEANIC'
    width=max(900,mw+320);height=max(700 if doc.get('junctions') or ocean else 640,mh+150)
    pixels=bytearray(bytes((18,29,36))*(width*height))
    def rect(x,y,w,h,color):
        for yy in range(max(0,y),min(height,y+h)):
            left=max(0,x);right=min(width,x+w)
            if right>left:pixels[(yy*width+left)*3:(yy*width+right)*3]=bytes(color)*(right-left)
    def text(x,y,value,color=(226,234,232),scale=2):
        for letter in str(value).upper():
            rows=FONT.get(letter,FONT[' ']).split('/')
            for yy,row in enumerate(rows):
                for xx,b in enumerate(row):
                    if b=='1':rect(x+xx*scale,y+yy*scale,scale,scale,color)
            x+=6*scale
    text(24,20,'OFFLINE PROTOTYPE - NOT GAMEPLAY',scale=2)
    text(24,47,'SEED '+doc['seed']+'   '+str(doc['width'])+' X '+str(doc['height'])+'   SURFACE Z2',scale=2)
    text(24,73,'IR SHA256 '+canonical_hash(doc)[:24],scale=1)
    ox,oy=24,100
    for y,row in enumerate(doc["layers"]["SURFACE"]["cells"]):
        for x,c in enumerate(row):
            key=c["water"] if c["water"]!="NONE" else c["terrain"] if c["terrain"] in {"MOUNTAIN","HILL","BEACH"} else c["biome"]
            px,py=ox+x*tile,oy+(doc['height']-1-y)*tile
            rect(px,py,tile,tile,COLORS.get(key,(140,140,140)))
            if c["tree"]!="NONE":rect(px+tile//2-1,py+tile//2-1,2,2,COLORS["TREE"])
            if c["resource"]!="NONE":rect(px+tile//2,py+tile//2,1,1,COLORS["RESOURCE"])
    for x,y,_ in doc["starts"]:
        px,py=ox+x*tile+tile//2,oy+(doc['height']-1-y)*tile+tile//2
        rect(px-3,py-1,7,3,COLORS['START']);rect(px-1,py-3,3,7,COLORS['START'])
    if doc.get('junctions'):
        for j in doc['junctions']:
            x,y,_=j['at'];px,py=ox+x*tile+tile//2,oy+(doc['height']-1-y)*tile+tile//2
            rect(px-4,py-1,9,3,COLORS['JUNCTION']);rect(px-1,py-4,3,9,COLORS['JUNCTION'])
        for port in doc['ports']:
            for value in range(port['span'][0],port['span'][1]+1):
                x,y=(value,doc['height']-1) if port['side']=='N' else (value,0) if port['side']=='S' else (0,value) if port['side']=='W' else (doc['width']-1,value)
                rect(ox+x*tile,oy+(doc['height']-1-y)*tile,tile,tile,COLORS['PORT'])
    lx=ox+mw+25;text(lx,oy,'TYPED IR LEGEND',scale=2)
    if ocean:
        for port in doc['ports']:
            x,y,_=port['at'];rect(ox+x*tile,oy+(doc['height']-1-y)*tile,tile,tile,COLORS['PORT'])
    labels=['TEMPERATE','LUSH','STEPPE','ARID','DESERT']+(['COAST'] if ocean else [])+['RIVER','LAKE','SEA','SWAMP','MOUNTAIN','HILL','BEACH','TREE','START','RESOURCE']
    for i,label in enumerate(labels):
        yy=oy+35+i*25;rect(lx,yy,15,15,COLORS[label]);text(lx+24,yy+1,label,scale=1)
    text(lx,oy+440,'ABSTRACT SUPPLIES',scale=1)
    text(lx,oy+458,'ARE SIDECAR LABELS',scale=1)
    text(lx,oy+484,'NO MATCHING SEED CLAIM',scale=1)
    text(lx,oy+502,'NO NATIVE RUN',scale=1)
    if doc.get('junctions'):
        rect(lx,oy+532,15,15,COLORS['PORT']);text(lx+24,oy+535,'EDGE PORT SPAN',scale=1)
        rect(lx,oy+557,15,15,COLORS['JUNCTION']);text(lx+24,oy+560,'GRAPH CONFLUENCE',scale=1)
    elif ocean:
        rect(lx,oy+532,15,15,COLORS['PORT']);text(lx+24,oy+535,'OCEAN EDGE PORT',scale=1)
    text(24,oy+mh+20,'GENERATED DATA ONLY - MOUNTAINS ARE EXPLICIT IR TERRAIN',scale=1)
    def chunk(kind,data):return struct.pack('>I',len(data))+kind+data+struct.pack('>I',zlib.crc32(kind+data)&0xffffffff)
    raw=b''.join(b'\0'+pixels[y*width*3:(y+1)*width*3] for y in range(height))
    png=b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',width,height,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(raw,9))+chunk(b'IEND',b'')
    Path(path).write_bytes(png)
    return {"kind":"typed-generated-IR-preview","gameplay_capture":False,"width":width,"height":height,"ir_sha256":canonical_hash(doc)}

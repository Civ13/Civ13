"""Native trace sprite replay. Stdlib only; uses preinstalled ffmpeg, no download.

This is not a DreamSeeker capture. No interpolation or invented vehicle positions.
The map background/platform annotations are schematic; rail/vehicle/lever pixels
come from the exact-source DMI files and native appearance/direction observations.
"""
import argparse
import bisect
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess
import time
import zlib
import contract
from prepare import record

W,H,TILE,FPS = 1280,720,20,10
FONT = {
'A':'01110 10001 10001 11111 10001 10001 10001','B':'11110 10001 10001 11110 10001 10001 11110',
'C':'01111 10000 10000 10000 10000 10000 01111','D':'11110 10001 10001 10001 10001 10001 11110',
'E':'11111 10000 10000 11110 10000 10000 11111','F':'11111 10000 10000 11110 10000 10000 10000',
'G':'01111 10000 10000 10111 10001 10001 01111','H':'10001 10001 10001 11111 10001 10001 10001',
'I':'11111 00100 00100 00100 00100 00100 11111','J':'00001 00001 00001 00001 10001 10001 01110',
'K':'10001 10010 10100 11000 10100 10010 10001','L':'10000 10000 10000 10000 10000 10000 11111',
'M':'10001 11011 10101 10101 10001 10001 10001','N':'10001 11001 10101 10011 10001 10001 10001',
'O':'01110 10001 10001 10001 10001 10001 01110','P':'11110 10001 10001 11110 10000 10000 10000',
'Q':'01110 10001 10001 10001 10101 10010 01101','R':'11110 10001 10001 11110 10100 10010 10001',
'S':'01111 10000 10000 01110 00001 00001 11110','T':'11111 00100 00100 00100 00100 00100 00100',
'U':'10001 10001 10001 10001 10001 10001 01110','V':'10001 10001 10001 10001 10001 01010 00100',
'W':'10001 10001 10001 10101 10101 10101 01010','X':'10001 10001 01010 00100 01010 10001 10001',
'Y':'10001 10001 01010 00100 00100 00100 00100','Z':'11111 00001 00010 00100 01000 10000 11111',
'0':'01110 10001 10011 10101 11001 10001 01110','1':'00100 01100 00100 00100 00100 00100 01110',
'2':'01110 10001 00001 00010 00100 01000 11111','3':'11110 00001 00001 01110 00001 00001 11110',
'4':'00010 00110 01010 10010 11111 00010 00010','5':'11111 10000 10000 11110 00001 00001 11110',
'6':'01110 10000 10000 11110 10001 10001 01110','7':'11111 00001 00010 00100 01000 01000 01000',
'8':'01110 10001 10001 01110 10001 10001 01110','9':'01110 10001 10001 01111 00001 00001 01110',
'-':'00000 00000 00000 11111 00000 00000 00000',':':'00000 00100 00100 00000 00100 00100 00000',
'.':'00000 00000 00000 00000 00000 00100 00100','/':'00001 00010 00010 00100 01000 01000 10000',
'=':'00000 00000 11111 00000 11111 00000 00000','(':'00010 00100 01000 01000 01000 00100 00010',
')':'01000 00100 00010 00010 00010 00100 01000','+':'00000 00100 00100 11111 00100 00100 00000',
' ':'00000 00000 00000 00000 00000 00000 00000'}


def require(ok, why):
    if not ok: raise ValueError(why)


class DMI:
    def __init__(self, path):
        raw = Path(path).read_bytes()
        require(len(raw) < 1024**2 and raw[:8] == b'\x89PNG\r\n\x1a\n', 'DMI PNG bound/signature')
        pos = 8; data = bytearray(); desc = None; palette=None; alpha=b''
        while pos < len(raw):
            size = struct.unpack('>I',raw[pos:pos+4])[0]
            kind = raw[pos+4:pos+8]; chunk = raw[pos+8:pos+8+size]
            require(size <= 1024**2 and len(chunk)==size and pos+12+size<=len(raw), 'PNG chunk')
            require(zlib.crc32(kind+chunk) & 0xffffffff == struct.unpack('>I',raw[pos+8+size:pos+12+size])[0], 'PNG CRC')
            if kind == b'IHDR':
                self.w,self.h,depth,mode,comp,filt,inter = struct.unpack('>IIBBBBB',chunk)
                require(depth == 8 and mode in (3,6) and comp == filt == inter == 0 and self.w*self.h <= 1024**2, 'supported DMI PNG')
            if kind == b'PLTE':palette=chunk
            if kind == b'tRNS':alpha=chunk
            if kind == b'zTXt':
                key, value = chunk.split(b'\0',1)
                if key == b'Description':
                    decoder=zlib.decompressobj(); description=decoder.decompress(value[1:],65537)
                    require(value[0] == 0 and len(description)<=65536 and decoder.eof and not decoder.unused_data,'DMI metadata bound')
                    desc=description.decode('utf8')
            if kind == b'IDAT': data.extend(chunk)
            pos += size + 12
        channels=4 if mode==6 else 1
        stride=self.w*channels
        decoder=zlib.decompressobj(); decoded=decoder.decompress(data,self.h*(stride+1)+1)
        require(len(decoded)==self.h*(stride+1) and decoder.eof and not decoder.unused_data,'PNG image size')
        pixels=bytearray();prev=bytearray(stride)
        for y in range(self.h):
            f=decoded[y*(stride+1)]; row=bytearray(decoded[y*(stride+1)+1:(y+1)*(stride+1)])
            require(f in range(5),'PNG filter')
            for i in range(stride):
                a=row[i-channels] if i>=channels else 0;b=prev[i];c=prev[i-channels] if i>=channels else 0
                p=a+b-c;pa,pb,pc=abs(p-a),abs(p-b),abs(p-c)
                prediction=a if pa<=pb and pa<=pc else b if pb<=pc else c
                row[i]=(row[i]+(0,a,b,(a+b)//2,prediction)[f])&255
            pixels.extend(row);prev=row
        if mode==3:
            require(palette is not None and len(palette)%3==0 and len(palette)<=768,'PNG palette')
            rgba=bytearray()
            for index in pixels:
                require(index*3+3<=len(palette),'PNG palette index')
                rgba.extend(palette[index*3:index*3+3]);rgba.append(alpha[index] if index<len(alpha) else 255)
            pixels=rgba
        self.pixels=pixels;self.states={};index=0
        require(desc is not None and 'width = 32' in desc and 'height = 32' in desc,'32px DMI metadata')
        for match in re.finditer(r'state = "([^"]+)"\s+dirs = (\d+)\s+frames = (\d+)',desc):
            name,dirs,frames=match.group(1),int(match.group(2)),int(match.group(3))
            require(name not in self.states and dirs in (1,4,8) and 1<=frames<=128,'DMI state')
            self.states[name]=(index,dirs,frames);index+=dirs*frames
        require(index*32*32 <= self.w*self.h,'DMI atlas size')

    def sprite(self, name, direction):
        require(name in self.states, 'missing actual sprite '+name)
        start,dirs,frames=self.states[name]
        offset=(2,1,4,8,6,10,5,9).index(direction) if dirs>1 else 0
        require(offset<dirs,'DMI direction')
        index=start+offset;cols=self.w//32;cx,cy=(index%cols)*32,(index//cols)*32
        return bytes(v for y in range(TILE) for x in range(TILE)
                     for v in self.pixels[((cy+y*32//TILE)*self.w+cx+x*32//TILE)*4:((cy+y*32//TILE)*self.w+cx+x*32//TILE)*4+4])


class Canvas:
    def __init__(self): self.buf=bytearray(bytes((15,23,32))*(W*H))
    def rect(self,x,y,w,h,c):
        for yy in range(max(0,y),min(H,y+h)):
            x0,x1=max(0,x),min(W,x+w)
            if x1>x0:self.buf[(yy*W+x0)*3:(yy*W+x1)*3]=bytes(c)*(x1-x0)
    def text(self,x,y,s,scale=2,color=(220,233,236)):
        for ch in s.upper().replace('_',' '):
            for yy,line in enumerate(FONT.get(ch,FONT[' ']).split()):
                for xx,bit in enumerate(line):
                    if bit=='1':self.rect(x+xx*scale,y+yy*scale,scale,scale,color)
            x+=6*scale
    def sprite(self,x,y,rgba):
        for yy in range(TILE):
            for xx in range(TILE):
                r,g,b,a=rgba[(yy*TILE+xx)*4:(yy*TILE+xx)*4+4]
                if a and 0<=x+xx<W and 0<=y+yy<H:
                    i=((y+yy)*W+x+xx)*3
                    self.buf[i:i+3]=bytes((s*a+self.buf[i+k]*(255-a))//255 for k,s in enumerate((r,g,b)))


def render(rows, train, lever, name, tick, run_id):
    c=Canvas();c.text(40,28,'CIV13 STATION - NATIVE SIMULATION REPLAY',3)
    c.text(40,64,'ACTUAL BYOND TILE OBSERVATIONS / EXACT SOURCE '+contract.PIN[:12],2)
    c.text(40,92,'NO DREAMSEEKER CLIENT CAPTURE - SCHEMATIC BACKGROUND - 2X PLAYBACK',2,(241,189,97))
    c.text(40,116,'GITHUB RUN '+run_id+' / ATTEMPT 1',1,(156,178,185))
    c.text(40,135,name,3);c.text(900,143,'TICK '+str(tick),2)
    def pos(x,y):return 80+(x+8)*TILE,210+(4-y)*TILE
    for y in range(-10,5):
        for x in range(-8,48):
            px,py=pos(x,y);c.rect(px,py,TILE-1,TILE-1,(43,63,53))
    for x in range(6,14):c.rect(*pos(x,2),TILE,TILE,(127,115,95))
    for x in range(25,34):c.rect(*pos(x,-9),TILE,TILE,(115,104,87))
    layout=next(r for r in rows if r['event']=='layout')['rails']
    available=[r for r in rows if r['event']=='frame' and r['tick']<=tick]
    state=available[-1] if available else None
    switches={(r['x'],r['y']):r for r in state['switches']} if state else {}
    if state:switches.update({(r['x'],r['y']):r for r in state['rotators']})
    # Latest recorded native appearances, including the regular-rail visual hook.
    for r in layout:
        s=switches.get((r['x'],r['y']),r)
        c.sprite(*pos(r['x'],r['y']),train.sprite(s['icon'],s['dir']))
    if state:
        for l in state['levers']:c.sprite(*pos(l['x'],l['y']),lever.sprite(l['icon'],2))
        for car in reversed(state['cars']):
            px,py=pos(car['x'],car['y']);c.sprite(px,py,train.sprite(car['icon'],car['dir']))
            c.text(px+7,py-8,str(car['id']),1,(255,220,115))
        c.text(40,566,'VEHICLES '+str(len(state['cars']))+' / ENGINE AUTO '+str(state['auto'])+' / '+state['kind'],2)
        if state['cars']:
            e,t=state['cars'][0],state['cars'][-1]
            c.text(40,594,'ENGINE '+str(e['x'])+':'+str(e['y'])+'   TAIL '+str(t['x'])+':'+str(t['y'])+'   HEALTH '+str(e['health']),2)
        c.text(40,623,'LEVERS '+ ' / '.join(str(l['x'])+':'+str(l['y'])+'='+l['state'] for l in state['levers']),2)
    c.text(40,655,'X43: EIGHT-VEHICLE TAIL STILL ON MERGE. X44: TAIL CLEAR AT X37.',2)
    c.text(40,687,'BASE WAGON MOVEMENT / REAL HITCH AND TIMER / STORAGE AND CRAFTING UI NOT TESTED',2,(156,178,185))
    return bytes(c.buf)


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--prepared',required=True,type=Path);p.add_argument('--log',required=True,type=Path)
    p.add_argument('--run-provenance',required=True,type=Path)
    p.add_argument('--output',required=True,type=Path);a=p.parse_args()
    import resource
    resource.setrlimit(resource.RLIMIT_AS,(256*1024**2,256*1024**2))
    resource.setrlimit(resource.RLIMIT_CPU,(120,120))
    resource.setrlimit(resource.RLIMIT_FSIZE,(8*1024**2,8*1024**2))
    resource.setrlimit(resource.RLIMIT_CORE,(0,0))
    source=contract.source_check(a.prepared);raw=a.log.read_bytes();rows=contract.parse(raw.decode('utf8',errors='replace'))
    provenance_bytes=a.run_provenance.read_bytes()
    require(len(provenance_bytes)<=65536 and provenance_bytes==(a.prepared/'run-provenance.json').read_bytes(),'retained run provenance differs')
    run_provenance=json.loads(provenance_bytes)
    require(run_provenance['source_commit']==contract.PIN and run_provenance['run_attempt']==1 and
            re.fullmatch('[1-9][0-9]*',run_provenance['run_id']) and
            run_provenance['workflow_sha']==run_provenance['candidate_head'] and
            run_provenance['source_manifest']==record((a.prepared/'source-manifest.json').read_bytes()),'video source/run provenance mismatch')
    accepted=contract.validate(rows)
    require(not a.output.exists(),'new output path required')
    ffmpeg=shutil.which('ffmpeg');require(ffmpeg is not None,'preinstalled ffmpeg required; no automatic installation')
    train=DMI(a.prepared/'stage/icons/obj/vehicles/trains.dmi');lever=DMI(a.prepared/'stage/icons/obj/vehicles/train_lever.dmi')
    groups={name:[r for r in rows if r['case']==name] for name in contract.ROUTES+contract.CONTROLS}
    # Observations are held until their real tick. No interpolation or path driver.
    timeline=[]
    for name,events in groups.items():
        first=min(r['tick'] for r in events);last=max(r['tick'] for r in events)
        timeline += [(name,t) for t in range(first,last+1,2)] + [(name,last)]*15
    require(len(timeline)<=1200,'120-second replay bound')
    argv=[ffmpeg,'-nostdin','-hide_banner','-loglevel','error','-f','rawvideo','-pixel_format','rgb24',
          '-video_size',str(W)+'x'+str(H),'-framerate',str(FPS),'-i','pipe:0','-an','-c:v','libx264',
          '-threads','2','-preset','fast','-crf','24','-maxrate','400k','-bufsize','800k','-pix_fmt','yuv420p',
          '-movflags','+faststart','-fs',str(8*1024**2),str(a.output)]
    start=time.monotonic();lastkey=None;image=None
    with a.output.with_suffix('.ffmpeg.log').open('wb') as log:
        child=subprocess.Popen(argv,stdin=subprocess.PIPE,stdout=subprocess.DEVNULL,stderr=log)
        try:
            for name,tick in timeline:
                require(time.monotonic()-start<=120,'renderer wall limit')
                events=groups[name];current=[r['seq'] for r in events if r['event']=='frame' and r['tick']<=tick]
                key=(name,current[-1] if current else 0,tick)
                if key!=lastkey:image=render(events,train,lever,name,tick,run_provenance['run_id']);lastkey=key
                child.stdin.write(image)
            child.stdin.close();child.wait(timeout=max(1,120-(time.monotonic()-start)))
            require(child.returncode==0,'ffmpeg failed')
        finally:
            if child.poll() is None:
                child.kill();child.wait(timeout=3)
    require(a.output.stat().st_size<8*1024**2,'video size limit')
    ffprobe=shutil.which('ffprobe');require(ffprobe is not None,'preinstalled ffprobe required')
    probe=subprocess.run([ffprobe,'-v','error','-count_frames','-select_streams','v:0','-show_entries',
          'stream=nb_read_frames,width,height,codec_name,avg_frame_rate','-of','json',str(a.output)],capture_output=True,timeout=15,check=True)
    require(len(probe.stdout)<65536,'video probe bound')
    streams=json.loads(probe.stdout)['streams'];require(len(streams)==1,'video stream count')
    video=streams[0]
    require(video['width']==W and video['height']==H and video['codec_name']=='h264' and
            video['avg_frame_rate']=='10/1' and int(video['nb_read_frames'])==len(timeline),'encoded video truncated or changed')
    receipt={'video':record(a.output.read_bytes()),'trace':record(raw),'source_commit':contract.PIN,
             'scope':'native extracted simulation sprite replay, not client capture','fps':FPS,'playback_speed':2,
             'frames':len(timeline),'no_interpolation':True,'case_end_hold_frames':15,'oracle':accepted,
             'run_provenance':run_provenance,'run_provenance_identity':record(provenance_bytes),
             'sprites':{n:source['original']['icons/obj/vehicles/'+n] for n in ('trains.dmi','train_lever.dmi')}}
    a.output.with_suffix('.provenance.json').write_text(json.dumps(receipt,indent=2)+'\n')


if __name__=='__main__':main()

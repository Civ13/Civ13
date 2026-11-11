import subprocess,sys,numpy as np
f=sys.argv[1]
W,H=800,600
ts=[float(x.split(',')[0]) for x in subprocess.run(['ffprobe','-v','error','-select_streams','v','-show_entries','frame=pts_time','-of','csv=p=0',f],capture_output=True,text=True).stdout.split() if x.split(',')[0]]
raw=subprocess.run(['ffmpeg','-v','error','-i',f,'-fps_mode','passthrough','-f','rawvideo','-pix_fmt','rgb24','-'],capture_output=True).stdout
a=np.frombuffer(raw,np.uint8).reshape(-1,H,W,3)
t=np.array(ts[:len(a)])
prof=a[:,212:250,10:390,1].astype(float).mean(axis=1)  # rows above the mob
F=np.fft.rfft(prof-prof.mean(axis=1,keepdims=True),axis=1)
k=np.abs(F).mean(axis=0)[2:].argmax()+2
period=prof.shape[1]/k
ph=np.unwrap(np.angle(F[:,k]))
pos=-ph/(2*np.pi)*period   # camera position in screen px (sign arbitrary)
mob=[]
for fr in a:
    m=(fr[:,:,0]>200)&(fr[:,:,1]<60)&(fr[:,:,2]<60)
    xx=np.nonzero(m)[1]; mob.append(xx.mean() if len(xx) else np.nan)
mob=np.array(mob)
d=np.diff(pos); dt=np.diff(t)
uniq=[0]+[i for i in range(1,len(a)) if np.any(a[i]!=a[i-1])]
tu=t[uniq]; pu=pos[uniq]
du=np.diff(pu); dtu=np.diff(tu)
v=du/dtu
mv=np.abs(v).mean()
print(f"frames {len(a)}, new frames {len(uniq)} in {t[-1]-t[0]:.2f}s ({len(uniq)/(t[-1]-t[0]):.0f}/s), period {period:.1f}px, mean speed {mv:.0f}px/s")
print("camera step per new frame:", ' '.join(f'{x:.1f}' for x in du[60:110]))
print(f"camera step cv {np.std(np.abs(du))/np.mean(np.abs(du)):.2f}, still new-frames {np.mean(np.abs(du)<0.2):.0%}, mob x std {np.nanstd(mob):.2f}")
# deviation from a local straight line (0.5 s windows) = visible judder
devs=[];backs=0
for s0 in np.arange(t[0],t[-1]-0.5,0.25):
    m=(t>=s0)&(t<s0+0.5)
    c=np.polyfit(t[m],pos[m],1); devs+=list(pos[m]-np.polyval(c,t[m]))
print(f"judder rms {np.sqrt(np.mean(np.square(devs))):.2f}px, max {np.max(np.abs(devs)):.2f}px, backward steps {(np.diff(pos)>0.4).sum()} ")

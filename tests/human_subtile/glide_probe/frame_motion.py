import sys,numpy as np
exec(open(__file__.replace('frame_motion.py','analyse_camera.py')).read().split('mob=[]')[0])
# resample camera position on a 20ms grid (50 Hz) by sample-and-hold, then velocity jitter
g=np.arange(t[0]+0.2,t[-1]-0.2,0.02)
idx=np.searchsorted(t,g,side='right')-1
p=pos[idx]
v=np.diff(p)/0.02
print(f"{sys.argv[1].split('/')[-1]}: speed {abs(v.mean()):.0f}px/s, 50Hz frames with no motion {np.mean(np.abs(np.diff(p))<0.2):.0%}, speed jitter {v.std()/abs(v.mean()):.2f}")

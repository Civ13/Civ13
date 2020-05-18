import os

currdir = os.path.dirname(os.path.abspath(__file__))
lines = open(os.path.join(currdir,"paths.txt"))
all_lines = lines.readlines()
mdir = all_lines[1]
mdir = mdir.replace("\n", "")
mdir = mdir.replace("mdir:", "")
cdir = all_lines[2]
cdir = cdir.replace("\n", "")
cdir = cdir.replace("cdir:", "")

filelist = [ f for f in os.listdir(os.path.join(mdir+cdir)) if f.endswith(".ogg") ]
for f in filelist:
    os.remove(os.path.join(mdir+cdir, f))
import shutil
import os
from server_paths import read_paths

currdir = os.path.dirname(os.path.abspath(__file__))
paths = read_paths(currdir)
mdir = paths["mdir"]
cdir = paths["cdir"]
gitpath = paths["gitpath"]

print("mdir: {} cdir: {} git: {}".format(mdir, cdir, gitpath))
with open(os.path.join(mdir, cdir, "scripts/copiedconfigpaths.txt")) as lines:
    for line in lines:
        path = line.replace("\n", "")
        if not path:
            continue
        shutil.copyfile(os.path.join(gitpath, path),
                        os.path.join(mdir, cdir, path))

with open(os.path.join(mdir, cdir, 'scripts/copiedfolderpaths.txt')) as lines:
    for line in lines:
        path = line.replace("\n", "")
        if not path:
            continue
        npath = os.path.join(mdir, cdir, path)
        if os.path.isdir(npath):
            shutil.rmtree(npath)
        shutil.copytree(os.path.join(gitpath, path), npath)

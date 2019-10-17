import shutil
import os

currdir = os.path.dirname(os.path.abspath(__file__))
with open(os.path.join(currdir,"/paths.txt")) as lines:
	for line in lines:
		if "mdir:" in line:
			mdir = line.replace("\n", "")
			mdir = mdir.replace("mdir:", "")
		if "cdir:" in line:
			cdir = line.replace("\n", "")
			cdir = cdir.replace("cdir:", "")
with open(os.path.join(mdir,cdir,"scripts/copiedconfigpaths.txt")) as lines:
	for line in lines:
		path = line.replace("\n", "")
		shutil.copyfile(os.path.join(mdir,"civ13-git",path), os.path.join(mdir,cdir,path))

with open(os.path.join(mdir,cdir,'scripts/copiedfolderpaths.txt')) as lines:
	for line in lines:
		path = line.replace("\n", "")
		shutil.copytree(os.path.join(mdir,"civ13-git",path), os.path.join(mdir,cdir,path))

shutil.rmtree(os.path.join(mdir,cdir,"config/names"))

shutil.copytree(os.path.join(mdir,cdir,"config/names"), os.path.join(mdir,cdir,"config/names"), symlinks=False, ignore=None)

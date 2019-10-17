import shutil
import os

with open('paths.txt') as lines:
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
		shutil.copyfile(os.path.join(path), path.replace("civ13-git", "civ13"))

with open(os.path.join(mdir,cdir,'scripts/copiedfolderpaths.txt')) as lines:
	for line in lines:
		path = line.replace("\n", "")
		shutil.copytree(os.path.join(path), path.replace("civ13-git", "civ13"))

shutil.rmtree(os.path.join(mdir,cdir,"config/names"))

shutil.copytree(os.path.join(mdir,cdir,"config/names"), os.path.join(mdir,cdir,"config/names"), symlinks=False, ignore=None)

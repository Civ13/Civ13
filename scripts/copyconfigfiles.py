import shutil
import os 

with open('/home/1713/civ13/scripts/copiedconfigpaths.txt') as lines:
	for line in lines:
		path = line.replace("\n", "")
		shutil.copyfile(os.path.join(path), path.replace("civ13-git", "civ13"))
	
		
shutil.rmtree('/home/1713/civ13/config/names')

shutil.copytree('/home/1713/civ13-git/config/names', '/home/1713/civ13/config/names', symlinks=False, ignore=None)

import shutil
import os 

with open('/home/1713/1713/scripts/copiedconfigpaths.txt') as lines:
	for line in lines:
		path = line.replace("\n", "")
		shutil.copyfile(os.path.join(path), path.replace("1713-git", "1713/1713-1"))
	
		
shutil.rmtree('/home/1713/1713/1713-1/config/names')

shutil.copytree('/home/1713/1713-git/config/names', '/home/1713/1713/1713-1/config/names', symlinks=False, ignore=None)

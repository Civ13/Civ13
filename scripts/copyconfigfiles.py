import shutil
import os 

with open('/home/customer/1713/scripts/copiedconfigpaths.txt') as lines:
	for line in lines:
		path = line.replace("\n", "")
		shutil.copyfile(os.path.join(path), path.replace("1713-git", "1713/1713-1"))
		shutil.copyfile(os.path.join(path), path.replace("1713-git", "1713/1713-2"))
		shutil.copyfile(os.path.join(path), path.replace("1713-git", "1713/1713-3"))
		shutil.copyfile(os.path.join(path), path.replace("1713-git", "1713/1713-4"))
		
shutil.rmtree('/home/customer/1713/1713-1/config/names')
shutil.rmtree('/home/customer/1713/1713-2/config/names')
shutil.rmtree('/home/customer/1713/1713-3/config/names')
shutil.rmtree('/home/customer/1713/1713-4/config/names')

shutil.copytree('/home/customer/1713-git/config/names', '/home/customer/1713/1713-1/config/names', symlinks=False, ignore=None)
shutil.copytree('/home/customer/1713-git/config/names', '/home/customer/1713/1713-2/config/names', symlinks=False, ignore=None)
shutil.copytree('/home/customer/1713-git/config/names', '/home/customer/1713/1713-3/config/names', symlinks=False, ignore=None)
shutil.copytree('/home/customer/1713-git/config/names', '/home/customer/1713/1713-4/config/names', symlinks=False, ignore=None)

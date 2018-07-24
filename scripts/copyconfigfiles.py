import shutil
import os 

with open('/home/customer/WW13/scripts/copiedconfigpaths.txt') as lines:
	for line in lines:
		path = line.replace("\n", "")
		shutil.copyfile(os.path.join(path), path.replace("WW13-git", "WW13/WW13-1"))
		shutil.copyfile(os.path.join(path), path.replace("WW13-git", "WW13/WW13-2"))
		shutil.copyfile(os.path.join(path), path.replace("WW13-git", "WW13/WW13-3"))
		shutil.copyfile(os.path.join(path), path.replace("WW13-git", "WW13/WW13-4"))
		
shutil.rmtree('/home/customer/WW13/WW13-1/config/names')
shutil.rmtree('/home/customer/WW13/WW13-2/config/names')
shutil.rmtree('/home/customer/WW13/WW13-3/config/names')
shutil.rmtree('/home/customer/WW13/WW13-4/config/names')

shutil.copytree('/home/customer/WW13-git/config/names', '/home/customer/WW13/WW13-1/config/names', symlinks=False, ignore=None)
shutil.copytree('/home/customer/WW13-git/config/names', '/home/customer/WW13/WW13-2/config/names', symlinks=False, ignore=None)
shutil.copytree('/home/customer/WW13-git/config/names', '/home/customer/WW13/WW13-3/config/names', symlinks=False, ignore=None)
shutil.copytree('/home/customer/WW13-git/config/names', '/home/customer/WW13/WW13-4/config/names', symlinks=False, ignore=None)

# to be called from bot.py only

import os
import shutil
import time


t1 = time.time()

currdir = os.path.dirname(os.path.abspath(__file__))
with open(os.path.join(currdir,"paths.txt")) as lines:
	for line in lines:
		if "mdir:" in line:
			mdir = line.replace("\n", "")
			mdir = mdir.replace("mdir:", "")
		if "cdir:" in line:
			cdir = line.replace("\n", "")
			cdir = cdir.replace("cdir:", "")
			
print("Updating git...")

os.chdir("{}civ13-git")
os.system("sudo git pull")
os.system("sudo git reset --hard origin/master")

print("Rebuilding binaries...")

os.system("sudo DreamMaker civ13.dme")
os.system("cd")

print("Copying configuration settings...")

os.system("sudo python3 {}{}scripts/copyconfigfiles.py".format(mdir,cdir))

print("Copying binaries...")

dmb = os.path.join('{}civ13-git/civ13.dmb'.format(mdir))
rsc = os.path.join('{}civ13-git/civ13.rsc'.format(mdir))

shutil.copyfile(dmb, '{}{}civ13.dmb'.format(mdir,cdir))

shutil.copyfile(rsc, '{}{}civ13.rsc'.format(mdir,cdir))

t2 = time.time() - t1

print("Finished updating all directories in {} seconds".format(t2))

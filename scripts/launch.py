import os
import psutil
import signal
import shutil
import time
currdir = os.path.dirname(os.path.abspath(__file__))
with open(os.path.join(currdir"/paths.txt")) as lines:
	for line in lines:
		if "mdir:" in line:
			mdir = line.replace("\n", "")
			mdir = mdir.replace("mdir:", "")
		if "cdir:" in line:
			cdir = line.replace("\n", "")
			cdir = cdir.replace("cdir:", "")
t1 = time.time()

print("Updating git...")

os.chdir("{}civ13-git".format(mdir))
os.system("sudo git pull")
os.system("sudo git reset --hard origin/new_scripts")

print("Rebuilding binaries...")

os.system("sudo DreamMaker civ13.dme")

os.system("cd")

print("Copying configuration settings...")

os.system("sudo python3 {}{}scripts/copyconfigfiles.py".format(mdir,cdir))

print("Copying binaries...")

dmb = os.path.join(mdir,'civ13-git/civ13.dmb')
rsc = os.path.join(mdir,'civ13-git/civ13.rsc')

shutil.copyfile(dmb, '{}{}civ13.dmb'.format(mdir,cdir))


shutil.copyfile(rsc, '{}{}civ13.rsc'.format(mdir,cdir))

t2 = time.time() - t1

print("Finished updating all directories in {} seconds".format(t2))

print("Started server on port 1714.")
os.system("sudo DreamDaemon {}{}civ13.dmb 1714 -trusted -logself -webclient &".format(mdir,cdir))

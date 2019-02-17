import os
import shutil 
import time
import subprocess

t1 = time.time()

print("Updating git...")

os.chdir("/home/1713/civ13-git")
os.system("sudo git pull")
os.system("sudo git reset --hard origin/master")

print("Rebuilding binaries...")

os.system("sudo DreamMaker civ13.dme")

os.system("cd")

print("Copying configuration settings...")

os.system("sudo python3 /home/1713/civ13/scripts/copyconfigfiles.py")

print("Copying binaries...")

dmb = os.path.join('/home/1713/civ13-git/civ13.dmb')
rsc = os.path.join('/home/1713/civ13-git/civ13.rsc')

shutil.copyfile(dmb, '/home/1713/civ13/civ13.dmb')

	
shutil.copyfile(rsc, '/home/1713/civ13/civ13.rsc')

t2 = time.time() - t1

print("Finished updating all directories in {} seconds".format(t2))

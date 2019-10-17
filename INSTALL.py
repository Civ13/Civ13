import os
import shutil
import time

t1 = time.time()
## if you want to change the installation directories, edit the mdir and cdir variables. mdir is the folder to install path, cdir is the civ13 game path to create.
mdir = os.path.dirname(os.path.abspath(__file__))
cdir = "civ13"

print("WELCOME TO CIV13!")
print("-----------------")
print("Cloning the github...")
os.system("sudo git clone https://github.com/civ13-ss13/civ13 civ13-git")

print("Building binaries...")

os.system("sudo DreamMaker civ13.dme")

os.system("cd")

print("Copying files and folders...")

dmb = os.path.join(mdir,'civ13-git/civ13.dmb')
rsc = os.path.join(mdir,'civ13-git/civ13.rsc')

shutil.copyfile(dmb, os.path.join(mdir,cdir,'civ13.dmb'))
shutil.copyfile(rsc, os.path.join(mdir,cdir,'civ13/civ13.rsc'))
shutil.copytree('civ13-git/UI', os.path.join(mdir,cdir,'UI'))
shutil.copytree('civ13-git/scripts', os.path.join(mdir,cdir,'scripts'))
shutil.copytree('civ13-git/config', os.path.join(mdir,cdir,'config'))
t2 = time.time() - t1

print("Finished creating everything in {} seconds".format(t2))

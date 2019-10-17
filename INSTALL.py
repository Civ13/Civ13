import os
import shutil
import time

t1 = time.time()
## if you want to change the installation directories, edit the mdir and cdir variables. mdir is the folder to install path, cdir is the civ13 game path to create.
mdir = os.path.dirname(os.path.abspath(__file__))
cdir = "civ13"

print("WELCOME TO CIV13!")
print("-----------------")
print("Installing dependencies...")
os.system("sudo dpkg --add-architecture i386")
os.system("apt-get update")
os.system("sudo apt upgrade")
os.system("sudo apt install make git wget unzip python3 lib32z1 lib32ncurses5 libc6-i386 lib32stdc++6")
os.system("sudo apt autoremove")
os.system("sudo apt autoclean")
print("Installing BYOND...")
exists = os.path.isfile('512.1488_byond_linux.zip')
if not exists:
	os.system("sudo wget http://www.byond.com/download/build/512/512.1488_byond_linux.zip")
os.system("unzip 512.1488_byond_linux.zip")
os.system("make install -C byond")
print("Cloning the github...")
os.system("sudo git clone https://github.com/civ13-ss13/civ13 --branch new_scripts civ13-git")

print("Building binaries...")

os.system("DreamMaker civ13-git/civ13.dme")

print("Copying files and folders...")
os.system("mkdir {}".format(cdir))
dmb = os.path.join(mdir,'civ13-git/civ13.dmb')
rsc = os.path.join(mdir,'civ13-git/civ13.rsc')

shutil.copy(dmb, os.path.join(mdir,cdir))
shutil.copy(rsc, os.path.join(mdir,cdir))
uip = os.path.join(mdir,cdir,'UI')
scriptsp = os.path.join(mdir,cdir,'scripts')
configp = os.path.join(mdir,cdir,'config')

shutil.copytree('civ13-git/UI', uip)
shutil.copytree('civ13-git/scripts', scriptsp)
shutil.copytree('civ13-git/config', configp)
t2 = time.time() - t1

print("Finished creating everything in {} seconds".format(t2))

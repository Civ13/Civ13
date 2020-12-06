import os
import shutil
import time
import sys

t1 = time.time()
##config
## if you want to change the installation directories, edit the mdir and cdir variables. mdir is the folder to install path, cdir is the civ13 game path to create.
mdir = os.path.dirname(os.path.abspath(__file__))
cdir = "civ13"
if (len(sys.argv)<3):
  print("ERROR: Missing the byond version to download. Use 'python install.py MAJOR MINOR'")
  quit()
byond_version_major = sys.argv[1]
byond_version_minor = sys.argv[2]
####
####

if sys.platform == "win32" or sys.platform == "darwin":
  print("ERROR: This script only runs on linux.")
  quit()
print("Installing dependencies...")
os.system("sudo apt install make git unzip python3 python3-pip lib32z1 lib32ncurses5 libc6-i386 lib32stdc++6")
os.system("sudo apt autoremove")
os.system("sudo apt autoclean")
print("Installing BYOND...")
exists = os.path.isfile(os.path.join(mdir,cdir,byond_version_major,".",byond_version_minor,"_byond_linux.zip"))
if not exists:
	os.system("sudo wget http://www.byond.com/download/build/{}/{}.{}_byond_linux.zip".format(byond_version_major,byond_version_major,byond_version_minor))
os.system("unzip {}.{}_byond_linux.zip".format(byond_version_major,byond_version_minor))
os.system("sudo mkdir /usr/share/man/man6")
os.system("make install -C byond")
print("Cloning the github...")
os.system("sudo git clone https://github.com/civ13/civ13 civ13-git")

print("Building binaries...")

os.system("DreamMaker civ13-git/civ13.dme")
os.system("sudo pip3 install psutil")
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

print("Updating the config...")
with open(os.path.join(mdir,cdir,"scripts/paths.txt"), 'r') as file :
  filedata = file.read()

filedata = filedata.replace("/home/1713", mdir)

with open(os.path.join(mdir,cdir,"scripts/paths.txt"), 'w') as file:
  file.write(filedata)
t2 = time.time() - t1

print("Finished creating everything in {} seconds".format(t2))
print("Run sudo python3 {}/scripts/launch.py to start the server!".format(cdir))
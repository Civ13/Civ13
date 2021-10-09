import os
import shutil
import time
currdir = os.path.dirname(os.path.abspath(__file__))
lines = open(os.path.join(currdir, "paths.txt"))
all_lines = lines.readlines()
mdir = all_lines[1]
mdir = mdir.replace("\n", "")
mdir = mdir.replace("mdir:", "")
cdir = all_lines[2]
cdir = cdir.replace("\n", "")
cdir = cdir.replace("cdir:", "")
port = all_lines[3]
port = port.replace("\n", "")
port = port.replace("port:", "")
print(port)
t1 = time.time()

print("Updating git...")

os.chdir("{}civ13-git".format(mdir))
os.system("sudo git pull")
os.system("sudo git reset --hard origin/master")

print("Rebuilding binaries...")

os.system("sudo DreamMaker civ13.dme")

os.system("cd")

print("Copying configuration settings...")

os.system("sudo python3 {}{}scripts/copyconfigfiles.py".format(mdir, cdir))

print("Copying binaries...")

dmb = os.path.join(mdir, 'civ13-git/civ13.dmb')
rsc = os.path.join(mdir, 'civ13-git/civ13.rsc')

shutil.copyfile(dmb, '{}{}civ13.dmb'.format(mdir, cdir))


shutil.copyfile(rsc, '{}{}civ13.rsc'.format(mdir, cdir))

t2 = time.time() - t1

print("Finished updating all directories in {} seconds".format(t2))

print("Started server on port {}.".format(port))
os.system("sudo DreamDaemon {}{}civ13.dmb {} -trusted -logself -webclient &".format(mdir, cdir, port))

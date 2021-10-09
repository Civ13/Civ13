import sys
import os
import shutil
import time

def getListOfFiles(dirName):
    # create a list of file and sub directories 
    # names in the given directory 
    listOfFile = os.listdir(dirName)
    allFiles = list()
    # Iterate over all the entries
    for entry in listOfFile:
        # Create full path
        fullPath = os.path.join(dirName, entry)
        # If entry is a directory then get the list of files in this directory 
        if os.path.isdir(fullPath):
            allFiles = allFiles + getListOfFiles(fullPath)
        else:
            allFiles.append(fullPath)
                
    return allFiles

if len(sys.argv) == 1:
	sys.exit()

currdir = os.path.dirname(os.path.abspath(__file__))
lines = open(os.path.join(currdir,"paths.txt"))
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
byonddir = all_lines[4]
byonddir = byonddir.replace("\n", "")
byonddir = byonddir.replace("byond_dir:", "")
os.chdir("{}civ13-git".format(mdir))
os.system("git pull")
os.system("git reset --hard origin/master")

map = sys.argv[1]
dmms = []
mapname = "{}.dmm".format(map.lower())
maploc = "{}civ13-git/maps/".format(mdir)
maplist = getListOfFiles(maploc)
done = 0
for i in maplist:
	if mapname in i:
		maploc = i
		done = 1
if done == 0:
	sys.exit()
else:
	maploc = maploc.replace(mdir,"")
	maploc = maploc.replace("\\","/")
	maploc = maploc.replace("civ13-git/","")
	dmms.append("#include \"{}\"".format(maploc))

DME = "{}civ13-git/civ13.dme".format(mdir)

lines = []
with open(DME, "r") as search:
	for line in search:
		lines.append(line)
	search.close()

wroteDMMs = False
DME = open(DME, "w")
for line in lines:
	if ".dmm" in line:
		if not wroteDMMs:
			for line2 in dmms:
				DME.write(line2)
				DME.write("\n")
			dmms = []
			wroteDMMs = True
	else:
		DME.write(line)

DME.close()

t1 = time.time()

os.system('"{}/bin/dm.exe" {}civ13-git/civ13.dme'.format(byonddir,mdir))

os.system('python3 "{}{}scripts/windows/copyconfigfiles.py"'.format(mdir,cdir))

t2 = time.time() - t1

time.sleep(30)
os.system("taskkill /f /im dreamdaemon.exe")
dmb = os.path.join('{}civ13-git/civ13.dmb'.format(mdir))
rsc = os.path.join('{}civ13-git/civ13.rsc'.format(mdir))
shutil.copyfile(dmb, '{}{}civ13.dmb'.format(mdir,cdir))
shutil.copyfile(rsc, '{}{}civ13.rsc'.format(mdir,cdir))
time.sleep(8)
os.system("\"{}/bin/dreamdaemon.exe\" {}{}civ13.dmb {} -trusted -webclient -logself".format(byonddir,mdir,cdir,port))

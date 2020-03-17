import sys
import os
import shutil
import time
import psutil
import signal

def findfile(name, path):
	for root, dirs, files in os.walk(path):
		if name in files:
			return os.path.join(root, name)

if len(sys.argv) == 1:
	print("Not enough args provided.")
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
print("Updating git...")

os.chdir("{}civ13-git".format(mdir))
os.system("git pull")
os.system("git reset --hard origin/master")

map = sys.argv[1]
dmms = []
mapname = "{}.dmm".format(map.lower())
checked_mapname = findfile(mapname,"{}{}".format(mdir,cdir))
if checked_mapname:
	mapname = mapname.replace("{}{}".format(mdir,cdir),"")
	dmms.append("#include \"{}\"".format(mapname))

else:
	print("Invalid argument.")
	sys.exit()

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

print("Rebuilding binaries...")

os.system("DreamMaker {}civ13-git/civ13.dme".format(mdir))

print("Copying configuration settings...")

os.system("sudo python3 {}{}scripts/copyconfigfiles.py".format(mdir,cdir))

t2 = time.time() - t1

print("Finished rebuilding in {} seconds".format(t2))

print("Moving into reboot in 30 seconds!")

time.sleep(30)

pids = [pid for pid in os.listdir('/proc') if pid.isdigit()]

for pid in pids:
	try:

		# due to BUGS we need to make sure the file we use as a reference is newer than the other
		# todo: add test server support
		may_restart_server = []
		may_restart_server.append(port)

		if len(may_restart_server) == 0:
			may_restart_server.append("notathing")

		name = open(os.path.join('/proc', pid, 'cmdline'), 'r').read()
		if "civ13.dmb" in name:
			if not "sudo" in name:

				# main server logic: for some reason I could get a valid string/int for port so we're just using "in"

				# civ13 is the active server; restart civ13
				if port in name and may_restart_server[0] == port:
					if os.path.isfile("{}{}serverdata.txt".format(mdir,cdir)):
						process = psutil.Process(int(pid))
						if process is not None:
							print("Killing the server...")
							os.kill(int(pid), signal.SIGKILL)
							print("Copying binaries...")
							dmb = os.path.join('{}civ13-git/civ13.dmb'.format(mdir))
							rsc = os.path.join('{}civ13-git/civ13.rsc'.format(mdir))
							shutil.copyfile(dmb, '{}{}civ13.dmb'.format(mdir,cdir))
							shutil.copyfile(rsc, '{}{}civ13.rsc'.format(mdir,cdir))
							time.sleep(8)
							print("Rebooting the server...")
							os.system('sudo DreamDaemon {}{}civ13.dmb {} -trusted -webclient -logself &'.format(mdir,cdir,port))
							print("Restarted main server on port {}.".format(port))

	except IOError:
		continue

print("Done!")

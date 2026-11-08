import sys
import os
import shutil
import subprocess
import time
import signal
from map_environment import select_map
from server_paths import read_paths

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


def replace_file(source, target):
    # A running DreamDaemon keeps its open world file; a rename never
    # exposes a half-written binary to the next start.
    temporary = target + ".new"
    shutil.copyfile(source, temporary)
    os.replace(temporary, target)


def server_pids(port):
    pids = []
    for pid in os.listdir('/proc'):
        if not pid.isdigit() or int(pid) == os.getpid():
            continue
        try:
            with open(os.path.join('/proc', pid, 'cmdline'), 'rb') as handle:
                argv = handle.read().decode('utf-8', 'replace').split('\0')
        except OSError:
            continue
        if not argv or os.path.basename(argv[0]) != "DreamDaemon":
            continue
        if any(arg.endswith("civ13.dmb") for arg in argv) and port in argv:
            pids.append(int(pid))
    return pids


def supervised_swap(paths, maploc):
    # A service manager owns DreamDaemon: build, install, then stop the
    # server and let the manager start the new world. Nothing runs as root.
    gitpath = paths["gitpath"]
    livepath = paths["livepath"]
    os.chdir(gitpath)
    if subprocess.run(["git", "fetch", "--depth", "1", "origin", "master"]).returncode:
        print("git fetch failed; building the current checkout.")
    else:
        subprocess.run(["git", "reset", "--hard", "FETCH_HEAD"], check=True)
    DME = os.path.join(gitpath, "civ13.dme")
    with open(DME, "r") as search:
        source = search.read()
    with open(DME, "w") as environment:
        environment.write(select_map(source, maploc))
    t1 = time.time()
    print("Rebuilding binaries...")
    build = subprocess.run(["DreamMaker", "-max_errors", "0", DME])
    if build.returncode:
        print("Build failed; the running world is left alone.")
        return 1
    print("Copying configuration settings...")
    subprocess.run([sys.executable, os.path.join(livepath, "scripts", "copyconfigfiles.py")], check=True)
    print("Installing binaries...")
    replace_file(os.path.join(gitpath, "civ13.dmb"), os.path.join(livepath, "civ13.dmb"))
    replace_file(os.path.join(gitpath, "civ13.rsc"), os.path.join(livepath, "civ13.rsc"))
    print("Finished rebuilding in {} seconds".format(time.time() - t1))
    print("Moving into reboot in 30 seconds!")
    time.sleep(30)
    for pid in server_pids(paths["port"]):
        print("Stopping the server for its supervisor to restart...")
        os.kill(pid, signal.SIGTERM)
    return 0


if __name__ != "__main__":
	pass
elif len(sys.argv) == 1:
	print("Not enough args provided.")
	sys.exit()
else:
	currdir = os.path.dirname(os.path.abspath(__file__))
	paths = read_paths(currdir)
	mdir = paths["mdir"]
	cdir = paths["cdir"]
	port = paths["port"]
	gitpath = paths["gitpath"]

	map = sys.argv[1]
	mapname = "{}.dmm".format(map.lower())
	maploc = os.path.join(gitpath, "maps/")
	maplist = getListOfFiles(maploc)
	done = 0

	# Try exact match first
	for i in maplist:
		if os.path.basename(i).lower() == mapname:
			maploc = i
			print(maploc)
			done = 1
			break

	# If no exact match, try partial match
	if done == 0:
		for i in maplist:
			if mapname in i.lower():
				maploc = i
				print(maploc)
				done = 1
				break

	if done == 0:
		print("Invalid argument.")
		sys.exit()

	if paths["supervisor"]:
		sys.exit(supervised_swap(paths, maploc))

	print("Updating git...")

	os.chdir(gitpath)
	os.system("git pull")
	os.system("git reset --hard origin/master")
	os.system("git pull")

	DME = os.path.join(gitpath, "civ13.dme")

	lines = []
	with open(DME, "r") as search:
		for line in search:
			lines.append(line)
		search.close()

	selected_source = select_map("".join(lines), maploc)
	with open(DME, "w") as environment:
		environment.write(selected_source)

	t1 = time.time()

	print("Rebuilding binaries...")

	os.system("DreamMaker {}".format(DME))

	print("Copying configuration settings...")

	os.system("sudo python3 {}{}scripts/copyconfigfiles.py".format(mdir,cdir))

	t2 = time.time() - t1

	print("Finished rebuilding in {} seconds".format(t2))

	print("Moving into reboot in 30 seconds!")

	time.sleep(30)

	import psutil

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
								dmb = os.path.join(gitpath, 'civ13.dmb')
								rsc = os.path.join(gitpath, 'civ13.rsc')
								shutil.copyfile(dmb, '{}{}civ13.dmb'.format(mdir,cdir))
								shutil.copyfile(rsc, '{}{}civ13.rsc'.format(mdir,cdir))
								time.sleep(8)
								print("Rebooting the server...")
								os.system('sudo DreamDaemon {}{}civ13.dmb {} -trusted -webclient -logself &'.format(mdir,cdir,port))
								print("Restarted main server on port {}.".format(port))

		except IOError:
			continue

	print("Done!")

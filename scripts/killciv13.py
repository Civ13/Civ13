# basically a modified copy of restartinactiveserver.py
import os
import signal

currdir = os.path.dirname(os.path.abspath(__file__))
lines = open(os.path.join(currdir,"paths.txt"))
all_lines = lines.readlines()

cdir = all_lines[2]
cdir = cdir.replace("\n", "")
cdir = cdir.replace("cdir:", "")


pids = [pid for pid in os.listdir('/proc') if pid.isdigit()]

for pid in pids:
	try:
		name = open(os.path.join('/proc', pid, 'cmdline'), 'r').read()
		if "civ13.dmb" in name and (cdir in name):
			os.kill(int(pid), signal.SIGKILL)
	except IOError:
		continue

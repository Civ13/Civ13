# basically a modified copy of restartinactiveserver.py
import os
import signal

currdir = os.path.dirname(os.path.abspath(__file__))
lines = open(os.path.join(currdir,"paths.txt"))
all_lines = lines.readlines()

port = all_lines[3]
port = port.replace("\n", "")
port = port.replace("port:", "")


pids = [pid for pid in os.listdir('/proc') if pid.isdigit()]

for pid in pids:
	try:
		name = open(os.path.join('/proc', pid, 'cmdline'), 'r').read()
		if "civ13.dmb" in name and (port in name):
			os.kill(int(pid), signal.SIGKILL)
	except IOError:
		continue

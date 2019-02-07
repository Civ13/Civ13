# basically a modified copy of restartinactiveserver.py
import os
import psutil
import subprocess
import signal

#pid2cpu = dict()
pids = [pid for pid in os.listdir('/proc') if pid.isdigit()]

for pid in pids:
	try:
		name = open(os.path.join('/proc', pid, 'cmdline'), 'r').read()
		if "civ13.dmb" in name and ("civ13" in name):
			os.kill(int(pid), signal.SIGKILL) 
	except IOError: # proc has already terminated
		continue

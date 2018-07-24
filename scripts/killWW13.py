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
		if "WW13.dmb" in name and ("WW13-1" in name or "WW13-2" in name):
			os.kill(int(pid), signal.SIGKILL) 
	except IOError: # proc has already terminated
		continue

# what name ends up being, for reference - Kachnov 

#sudoWW13.dmb13000-trusted-logself
#DreamDaemonWW13.dmb13000-trusted-logself
#sudoDreamDaemonWW13.dmb13001-trusted-logself
#DreamDaemonWW13.dmb13001-trusted-logself

# also note os.getpid() to get our pid
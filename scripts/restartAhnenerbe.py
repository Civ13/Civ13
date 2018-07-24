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
		if "InterBay.dmb" in name or "LebenBay.dmb" in name or "Ahnenerbe.dmb" in name:
			if not "sudo" in name:
				os.kill(int(pid), signal.SIGUSR1) 
	except IOError: # proc has already terminated
		continue

# what name ends up being, for reference - Kachnov 

#sudoWW13.dmb13000-trusted-logself
#DreamDaemonWW13.dmb13000-trusted-logself
#sudoDreamDaemonWW13.dmb13001-trusted-logself
#DreamDaemonWW13.dmb13001-trusted-logself

# also note os.getpid() to get our pid
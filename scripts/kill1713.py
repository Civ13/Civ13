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
		if "1713.dmb" in name and ("1713-1" in name or "1713-2" in name):
			os.kill(int(pid), signal.SIGKILL) 
	except IOError: # proc has already terminated
		continue

# what name ends up being, for reference - Kachnov 

#sudo1713.dmb13000-trusted-logself
#DreamDaemon1713.dmb13000-trusted-logself
#sudoDreamDaemon1713.dmb13001-trusted-logself
#DreamDaemon1713.dmb13001-trusted-logself

# also note os.getpid() to get our pid
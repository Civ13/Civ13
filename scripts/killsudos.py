# https://stackoverflow.com/questions/2703640/process-list-on-linux-via-python
# https://stackoverflow.com/questions/21090379/how-to-use-psutil-get-cpu-percent

import os
import psutil
import subprocess
import signal
import time

#pid2cpu = dict()
pids = [pid for pid in os.listdir('/proc') if pid.isdigit()]

for pid in pids:
	try:
		name = open(os.path.join('/proc', pid, 'cmdline'), 'r').read()
		if "civ13.dmb" in name:
			if "sudo" in name:
				os.kill(int(pid), signal.SIGKILL)
	except IOError: # proc has already terminated
		continue
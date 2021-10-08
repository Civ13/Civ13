import os
import signal

pids = [pid for pid in os.listdir('/proc') if pid.isdigit()]

for pid in pids:
	try:
		name = open(os.path.join('/proc', pid, 'cmdline'), 'r').read()
		if "civ13.dmb" in name:
			if "sudo" in name:
				os.kill(int(pid), signal.SIGKILL)
	except IOError:
		continue

# restarts the ACTIVE server only

import os
import psutil
import signal

pids = [pid for pid in os.listdir('/proc') if pid.isdigit()]

for pid in pids:
	try:
		name = open(os.path.join('/proc', pid, 'cmdline'), 'r').read()
		if "civ13.dmb" in name:
			if not "sudo" in name:

				# main server logic: for some reason I could get a valid string/int for port so we're just using "in"
				# civ13 is the active server; restart civ13
				if "1714" in name:
					process = psutil.Process(int(pid))
					if process is not None:
						os.kill(int(pid), signal.SIGUSR1)
						print("Restarted ACTIVE server on port 1714.")

	except IOError:
		continue

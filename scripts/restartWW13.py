# restarts the ACTIVE server only

import os
import psutil
import subprocess
import signal

#pid2cpu = dict()
pids = [pid for pid in os.listdir('/proc') if pid.isdigit()]

for pid in pids:
	try:
		name = open(os.path.join('/proc', pid, 'cmdline'), 'r').read()
		if "WW13.dmb" in name:
			if not "sudo" in name:

				# main server logic: for some reason I could get a valid string/int for port so we're just using "in"
				
				# WW13-1 is the active server; restart WW13-1
				if "13000" in name:
					if os.path.isfile("/home/customer/WW13/WW13-1/serverdata.txt"):
						process = psutil.Process(int(pid))
						if process != None:
							os.kill(int(pid), signal.SIGUSR1)
							print("Restarted ACTIVE server on port 13000.")
							
				# WW13-2 is the active server; restart WW13-2
				elif "13001" in name:
					if os.path.isfile("/home/customer/WW13/WW13-2/serverdata.txt"):
						process = psutil.Process(int(pid))
						if process != None:
							os.kill(int(pid), signal.SIGUSR1)
							print("Restarted ACTIVE server on port 13001.")
						
			 		  
	except IOError: # proc has already terminated
		continue

# what name ends up being, for reference - Kachnov 

#sudoWW13.dmb13000-trusted-logself
#DreamDaemonWW13.dmb13000-trusted-logself
#sudoDreamDaemonWW13.dmb13001-trusted-logself
#DreamDaemonWW13.dmb13001-trusted-logself

# also note os.getpid() to get our pid
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
	
		# due to BUGS we need to make sure the file we use as a reference is newer than the other 
		# todo: add test server support
		may_restart_server = []
		may_restart_server.append("1713")

		if len(may_restart_server) == 0:
			may_restart_server.append("notathing")
			
		name = open(os.path.join('/proc', pid, 'cmdline'), 'r').read()
		if "civ13.dmb" in name:
			if not "sudo" in name:

				# main server logic: for some reason I could get a valid string/int for port so we're just using "in"
				
				# 1713-1 is the active server; restart 1713-1
				if "1713" in name and may_restart_server[0] == "1713":
					if os.path.isfile("/home/1713/civ13/serverdata.txt"):
						process = psutil.Process(int(pid))
						if process != None:
							os.kill(int(pid), signal.SIGKILL)
							# for some reason I have to do this now
							time.sleep(5) # important or the process will die
							os.system('sudo DreamDaemon /home/1713/civ13/civ13.dmb 1713 -trusted -webclient -logself &')
							print("Restarted main server on port civ13.")
	except IOError: # proc has already terminated
		continue

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
		if os.path.isfile("/home/customer/WW13/WW13-1/serverdata.txt"):
			if os.path.isfile("/home/customer/WW13/WW13-2/serverdata.txt"):
				if os.path.getmtime("/home/customer/WW13/WW13-1/serverdata.txt") > os.path.getmtime("/home/customer/WW13/WW13-2/serverdata.txt"):
					may_restart_server.append("13001")
				else:
					may_restart_server.append("13000")
			else:
				may_restart_server.append("13001")
		elif os.path.isfile("/home/customer/WW13/WW13-2/serverdata.txt"):
			may_restart_server.append("13000")
			
		if len(may_restart_server) == 0:
			may_restart_server.append("notathing")
			
		name = open(os.path.join('/proc', pid, 'cmdline'), 'r').read()
		if "WW13.dmb" in name:
			if not "sudo" in name:

				# main server logic: for some reason I could get a valid string/int for port so we're just using "in"
				
				# WW13-2 is the active server; restart WW13-1
				if "13000" in name and may_restart_server[0] == "13000":
					if os.path.isfile("/home/customer/WW13/WW13-2/serverdata.txt"):
						process = psutil.Process(int(pid))
						if process != None:
							os.kill(int(pid), signal.SIGKILL)
							# for some reason I have to do this now
							time.sleep(5) # important or the process will die
							os.system('sudo DreamDaemon /home/customer/WW13/WW13-1/WW13.dmb 13000 -trusted -logself &')
							print("Restarted inactive server on port 13000.")

				# WW13-1 is the active server; restart WW13-2
				elif "13001" in name and may_restart_server[0] == "13001":
					if os.path.isfile("/home/customer/WW13/WW13-1/serverdata.txt"):
						process = psutil.Process(int(pid))
						if process != None:
							os.kill(int(pid), signal.SIGKILL)
							time.sleep(5)
							os.system('sudo DreamDaemon /home/customer/WW13/WW13-2/WW13.dmb 13001 -trusted -logself &')
							print("Restarted inactive server on port 13001.")

				# testing server logic: TODO

				# WW13-4 is the active server; restart WW13-3
				elif "13002" in name:
					if os.path.isfile("/home/customer/WW13/WW13-4/serverdata.txt"):
						process = psutil.Process(int(pid))
						if process != None:
							os.kill(int(pid), signal.SIGKILL)
							time.sleep(5)
							os.system('sudo DreamDaemon /home/customer/WW13/WW13-3/WW13.dmb 13002 -trusted -logself &')
							print("Restarted inactive server on port 13002.")

				# WW13-3 is the active server; restart WW13-4
				elif "13003" in name:
					if os.path.isfile("/home/customer/WW13/WW13-3/serverdata.txt"):
						process = psutil.Process(int(pid))
						if process != None:
							os.kill(int(pid), signal.SIGKILL)
							time.sleep(5)
							os.system('sudo DreamDaemon /home/customer/WW13/WW13-4/WW13.dmb 13003 -trusted -logself &')
							print("Restarted inactive server on port 13003.")
						
			 		  
	except IOError: # proc has already terminated
		continue

# what name ends up being, for reference - Kachnov 

#sudoWW13.dmb13000-trusted-logself
#DreamDaemonWW13.dmb13000-trusted-logself
#sudoDreamDaemonWW13.dmb13001-trusted-logself
#DreamDaemonWW13.dmb13001-trusted-logself

# also note os.getpid() to get our pid
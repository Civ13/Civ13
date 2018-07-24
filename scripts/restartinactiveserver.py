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
		if os.path.isfile("/home/customer/1713/1713-1/serverdata.txt"):
			if os.path.isfile("/home/customer/1713/1713-2/serverdata.txt"):
				if os.path.getmtime("/home/customer/1713/1713-1/serverdata.txt") > os.path.getmtime("/home/customer/1713/1713-2/serverdata.txt"):
					may_restart_server.append("12001")
				else:
					may_restart_server.append("12000")
			else:
				may_restart_server.append("12001")
		elif os.path.isfile("/home/customer/1713/1713-2/serverdata.txt"):
			may_restart_server.append("12000")
			
		if len(may_restart_server) == 0:
			may_restart_server.append("notathing")
			
		name = open(os.path.join('/proc', pid, 'cmdline'), 'r').read()
		if "1713.dmb" in name:
			if not "sudo" in name:

				# main server logic: for some reason I could get a valid string/int for port so we're just using "in"
				
				# 1713-2 is the active server; restart 1713-1
				if "12000" in name and may_restart_server[0] == "12000":
					if os.path.isfile("/home/customer/1713/1713-2/serverdata.txt"):
						process = psutil.Process(int(pid))
						if process != None:
							os.kill(int(pid), signal.SIGKILL)
							# for some reason I have to do this now
							time.sleep(5) # important or the process will die
							os.system('sudo DreamDaemon /home/customer/1713/1713-1/1713.dmb 12000 -trusted -logself &')
							print("Restarted inactive server on port 12000.")

				# 1713-1 is the active server; restart 1713-2
				elif "12001" in name and may_restart_server[0] == "12001":
					if os.path.isfile("/home/customer/1713/1713-1/serverdata.txt"):
						process = psutil.Process(int(pid))
						if process != None:
							os.kill(int(pid), signal.SIGKILL)
							time.sleep(5)
							os.system('sudo DreamDaemon /home/customer/1713/1713-2/1713.dmb 12001 -trusted -logself &')
							print("Restarted inactive server on port 12001.")

				# testing server logic: TODO

				# 1713-4 is the active server; restart 1713-3
				elif "12002" in name:
					if os.path.isfile("/home/customer/1713/1713-4/serverdata.txt"):
						process = psutil.Process(int(pid))
						if process != None:
							os.kill(int(pid), signal.SIGKILL)
							time.sleep(5)
							os.system('sudo DreamDaemon /home/customer/1713/1713-3/1713.dmb 12002 -trusted -logself &')
							print("Restarted inactive server on port 12002.")

				# 1713-3 is the active server; restart 1713-4
				elif "12003" in name:
					if os.path.isfile("/home/customer/1713/1713-3/serverdata.txt"):
						process = psutil.Process(int(pid))
						if process != None:
							os.kill(int(pid), signal.SIGKILL)
							time.sleep(5)
							os.system('sudo DreamDaemon /home/customer/1713/1713-4/1713.dmb 12003 -trusted -logself &')
							print("Restarted inactive server on port 12003.")
						
			 		  
	except IOError: # proc has already terminated
		continue

# what name ends up being, for reference - Kachnov 

#sudo1713.dmb12000-trusted-logself
#DreamDaemon1713.dmb12000-trusted-logself
#sudoDreamDaemon1713.dmb12001-trusted-logself
#DreamDaemon1713.dmb12001-trusted-logself

# also note os.getpid() to get our pid
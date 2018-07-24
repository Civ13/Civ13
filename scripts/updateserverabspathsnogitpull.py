# to be called from mapswap.py only

import os
import shutil 
import time
import subprocess
import sys 

t1 = time.time()

print("Rebuilding binaries...")

os.system("DreamMaker /home/customer/1713-git/1713.dme")

print("Copying configuration settings...")

os.system("sudo python3.5 /home/customer/1713/scripts/copyconfigfiles.py")

print("Copying binaries...")

dmb = os.path.join('/home/customer/1713-git/1713.dmb')
rsc = os.path.join('/home/customer/1713-git/1713.rsc')

shutil.copyfile(dmb, '/home/customer/1713/1713-1/1713.dmb')
shutil.copyfile(dmb, '/home/customer/1713/1713-2/1713.dmb')
shutil.copyfile(dmb, '/home/customer/1713/1713-3/1713.dmb')
shutil.copyfile(dmb, '/home/customer/1713/1713-4/1713.dmb')

shutil.copyfile(rsc, '/home/customer/1713/1713-1/1713.rsc')
shutil.copyfile(rsc, '/home/customer/1713/1713-2/1713.rsc')
shutil.copyfile(rsc, '/home/customer/1713/1713-3/1713.rsc')
shutil.copyfile(rsc, '/home/customer/1713/1713-4/1713.rsc')

# detect if we're using serverswap, and, if so, restart the inactive server 
# its on the host to make sure this doesn't happen at a bad time causing the server to restart 
# while the active server is also restarting

# this is NOT failsafe: it will probably work 95% of the time. If it fails, the host has to type 
# it manually or we won't get an update next round, but the round after - Kachnov

c1 = os.path.exists('/home/customer/1713/1713-1/serverdata.txt')
c2 = os.path.exists('/home/customer/1713/1713-2/serverdata.txt')
c3 = os.path.exists('/home/customer/1713/1713-3/serverdata.txt')
c4 = os.path.exists('/home/customer/1713/1713-4/serverdata.txt')

if not c1 and not c2 and not c3 and not c4:
	print("updateserver.py has detected that you aren't using serverswap, so no server will be restarted.")
else:
	os.system('sudo python3.5 /home/customer/1713/scripts/restartinactiveserver.py')


t2 = time.time() - t1

print("Finished updating all directories in {} seconds".format(t2))

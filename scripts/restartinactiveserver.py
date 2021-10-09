import os
import psutil
import signal
import time
currdir = os.path.dirname(os.path.abspath(__file__))
lines = open(os.path.join(currdir, "paths.txt"))
all_lines = lines.readlines()
mdir = all_lines[1]
mdir = mdir.replace("\n", "")
mdir = mdir.replace("mdir:", "")
cdir = all_lines[2]
cdir = cdir.replace("\n", "")
cdir = cdir.replace("cdir:", "")
port = all_lines[3]
port = port.replace("\n", "")
port = port.replace("port:", "")
pids = [pid for pid in os.listdir('/proc') if pid.isdigit()]

for pid in pids:
    try:

        # due to BUGS we need to make sure the file we use as a reference is newer than the other
        # todo: add test server support
        may_restart_server = []
        may_restart_server.append("1714")

        if len(may_restart_server) == 0:
            may_restart_server.append("notathing")

        name = open(os.path.join('/proc', pid, 'cmdline'), 'r').read()
        if "civ13.dmb" in name:
            if not "sudo" in name:

                # main server logic: for some reason I could get a valid string/int for port so we're just using "in"

                # 1714-1 is the active server; restart 1714-1
                if "1714" in name and may_restart_server[0] == port:
                    if os.path.isfile("{}{}serverdata.txt".format(mdir, cdir)):
                        process = psutil.Process(int(pid))
                        if process is not None:
                            os.kill(int(pid), signal.SIGKILL)
                            # for some reason I have to do this now
                            time.sleep(5)
                            os.system(
                                'sudo DreamDaemon {}{}civ13.dmb {} -trusted -webclient -logself &'.format(mdir, cdir, port))
                            print("Restarted main server on port {}.".format(port))
    except IOError:
        continue

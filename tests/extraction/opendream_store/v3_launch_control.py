"""Frozen V3 launch negative control; never use for real effects."""
import subprocess
import os
import run as r

def launch_control(self, owned, argv, cwd, env, logroot):
    # Retain Popen object before __init__: even a partial creation failure has
    # a recorded object/pid. Owner slot itself is registered by caller first.
    owned.process = subprocess.Popen.__new__(subprocess.Popen)
    owned.stdout = open(self._safe(logroot+'.stdout'), 'xb', buffering=0)
    owned.stderr = open(self._safe(logroot+'.stderr'), 'xb', buffering=0)
    try:
        subprocess.Popen.__init__(owned.process, argv, cwd=cwd, env=env,
            stdin=subprocess.PIPE if owned.console else subprocess.DEVNULL,
            stdout=owned.stdout, stderr=owned.stderr,
            shell=False, start_new_session=True, close_fds=True)
    finally:
        owned.pid = getattr(owned.process, 'pid', None)
        if owned.pid:
            try: owned.birth = self._stat(owned.pid)['birth']
            except FileNotFoundError: pass
    r.need(owned.pid and owned.birth, 'launch identity unavailable')
    if owned.console: os.set_blocking(owned.process.stdin.fileno(), False)

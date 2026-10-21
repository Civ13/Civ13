#!/usr/bin/python3
"""Root-installed, fixed-service interface. Never import from a writable checkout."""
import os
import subprocess
import sys
import time

SERVICE = "civilizationbot.service"
ACTIONS = {"start", "restart", "status"}
STATE = "/run/civ13-bot-control"

def perform(action, previous, now, runner):
    if action not in ACTIONS:
        return 64, previous
    # One shared budget across game servers. Status does not consume it.
    if action != "status" and previous is not None and now - previous < 60:
        return 75, previous
    command = ["/usr/bin/systemctl"]
    command += ["is-active", "--quiet"] if action == "status" else ["--no-block", action]
    command.append(SERVICE)
    try:
        result = runner(command, timeout=3, check=False)
        code = result.returncode
    except subprocess.TimeoutExpired:
        code = 124
    # Reserve even failed requests, preventing failure/restart storms.
    return code, previous if action == "status" else now

def main():
    import fcntl
    if len(sys.argv) != 2 or sys.argv[1] not in ACTIONS:
        return 64
    if os.geteuid() != 0:
        return 77
    os.makedirs(STATE, mode=0o700, exist_ok=True)
    flags = os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW
    fd = os.open(STATE + "/lock", flags, 0o600)
    with os.fdopen(fd, "r+") as lock:
        # Never queue a sleeping game proc behind another helper invocation.
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return 75
        raw = lock.read().strip()
        previous = float(raw) if raw else None
        code, stamp = perform(sys.argv[1], previous, time.monotonic(), subprocess.run)
        if stamp is not None:
            lock.seek(0)
            lock.truncate()
            lock.write(str(stamp))
            lock.flush()
        return code

if __name__ == "__main__":
    sys.exit(main())

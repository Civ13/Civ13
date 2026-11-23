"""Inert socket controls and pre-exec namespace assertion for the native probe."""
import errno
import os
import socket
import subprocess
import sys


def denied(action):
    try:
        action()
    except OSError as error:
        assert error.errno == errno.EPERM, error
    else:
        raise AssertionError(f"Expected EPERM: {action}")


def prove():
    netns = os.readlink("/proc/self/ns/net")
    assert netns != os.environ["PARENT_NET"], (netns, os.environ["PARENT_NET"])
    devices = [x.split(":")[0].strip() for x in open("/proc/net/dev").read().splitlines()[2:]]
    assert devices == ["lo"], devices
    assert not open("/proc/net/if_inet6").read().strip()
    assert all(not line.strip() or line.startswith("Iface") for line in open("/proc/net/route"))
    for table in ("tcp", "tcp6", "udp", "udp6"):
        assert len(open(f"/proc/net/{table}").read().splitlines()) == 1, table
    for family in (socket.AF_INET, socket.AF_INET6, socket.AF_UNIX):
        denied(lambda: socket.socket(family, socket.SOCK_STREAM))
    print("socket(AF_INET/AF_INET6/AF_UNIX) denied")
    print("network namespace differs, only loopback (DOWN), no routes, IPv6 entries or listeners")


if __name__ == "__main__":
    prove()
    if len(sys.argv) > 1:
        assert sys.argv[1] == "--exec" and len(sys.argv) >= 3
        subprocess.run([sys.executable, __file__], check=True)
        print("denial inherited by fresh child exec")
        sys.stdout.flush()
        os.execv(sys.argv[2], sys.argv[2:])

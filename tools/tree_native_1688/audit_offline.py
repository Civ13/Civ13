"""Offline audit fence installed before imports/preparation/tests.

Reject real subprocess, socket, dynamic native loading, execution, and /proc
inspection. This is an audit defense for this Python process, not an OS sandbox.
"""
import os
import sys

DENIED_PREFIXES = ('subprocess.', 'socket.', 'ctypes.dlopen', 'os.exec', 'os.spawn',
                   'os.posix_spawn', 'os.fork', 'os.system', 'pty.spawn')


def guard(event, args):
    if event.startswith(DENIED_PREFIXES):
        raise RuntimeError('OFFLINE_AUDIT_DENIED: ' + event)
    if event == 'open' and args:
        path = args[0]
        if isinstance(path, (str, bytes, os.PathLike)):
            normalized = os.path.abspath(os.fsdecode(path))
            if normalized == '/proc' or normalized.startswith('/proc/'):
                raise RuntimeError('OFFLINE_AUDIT_DENIED: /proc inspection')
    if event in ('os.listdir', 'os.scandir') and args and isinstance(args[0], (str, bytes, os.PathLike)):
        normalized = os.path.abspath(os.fsdecode(args[0]))
        if normalized == '/proc' or normalized.startswith('/proc/'):
            raise RuntimeError('OFFLINE_AUDIT_DENIED: /proc discovery')


def install():
    sys.addaudithook(guard)

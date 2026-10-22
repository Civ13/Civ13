"""Frozen V2 signal function, with syscall modules absent until injected by tests.

Copied from cbea484568a9a54dc63e8e2b042b07bcc897a339feb66905a2cc43253c87eb9b
backend.py. This is a negative control only, never a production backend.
"""
import run as r
os = None
signal = None


def signal_control(self, owned, sig):
    if owned.process is not None:
        r.need(owned.pid is not None and owned.birth is not None, 'partial process identity unresolved')
    rows = self.members(owned)
    if rows:
        os.killpg(owned.pid, getattr(signal,sig))

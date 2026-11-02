"""Job-local Docker identity checks; no Docker operation occurs on import."""
import hashlib
import json
import os
from pathlib import Path
import signal
import socket
import stat
import struct
import subprocess
import tempfile
import time

ENDPOINT = 'unix:///var/run/docker.sock'
SOCKET = '/var/run/docker.sock'
IMAGE_ID = 'sha256:4690e6bc50d08b799d527398716478f164832b5a9dddb8eb0588c88ba5cd40bc'

def boot_identity():
    value = Path('/proc/sys/kernel/random/boot_id').read_text(encoding='ascii').strip()
    if len(value) != 36:
        raise ValueError('host boot identity unavailable')
    return value

def file_hash(path):
    path = Path(path).resolve(strict=True)
    if not path.is_file() or path.stat().st_size > 64 * 1024**2:
        raise ValueError('invalid executable')
    return hashlib.sha256(path.read_bytes()).hexdigest()

def socket_identity(path=SOCKET):
    before = os.stat(path)
    if not stat.S_ISSOCK(before.st_mode):
        raise ValueError('Docker endpoint is not a Unix socket')
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as conn:
        conn.settimeout(3); conn.connect(path)
        peer_pid, peer_uid, peer_gid = struct.unpack('3i', conn.getsockopt(socket.SOL_SOCKET, socket.SO_PEERCRED, 12))
    after = os.stat(path)
    if peer_pid <= 0 or (before.st_dev, before.st_ino, before.st_uid, before.st_gid) != (after.st_dev, after.st_ino, after.st_uid, after.st_gid):
        raise ValueError('Docker socket changed during peer identification')
    return {'device': before.st_dev, 'inode': before.st_ino, 'uid': before.st_uid, 'gid': before.st_gid,
            'peer_pid': peer_pid, 'peer_uid': peer_uid, 'peer_gid': peer_gid}

def info(docker, config):
    import resource
    env = {'PATH': '/usr/bin:/bin', 'HOME': str(config), 'LANG': 'C', 'LC_ALL': 'C'}
    cmd = [str(docker), '--host', ENDPOINT, '--config', str(config), 'info', '--format', '{{json .}}']
    def limits():
        resource.setrlimit(resource.RLIMIT_FSIZE, (1024 * 1024, 1024 * 1024))
        resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    with tempfile.TemporaryFile() as out, tempfile.TemporaryFile() as err:
        proc = subprocess.Popen(cmd, env=env, stdin=subprocess.DEVNULL, stdout=out, stderr=err,
                                start_new_session=True, preexec_fn=limits)
        timed_out = False; deadline = time.monotonic() + 10
        try:
            while os.waitid(os.P_PID, proc.pid, os.WEXITED | os.WNOHANG | os.WNOWAIT) is None:
                if time.monotonic() >= deadline:
                    timed_out = True; break
                time.sleep(.05)
        finally:
            try: os.killpg(proc.pid, signal.SIGKILL)
            except ProcessLookupError: pass
            proc.wait(timeout=10)
        out.seek(0); err.seek(0); data = out.read(1024 * 1024 + 1); errors = err.read(1024 * 1024 + 1)
    if timed_out or proc.returncode != 0 or len(data) > 1024 * 1024 or len(errors) > 1024 * 1024:
        raise ValueError('Docker info failed or was oversized')
    row = json.loads(data)
    if type(row) is not dict or not isinstance(row.get('ID'), str) or not row['ID'] or not isinstance(row.get('ServerVersion'), str) or not row['ServerVersion']:
        raise ValueError('Docker daemon ID unavailable')
    return {'id': row['ID'], 'server_version': row.get('ServerVersion')}

def same_daemon(docker, config, expected, *, get_socket=socket_identity, get_info=info):
    before = get_socket()
    observed = get_info(docker, config)
    after = get_socket()
    if before != after or before != expected['socket'] or observed != expected['daemon']:
        raise ValueError('Docker daemon/socket identity changed')
    return True

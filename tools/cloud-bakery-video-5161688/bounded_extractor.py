"""Capture bounded stdout/stderr and exit state of one owned system tool."""
import json
import subprocess
import threading
import time
from pathlib import Path

MAX_OUTPUT = 65536


def invoke(command, cwd, env, phase, deadline):
    cwd = Path(cwd)
    if phase not in ('tar-list', 'expand-extract'):
        raise ValueError('invalid_extractor_phase')
    files = [cwd / (phase + suffix) for suffix in ('.stdout.log', '.stderr.log', '.json')]
    if any(p.exists() or p.is_symlink() for p in files):
        raise ValueError('fresh_extractor_logs_required')
    outputs = {'stdout': bytearray(), 'stderr': bytearray()}
    counts = {'stdout': 0, 'stderr': 0}
    overflow = {'stdout': False, 'stderr': False}
    read_errors = {'stdout': False, 'stderr': False}
    receipt = {'phase': phase, 'exit_code': None, 'timed_out': False,
               'direct_child_exited': False, 'stdout_overflow': False, 'stderr_overflow': False}
    process = None
    readers = []
    def consume(name, stream):
        try:
            while True:
                chunk = stream.read(4096)
                if not chunk:
                    break
                counts[name] += len(chunk)
                remaining = MAX_OUTPUT - len(outputs[name])
                outputs[name].extend(chunk[:max(0, remaining)])
                if counts[name] > MAX_OUTPUT:
                    overflow[name] = True
                    try: process.kill()
                    except OSError: pass
        except Exception:
            read_errors[name] = True
            try: process.kill()
            except OSError: pass
        finally:
            stream.close()
    try:
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise TimeoutError('extractor_deadline')
        process = subprocess.Popen(command, cwd=cwd, env=env, stdin=subprocess.DEVNULL,
                                   stdout=subprocess.PIPE, stderr=subprocess.PIPE, close_fds=True,
                                   creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
        readers = [threading.Thread(target=consume, args=(name, stream), daemon=True)
                   for name, stream in (('stdout', process.stdout), ('stderr', process.stderr))]
        for thread in readers: thread.start()
        try:
            receipt['exit_code'] = process.wait(timeout=min(45, remaining))
        except subprocess.TimeoutExpired:
            receipt['timed_out'] = True
            process.kill()
            receipt['exit_code'] = process.wait(timeout=5)
        receipt['direct_child_exited'] = process.poll() is not None
        for thread in readers: thread.join(timeout=5)
        if any(thread.is_alive() for thread in readers):
            raise RuntimeError('extractor_pipe_cleanup_unconfirmed')
    except Exception as error:
        receipt['failure_class'] = type(error).__name__
        if process is not None and process.poll() is None:
            try:
                process.kill()
                process.wait(timeout=5)
                receipt['direct_child_exited'] = True
            except Exception:
                receipt['direct_child_exited'] = False
        raise
    finally:
        for thread in readers:
            if thread.is_alive(): thread.join(timeout=5)
        receipt['pipes_closed'] = all(not thread.is_alive() for thread in readers)
        receipt.update(stdout_bytes_observed=counts['stdout'], stderr_bytes_observed=counts['stderr'],
                       stdout_overflow=overflow['stdout'], stderr_overflow=overflow['stderr'],
                       stdout_read_error=read_errors['stdout'], stderr_read_error=read_errors['stderr'])
        for path, name in zip(files[:2], ('stdout', 'stderr')):
            with path.open('xb') as stream: stream.write(outputs[name])
        encoded = (json.dumps(receipt, sort_keys=True) + '\n').encode()
        if len(encoded) > 16384:
            raise RuntimeError('extractor_receipt_oversize')
        with files[2].open('xb') as stream: stream.write(encoded)
    return receipt

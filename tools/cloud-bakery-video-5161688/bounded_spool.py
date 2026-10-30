"""Bounded raw-frame spool worker; no process, window or capture authority."""
import hashlib
import queue
import threading
import time


class BoundedSpool:
    """One worker and at most four queued-or-writing RGB frames.

    The capture thread retains all owner/window/watchdog checks and timestamps.
    This worker only hashes and exclusively writes caller-supplied bytes to
    caller-owned fresh paths. Failure or saturation aborts the take.
    """
    CAPACITY = 4
    FRAME_BYTES = 691200

    def __init__(self):
        self._queue = queue.Queue(maxsize=self.CAPACITY)
        self._slots = threading.BoundedSemaphore(self.CAPACITY)
        self._abort = threading.Event()
        self._closing = threading.Event()
        self._lock = threading.Lock()
        self._error = None
        self._completed = {}
        self._created = []
        self._pending = 0
        self._peak = 0
        self._submitted = 0
        self._max_hash_ns = 0
        self._max_write_ns = 0
        self._thread = threading.Thread(target=self._run, name='bounded-raw-spool', daemon=True)
        self._thread.start()

    def check(self):
        with self._lock:
            error = self._error
        if error is not None:
            raise RuntimeError('Raw spool worker failed: ' + error)

    def submit(self, index, path, data):
        self.check()
        if self._closing.is_set() or self._abort.is_set():
            raise RuntimeError('Raw spool closed')
        if type(index) is not int or index < 0 or type(data) is not bytes or len(data) != self.FRAME_BYTES:
            raise RuntimeError('Invalid raw spool item')
        if not self._slots.acquire(blocking=False):
            raise RuntimeError('Raw spool backlog exhausted')
        registered = False
        try:
            with self._lock:
                if index != self._submitted:
                    raise RuntimeError('Raw spool indices must be sequential')
                self._pending += 1
                self._peak = max(self._peak, self._pending)
                self._submitted += 1
                registered = True
            self._queue.put_nowait((index, path, data))
        except BaseException:
            with self._lock:
                if registered:
                    self._submitted -= 1
                    self._pending -= 1
            self._slots.release()
            raise
        self.check()

    def _run(self):
        while not self._abort.is_set():
            try:
                index, path, data = self._queue.get(timeout=.01)
            except queue.Empty:
                if self._closing.is_set():
                    return
                continue
            try:
                start = time.perf_counter_ns()
                digest = hashlib.sha256(data).hexdigest()
                hashed = time.perf_counter_ns()
                with path.open('xb') as stream:
                    with self._lock:
                        self._created.append(path)
                    if stream.write(data) != len(data):
                        raise OSError('Incomplete raw spool write')
                written = time.perf_counter_ns()
                with self._lock:
                    if index in self._completed:
                        raise RuntimeError('Duplicate raw spool index')
                    self._completed[index] = digest
                    self._max_hash_ns = max(self._max_hash_ns, hashed-start)
                    self._max_write_ns = max(self._max_write_ns, written-hashed)
            except BaseException as error:
                with self._lock:
                    self._error = type(error).__name__ + ': ' + str(error)[:256]
                self._abort.set()
            finally:
                with self._lock:
                    self._pending -= 1
                self._slots.release()
                self._queue.task_done()

    def stats(self):
        with self._lock:
            return dict(capacity=self.CAPACITY, peak_outstanding=self._peak,
                        submitted=self._submitted, completed=len(self._completed),
                        max_hash_ns=self._max_hash_ns, max_write_ns=self._max_write_ns)

    def created_paths(self):
        """Only files this worker successfully created with exclusive open."""
        with self._lock:
            return list(self._created)

    def finish(self, count, watch, timeout=.5):
        self._closing.set()
        deadline = time.monotonic() + timeout
        while self._thread.is_alive():
            self.check()
            watch()
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise RuntimeError('Raw spool drain deadline exceeded')
            self._thread.join(min(.01, remaining))
        self.check()
        with self._lock:
            if set(self._completed) != set(range(count)):
                raise RuntimeError('Raw spool incomplete')
            return dict(self._completed)

    def cancel_and_join(self, timeout=2):
        """No file cleanup until the worker has stopped writing."""
        self._abort.set()
        self._thread.join(timeout)
        if self._thread.is_alive():
            return False
        while True:
            try:
                self._queue.get_nowait()
            except queue.Empty:
                break
            else:
                self._queue.task_done()
        return True

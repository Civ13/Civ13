"""Shared original-entry smoke budget; no host or native effects."""
import time

def require(condition, message):
    if not condition:
        raise RuntimeError(message)


class Budget:
    """One entry-anchored cooperative envelope; blocking calls are not preempted."""
    CLEANUP_RESERVE = 15
    RECEIPT_RESERVE = 1

    def __init__(self):
        self.started_monotonic = time.monotonic()
        self.started_utc = time.time()
        self.full_end = self.started_monotonic + 165
        self.utc_end = self.started_utc + 165
        self.work_end = self.started_monotonic + 150

    def bind(self, expires):
        self.utc_end = min(self.utc_end, expires)
        # Anchor the grant conversion to ENTRY, never to the end of preparation.
        self.full_end = min(self.full_end, self.started_monotonic + expires - self.started_utc)
        self.check()

    def remaining(self, work=False):
        mono, utc = time.monotonic(), time.time()
        # A forward UTC jump permanently contracts the monotonic allowance;
        # moving UTC backward later cannot replenish an observed grant.
        self.full_end = min(self.full_end, mono + self.utc_end - utc)
        end = self.full_end
        if work:
            end = min(self.work_end, end - self.CLEANUP_RESERVE - self.RECEIPT_RESERVE)
        return max(0, end - mono)

    def check(self, work=True):
        require(self.remaining(work) > 0, 'Shared smoke work/cleanup budget exhausted')

    def cleanup_wait(self):
        return min(5, max(0, self.remaining() - self.RECEIPT_RESERVE))

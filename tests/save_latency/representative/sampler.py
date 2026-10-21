"""Independent monotonic observation with bounded requests and explicit gaps."""
import math


def validate_bounds(duration, cadence, max_samples):
    if (not all(math.isfinite(value) and value > 0 for value in (duration, cadence))
            or type(max_samples) is not int or not 1 <= max_samples <= 100000):
        raise ValueError('Finite positive sampling bounds required')
    if math.ceil(duration / cadence) > max_samples:
        raise ValueError('Sampling allocation exceeds hard sample bound')


def sample(request, clock, wait, *, duration, cadence, max_samples,
           stopped=lambda: False, record=None, deadline=None):
    """request(remaining_seconds) is injected; it must honor its bounded timeout.

    One call is outstanding at a time. No socket, process or clock is created.
    Missed deadlines are retained, never filled with synthetic heartbeat values.
    """
    validate_bounds(duration, cadence, max_samples)
    start = clock()
    end = min(start + duration, deadline) if deadline is not None else start + duration
    target = start
    rows = []
    last_time = start
    while target < end and not stopped():
        now = clock()
        if now < last_time:
            raise ValueError('Monotonic clock moved backwards')
        if now >= end:
            break
        missed_before = 0
        if now-target >= cadence:
            missed_before = math.ceil((now-target)/cadence)
            target += missed_before*cadence
        if target >= end:
            break
        if now < target:
            wait(target - now)
        if stopped():
            break
        sent = clock()
        if sent >= end:
            break
        if sent < max(target, last_time):
            raise ValueError('Sampling wait did not reach its monotonic target')
        row = {'scheduled': target, 'sent': sent,
               'deadline_misses': missed_before + max(0, int((sent-target)//cadence))}
        try:
            observation = request(min(cadence, end-sent))
            heartbeat = observation.get('heartbeat') if isinstance(observation, dict) else observation
            if type(heartbeat) is not int or heartbeat < 0:
                raise ValueError('Invalid actual heartbeat counter')
            row['heartbeat'] = heartbeat
            if isinstance(observation, dict):
                row['server_phase_at_response'] = observation.get('phase')
                row['world_time_at_response'] = observation.get('world_time')
            row['status'] = 'observed'
        except TimeoutError:
            row['status'] = 'timeout'
        received = clock()
        if received < sent:
            raise ValueError('Monotonic clock moved backwards')
        row['received'] = received
        row['latency'] = received - sent
        row['service_delay'] = received - target
        row['skipped_after'] = max(0, math.floor((received-start)/cadence) - math.floor((target-start)/cadence))
        if received > sent + min(cadence, end-sent):
            row['status'] = 'transport_exceeded_timeout'
        rows.append(row)
        if len(rows) > max_samples:
            raise RuntimeError('Hard sample bound exceeded')
        if record:
            record(row)
        last_time = received
        # Skip missed slots without queuing a burst after a stall.
        target = max(sent+cadence, start + (math.floor((received-start)/cadence)+1)*cadence)
    return rows

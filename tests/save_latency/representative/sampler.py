"""Independent monotonic observation with bounded requests and explicit gaps."""
import math


def sample(request, clock, wait, *, duration, cadence, max_samples):
    """request(remaining_seconds) is injected; it must honor its bounded timeout.

    One call is outstanding at a time. No socket, process or clock is created.
    Missed deadlines are retained, never filled with synthetic heartbeat values.
    """
    if (not all(math.isfinite(value) and value > 0 for value in (duration, cadence))
            or type(max_samples) is not int or not 1 <= max_samples <= 100000):
        raise ValueError('Finite positive sampling bounds required')
    if math.ceil(duration / cadence) > max_samples:
        raise ValueError('Sampling allocation exceeds hard sample bound')
    start = clock()
    end = start + duration
    target = start
    rows = []
    last_time = start
    while target < end:
        now = clock()
        if now < last_time:
            raise ValueError('Monotonic clock moved backwards')
        if now >= end:
            break
        if now < target:
            wait(target - now)
        sent = clock()
        if sent >= end:
            break
        row = {'scheduled': target, 'sent': sent, 'deadline_misses': max(0, int((sent-target)//cadence))}
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
        last_time = received
        # Skip missed slots without queuing a burst after a stall.
        target = start + (max(len(rows), math.floor((received-start)/cadence)+1)) * cadence
    return rows

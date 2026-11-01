"""Timing preflight for an unimplemented paired worker; not a runner."""
import math

SUITE = 'bump05'
COMPILE_SECONDS = 90
DAEMON_SECONDS = 60
SETUP_SECONDS = 60
WORK_SECONDS = 490
OUTER_SECONDS = 600
ADMISSION_RESERVE = 2 * COMPILE_SECONDS + 2 * DAEMON_SECONDS + SETUP_SECONDS
PHASES = (('baseline_compile', COMPILE_SECONDS), ('baseline_daemon', DAEMON_SECONDS),
          ('candidate_compile', COMPILE_SECONDS), ('candidate_daemon', DAEMON_SECONDS))


def finite(value):
    return type(value) in (int, float) and math.isfinite(value)


def admission(suite, now, work_deadline):
    if (suite != SUITE or not finite(now) or not finite(work_deadline) or
            now + ADMISSION_RESERVE > work_deadline):
        raise ValueError('insufficient paired work deadline or invalid suite')


def remaining(phase_index, setup_used, now, work_deadline):
    if (type(phase_index) is not int or not 0 <= phase_index <= len(PHASES) or
            not finite(setup_used) or not 0 <= setup_used <= SETUP_SECONDS or
            not finite(now) or not finite(work_deadline)):
        raise ValueError('invalid remaining work accounting')
    reserve = sum(limit for _, limit in PHASES[phase_index:]) + SETUP_SECONDS - setup_used
    if now + reserve > work_deadline:
        raise ValueError('insufficient deadline for remaining bounded phases')


def validate_accounting(phases, elapsed, setup):
    if type(phases) is not list or len(phases) != len(PHASES):
        raise ValueError('incomplete phases')
    total = 0
    for actual, (name, limit) in zip(phases, PHASES):
        if (type(actual) is not dict or actual.get('name') != name or
                actual.get('returncode') != 0 or actual.get('timed_out') is not False or
                actual.get('oversized_log') is not False or actual.get('deadline') != limit or
                not finite(actual.get('seconds')) or not 0 <= actual['seconds'] <= limit):
            raise ValueError('failed, missing or excessive phase: ' + name)
        total += actual['seconds']
    if (not finite(elapsed) or not finite(setup) or not 0 <= setup <= SETUP_SECONDS or
            not 0 <= elapsed <= WORK_SECONDS or abs(elapsed - total - setup) > 0.001):
        raise ValueError('unaccounted elapsed or setup')
    return True

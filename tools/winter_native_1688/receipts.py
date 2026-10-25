"""Pure injected lifecycle model. Its records are NOT native process evidence.

The backend must call started immediately after a successful spawn, BEFORE
identity observation or any receipt IO. Attempted is not started. A returned
process receipt is not a successful oracle, and cleanup failure never advances.
"""
import copy
from plan import PHASES, TOTAL_WALL_SECONDS, CLEANUP_RESERVE_SECONDS, PROFILES


class LifecycleModel:
    def __init__(self, binding, now=0.0):
        self.deadline = now + TOTAL_WALL_SECONDS
        self.binding = binding
        self.state = {'evidence_kind': 'offline-injected-lifecycle-model-not-native-execution',
                      'candidate_manifest_sha256': binding, 'native_executed': False,
                      'compiler_attempted': False, 'compiler_started': False, 'compiler_completed': False,
                      'daemon_attempted': False, 'daemon_started': False, 'daemon_completed': False,
                      'phases': [], 'status': 'pending'}
        self.next = 0
        self.active = None

    def attempt(self, phase_id, now):
        if self.state['status'] in ('failed', 'completed') or self.active is not None:
            raise ValueError('Cannot start another phase')
        if self.next >= len(PHASES) or PHASES[self.next][0] != phase_id:
            raise ValueError('Phase order or fixed phase inventory differs')
        role = PHASES[self.next][1]
        remaining = min(PROFILES[role]['wall_seconds'], self.deadline - now - CLEANUP_RESERVE_SECONDS)
        if remaining <= 0:
            self.state['status'] = 'failed'
            self.state['error'] = 'Aggregate deadline exhausted before spawn'
            raise ValueError(self.state['error'])
        self.active = {'phase': phase_id, 'role': role, 'attempted': True, 'started': False,
                       'terminated': False, 'process_completed': False, 'cleanup_verified': False,
                       'validated': False, 'pid': None, 'process_receipt': None,
                       'wall_seconds': remaining, 'candidate_manifest_sha256': self.binding}
        self.state['phases'].append(self.active)
        self.state[role + '_attempted'] = True
        self.state['status'] = 'running'
        return remaining

    def started(self, pid):
        if self.active is None or self.active['started'] or type(pid) is not int or pid <= 0:
            raise ValueError('Invalid or duplicate actual-start event')
        # The in-memory facts precede any future filesystem or identity operation.
        self.active['started'] = True
        self.active['pid'] = pid
        self.state['native_executed'] = True
        self.state[self.active['role'] + '_started'] = True

    def process_returned(self, receipt):
        if self.active is None or not self.active['started'] or self.active['process_completed']:
            raise ValueError('Completion cannot precede an actual-start event')
        if receipt.get('process_started') is not True or receipt.get('pid') != self.active['pid']:
            raise ValueError('Process receipt belongs to another invocation')
        self.active['process_receipt'] = copy.deepcopy(receipt)
        self.active['terminated'] = receipt.get('termination_observed') is True
        self.active['process_completed'] = True
        self.active['cleanup_verified'] = receipt.get('cleanup_verified') is True
        role = self.active['role']
        count = sum(row['process_completed'] for row in self.state['phases'] if row['role'] == role)
        self.state[role + '_completed'] = count == sum(item[1] == role for item in PHASES)
        required = ('termination_observed', 'leader_reaped', 'cleanup_verified',
                    'cleanup_no_observed_live_descendants', 'cleanup_process_group_absent',
                    'owned_child_listing_available', 'owned_observation_trusted', 'signal_handlers_restored')
        if (any(receipt.get(key) is not True for key in required) or
                type(receipt.get('exit_code')) is not int or receipt['exit_code'] != 0 or
                receipt.get('stop_reason') is not None or receipt.get('log_truncated') is not False or
                receipt.get('cleanup_errors') != []):
            self.fail('Process or cleanup failed', receipt)
            raise ValueError('Process or cleanup failed')

    def validate(self, verdict, now):
        if self.active is None or not self.active['process_completed'] or not self.active['cleanup_verified']:
            raise ValueError('Cannot validate absent process or cleanup proof')
        if verdict not in ('passed', 'causal-control-detected') or now > self.deadline:
            self.fail('Oracle or aggregate deadline failed')
            raise ValueError('Oracle or aggregate deadline failed')
        is_control = PHASES[self.next][1] == 'daemon' and PHASES[self.next][2] != 'baseline'
        if verdict != ('causal-control-detected' if is_control else 'passed'):
            self.fail('Wrong phase verdict')
            raise ValueError('Wrong phase verdict')
        self.active['validated'] = True
        self.active['verdict'] = verdict
        self.next += 1
        self.active = None
        self.state['status'] = 'completed' if self.next == len(PHASES) else 'pending'

    def fail(self, error, receipt=None):
        # A backend exception may include an actual-start fact even if callback
        # receipt IO failed. Preserve it; never infer cleanup or completion.
        if self.active is not None:
            if receipt is not None:
                self.active['process_receipt'] = copy.deepcopy(receipt)
                if receipt.get('process_started') is True:
                    pid = receipt.get('pid')
                    if type(pid) is int and pid > 0:
                        if self.active['started'] and self.active['pid'] != pid:
                            raise ValueError('Failure receipt belongs to another invocation')
                        self.active['started'] = True
                        self.active['pid'] = pid
                        self.state['native_executed'] = True
                        self.state[self.active['role'] + '_started'] = True
                self.active['terminated'] = receipt.get('termination_observed') is True
                self.active['cleanup_verified'] = receipt.get('cleanup_verified') is True
            self.active['error'] = str(error)
        self.state['status'] = 'failed'
        self.state['error'] = str(error)
        self.active = None

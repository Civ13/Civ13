"""Default-disabled, metadata-only diagnostic of one Job-owned client."""
import hashlib
import json
import ntpath
import re

CLIENT_STARTUP_DIAGNOSTIC_ENABLED = True
SECONDS = 5
EVENT_CAP = 256
COLLECT_EVENT_CAP = 240  # Reserve sixteen events for bounded termination draining.
IMAGE_CAP = 128
BYTE_CAP = 65536
CONTINUE = 0x00010002
NOT_HANDLED = 0x80010001
BREAKPOINTS = (0x80000003, 0x4000001f)


class DiagnosticError(RuntimeError):
    pass


def require(ok, label):
    if not ok:
        raise DiagnosticError(label)


def mode(requested, admission):
    require(type(requested) is bool, 'diagnostic_mode_type')
    admitted = admission.get('client_startup_diagnostic', False)
    require(type(admitted) is bool and admitted is requested, 'diagnostic_mode_binding')
    require(CLIENT_STARTUP_DIAGNOSTIC_ENABLED is requested, 'held_client_diagnostic')


def require_admission(requested):
    require(CLIENT_STARTUP_DIAGNOSTIC_ENABLED is requested, 'held_client_diagnostic')
    from activation import require_runtime
    admission = require_runtime()
    mode(requested, admission)
    return admission


def require_command(argv, phase, visible):
    require(CLIENT_STARTUP_DIAGNOSTIC_ENABLED is True, 'held_client_diagnostic')
    admission = require_admission(True)
    require(phase == 'client' and visible is True and len(argv) == 2 and
            ntpath.basename(str(argv[0])).lower() == 'dreamseeker.exe' and
            re.fullmatch(r'byond://127\.0\.0\.1:([1-9][0-9]{3,4})##guest', argv[1]) is not None,
            'diagnostic_command_binding')
    require(1024 <= int(argv[1].split(':')[-1].split('#')[0]) <= 65535,
            'diagnostic_port_binding')
    return admission


def failure_label(error):
    if isinstance(error, DiagnosticError):
        label = str(error)
        if re.fullmatch('[a-z0-9_]{1,80}', label):
            return label
    return 'api_error' if isinstance(error, OSError) else 'unexpected_error'


def bounded(value):
    raw = (json.dumps(value, sort_keys=True, allow_nan=False, separators=(',', ':'))+'\n').encode()
    if len(raw) < BYTE_CAP:
        return value
    return {'schema': 1, 'status': 'FAILED_DIAGNOSTIC_BYTE_CAP',
            'original_bytes': len(raw), 'original_sha256': hashlib.sha256(raw).hexdigest(),
            'detail_omitted': True, 'native_acceptance': False, 'root_cause_proven': False}


class Trace:
    def __init__(self, identity, binding):
        require(set(identity) == {'pid', 'creation_filetime', 'image'} and
                type(identity['pid']) is int and 0 < identity['pid'] < 2**32 and
                type(identity['creation_filetime']) is int and 0 < identity['creation_filetime'] < 2**63 and
                isinstance(identity['image'], str) and len(identity['image']) <= 512 and ntpath.isabs(identity['image']) and
                not any(ch in identity['image'] for ch in '\r\n\0') and
                ntpath.basename(identity['image']).lower() == 'dreamseeker.exe',
                'diagnostic_identity')
        self.identity, self.binding = dict(identity), dict(binding)
        self.events = self.images_seen = self.unknown_images = 0
        self.images, self.selected = {}, {}
        self.created = self.exit_seen = False
        self.exit_code = self.fault = self.outcome = None
        self.exit_during_cleanup = False
        self.observation_seconds = 0.
        self.system_breakpoints = set()
        self.application_exception_seen = False
        self.errors = []

    def error(self, label):
        if label not in self.errors and len(self.errors) < 8:
            self.errors.append(label)

    def match(self, address):
        hits = [row for base, row in self.images.items()
                if row.get('size') and base <= address < base+row['size']]
        return hits[0] if len(hits) == 1 else None

    def image(self, value):
        require(self.images_seen < IMAGE_CAP, 'diagnostic_image_cap')
        self.images_seen += 1
        base = value['base']
        require(type(base) is int and 0 < base < 2**64 and base not in self.images,
                'diagnostic_image_base')
        row = {'base': base, 'size': None}
        if value.get('name') is None:
            self.unknown_images += 1
        else:
            require(re.fullmatch(r'[A-Za-z0-9_. -]{1,128}', value['name']) is not None and
                    ntpath.basename(value['name']) == value['name'] and
                    type(value['size']) is int and 0 < value['size'] <= 512*1024**2 and
                    base+value['size'] <= 2**64 and value['origin'] in ('system', 'package', 'other'),
                    'diagnostic_image_metadata')
            row.update(name=value['name'], size=value['size'], origin=value['origin'])
            if value.get('selected'):
                require(re.fullmatch('[0-9a-f]{64}', value['sha256']) is not None and
                        type(value['matches_pin']) is bool, 'diagnostic_selected_metadata')
                name = value['name'].lower()
                previous = self.selected.get(name)
                selected = {
                    'name': value['name'], 'origin': value['origin'], 'sha256': value['sha256'],
                    'matches_pin': value['matches_pin'] is True, 'loads': 1}
                if previous:
                    selected.update(loads=previous['loads']+1, previous_sha256=previous['sha256'])
                self.selected[name] = selected
                require(value['matches_pin'] is True, 'diagnostic_selected_pin_mismatch')
        self.images[base] = row

    def consume(self, event, backend):
        require(type(event['pid']) is int and event['pid'] == self.identity['pid'] and
                type(event['tid']) is int and 0 < event['tid'] < 2**32,
                'diagnostic_event_identity')
        require(self.events < EVENT_CAP, 'diagnostic_event_cap')
        self.events += 1
        event['counted'] = True
        code = event['code']
        require(type(code) is int and 1 <= code <= 9 and not self.exit_seen, 'diagnostic_event_schema')
        if code == 3:
            require(not self.created and self.events == 1, 'diagnostic_creation_order')
            backend.adopt(event)
            self.created = True
            require(self.images_seen < IMAGE_CAP, 'diagnostic_image_cap')
            self.image(backend.image(event))
        else:
            require(self.created, 'diagnostic_creation_missing')
            if code == 6:
                require(self.images_seen < IMAGE_CAP, 'diagnostic_image_cap')
                self.image(backend.image(event))
            elif code == 7:
                self.images.pop(event['base'], None)
            elif code == 1:
                number, address, first = event['exception'], event['address'], event['first']
                require(type(first) is bool and type(number) is int and 0 <= number <= 0xffffffff and
                        type(address) is int and 0 <= address < 2**64, 'diagnostic_exception_schema')
                hit = self.match(address)
                # Only the first system-ntdll startup breakpoint per mapped image
                # (native + WOW64, at most two). Never swallow an application AV.
                if (first and number in BREAKPOINTS and not self.application_exception_seen and hit and
                        hit['name'].lower() == 'ntdll.dll' and hit['origin'] == 'system' and
                        hit['base'] not in self.system_breakpoints and len(self.system_breakpoints) < 2):
                    self.system_breakpoints.add(hit['base'])
                    return CONTINUE
                self.application_exception_seen = True
                if not first:
                    self.fault = {'exception_code': hex(number),
                                  'module': hit.get('name') if hit else None,
                                  'module_offset': hex(address-hit['base']) if hit else None,
                                  'root_cause_proven': False}
                    self.outcome = 'unhandled_exception'
                return NOT_HANDLED
            elif code == 5:
                require(type(event['exit']) is int and 0 <= event['exit'] <= 0xffffffff,
                        'diagnostic_exit_schema')
                self.exit_seen, self.exit_code = True, event['exit']
                self.outcome = self.outcome or 'exited'
            elif code == 9:
                raise DiagnosticError('diagnostic_rip_event')
        return CONTINUE  # No debug-string content, thread context or memory is read.

    def snapshot(self):
        return bounded({'schema': 1, 'identity': self.identity, 'admission': self.binding,
                        'status': 'FAILED_DIAGNOSTIC' if self.errors else 'DIAGNOSTIC_REVIEW_REQUIRED',
                        'outcome': self.outcome, 'events': self.events, 'images_seen': self.images_seen,
                        'unknown_images': self.unknown_images,
                        'handled_system_startup_breakpoints': len(self.system_breakpoints),
                        'selected_modules': list(self.selected.values()), 'exception': self.fault,
                        'exit_seen': self.exit_seen, 'exit_code': self.exit_code, 'errors': list(self.errors),
                        'exit_during_cleanup': self.exit_during_cleanup,
                        'observation_seconds': self.observation_seconds,
                        'observation_clock': 'perf_counter',
                        'native_acceptance': False, 'rendering_or_fps_verified': False,
                        'root_cause_proven': False, 'limits': {'seconds': SECONDS, 'events': EVENT_CAP,
                                                             'images': IMAGE_CAP, 'bytes': BYTE_CAP}})


def collect(trace, backend, watch, now):
    """The backend retains a pending event on failure for termination draining."""
    deadline = backend.started+SECONDS
    last_watch = -float('inf')
    try:
        while not trace.exit_seen:
            if now() >= deadline:
                trace.outcome = trace.outcome or 'five_second_limit'
                break
            require(trace.events < COLLECT_EVENT_CAP, 'diagnostic_event_cleanup_reserve')
            if now()-last_watch >= .05:
                watch()
                last_watch = now()
            require(now() < deadline, 'diagnostic_five_second_overrun')
            event = backend.next(min(50, max(0, int((deadline-now())*1000))))
            if event is None:
                continue
            require(now() < deadline, 'diagnostic_five_second_overrun')
            disposition = trace.consume(event, backend)
            backend.ack(disposition)
    except Exception as error:
        trace.error(failure_label(error))
    trace.observation_seconds = max(0., now()-backend.started)
    return trace.snapshot()


def drain(trace, backend, deadline, now):
    """After Job termination: no more image reads or exported module collection."""
    try:
        while (not trace.exit_seen or backend.pending is not None) and now() < deadline:
            event = backend.pending
            if event is None:
                require(trace.events < EVENT_CAP, 'diagnostic_cleanup_event_cap')
                event = backend.next(min(50, max(0, int((deadline-now())*1000))))
                if event is None:
                    continue
            require(event['pid'] == trace.identity['pid'] and 0 < event['tid'] < 2**32,
                    'diagnostic_cleanup_identity')
            require(type(event['code']) is int and 1 <= event['code'] <= 9, 'diagnostic_cleanup_schema')
            # Pending events rejected by consume have not necessarily been counted.
            if not event.get('counted'):
                require(trace.events < EVENT_CAP, 'diagnostic_cleanup_event_cap')
                trace.events += 1
                event['counted'] = True
            if event['code'] == 3 and not getattr(backend, 'adopted', False):
                backend.adopt(event, cleanup=True)
            if event['code'] == 5:
                if not trace.exit_seen:
                    trace.exit_during_cleanup = True
                trace.exit_seen, trace.exit_code = True, event['exit']
            backend.ack(NOT_HANDLED if event['code'] == 1 else CONTINUE)
        require(trace.exit_seen and backend.pending is None, 'diagnostic_exit_not_drained')
        require(not backend.handle_errors, 'diagnostic_event_handle_cleanup')
        return True
    except Exception as error:
        trace.error(failure_label(error))
        return False


if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('--check-mode', choices=('preflight', 'diagnostic'), required=True)
    args = parser.parse_args()
    require_admission(args.check_mode == 'diagnostic')
    print('Bound mode checked; no process created')

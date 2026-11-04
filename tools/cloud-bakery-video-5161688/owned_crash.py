"""Read only one exact owned client's post-exit Application Error metadata.

No debugger, memory dump/read, registry/WER change, broad log enumeration or
fallback query. An absent/denied event is unavailable evidence, never a pass.
"""
import ctypes as c
from ctypes import wintypes as w
from datetime import datetime, timedelta, timezone
import json
import ntpath
import os
import re
import time
import xml.etree.ElementTree as ET

NS = '{http://schemas.microsoft.com/win/2004/08/events/event}'
EPOCH = datetime(1601, 1, 1, tzinfo=timezone.utc)
XML_LIMIT = 65536
BIRTH_FIELDS = ('ProcessCreationTime',)


def require(ok, reason):
    if not ok:
        raise ValueError(reason)


def binding(identity, exit_code):
    require(set(identity) == {'pid', 'creation_filetime', 'image'}, 'identity_fields')
    require(type(identity['pid']) is int and 0 < identity['pid'] < 2**32, 'pid')
    require(type(identity['creation_filetime']) is int and 0 < identity['creation_filetime'] < 2**63, 'birth')
    path = identity['image']
    require(isinstance(path, str) and len(path) <= 512 and ntpath.isabs(path) and
            ntpath.basename(path).lower() == 'dreamseeker.exe' and
            not any(ch in path for ch in '\r\n\0\'"'), 'image')
    require(type(exit_code) is int and 0x80000000 <= exit_code <= 0xffffffff, 'nonexception_exit')
    born = EPOCH + timedelta(microseconds=identity['creation_filetime']//10)
    return born


def hex_forms(value):
    return sorted({str(value), hex(value), '0x'+format(value, 'X'),
                   '0x'+format(value, '016x'), '0x'+format(value, '016X')})


def legacy_forms(value, width):
    return sorted({format(value, 'x'), format(value, 'X'), format(value, '0%dx' % width), format(value, '0%dX' % width)})


def query_for(identity, exit_code, until):
    born = binding(identity, exit_code)
    require(born <= until <= born + timedelta(seconds=180), 'event_time_window')
    stamp = lambda v: v.isoformat(timespec='microseconds').replace('+00:00', 'Z')
    system = ("System[Provider[@Name='Application Error'] and EventID=1000 and "
              "TimeCreated[@SystemTime >= '%s' and @SystemTime <= '%s']]" % (stamp(born),stamp(until)))
    root = ET.Element('QueryList')
    query = ET.SubElement(root, 'Query', Id='0', Path='Application')
    # Separate exact selectors keep each XPath below the 32-expression limit.
    for birth_name in BIRTH_FIELDS:
        clauses = ["Data[@Name='AppPath']='"+identity['image']+"'"]
        for name,value in (('ProcessId',identity['pid']),(birth_name,identity['creation_filetime'])):
            clauses.append('('+' or '.join("Data[@Name='%s']='%s'" % (name,item) for item in hex_forms(value))+')')
        ET.SubElement(query,'Select',Path='Application').text = '*[%s and EventData[%s]]' % (system,' and '.join(clauses))
    legacy = ["Data[11]='"+identity['image']+"'"]
    for index,value,width in ((9,identity['pid'],8),(10,identity['creation_filetime'],16)):
        legacy.append('('+' or '.join("Data[%d]='%s'" % (index,item) for item in legacy_forms(value,width))+')')
    ET.SubElement(query,'Select',Path='Application').text = '*[%s and EventData[%s]]' % (system,' and '.join(legacy))
    return ET.tostring(root, encoding='unicode')


def parse_event(xml, identity, exit_code, until):
    born = binding(identity, exit_code)
    require(isinstance(xml, str) and len(xml.encode('utf-16-le')) <= XML_LIMIT and
            '<!DOCTYPE' not in xml.upper() and '<!ENTITY' not in xml.upper(), 'event_xml_bound')
    root = ET.fromstring(xml)
    system = root.find(NS+'System')
    require(root.tag == NS+'Event' and system is not None, 'event_schema')
    require(system.find(NS+'Provider').get('Name') == 'Application Error' and
            system.findtext(NS+'EventID') == '1000', 'event_provider')
    stamp = system.find(NS+'TimeCreated').get('SystemTime')
    when = datetime.fromisoformat(stamp.replace('Z', '+00:00'))
    require(when.tzinfo is not None and born <= when <= until, 'event_time_mismatch')
    require(system.findtext(NS+'Channel') == 'Application', 'event_channel')
    items = root.findall(NS+'EventData/'+NS+'Data')
    values = {}
    if items and all(item.get('Name') is None for item in items):
        # Documented firsthand Server 2022 classic event: exactly 15 positions.
        require(len(items) == 15 and system.find(NS+'EventID').get('Qualifiers') == '0' and
                system.findtext(NS+'Version') == '0' and system.findtext(NS+'Task') == '100', 'classic_event_schema')
        names = ('AppName','AppVersion','AppTimeStamp','ModuleName','ModuleVersion','ModuleTimeStamp',
                 'ExceptionCode','FaultingOffset','ProcessId','AppStartTime','AppPath','ModulePath',
                 'IntegratorReportId','PackageFullName','PackageRelativeAppId')
        values = {name:item.text or '' for name,item in zip(names,items)}
        require(values['ProcessId'] in legacy_forms(identity['pid'],8) and
                values['AppStartTime'] in legacy_forms(identity['creation_filetime'],16), 'event_identity_mismatch')
        schema = 'classic_15_position'
    else:
        for item in items:
            name = item.get('Name')
            require(name is not None and name not in values, 'duplicate_or_mixed_event_field')
            values[name] = item.text or ''
        birth_fields = [name for name in BIRTH_FIELDS if name in values]
        require(len(birth_fields) == 1, 'event_birth_schema')
        for name, expected in (('ProcessId', identity['pid']), (birth_fields[0], identity['creation_filetime'])):
            require(values.get(name) in hex_forms(expected), 'event_identity_mismatch')
        schema = 'named_'+birth_fields[0]
    require(values.get('AppPath') == identity['image'], 'event_image_mismatch')
    code, offset, module = (values.get(k, '') for k in ('ExceptionCode', 'FaultingOffset', 'ModuleName'))
    require(re.fullmatch(r'(?:0x)?[0-9a-fA-F]{1,8}', code) is not None and int(code,16) == exit_code, 'event_exception_mismatch')
    require(re.fullmatch(r'(?:0x)?[0-9a-fA-F]{1,16}', offset) is not None, 'event_offset')
    require(re.fullmatch(r'[A-Za-z0-9_. -]{1,128}', module) is not None and
            module == ntpath.basename(module), 'event_module')
    # No machine name, account/SID, report ID, raw XML, module path or extra data.
    return {'status':'matched_owned_crash_event', 'identity':dict(identity),
            'event_schema':schema, 'event_utc':stamp, 'exception_code':hex(exit_code),
            'faulting_module':module, 'module_offset':hex(int(offset,16)),
            'root_cause_proven':False}


def read_one(query):
    """OS-filtered query only. Close every returned query/event handle."""
    require(os.name == 'nt', 'windows_only')
    api = c.WinDLL('wevtapi', use_last_error=True)
    api.EvtQuery.argtypes = [w.HANDLE, w.LPCWSTR, w.LPCWSTR, w.DWORD]
    api.EvtQuery.restype = w.HANDLE
    api.EvtNext.argtypes = [w.HANDLE,w.DWORD,c.POINTER(w.HANDLE),w.DWORD,w.DWORD,c.POINTER(w.DWORD)]
    api.EvtNext.restype = w.BOOL
    api.EvtRender.argtypes = [w.HANDLE,w.HANDLE,w.DWORD,w.DWORD,c.c_void_p,c.POINTER(w.DWORD),c.POINTER(w.DWORD)]
    api.EvtRender.restype = w.BOOL
    api.EvtClose.argtypes = [w.HANDLE]
    api.EvtClose.restype = w.BOOL
    handle = api.EvtQuery(None, 'Application', query, 1 | 0x200)
    if not handle:
        raise c.WinError(c.get_last_error())
    events, count = (w.HANDLE*2)(), w.DWORD()
    try:
        if not api.EvtNext(handle, 2, events, 0, 0, c.byref(count)):
            code = c.get_last_error()
            if code in (259, 1460):
                return None
            raise c.WinError(code)
        require(count.value == 1, 'ambiguous_owned_events')
        used, fields = w.DWORD(), w.DWORD()
        ok = api.EvtRender(None,events[0],1,0,None,c.byref(used),c.byref(fields))
        require(not ok and c.get_last_error() == 122 and 0 < used.value <= XML_LIMIT and used.value % 2 == 0,
                'event_render_size')
        buffer = c.create_unicode_buffer(used.value//2)
        if not api.EvtRender(None,events[0],1,c.sizeof(buffer),buffer,c.byref(used),c.byref(fields)):
            raise c.WinError(c.get_last_error())
        return buffer.value
    finally:
        closed = [bool(api.EvtClose(event)) for event in events if event]
        closed.append(bool(api.EvtClose(handle)))
        require(all(closed), 'event_handle_close_failed')


def collect(identity, exit_code, seconds=2, *, reader=read_one, now=None, monotonic=None, sleep=None):
    """Post-cleanup only. Cooperative time budget; synchronous OS calls cannot be preempted."""
    now = now or (lambda: datetime.now(timezone.utc))
    monotonic, sleep = monotonic or time.monotonic, sleep or time.sleep
    result = {'status':'owned_crash_evidence_unavailable', 'reason':'not_queried'}
    try:
        require(0 < seconds <= 2, 'diagnostic_budget_unavailable')
        binding(identity, exit_code)
        deadline = monotonic()+seconds
        for _ in range(11):
            if monotonic() >= deadline:
                break
            until = now()
            raw = reader(query_for(identity, exit_code, until))
            if monotonic() >= deadline:
                result['reason'] = 'diagnostic_budget_exceeded'
                break
            if raw is not None:
                result = parse_event(raw, identity, exit_code, until)
                break
            result['reason'] = 'no_exact_event_within_bound'
            sleep(min(.2, max(0, deadline-monotonic())))
    except OSError as error:
        code = getattr(error,'winerror',None) or error.errno
        result = {'status':'owned_crash_evidence_unavailable', 'reason':'access_denied' if code == 5 else 'event_api_error', 'winerror':code}
    except Exception as error:
        # Error messages are fixed validation labels, not event/source text.
        result = {'status':'owned_crash_evidence_unavailable', 'reason':'validation_or_schema_unavailable', 'error_type':type(error).__name__}
    require(len(json.dumps(result)) <= 2048, 'diagnostic_output_bound')
    return result

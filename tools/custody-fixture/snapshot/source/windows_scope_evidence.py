"""Read-only Windows handle evidence; never grants channel authority.

The caller must already own a live handle opened with READ_CONTROL. This module
neither opens paths nor changes permissions, tokens, credentials or privileges.
Snapshots alone cannot prove stable path-to-handle identity or retained authority.
"""
from dataclasses import dataclass
import ctypes
from ctypes import wintypes
import os
import re

SID_TEXT = re.compile(r"S-1-(?:0|[1-9][0-9]*)(?:-(?:0|[1-9][0-9]*))+\Z")
MAX_ACES = 1024
MAX_ACL_BYTES = 65535
STANDARD_ALLOW, STANDARD_DENY = 0, 1

class EvidenceUnavailable(RuntimeError):
    pass

@dataclass(frozen=True)
class Ace:
    kind: int
    flags: int
    mask: int
    sid: str

@dataclass(frozen=True)
class Snapshot:
    owner_sid: str
    aces: tuple

@dataclass(frozen=True)
class Decision:
    permitted: bool
    reason: str


def _sid_text(value):
    return isinstance(value, str) and len(value) <= 184 and bool(SID_TEXT.fullmatch(value))


def evaluate(snapshot, process_sid, approved_sids):
    """Conservative candidate policy, not an AccessCheck or retained lease.

    Every allow ACE must name an explicitly approved SID, even read-only ACEs.
    Complex ACEs and malformed or excessive evidence fail closed. Deny ACEs
    cannot expand access and are not used to excuse an unapproved allow ACE.
    Privileged bypass and prior open handles remain outside this snapshot.
    """
    if type(snapshot) is not Snapshot or type(snapshot.aces) is not tuple:
        return Decision(False, 'invalid_snapshot')
    if not _sid_text(process_sid) or type(approved_sids) is not frozenset or not approved_sids or len(approved_sids)>32:
        return Decision(False, 'missing_identity_policy')
    if not all(_sid_text(s) for s in approved_sids):
        return Decision(False, 'invalid_identity_policy')
    if not _sid_text(snapshot.owner_sid) or process_sid not in approved_sids or snapshot.owner_sid not in approved_sids:
        return Decision(False, 'unapproved_process_or_owner')
    if len(snapshot.aces)>MAX_ACES:
        return Decision(False, 'excessive_aces')
    for ace in snapshot.aces:
        if (type(ace) is not Ace or type(ace.kind) is not int or
            type(ace.flags) is not int or type(ace.mask) is not int or
            not 0<=ace.flags<=255 or not 0<=ace.mask<=0xffffffff or not _sid_text(ace.sid)):
            return Decision(False, 'malformed_ace')
        if ace.kind not in (STANDARD_ALLOW, STANDARD_DENY):
            return Decision(False, 'unsupported_ace')
        if ace.kind == STANDARD_ALLOW and ace.sid not in approved_sids:
            return Decision(False, 'unapproved_allow')
    return Decision(True, 'snapshot_matches_policy_not_authority')


@dataclass(frozen=True)
class IntegrityPolicy:
    owners: frozenset
    writers: frozenset

# Windows file/directory generic read/execute, read data/EA/attributes,
# traverse, READ_CONTROL and SYNCHRONIZE. Anything else is rejected for an
# unapproved principal, including generic write/all, delete and ACL ownership.
_READ_TRAVERSE_MASK=(0x80000000|0x20000000|0x00100000|0x00020000|
                     0x00000080|0x00000020|0x00000008|0x00000001)


def evaluate_integrity(snapshot,policy):
    """Conservative integrity only; never grants confidentiality or access."""
    if type(snapshot) is not Snapshot or type(snapshot.aces) is not tuple or type(policy) is not IntegrityPolicy:
        return Decision(False,'invalid_integrity_evidence')
    if (type(policy.owners) is not frozenset or type(policy.writers) is not frozenset or
        not policy.owners or not policy.writers or len(policy.owners)>32 or len(policy.writers)>32 or
        not policy.owners.issubset(policy.writers) or
        not all(_sid_text(s) for s in policy.owners|policy.writers)):
        return Decision(False,'invalid_integrity_policy')
    if not _sid_text(snapshot.owner_sid) or snapshot.owner_sid not in policy.owners:
        return Decision(False,'unapproved_integrity_owner')
    if len(snapshot.aces)>MAX_ACES:return Decision(False,'excessive_aces')
    for ace in snapshot.aces:
        if (type(ace) is not Ace or type(ace.kind) is not int or type(ace.flags) is not int or
            type(ace.mask) is not int or not 0<=ace.flags<=255 or not 0<=ace.mask<=0xffffffff or
            not _sid_text(ace.sid)):
            return Decision(False,'malformed_ace')
        if ace.kind not in (STANDARD_ALLOW,STANDARD_DENY):return Decision(False,'unsupported_ace')
        if ace.kind==STANDARD_ALLOW and ace.sid not in policy.writers and (ace.mask & ~_READ_TRAVERSE_MASK):
            return Decision(False,'unapproved_integrity_rights')
    return Decision(True,'integrity_snapshot_not_authority')


class _AclSizeInformation(ctypes.Structure):
    _fields_ = [('AceCount', wintypes.DWORD), ('AclBytesInUse', wintypes.DWORD),
                ('AclBytesFree', wintypes.DWORD)]


def _libraries():
    if os.name != 'nt':
        raise EvidenceUnavailable('windows_required')
    return ctypes.WinDLL('advapi32', use_last_error=True), ctypes.WinDLL('kernel32', use_last_error=True)


def _sid_to_text(advapi, kernel, sid):
    advapi.IsValidSid.argtypes=[ctypes.c_void_p]
    advapi.IsValidSid.restype=wintypes.BOOL
    advapi.ConvertSidToStringSidW.argtypes=[ctypes.c_void_p,ctypes.POINTER(wintypes.LPWSTR)]
    advapi.ConvertSidToStringSidW.restype=wintypes.BOOL
    kernel.LocalFree.argtypes=[ctypes.c_void_p]
    kernel.LocalFree.restype=ctypes.c_void_p
    if not sid or not advapi.IsValidSid(sid):
        raise EvidenceUnavailable('invalid_sid')
    value=wintypes.LPWSTR()
    if not advapi.ConvertSidToStringSidW(sid,ctypes.byref(value)):
        raise EvidenceUnavailable('sid_conversion_failed')
    try:
        result=value.value
        if not _sid_text(result):raise EvidenceUnavailable('unsupported_sid')
        return result
    finally:
        kernel.LocalFree(ctypes.cast(value,ctypes.c_void_p))


def current_process_sid():
    """Read the process token user only; refuse a thread impersonation token."""
    a,k=_libraries()
    k.GetCurrentThread.restype=wintypes.HANDLE
    k.GetCurrentProcess.restype=wintypes.HANDLE
    k.CloseHandle.argtypes=[wintypes.HANDLE]
    k.CloseHandle.restype=wintypes.BOOL
    a.OpenThreadToken.argtypes=[wintypes.HANDLE,wintypes.DWORD,wintypes.BOOL,ctypes.POINTER(wintypes.HANDLE)]
    a.OpenThreadToken.restype=wintypes.BOOL
    a.OpenProcessToken.argtypes=[wintypes.HANDLE,wintypes.DWORD,ctypes.POINTER(wintypes.HANDLE)]
    a.OpenProcessToken.restype=wintypes.BOOL
    a.GetTokenInformation.argtypes=[wintypes.HANDLE,ctypes.c_int,ctypes.c_void_p,wintypes.DWORD,ctypes.POINTER(wintypes.DWORD)]
    a.GetTokenInformation.restype=wintypes.BOOL
    token=wintypes.HANDLE()
    if a.OpenThreadToken(k.GetCurrentThread(),0x0008,True,ctypes.byref(token)):
        k.CloseHandle(token)
        raise EvidenceUnavailable('thread_impersonation_refused')
    if ctypes.get_last_error()!=1008:
        raise EvidenceUnavailable('thread_token_unavailable')
    if not a.OpenProcessToken(k.GetCurrentProcess(),0x0008,ctypes.byref(token)):
        raise EvidenceUnavailable('process_token_unavailable')
    try:
        length=wintypes.DWORD()
        if a.GetTokenInformation(token,1,None,0,ctypes.byref(length)) or ctypes.get_last_error()!=122 or not 1<=length.value<=65536:
            raise EvidenceUnavailable('token_size_unavailable')
        buf=ctypes.create_string_buffer(length.value)
        if not a.GetTokenInformation(token,1,buf,length.value,ctypes.byref(length)):
            raise EvidenceUnavailable('token_user_unavailable')
        sid=ctypes.cast(buf,ctypes.POINTER(ctypes.c_void_p)).contents.value
        return _sid_to_text(a,k,sid)
    finally:
        k.CloseHandle(token)


def inspect_handle(handle):
    """Read owner and simple DACL ACEs from an existing file-object handle."""
    a,k=_libraries()
    a.GetSecurityInfo.argtypes=[wintypes.HANDLE,ctypes.c_int,wintypes.DWORD,
        ctypes.POINTER(ctypes.c_void_p),ctypes.c_void_p,ctypes.POINTER(ctypes.c_void_p),
        ctypes.c_void_p,ctypes.POINTER(ctypes.c_void_p)]
    a.GetSecurityInfo.restype=wintypes.DWORD
    a.GetAclInformation.argtypes=[ctypes.c_void_p,ctypes.c_void_p,wintypes.DWORD,ctypes.c_int]
    a.GetAclInformation.restype=wintypes.BOOL
    a.GetAce.argtypes=[ctypes.c_void_p,wintypes.DWORD,ctypes.POINTER(ctypes.c_void_p)]
    a.GetAce.restype=wintypes.BOOL
    k.LocalFree.argtypes=[ctypes.c_void_p]
    k.LocalFree.restype=ctypes.c_void_p
    owner=ctypes.c_void_p(); acl=ctypes.c_void_p(); descriptor=ctypes.c_void_p()
    result=a.GetSecurityInfo(handle,1,0x1|0x4,ctypes.byref(owner),None,ctypes.byref(acl),None,ctypes.byref(descriptor))
    if result!=0:
        raise EvidenceUnavailable('security_descriptor_unavailable')
    try:
        if not descriptor or not owner or not acl:
            raise EvidenceUnavailable('null_owner_or_dacl')
        owner_text=_sid_to_text(a,k,owner)
        info=_AclSizeInformation()
        if not a.GetAclInformation(acl,ctypes.byref(info),ctypes.sizeof(info),2):
            raise EvidenceUnavailable('acl_information_unavailable')
        if info.AceCount>MAX_ACES or info.AclBytesInUse>MAX_ACL_BYTES:
            raise EvidenceUnavailable('acl_too_large')
        aces=[]
        for index in range(info.AceCount):
            ace=ctypes.c_void_p()
            if not a.GetAce(acl,index,ctypes.byref(ace)) or not ace:
                raise EvidenceUnavailable('ace_unavailable')
            acl_start=acl.value
            acl_end=acl_start+info.AclBytesInUse
            if ace.value<acl_start+8 or ace.value+4>acl_end:
                raise EvidenceUnavailable('ace_outside_acl')
            header=ctypes.string_at(ace,4)
            kind,flags,size=header[0],header[1],int.from_bytes(header[2:4],'little')
            if kind not in (STANDARD_ALLOW,STANDARD_DENY) or size<16 or size>MAX_ACL_BYTES or ace.value+size>acl_end:
                raise EvidenceUnavailable('unsupported_ace')
            raw=ctypes.string_at(ace,size)
            count=raw[9]
            if count>15 or 16+4*count>size:
                raise EvidenceUnavailable('malformed_ace_sid')
            sid=ctypes.c_void_p(ace.value+8)
            aces.append(Ace(kind,flags,int.from_bytes(raw[4:8],'little'),_sid_to_text(a,k,sid)))
        return Snapshot(owner_text,tuple(aces))
    finally:
        if descriptor:k.LocalFree(descriptor)

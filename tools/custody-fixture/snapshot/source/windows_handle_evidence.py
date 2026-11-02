"""Retained read-only Windows path evidence; not a channel authorization guard.

Open every component with OPEN_REPARSE_POINT and without SHARE_DELETE. A caller
must separately validate security descriptors, trusted identity and actual I/O
bindings. Snapshot/recheck does not itself grant permission to run a cycle.
"""
from dataclasses import dataclass
import ctypes
from ctypes import wintypes
import ntpath
import os
import re
from windows_scope_evidence import EvidenceUnavailable

@dataclass(frozen=True)
class Identity:
    volume: int
    file_index: int
    attributes: int
    links: int

class _FileInfo(ctypes.Structure):
    _fields_=[('attributes',wintypes.DWORD),('created',wintypes.FILETIME),
      ('accessed',wintypes.FILETIME),('written',wintypes.FILETIME),
      ('volume',wintypes.DWORD),('size_high',wintypes.DWORD),('size_low',wintypes.DWORD),
      ('links',wintypes.DWORD),('index_high',wintypes.DWORD),('index_low',wintypes.DWORD)]


def components(path):
    if not isinstance(path,str) or len(path)>4096 or '\x00' in path or '/' in path:
        raise EvidenceUnavailable('invalid_path')
    drive,tail=ntpath.splitdrive(path)
    if not re.fullmatch(r'[A-Za-z]:',drive) or not tail.startswith('\\') or tail.startswith('\\\\'):
        raise EvidenceUnavailable('local_absolute_drive_required')
    parts=tail[1:].split('\\')
    if any(not p or p in ('.','..') or ':' in p or p.endswith((' ','.')) for p in parts):
        raise EvidenceUnavailable('ambiguous_path')
    result=[drive.upper()+'\\']
    for part in parts:result.append(ntpath.join(result[-1],part))
    return tuple(result)


def _kernel():
    if os.name!='nt':raise EvidenceUnavailable('windows_required')
    k=ctypes.WinDLL('kernel32',use_last_error=True)
    k.CreateFileW.argtypes=[wintypes.LPCWSTR,wintypes.DWORD,wintypes.DWORD,ctypes.c_void_p,
                            wintypes.DWORD,wintypes.DWORD,wintypes.HANDLE]
    k.CreateFileW.restype=wintypes.HANDLE
    k.GetFileInformationByHandle.argtypes=[wintypes.HANDLE,ctypes.POINTER(_FileInfo)]
    k.GetFileInformationByHandle.restype=wintypes.BOOL
    k.GetFileType.argtypes=[wintypes.HANDLE];k.GetFileType.restype=wintypes.DWORD
    k.CloseHandle.argtypes=[wintypes.HANDLE];k.CloseHandle.restype=wintypes.BOOL
    return k


def _open(k,path):
    # READ_CONTROL | FILE_READ_ATTRIBUTES; FILE_SHARE_READ | FILE_SHARE_WRITE.
    # OPEN_EXISTING, BACKUP_SEMANTICS | OPEN_REPARSE_POINT. No delete sharing.
    handle=k.CreateFileW(path,0x20080,3,None,3,0x02200000,None)
    if handle==ctypes.c_void_p(-1).value or not handle:
        raise EvidenceUnavailable('handle_open_unavailable')
    return handle


def _file_info(k,handle,allow_hardlinks):
    info=_FileInfo()
    if k.GetFileType(handle)!=1 or not k.GetFileInformationByHandle(handle,ctypes.byref(info)):
        raise EvidenceUnavailable('identity_unavailable')
    ident=Identity(info.volume,(info.index_high<<32)|info.index_low,info.attributes,info.links)
    if ident.attributes & 0x400:
        raise EvidenceUnavailable('reparse_refused')
    if not (ident.attributes & 0x10) and (ident.links<1 or (not allow_hardlinks and ident.links!=1)):
        raise EvidenceUnavailable('hardlink_or_unknown_link_count')
    return ident


def _info(k,handle):
    return _file_info(k,handle,False)


def _tool_info(k,handle):
    return _file_info(k,handle,True)


class RetainedPathEvidence:
    """Pins a chain for observation, then closes all handles in reverse order."""
    def __init__(self,path,*,api=None,allow_tool_hardlinks=False):
        if type(allow_tool_hardlinks) is not bool:raise EvidenceUnavailable('hardlink_policy_invalid')
        self.allow_tool_hardlinks=allow_tool_hardlinks
        self.paths=components(path)
        self.api=api
        self.handles=[]
        self.identities=[]
        self.closed=False
    def __enter__(self):
        if self.handles or self.closed:raise EvidenceUnavailable('scope_reuse_refused')
        k=self.api or _kernel();self.api=k
        try:
            for index,path in enumerate(self.paths):
                handle=_open(k,path)
                self.handles.append(handle)
                identity=(_tool_info if self.allow_tool_hardlinks else _info)(k,handle)
                if index<len(self.paths)-1 and not (identity.attributes & 0x10):
                    raise EvidenceUnavailable('parent_not_directory')
                self.identities.append(identity)
            return self
        except BaseException as original:
            try:self.close()
            except BaseException as cleanup:
                raise BaseExceptionGroup('acquisition and cleanup failed',[original,cleanup]) from original
            raise
    def recheck(self):
        if self.closed or len(self.handles)!=len(self.paths):raise EvidenceUnavailable('scope_closed')
        for path,old_handle,expected in zip(self.paths,self.handles,self.identities):
            inspect=_tool_info if self.allow_tool_hardlinks else _info
            if inspect(self.api,old_handle)!=expected:raise EvidenceUnavailable('retained_identity_changed')
            candidate=_open(self.api,path)
            try:
                if inspect(self.api,candidate)!=expected:raise EvidenceUnavailable('path_identity_changed')
            finally:
                if not self.api.CloseHandle(candidate):raise EvidenceUnavailable('candidate_close_failed')
        return True
    def close(self):
        failures=False
        while self.handles:
            handle=self.handles.pop()
            try:
                if not self.api.CloseHandle(handle):failures=True
            except BaseException:
                failures=True
        self.closed=True
        if failures:raise EvidenceUnavailable('retained_handle_close_failed')
    def __exit__(self,exc_type,exc,tb):
        try:self.close()
        except BaseException as cleanup:
            if exc is None:raise
            raise BaseExceptionGroup('scope body and cleanup failed',[exc,cleanup]) from exc
        return False

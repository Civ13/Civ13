"""Check only the retained owned client's loaded D3DX module paths."""
import ctypes as c
from ctypes import wintypes as w
import os
from pathlib import Path

import acquire
import nuget_pins as pins


def validate_paths(paths, binary_dir):
    binary_dir = Path(binary_dir).absolute()
    acquire._plain_ancestors(binary_dir)
    selected = {}
    for value in paths:
        name = Path(value).name.lower()
        if name not in pins.FILES:
            continue
        if name in selected:
            raise RuntimeError('duplicate_nuget_module')
        expected = binary_dir/name
        if os.path.normcase(os.path.abspath(value)) != os.path.normcase(os.path.abspath(expected)):
            raise RuntimeError('nuget_module_wrong_path')
        raw = acquire._read(expected, pins.FILES[name]['bytes'])
        if len(raw) != pins.FILES[name]['bytes'] or acquire._sha(raw) != pins.FILES[name]['sha256']:
            raise RuntimeError('nuget_module_changed')
        acquire._pe_x86(raw)
        selected[name] = {'sha256': pins.FILES[name]['sha256'], 'location': 'app-local'}
    if 'd3dx9_43.dll' not in selected:
        raise RuntimeError('nuget_d3dx_module_not_loaded')
    return {'modules': selected, 'compiler_loaded': 'd3dcompiler_43.dll' in selected,
            'dynamic_compiler_usage_proven': False}


def inspect(adapter, process, binary_dir):
    if os.name != 'nt' or adapter.exited(process):
        raise RuntimeError('owned_client_not_live')
    identity = adapter.identity(process)
    ps = adapter.ps
    ps.EnumProcessModulesEx.argtypes = [w.HANDLE, c.POINTER(w.HMODULE), w.DWORD,
                                        c.POINTER(w.DWORD), w.DWORD]
    ps.EnumProcessModulesEx.restype = w.BOOL
    ps.GetModuleFileNameExW.argtypes = [w.HANDLE, w.HMODULE, w.LPWSTR, w.DWORD]
    ps.GetModuleFileNameExW.restype = w.DWORD
    modules = (w.HMODULE * 512)()
    needed = w.DWORD()
    if not ps.EnumProcessModulesEx(process.process, modules, c.sizeof(modules), c.byref(needed), 1):
        raise RuntimeError('owned_module_enumeration_failed')
    if needed.value > c.sizeof(modules) or needed.value % c.sizeof(w.HMODULE):
        raise RuntimeError('owned_module_list_bound')
    selected = []
    for module in modules[:needed.value // c.sizeof(w.HMODULE)]:
        buf = c.create_unicode_buffer(32768)
        length = ps.GetModuleFileNameExW(process.process, module, buf, len(buf))
        if not length or length >= len(buf)-1:
            raise RuntimeError('owned_module_path_unavailable')
        if Path(buf.value).name.lower() in pins.FILES:
            selected.append(buf.value)
    result = validate_paths(selected, binary_dir)
    if adapter.exited(process) or adapter.identity(process) != identity:
        raise RuntimeError('owned_client_identity_changed')
    result['pid'] = identity['pid']
    result['creation_filetime'] = identity['creation_filetime']
    return result

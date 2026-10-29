"""Strict JSON and new-output-only helpers for this offline CLI."""
import json
from pathlib import Path
import stat

MAX_JSON_BYTES=256*1024*1024


def read_json(path):
    path=Path(path)
    if path.suffix.lower()!='.json':raise ValueError('only .json input is supported; native saves are not read')
    if path.stat().st_size>MAX_JSON_BYTES:raise ValueError('JSON input exceeds 256 MiB limit')
    def pairs(items):
        result={}
        for k,v in items:
            if k in result:raise ValueError('duplicate JSON key: '+k)
            result[k]=v
        return result
    def constant(value):raise ValueError('nonfinite JSON: '+value)
    return json.loads(path.read_text(encoding='utf-8'),object_pairs_hook=pairs,parse_constant=constant)


def new_output(path,directory=False):
    path=Path(path).absolute()
    for item in [path,*path.parents]:
        if item.is_symlink():raise ValueError('symlink output components are not supported')
        if item.exists() and getattr(item.stat(),'st_file_attributes',0)&getattr(stat,'FILE_ATTRIBUTE_REPARSE_POINT',0x400):
            raise ValueError('reparse-point output components are not supported')
    if path.exists():raise ValueError('output already exists; choose a new path: '+str(path))
    path.parent.mkdir(parents=True,exist_ok=True)
    if directory:path.mkdir()
    return path


def json_text(value,compact=False):
    return json.dumps(value,indent=None if compact else 2,separators=(',',':') if compact else None,allow_nan=False)+'\n'

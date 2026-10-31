"""Bound only this standalone compiler's outputs, including an absent RSC."""
from pathlib import Path
import hashlib
from materialize import _plain_ancestors


def identify(source):
    source=Path(source)
    _plain_ancestors(source)
    result={}
    for name in ('civ13.dmb','civ13.rsc'):
        path=source/name
        if path.is_symlink(): raise ValueError('Linked compiled output')
        if not path.exists():
            if name=='civ13.dmb': raise ValueError('Missing minimal DMB')
            result[name]={'present':False}
            continue
        info=path.stat()
        if (not path.is_file() or getattr(info,'st_file_attributes',0)&0x400
                or info.st_size>256*1024**2 or (name=='civ13.dmb' and not info.st_size)):
            raise ValueError('Compiled output type/size')
        with path.open('rb') as stream: digest=hashlib.file_digest(stream,'sha256').hexdigest()
        if path.stat().st_size!=info.st_size: raise ValueError('Compiled output changed')
        result[name]={'present':True,'bytes':info.st_size,'sha256':digest}
    return result

"""One fixed standalone startup control; no game export or caller-selected code."""
import hashlib
import json
from pathlib import Path
from materialize import _plain_ancestors

PROFILE_ID='minimal-world-control'
SOURCE='standalone-minimal-world-v1'
BASELINE_SHA256='83a312f1aea0da84650ad037bef81f866fcb993daa174bdc8a6c3c18a7ef67ed'
SCOPE='Standalone default-client startup control; no Civ13 gameplay, capture or acceptance'
NAMES={'civ13.dme','filming/minimal.dm','filming/minimal.dmf'}


def load(here):
    root=Path(here)/'profiles/minimal-world'
    _plain_ancestors(root)
    def read(name):
        path=root/name
        info=path.lstat()
        if path.is_symlink() or not path.is_file() or info.st_size>=65536 or getattr(info,'st_file_attributes',0)&0x400:
            raise ValueError('Invalid minimal profile manifest')
        return path.read_bytes()
    baseline_raw=read('baseline-derived-source.json')
    if hashlib.sha256(baseline_raw).hexdigest()!=BASELINE_SHA256:
        raise ValueError('Changed minimal baseline')
    baseline=json.loads(baseline_raw)
    raw=read('derived-source.json');active=json.loads(raw)
    if (set(active)!={'scene_revision','native_released','changes'} or active['scene_revision']!=SOURCE
            or type(active['native_released']) is not bool or set(active['changes'])!=NAMES):
        raise ValueError('Wrong minimal profile identity/state')
    tree=root/'changed-source'
    _plain_ancestors(tree)
    actual=set()
    for path in tree.rglob('*'):
        if path.is_symlink() or getattr(path.lstat(),'st_file_attributes',0)&0x400:
            raise ValueError('Linked minimal source')
        if path.is_file(): actual.add(path.relative_to(tree).as_posix())
    if actual!=NAMES: raise ValueError('Missing or extra minimal source')
    changes={}
    for name in sorted(NAMES):
        path=tree/name
        _plain_ancestors(path.parent)
        data=path.read_bytes()
        if len(data)>=16384 or hashlib.sha256(data).hexdigest()!=active['changes'][name]:
            raise ValueError('Minimal source identity/size mismatch')
        original=data
        if name=='filming/minimal.dm':
            flag=b'TRUE' if active['native_released'] else b'FALSE'
            token=b'#define MINIMAL_WORLD_RELEASED '+flag
            if data.count(token)!=1: raise ValueError('Minimal release mismatch')
            original=data.replace(token,b'#define MINIMAL_WORLD_RELEASED FALSE')
        if hashlib.sha256(original).hexdigest()!=baseline['changes'][name]:
            raise ValueError('Minimal source differs from frozen baseline')
        changes[name]=data
    return raw,active,changes

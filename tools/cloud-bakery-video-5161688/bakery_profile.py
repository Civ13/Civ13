"""The complete pinned earlier bakery scene; never a mixed city/bakery profile."""
import hashlib
import json
from pathlib import Path
from materialize import _plain_ancestors, _relative

PROFILE_ID = 'bakery225-control'
SOURCE = '58404f5bd16e3fed80f1d9844c5db3edd144942c'
BASELINE_SHA256 = '6133d4a11d63266cd7d36251da875b2799351214233466c73beacfabb150fb41'
SCOPE = 'Complete pinned 225-cell bakery startup control; no capture or ordinary-player acceptance'


def load(here):
    profile = Path(here)/'profiles/bakery225'
    _plain_ancestors(profile)
    baseline_path = profile/'baseline-derived-source.json'
    if baseline_path.is_symlink() or baseline_path.stat().st_size > 65536:
        raise ValueError('Invalid bakery baseline manifest')
    raw = baseline_path.read_bytes()
    if hashlib.sha256(raw).hexdigest() != BASELINE_SHA256:
        raise ValueError('Wrong bakery baseline identity')
    baseline = json.loads(raw)
    path = profile/'derived-source.json'
    if path.is_symlink() or path.stat().st_size > 65536:
        raise ValueError('Invalid bakery active manifest')
    active_raw = path.read_bytes()
    active = json.loads(active_raw)
    if (set(active) != {'scene_revision','native_released','changes'} or
            active['scene_revision'] != SOURCE or type(active['native_released']) is not bool or
            len(baseline['changes']) != 18 or set(active['changes']) != set(baseline['changes'])):
        raise ValueError('Incomplete or mixed bakery profile')
    tree = profile/'changed-source'
    _plain_ancestors(tree)
    actual = set()
    for item in tree.rglob('*'):
        if item.is_symlink() or getattr(item,'is_junction',lambda:False)():
            raise ValueError('Linked bakery profile entry')
        if item.is_file(): actual.add(item.relative_to(tree).as_posix())
    if actual != set(baseline['changes']):
        raise ValueError('Extra or missing bakery source file')
    changes = {}
    for name, original_hash in baseline['changes'].items():
        _relative(name)
        item = tree/name
        _plain_ancestors(item.parent)
        if item.stat().st_size > 4*1024**2:
            raise ValueError('Bakery derivative size exceeded')
        data = item.read_bytes()
        if hashlib.sha256(data).hexdigest() != active['changes'][name]:
            raise ValueError('Changed bakery active derivative')
        original = data
        if name == 'filming/actions.dm':
            flag = b'TRUE' if active['native_released'] else b'FALSE'
            held = b'#define BAKERY_VIDEO_RELEASED '+flag
            if data.count(held) != 1:
                raise ValueError('Bakery profile release mismatch')
            original = data.replace(held,b'#define BAKERY_VIDEO_RELEASED TRUE')
        if hashlib.sha256(original).hexdigest() != original_hash:
            raise ValueError('Bakery source differs from complete baseline')
        changes[name] = data
    return active_raw, active, changes

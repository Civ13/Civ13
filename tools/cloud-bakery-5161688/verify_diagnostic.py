"""Exact reviewed acquisition tooling/source closure; no native operations."""
import hashlib,json
from pathlib import Path
from activation import check
HERE=Path(__file__).resolve().parent

def verify(root=HERE):
    root=Path(root);base=root.parents[1]
    activation=check(root)
    pins=json.loads((root/'diagnostic-pins.json').read_text(encoding='utf-8'))
    if pins['activation']!=activation or pins['scope']!='ONE_NATIVE_ACQUISITION_DIAGNOSTIC_NO_EXPORT':raise ValueError('Diagnostic activation mismatch')
    expected={f['path']:f for f in pins['files']}
    actual={str(p.relative_to(base)) for p in root.rglob('*') if p.is_file() and '__pycache__' not in p.parts and p.name!='diagnostic-pins.json'}
    actual.add('.github/workflows/cloud-bakery-5161688.yml')
    if actual!=set(expected):raise ValueError('Tooling/source closure membership mismatch')
    for name,f in expected.items():
        p=base/name
        if p.is_symlink() or p.stat().st_size!=f['bytes'] or hashlib.sha256(p.read_bytes()).hexdigest()!=f['sha256']:raise ValueError('Exact diagnostic source pin mismatch: '+name)
    return {'status':'EXACT_DIAGNOSTIC_CLOSURE_VERIFIED','files':len(expected),'activation':activation}
if __name__=='__main__':print(json.dumps(verify(),sort_keys=True))

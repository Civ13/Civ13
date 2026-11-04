"""Exact raw Git source + sealed isolated harvest derivative; no native call."""
import argparse, hashlib, json, subprocess
from pathlib import Path
from materialize import export_blobs, _plain_ancestors, _relative
from activation import SOURCE

HERE=Path(__file__).resolve().parent
def stage(repository,destination):
    repository,destination=Path(repository).absolute(),Path(destination).absolute()
    _plain_ancestors(repository);_plain_ancestors(destination)
    if destination.exists(): raise ValueError('Fresh source destination required')
    head=subprocess.check_output(['git','-C',str(repository),'rev-parse','HEAD'],text=True,timeout=15).strip()
    if head!=SOURCE: raise ValueError('Wrong exact game checkout')
    m=json.loads((HERE/'source-manifest.json').read_text())
    d=json.loads((HERE/'derived-source.json').read_text())
    if m['revision']!=SOURCE or d['scene_revision']!=SOURCE or type(d['native_released']) is not bool:
        raise ValueError('Source identity/state mismatch')
    changes={}
    for name,h in d['changes'].items():
        _relative(name);p=HERE/'changed-source'/name;_plain_ancestors(p.parent)
        if p.is_symlink() or not p.is_file() or hashlib.sha256(p.read_bytes()).hexdigest()!=h:
            raise ValueError('Linked/changed derivative')
        changes[name]=p.read_bytes()
    flag=b'TRUE' if d['native_released'] else b'FALSE'
    if b'#define HARVEST_VIDEO_RELEASED '+flag not in changes['filming/actions.dm']:
        raise ValueError('Scene hold mismatch')
    result=export_blobs(repository,SOURCE,destination,
        ['civ13.dme','code','icons','sound','UI','interface','config/names'],
        {r['path']:r['git_blob'] for r in m['materialization_allowlist']})
    for name,data in changes.items():
        p=destination/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(data)
    receipt=dict(source_revision=SOURCE,source_blob_count=result['count'],source_bytes=result['bytes'],
        derived_manifest_sha256=hashlib.sha256((HERE/'derived-source.json').read_bytes()).hexdigest(),
        map_sha256=hashlib.sha256((destination/'filming/harvest.dmm').read_bytes()).hexdigest(),
        source_manifest_sha256=hashlib.sha256((HERE/'source-manifest.json').read_bytes()).hexdigest(),
        native_released=d['native_released'],native_executed=False,
        scope='225 authored cells; scripted normal staged mature wheat; native harvest and pickup; no observed growth or cross-run identity handlers; isolated startup, not ordinary-player acceptance')
    (destination/'source-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
    return receipt

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--repository',type=Path,required=True);p.add_argument('--destination',type=Path,required=True)
    a=p.parse_args();print(json.dumps(stage(a.repository,a.destination)))

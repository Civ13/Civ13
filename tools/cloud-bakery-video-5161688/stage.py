"""Materialize only the three sealed standalone files; no native call."""
import argparse, hashlib, json
from pathlib import Path
from materialize import _plain_ancestors
from minimal_profile import SOURCE, PROFILE_ID, SCOPE, load as load_scene_profile

HERE=Path(__file__).resolve().parent
def stage(destination):
    destination=Path(destination).absolute()
    _plain_ancestors(destination)
    if destination.exists(): raise ValueError('Fresh source destination required')
    derived_raw,d,changes=load_scene_profile(HERE)
    destination.mkdir()
    for name,data in changes.items():
        p=destination/name;p.parent.mkdir(parents=True,exist_ok=True)
        with p.open('xb') as stream: stream.write(data)
    receipt=dict(source_revision=SOURCE,source_blob_count=len(changes),source_bytes=sum(map(len,changes.values())),
        derived_manifest_sha256=hashlib.sha256(derived_raw).hexdigest(),scene_profile=PROFILE_ID,
        files={name:hashlib.sha256(data).hexdigest() for name,data in changes.items()},
        expected_dimensions=[15,15,1],project_art_or_gameplay_included=False,
        native_released=d['native_released'],native_executed=False,
        scope=SCOPE)
    with (destination/'source-receipt.json').open('x',encoding='utf-8') as stream:
        stream.write(json.dumps(receipt,indent=2)+'\n')
    return receipt

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--destination',type=Path,required=True)
    a=p.parse_args();print(json.dumps(stage(a.destination)))

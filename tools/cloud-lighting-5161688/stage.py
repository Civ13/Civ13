"""Source-only raw-blob staging. Held native flags are never rewritten here."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
from materialize import export_blobs, _plain_ancestors, _relative

HERE = Path(__file__).resolve().parent
SOURCE = 'ff67d89241336d55f456967ec596d5cd10358df6'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def stage(repository, destination, mode):
    if type(mode) is not int or mode not in (0,1):
        raise ValueError('Explicit mode 0 or 1 required')
    repository, destination = Path(repository).absolute(), Path(destination).absolute()
    _plain_ancestors(repository); _plain_ancestors(destination)
    if destination.exists():
        raise ValueError('Fresh output only')
    head = subprocess.check_output(['git','-C',str(repository),'rev-parse','HEAD'],timeout=15,text=True).strip()
    if head != SOURCE:
        raise ValueError('Wrong game source checkout')
    m = json.loads((HERE/'source-manifest.json').read_text())
    d = json.loads((HERE/'derived-source.json').read_text())
    if m['revision'] != SOURCE or d['scene_revision'] != SOURCE:
        raise ValueError('Wrong source manifests')
    files = {row['path']:row['git_blob'] for row in m['materialization_allowlist']}
    changes = {}
    for relative, expected in d['changes'].items():
        _relative(relative)
        source = HERE/'changed-source'/relative
        _plain_ancestors(source.parent)
        if source.is_symlink() or not source.is_file() or digest(source) != expected:
            raise ValueError('Changed or linked derivative')
        changes[relative] = source.read_bytes()
    for name, flag in (('filming/scene.dm','FILMING_NATIVE_RELEASED'),
                       ('filming/capture_scene.dm','LIGHTING_CAPTURE_SCENE_RELEASED')):
        if type(d.get('native_released')) is not bool:
            raise ValueError('Missing explicit derivative release identity')
        state = 'TRUE' if d['native_released'] else 'FALSE'
        if ('#define '+flag+' '+state).encode() not in changes[name]:
            raise ValueError('Derivative hold and manifest disagree')
    result = export_blobs(repository, SOURCE, destination,
        ['civ13.dme','code','icons','sound','UI','interface','config/names'], files)
    for name, data in changes.items():
        p = destination/name; p.parent.mkdir(parents=True,exist_ok=True); p.write_bytes(data)
    dme = destination/'civ13.dme'
    dme.write_bytes(('#define LIGHTING_COMPOSITION_V2 '+str(mode)+'\n').encode()+dme.read_bytes())
    receipt = dict(source_revision=SOURCE, mode=mode, source_blob_count=result['count'],
        source_bytes=result['bytes'], source_manifest_sha256=digest(HERE/'source-manifest.json'),
        derived_manifest_sha256=digest(HERE/'derived-source.json'), dme_sha256=digest(dme),
        native_executed=False, native_released=d['native_released'],
        scope='195-cell native lighting fixture proposal, not production Login/lifecycle acceptance')
    (destination/'source-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
    return receipt


if __name__ == '__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--repository',type=Path,required=True)
    p.add_argument('--destination',type=Path,required=True)
    p.add_argument('--mode',type=int,choices=(0,1),required=True)
    a=p.parse_args()
    print(json.dumps(stage(a.repository,a.destination,a.mode)))

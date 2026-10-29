"""Prepare canonical committed source/art and all generated compiler inputs."""
import argparse,importlib.util,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('tree_prepare_provenance',Path(__file__).with_name('provenance.py'))
provenance=importlib.util.module_from_spec(spec);spec.loader.exec_module(provenance)

def prepare(out,head,*,renderer_control=None):
    manifest,files=provenance.plan(head,renderer_control)
    out=Path(out).resolve();out.mkdir(exist_ok=False)
    for name,data in files.items():
        target=out/name;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(data)
    (out/'source-manifest.json').write_bytes((json.dumps(manifest,indent=2)+'\n').encode())
    return manifest

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);p.add_argument('--head',required=True)
    p.add_argument('--renderer-control',choices=provenance.RENDERER_CONTROLS)
    a=p.parse_args();m=prepare(a.output,a.head,renderer_control=a.renderer_control);print(json.dumps({'output':str(a.output.resolve()),'head':m['head'],'renderer_control':m['renderer_control'],'files':len(m['files']),'executed':False}))

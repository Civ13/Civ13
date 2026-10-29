"""Prepare exact source/art native pixel input. Never launches an executable."""
import argparse,hashlib,json,re,shutil
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]

def proc(path,signature):
    lines=(ROOT/path).read_text().splitlines();start=next(i for i,l in enumerate(lines) if l.startswith(signature))
    end=next((i for i in range(start+1,len(lines)) if lines[i].startswith('/')),len(lines))
    return '\n'.join(lines[start:end])+'\n'

def prepare(out):
    out=out.resolve();out.mkdir(exist_ok=False)
    inputs=['code/modules/visibility/los_context.dm','code/modules/visibility/root_light_snapshot.dm',
            'code/modules/visibility/root_tree_presenter.dm','tests/root_tree_presentation/fixture.dm']
    manifest={'scope':'native pixel fixture input only; not executed','inputs':{}}
    for path in inputs:
        data=(ROOT/path).read_bytes();dest=out/Path(path).name;dest.write_bytes(data)
        manifest['inputs'][path]={'sha256':hashlib.sha256(data).hexdigest(),'bytes':len(data)}
    update=proc('code/modules/lighting/lighting_overlay.dm','/atom/movable/lighting_overlay/proc/update_overlay(')
    copy=proc('code/modules/lighting/lighting_overlay.dm','/proc/copylist(')
    backdrop=proc('code/_onclick/hud/plane_master.dm','/obj/screen/plane_master/light_mask/backdrop(')
    dispatch=proc('code/_onclick/hud/plane_master.dm','/mob/proc/update_lighting_plane(')
    coverage=(ROOT/'code/modules/lighting/lighting_composition.dm').read_text()
    production=copy+update+backdrop+dispatch+coverage
    (out/'production-light-update.dm').write_text(production)
    manifest['production_light_update_sha256']=hashlib.sha256(production.encode()).hexdigest()
    assets=['icons/effects/icon.png','icons/turf/areas.dmi','icons/turf/floors.dmi',
            'icons/obj/flora/bigtrees.dmi','icons/obj/flora/bigtrees_winter.dmi',
            'icons/obj/flora/deadtrees.dmi','icons/obj/flora/deadtrees_winter.dmi']
    for path in assets:
        target=out/path;target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(ROOT/path,target)
        manifest['inputs'][path]={'sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'bytes':target.stat().st_size}
    (out/'fixture.dme').write_text('#include "fixture.dm"\n#include "los_context.dm"\n#include "root_light_snapshot.dm"\n#include "root_tree_presenter.dm"\n#include "production-light-update.dm"\n#include "fixture.dmf"\n')
    (out/'fixture.dmf').write_text('window "root"\n    elem "root"\n        type = MAIN\n        size = 600x600\n        title = "Civ13 root RGB pixel fixture"\n        can-resize = false\n    elem "map"\n        type = MAP\n        pos = 44,62\n        size = 480x480\n        zoom = 1\n        letterbox = true\n        is-default = true\n')
    (out/'source-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    return manifest

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True)
    a=p.parse_args();m=prepare(a.output);print(json.dumps({'output':str(a.output.resolve()),'inputs':len(m['inputs']),'executed':False}))

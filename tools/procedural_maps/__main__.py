"""Generate, validate, export and inspect new offline geography bundles."""
import argparse
import json
from pathlib import Path
import sys
from .bundle import write_bundle,verify_bundle
from .configuration import preset,port_surface_preset,oceanic_preset,validate_config
from .io import read_json,new_output,json_text
from .source_audit import audit
from .generator import generate
from .validator import validate


def main(argv=None):
    parser=argparse.ArgumentParser(description=__doc__)
    commands=parser.add_subparsers(dest='command',required=True)
    p=commands.add_parser('preset',help='write a complete versioned config to a new JSON file')
    p.add_argument('--profile',choices=['SURFACE','OCEANIC','UNDERGROUND_CAVERN'],default='SURFACE')
    p.add_argument('--legacy',action='store_true');p.add_argument('--coast',choices=['N','S','E','W'])
    p.add_argument('--seed',default='ports-0');p.add_argument('--width',type=int,default=64);p.add_argument('--height',type=int,default=80)
    p.add_argument('--out',required=True,type=Path)
    p=commands.add_parser('generate',help='one candidate, with DMM and sidecar; rejects explicitly')
    p.add_argument('--config',required=True,type=Path);p.add_argument('--out',required=True,type=Path)
    p.add_argument('--catalog-root',type=Path);p.add_argument('--traversal',choices=['forward','reverse'],default='forward')
    p.add_argument('--no-preview',action='store_true')
    p=commands.add_parser('validate',help='validate typed IR only');p.add_argument('document',type=Path)
    p=commands.add_parser('validate-config',help='check configuration before generation');p.add_argument('document',type=Path)
    p=commands.add_parser('export',help='export existing IR and its manifest to a new bundle')
    p.add_argument('--ir',required=True,type=Path);p.add_argument('--manifest',required=True,type=Path)
    p.add_argument('--out',required=True,type=Path);p.add_argument('--catalog-root',type=Path);p.add_argument('--no-preview',action='store_true')
    p=commands.add_parser('verify',help='verify bundle hashes, sidecar binding, layout and catalog')
    p.add_argument('directory',type=Path);p.add_argument('--catalog-root',type=Path)
    p=commands.add_parser('audit-source',help='read-only classic map/source audit')
    p.add_argument('--catalog-root',type=Path);p.add_argument('--reference-image',type=Path)
    p=commands.add_parser('annotate-reference',help='source components and uncertain hydrology proposals')
    p.add_argument('--out',required=True,type=Path)
    p.add_argument('--catalog-root',type=Path)
    a=parser.parse_args(argv)
    try:
        if a.command=='preset':
            if a.profile!='SURFACE' and a.coast is not None:raise ValueError('--coast is a SURFACE-only control')
            c=port_surface_preset(a.seed,a.width,a.height,sea_side=a.coast or 'S') if a.profile=='SURFACE' and not a.legacy else preset(a.profile,a.seed)
            if a.profile=='OCEANIC' and not a.legacy:c=oceanic_preset(a.seed,a.width,a.height)
            if a.profile!='SURFACE' or a.legacy:c['dimensions'].update(width=a.width,height=a.height)
            errors=validate_config(c)
            if errors:print(json_text(dict(accepted=False,errors=errors)));return 1
            if a.out.suffix.lower()!='.json':raise ValueError('config output must end in .json')
            new_output(a.out).write_text(json_text(c),encoding='utf-8',newline='\n')
            result=dict(status='CONFIG_WRITTEN',path=str(a.out),generation_run=False)
        elif a.command in {'validate','validate-config'}:
            errors=(validate if a.command=='validate' else validate_config)(read_json(a.document))
            print(json_text(dict(accepted=not errors,scope='offline-ir-only' if a.command=='validate' else 'offline-config-only',errors=errors)))
            return 1 if errors else 0
        elif a.command=='generate':
            c=read_json(a.config)
            # Refuse an existing destination before spending generation time.
            folder=new_output(a.out,True)
            r=generate(c,traversal=a.traversal)
            if r['document'] is None:
                (folder/'rejection.json').write_text(json_text(r),encoding='utf-8',newline='\n')
                print(json_text(r));return 1
            result=write_bundle(folder,r['document'],r['manifest'],a.catalog_root,not a.no_preview)
        elif a.command=='export':
            doc=read_json(a.ir);manifest=read_json(a.manifest);folder=new_output(a.out,True)
            result=write_bundle(folder,doc,manifest,a.catalog_root,not a.no_preview)
        elif a.command=='verify':result=verify_bundle(a.directory,a.catalog_root)
        elif a.command=='audit-source':result=audit(a.catalog_root,a.reference_image)
        else:
            from .reference_annotation import build
            result=build(a.catalog_root);new_output(a.out).write_text(json_text(result),encoding='utf-8',newline='\n')
        print(json_text(result));return 0
    except (OSError,ValueError,TypeError,KeyError,RecursionError) as e:
        print(json_text(dict(accepted=False,scope='offline-only',errors=[dict(code='INPUT',detail=str(e))])))
        return 2


if __name__=='__main__':raise SystemExit(main())

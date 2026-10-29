"""New-output-only indoor plan bundles; deliberately no native DMM emitter."""
import argparse
import hashlib
from pathlib import Path
from .catalog import CATALOG
from .common import canonical_hash
from .io import read_json,new_output,json_text
from .prototype import preset,generate,validate,validate_config
from .contracts import level_template,escape_scenario


def read(path):
    if Path(path).stat().st_size>2*1024*1024:raise ValueError('indoor prototype JSON exceeds 2 MiB cap')
    return read_json(path)


def write_bundle(folder,result,scenario_year=1990):
    doc=result['document'];manifest=result['manifest'];proof=validate(doc)
    if not proof['accepted']:raise ValueError('IR_REJECTED')
    if manifest['ir_sha256']!=canonical_hash(doc) or manifest['configuration']!=doc['configuration'] or manifest['configuration_sha256']!=canonical_hash(doc['configuration']):raise ValueError('MANIFEST_BINDING')
    template=level_template(doc);scenario=escape_scenario(doc,template,scenario_year)
    manifest=dict(manifest,schema='civ13-liminal-manifest/2',template_id=template['template_id'],level_template_sha256=canonical_hash(template),escape_scenario_sha256=canonical_hash(scenario))
    files={'plan.json':doc,'manifest.json':manifest,'proof.json':proof,'level-template.json':template,'escape-scenario.json':scenario}
    for name,data in files.items():(folder/name).write_text(json_text(data),encoding='utf-8',newline='\n')
    hashes={name:hashlib.sha256((folder/name).read_bytes()).hexdigest() for name in files}
    complete=dict(schema='civ13-liminal-offline-bundle/2',status='COMPLETE_TOPOLOGY_ONLY',native_ready=False,native_dmm_emitted=False,files=hashes)
    (folder/'complete.json').write_text(json_text(complete),encoding='utf-8',newline='\n')
    return complete


def verify_bundle(folder):
    folder=Path(folder);complete=read(folder/'complete.json')
    if complete.get('schema')!='civ13-liminal-offline-bundle/2' or complete.get('status')!='COMPLETE_TOPOLOGY_ONLY' or complete.get('native_ready') is not False or complete.get('native_dmm_emitted') is not False or set(complete.get('files',{}))!={'plan.json','manifest.json','proof.json','level-template.json','escape-scenario.json'}:raise ValueError('BUNDLE_MARKER')
    for name,digest in complete['files'].items():
        if hashlib.sha256((folder/name).read_bytes()).hexdigest()!=digest:raise ValueError('BUNDLE_HASH')
    doc=read(folder/'plan.json');manifest=read(folder/'manifest.json');proof=validate(doc)
    if manifest.get('schema')!='civ13-liminal-manifest/2':raise ValueError('MANIFEST_SCHEMA')
    if not proof['accepted'] or read(folder/'proof.json')!=proof:raise ValueError('VALIDATION_PROOF')
    if manifest.get('ir_sha256')!=canonical_hash(doc) or manifest.get('configuration')!=doc['configuration'] or manifest.get('configuration_sha256')!=canonical_hash(doc['configuration']):raise ValueError('MANIFEST_BINDING')
    for key in ['algorithm_version','content_version','profile_version','catalog_sha256']:
        if manifest.get(key)!=doc[key]:raise ValueError('VERSION_BINDING')
    if manifest.get('native_dmm_emitted') is not False or manifest.get('native_integration')!='PENDING':raise ValueError('NATIVE_ADMISSION')
    template=read(folder/'level-template.json');scenario=read(folder/'escape-scenario.json')
    if template!=level_template(doc) or manifest.get('template_id')!=template['template_id'] or manifest.get('level_template_sha256')!=canonical_hash(template):raise ValueError('TEMPLATE_BINDING')
    if scenario!=escape_scenario(doc,template,scenario.get('scenario_year')) or manifest.get('escape_scenario_sha256')!=canonical_hash(scenario):raise ValueError('SCENARIO_BINDING')
    return dict(status='VERIFIED_OFFLINE_TOPOLOGY_ONLY',native_ready=False,ir_sha256=canonical_hash(doc),template_id=template['template_id'],scenario_year=scenario['scenario_year'],proof=proof)


def main():
    p=argparse.ArgumentParser(description=__doc__);s=p.add_subparsers(dest='command',required=True)
    q=s.add_parser('preset');q.add_argument('--seed',default='liminal-0');q.add_argument('--out',type=Path,required=True)
    q=s.add_parser('generate');q.add_argument('--config',type=Path,required=True);q.add_argument('--out',type=Path,required=True);q.add_argument('--reverse',action='store_true');q.add_argument('--scenario-year',type=int,default=1990)
    q=s.add_parser('validate');q.add_argument('plan',type=Path)
    q=s.add_parser('verify');q.add_argument('directory',type=Path)
    q=s.add_parser('catalog');q.add_argument('--out',type=Path,required=True)
    a=p.parse_args()
    try:
        if a.command in {'preset','catalog'}:
            if a.out.suffix.lower()!='.json':raise ValueError('JSON output required')
            value=preset(a.seed) if a.command=='preset' else CATALOG
            new_output(a.out).write_text(json_text(value),encoding='utf-8',newline='\n');answer=dict(status='WRITTEN_OFFLINE_ONLY',native_ready=False)
        elif a.command=='generate':
            if not 1990<=a.scenario_year<=1993:raise ValueError('SCENARIO_YEAR: 1990..1993 required')
            c=read(a.config);folder=new_output(a.out,True);result=generate(c,traversal='reverse' if a.reverse else 'forward')
            if result['document'] is None:
                (folder/'rejection.json').write_text(json_text(result),encoding='utf-8',newline='\n');print(json_text(result));return 1
            answer=write_bundle(folder,result,a.scenario_year)
        elif a.command=='validate':
            answer=validate(read(a.plan));print(json_text(answer));return 0 if answer['accepted'] else 1
        else:answer=verify_bundle(a.directory)
        print(json_text(answer));return 0
    except (OSError,ValueError,TypeError,KeyError,RecursionError) as e:
        print(json_text(dict(status='INPUT_REJECTED',native_ready=False,error=str(e))));return 2


if __name__=='__main__':raise SystemExit(main())

"""Bound IR, config/version manifest, DMM and sidecar. No live-map application."""
import hashlib
from pathlib import Path
from .configuration import validate_config
from .dmm_export import emit,verify_roundtrip,verify_catalog
from .io import json_text,read_json
from .render_preview import render
from .validator import validate,canonical_hash


def check_manifest(doc,manifest):
    if validate(doc):raise ValueError('IR_REJECTED')
    config=manifest.get('configuration',{})
    if validate_config(config) or manifest.get('configuration_sha256')!=canonical_hash(config):raise ValueError('CONFIG_BINDING_MISMATCH')
    if config['seed']!=doc['seed'] or any(config['dimensions'][key]!=doc[key] for key in ['width','height']):raise ValueError('IDENTITY_BINDING_MISMATCH')
    if config['profile']!=doc['profile']:raise ValueError('PROFILE_BINDING_MISMATCH')
    if doc['schema']=='civ13-geography-ir/3':
        layout=config.get('ocean_layout',{});rules=doc['ocean_policy']
        if any(rules[k]!=layout.get(k) for k in ['island_min_area','island_gap_tiles']) or not layout.get('island_count',[7,7])[0]<=rules['island_count']<=layout.get('island_count',[7,7])[1]:raise ValueError('OCEAN_CONFIG_BINDING_MISMATCH')
        if doc['policy']['ship_radius']!=layout.get('ship_radius') or rules['start_min_spacing']!=config['starts']['min_spacing_tiles'] or rules['coast_route_max']!=config['starts']['max_route_tiles'] or len(doc['starts'])!=config['starts']['count']:raise ValueError('OCEAN_CONFIG_BINDING_MISMATCH')
    if {key:level['native_z'] for key,level in doc['layers'].items()}!=config['dimensions']['layers']:raise ValueError('LAYER_BINDING_MISMATCH')
    if any(manifest.get(key)!=doc[key] for key in ['algorithm_version','content_version','profile_version']):raise ValueError('VERSION_BINDING_MISMATCH')
    if manifest.get('generation_result',{}).get('ir_sha256')!=canonical_hash(doc):raise ValueError('IR_BINDING_MISMATCH')


def write_bundle(folder,doc,manifest,catalog_root=None,preview=True):
    check_manifest(doc,manifest)
    dmm,sidecar=emit(doc,manifest,catalog_root)
    proof=verify_roundtrip(dmm,sidecar)
    files={'map.ir.json':json_text(doc,True),'seed.manifest.json':json_text(manifest),
           'map.dmm':dmm,'map.dmm.sidecar.json':json_text(sidecar,True),'roundtrip.json':json_text(proof)}
    for name,data in files.items():(folder/name).write_text(data,encoding='utf-8',newline='\n')
    if preview:render(doc,folder/'preview.png')
    hashes={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(folder.iterdir()) if p.is_file()}
    result={'schema':'civ13-offline-map-bundle/1','status':'COMPLETE_OFFLINE_ONLY','native_ready':False,
            'reference_match':'NOT_EVALUATED','ir_sha256':canonical_hash(doc),'files':hashes}
    (folder/'complete.json').write_text(json_text(result),encoding='utf-8',newline='\n')
    return result


def verify_bundle(folder,catalog_root=None):
    folder=Path(folder);complete=read_json(folder/'complete.json')
    expected={'map.ir.json','seed.manifest.json','map.dmm','map.dmm.sidecar.json','roundtrip.json'}
    if complete.get('schema')!='civ13-offline-map-bundle/1' or complete.get('status')!='COMPLETE_OFFLINE_ONLY' or complete.get('native_ready') is not False:
        raise ValueError('BUNDLE_MARKER_MISMATCH')
    if set(complete.get('files',{})) not in [expected,expected|{'preview.png'}]:raise ValueError('BUNDLE_FILES_MISMATCH')
    for name,digest in complete['files'].items():
        if hashlib.sha256((folder/name).read_bytes()).hexdigest()!=digest:raise ValueError('BUNDLE_FILE_HASH_MISMATCH: '+name)
    doc=read_json(folder/'map.ir.json');manifest=read_json(folder/'seed.manifest.json');sidecar=read_json(folder/'map.dmm.sidecar.json')
    check_manifest(doc,manifest)
    if sidecar.get('semantic_ir')!=doc or sidecar.get('manifest')!=manifest:raise ValueError('SIDECAR_BINDING_MISMATCH')
    if complete.get('ir_sha256')!=canonical_hash(doc):raise ValueError('BUNDLE_IR_MISMATCH')
    verify_catalog(catalog_root)
    proof=verify_roundtrip((folder/'map.dmm').read_text(encoding='utf-8'),sidecar)
    if read_json(folder/'roundtrip.json')!=proof:raise ValueError('ROUNDTRIP_REPORT_MISMATCH')
    return dict(status='VERIFIED_OFFLINE_ONLY',native_ready=False,**proof)

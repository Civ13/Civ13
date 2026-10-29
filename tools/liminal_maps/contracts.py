"""Scenario-neutral template identity and a separate 1990-default escape spec.

No live instance is created, loaded, reset or migrated. Native era/equipment,
research, interaction and DMM admission remain explicitly pending.
"""
from copy import deepcopy
from .catalog import CATALOG
from .common import canonical_hash
from .prototype import validate

LEVEL_SCHEMA='civ13-generated-level-template/1'
ESCAPE_SCHEMA='civ13-liminal-escape-scenario/1'


def level_template(plan):
    proof=validate(plan)
    if not proof['accepted']:raise ValueError('TEMPLATE_REQUIRES_VALID_TOPOLOGY')
    links=[{key:deepcopy(link[key]) for key in ['id','a','b','kind','width']} for link in sorted(plan['links'],key=lambda e:e['id'])]
    anchors=[]
    for room in plan['rooms']:
        for kind,sites in CATALOG['archetypes'][room['archetype']]['anchors'].items():
            for index,p in enumerate(sites):anchors.append(dict(id=room['id']+'.'+kind+'.'+str(index),room=room['id'],kind=kind,local_at=p[:]))
    anchors.sort(key=lambda a:a['id'])
    geometry=dict(logical_layer=plan['logical_layer'],rooms=deepcopy(sorted(plan['rooms'],key=lambda r:r['id'])),links=links,sealed_sockets=deepcopy(sorted(plan['sealed_sockets'],key=lambda e:(e['room'],e['socket']))),
                  anchors=anchors,blueprint=deepcopy(plan['blueprint']))
    c=plan['configuration']
    parameters={key:deepcopy(c[key]) for key in ['schema','profile','catalog_version','catalog_sha256','hub_allowlist','branch_alcove','actor_radius_tiles','max_rooms','max_blueprint_tiles']}
    identity=dict(schema=LEVEL_SCHEMA,generator=dict(algorithm_version=plan['algorithm_version'],profile_version=plan['profile_version'],content_version=plan['content_version'],catalog_sha256=plan['catalog_sha256']),
                  seed=plan['seed'],geometry_configuration_sha256=canonical_hash(parameters),geometry_sha256=canonical_hash(geometry),geometry=geometry)
    return dict(schema=LEVEL_SCHEMA,template_id='sha256:'+canonical_hash(identity),identity=identity,
                generation_receipt=dict(configuration=deepcopy(c),configuration_sha256=canonical_hash(c),source_topology_sha256=canonical_hash(plan)),
                native_export=dict(native_ready=False,native_catalog=None,logical_to_native_z=None,dmm_sha256=None))


def escape_scenario(plan,template,year=1990):
    if type(year) is not int or not 1990<=year<=1993:raise ValueError('SCENARIO_YEAR: initial early-1990s policy accepts 1990..1993')
    if template!=level_template(plan):raise ValueError('TEMPLATE_BINDING')
    lookup={(a['room'],a['kind'],tuple(a['local_at'])):a['id'] for a in template['identity']['geometry']['anchors']}
    bindings={}
    for group,kind in [('spawns','spawn'),('objectives','objective'),('exits','exit')]:
        bindings[group]=[]
        for marker in plan[group]:
            record={k:deepcopy(v) for k,v in marker.items() if k not in {'room','local_at','native_admission'}}
            record['anchor_id']=lookup[(marker['room'],kind,tuple(marker['local_at']))];bindings[group].append(record)
    bindings['gate_rules']=[dict(slot_id=e['id'],requires_flags=deepcopy(e['requires_flags'])) for e in plan['links'] if e['requires_flags']]
    return dict(schema=ESCAPE_SCHEMA,scenario='LIMINAL_ESCAPE',scenario_version='liminal-escape-spec/1',scenario_year=year,epoch='EARLY_1990S',
                template_id=template['template_id'],bindings=bindings,
                era_policy=dict(version='early-1990s-proposal/1',native_admission='PENDING_PERIOD_ALLOWLIST',equipment_ids=[],prop_ids=[],recipe_ids=[],research_ids=[]),
                native_admission='PENDING_MODE_ADAPTER',native_ready=False)

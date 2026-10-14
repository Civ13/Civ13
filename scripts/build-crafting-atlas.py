"""Generate current-source recipes and genuine isolated BYOND icon previews."""
from pathlib import Path
import subprocess, re, json, hashlib, argparse, sys

ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output', type=Path, default=ROOT/'data/atlas-preview')
parser.add_argument('--byond-bin', type=Path)
parser.add_argument('--catalog-only', action='store_true')
parser.add_argument('--game-catalog', type=Path)
parser.add_argument('--check-game-catalog', type=Path)
options=parser.parse_args()
OUT=options.output.resolve()
def git(*args):
    return subprocess.check_output(['git','-C',str(ROOT),*args])
SHA=git('rev-parse','HEAD').decode().strip()
paths=git('ls-files','-z').decode().split('\0')
files={p:(ROOT/p).read_text(encoding='utf-8',errors='replace') for p in paths if p and (p.endswith('.dm') or p.startswith('config/crafting/') or p=='civ13.dme')}
def uncomment(s):
    s=re.sub(r'/\*.*?\*/',lambda m:'\n'*m[0].count('\n'),s,flags=re.S)
    return '\n'.join(re.sub(r'//.*','',x) for x in s.splitlines())
def label(s):
    return s.rstrip('/').split('/')[-1].replace('_',' ')
material_stacks={}
material_aliases={}
material_source=uncomment(files.get('code/modules/materials/materials.dm',''))
for match in re.finditer(r'^(/material/[^\s(]+)\s*\n((?:\t[^\n]*\n|\n)*)',material_source,re.M):
    typepath,body=match.groups()
    stack=re.search(r'\bstack_type\s*=\s*(/[^\s]+)',body)
    name=re.search(r'\bname\s*=\s*"([^"]+)"',body)
    if stack:
        material_stacks[typepath]=stack[1]
        material_aliases[stack[1]]=typepath
        if name:material_aliases['/material/'+name[1]]=typepath
def material_stack(typepath):
    parent=typepath
    while parent.startswith('/material/'):
        if parent in material_stacks:return material_stacks[parent]
        parent=parent.rsplit('/',1)[0]
    return '/obj/item/stack/material/'+typepath.removeprefix('/material/')
def canon(s):
    if s.startswith('material:'):s='/material/'+s.split(':',1)[1]
    s=s.strip().strip('"').rstrip('/')
    if s.startswith('reagent:'):return s.removeprefix('reagent:')
    if s.startswith('material:'):s='/material/'+s.removeprefix('material:')
    if s in material_aliases:return material_aliases[s]
    if s.startswith('/obj/item/stack/material/'):
        return '/material/'+s.split('/obj/item/stack/material/')[1]
    return s
records=[]; issues=[]; occurrence=[]
def add(name,kind,inputs,outputs,path,line,conditions='',raw=''):
    for typepath,_ in outputs:
        if typepath.startswith('/obj/structure/exercise'):
            modern=typepath.startswith('/obj/structure/exercise/modern')
            conditions+=f' Native crafting skill {105 if modern else 30}; completed research or existing faction baseline required at construction.'
            if modern:conditions+=' Minimum era Modern (ordinal 8).'
        if typepath.startswith('/obj/structure/telecom') or typepath == '/obj/item/weapon/telephone/landline':
            skill=100 if typepath.endswith('/landline') else 160 if typepath in ('/obj/structure/telecom/tv','/obj/structure/telecom/station/tv','/obj/structure/telecom/terminal') else 105
            conditions+=f' Minimum era Modern (ordinal 8); native crafting skill {skill}; completed research node required at construction.'
    inputs=[{'id':canon(a),'name':label(a),'quantity':str(b)} for a,b in inputs]
    outputs=[{'id':canon(a),'name':label(a),'quantity':str(b)} for a,b in outputs]
    records.append(dict(id='r'+str(len(records)),name=name,kind=kind,inputs=inputs,outputs=outputs,file=path,line=line,conditions=conditions,raw=raw))
for p,s in files.items():
    if p.startswith('config/crafting/'):
        for ln,row in enumerate(s.splitlines(),1):
            if 'RECIPE: ' not in row or '//' in row: continue
            cols=row.split('RECIPE: ',1)[1].strip().split(',')
            if len(cols)!=13: issues.append(dict(file=p,line=ln,reason='Expected 13 fields',raw=row));continue
            a,n,b,c,t,one,floor,category,ind,mil,med,age,mat=cols
            add(n,'Material / '+Path(p).stem.replace('material_recipes_',''),[(a,c)],[(b,1)],p,ln,f'Legacy research I/M/M: {ind}/{mil}/{med}; maximum era ordinal {age}; time {t} deciseconds; category {category}; one per turf {one}; floor {floor}; supplied material {mat}. Research-node and map gates also apply.',row)

def splitargs(s):
    out=[];start=0;depth=0;quoted=False
    for i,c in enumerate(s):
        if c=='"' and (i==0 or s[i-1]!='\\'): quoted=not quoted
        if not quoted:
            if c=='(':depth+=1
            elif c==')':depth-=1
            elif c==',' and depth==0:out.append(s[start:i].strip());start=i+1
    out.append(s[start:].strip());return out
def lists(s,key):
    m=re.search(r'\b'+key+r'\s*=\s*list\(',s)
    if not m:return []
    i=m.end();j=i;depth=1;quote=False
    while j<len(s) and depth:
        c=s[j]
        if c=='"' and s[j-1]!='\\':quote=not quote
        if not quote:
            if c=='(':depth+=1
            elif c==')':depth-=1
        j+=1
    pairs=[]
    for arg in splitargs(s[i:j-1]):
        m=re.match(r'("[^"]+"|/[\w/]+)\s*(?:=\s*(.*))?$',arg,re.S)
        if m:pairs.append((m[1].strip('"'),m[2] or '1'))
    return pairs
for p,raw in files.items():
    if not p.endswith('.dm'):continue
    s=uncomment(raw)
    for m in re.finditer(r'^\s*"([^"]+)"\s*=\s*list\(([^\n]+)\)',s,re.M):
        args=splitargs(m[2])
        if p.endswith('blacksmithing_recipes.dm') and len(args)==9 and args[-1].startswith('/obj/'):
            # These are alternative feedstock costs, not a cumulative bill of materials.
            for material,cost in zip(['steel','iron','bronze','kevlar'],args[4:8]):
                if cost!='0':
                    add(m[1]+' ['+material+']','Anvil', [('/material/'+material,cost)],[(args[-1],1)],p,s[:m.start()].count('\n')+1,f'Era ordinals {args[2]} through {args[3]}; category {args[1]}; alternative {material} route, not all feedstocks together; anvil material/category/job gates apply. Mold alloy substitutions have separate runtime multipliers.',m[0])
    declarations=list(re.finditer(r'^(/datum/chemical_reaction[^\s(]*)\s*$',s,re.M))
    for ix,m in enumerate(declarations):
        end=declarations[ix+1].start() if ix+1<len(declarations) else len(s)
        body=s[m.end():end]
        # Restrict assignments to declaration body before the next top-level proc/type.
        body=re.split(r'^\S',body,maxsplit=1,flags=re.M)[0]
        inp=lists(body,'required_reagents')
        result=re.search(r'^\s*result\s*=\s*"([^"]+)"',body,re.M)
        resultpath=re.search(r'^\s*result\s*=\s*(/[^\s]+)',body,re.M)
        if not inp:continue
        output=result[1] if result else resultpath[1] if resultpath else None
        if output in ('','null') or not output:
            issues.append(dict(file=p,line=s[:m.start()].count('\n')+1,reason='Reaction has custom/inherited products; inspect callback',raw=m[1]));continue
        name=re.search(r'^\s*name\s*=\s*"([^"]+)"',body,re.M)
        qty=re.search(r'^\s*result_amount\s*=\s*([^\n]+)',body,re.M)
        catalysts=lists(body,'catalysts'); inhibitors=lists(body,'inhibitors')
        conditions=f'Catalysts: {catalysts}; inhibitors: {inhibitors}; additional can_happen/process callbacks may apply.'
        add(name[1] if name else label(m[1]),'Chemistry',inp,[(output,qty[1] if qty else 'inherited')],p,s[:m.start()].count('\n')+1,conditions,body.strip())
    # Direct static stack recipes outside configuration lists.
    for m in re.finditer(r'new\s*/datum/stack_recipe\s*\(',s):
        start=m.end();i=start;depth=1;quote=False
        while i<len(s) and depth:
            c=s[i]
            if c=='"' and s[i-1]!='\\':quote=not quote
            if not quote:
                if c=='(':depth+=1
                elif c==')':depth-=1
            i+=1
        args=splitargs(s[start:i-1])
        if len(args)>=3 and args[0].startswith('"') and args[1].startswith('/'):
            prior=s[:m.start()];decls=re.findall(r'^(/[^\s(]+)',prior,re.M);owner=decls[-1] if decls else 'runtime material'
            add(args[0].strip('"'),'Native stack',[(owner,args[2])],[(args[1],1)],p,prior.count('\n')+1,'Receiver/context dependent; named constructor arguments retained in source.',s[m.start():i])
    for m in re.finditer(r'(/obj/[\w/]+)\s*=\s*(/obj/[\w/]+)',s):
        if p.endswith('/pot.dm'):
            add('Boil '+label(m[1]),'Cooking',[(m[1],1)],[ (m[2],1)],p,s[:m.start()].count('\n')+1,'Boiling water and pot/stove conditions apply.',m[0])
    # Every lexical production site stays searchable, not an asserted recipe edge.
    for ln,row in enumerate(s.splitlines(),1):
        if re.search(r'\bnew\s*/obj/|\bnew\s+/obj/|\.add_reagent\(|\bnew\s+(?:result|resultpath|path|product)',row):
            occurrence.append(dict(file=p,line=ln,text=row.strip()))

nodes=files.get('code/modules/research_tree/research_node.dm','')
sprite_variants={}
assembly_path='code/modules/1713/gunsmithing/blackpowder_assembly.dm'
assembly=uncomment(files.get(assembly_path,''))
if assembly:
    contracts=json.loads((ROOT/'scripts/atlas/procedural-contracts.json').read_text())
    for path,digest in contracts.items():
        current=hashlib.sha256((ROOT/path).read_bytes().replace(b'\r\n',b'\n')).hexdigest()
        if current!=digest:
            raise SystemExit('Procedural source changed: review atlas assembly/preparation extraction and update scripts/atlas/procedural-contracts.json: '+path)
    mechanism='/obj/item/blackpowder_part/mechanism'
    for match in re.finditer(r'^(/obj/item/blackpowder_part/[^\s(]+)\s*\n((?:\t[^\n]*\n|\n)*)',assembly,re.M):
        item,body=match.groups()
        name=re.search(r'\bname\s*=\s*"([^"]+)"',body)
        if name:
            sprite_variants[item]=dict(type=item,name=name[1])
    loaded=mechanism+'#flint_loaded'
    sprite_variants[loaded]=dict(type=mechanism,state='flintlock_mechanism',name='flint-loaded mechanism')
    # Preserve stateful prerequisites as separate graph nodes. Loading flint does
    # not change the mechanism sprite in production, but does change eligibility.
    if 'has_flint = TRUE' in assembly and 'if (!F.sharpened)' in assembly:
        add('Load sharpened flint into mechanism','Flintlock assembly',[(mechanism,1),('/obj/item/weapon/flint/sharpened',1)],[(loaded,1)],assembly_path,assembly[:assembly.index('/obj/item/blackpowder_part/mechanism/assemble')].count('\n')+1,'Sharpened flint required; gunsmithing research; era 3-4; 20 ticks; held active input, nearby/held target, action rechecks.', 'has_flint = TRUE after consuming sharpened flint')
    else:
        issues.append(dict(file=assembly_path,line=1,reason='Flint-loading source contract changed; inspect assembly callback',raw='mechanism assembly'))
    for match in re.finditer(r'^(/obj/item/blackpowder_part/stock/[^\s(]+)\s*\n((?:\t[^\n]*\n|\n)*)',assembly,re.M):
        stock,body=match.groups()
        barrel=re.search(r'\bbarrel_type\s*=\s*(/[^\s]+)',body)
        gun=re.search(r'\bgun_type\s*=\s*(/[^\s]+)',body)
        state=re.search(r'\bbarreled_icon\s*=\s*"([^"]+)"',body)
        if not (barrel and gun and state):continue
        partial=stock+'#barrel_attached'
        sprite_variants[partial]=dict(type=stock,state=state[1],name=label(stock)+' stock with barrel')
        line=assembly[:match.start()].count('\n')+1
        gate='Gunsmithing research; era 3-4; held active input and nearby/held target; matching barrel and loaded mechanism required; production action rechecks; pistol 20 ticks, musket 30 ticks per attachment.'
        add('Attach '+label(stock)+' barrel','Flintlock assembly',[(stock,1),(barrel[1],1)],[(partial,1)],assembly_path,line,gate,body)
        add('Finish Flintlock '+label(stock)+' assembly','Flintlock assembly',[(partial,1),(loaded,1)],[(gun[1],1)],assembly_path,line,gate+' Optional component route; legacy direct anvil route remains separate.',body)
    rock_path='code/game/objects/structures/rocks.dm'
    rock=uncomment(files.get(rock_path,''))
    if 'var/obj/item/weapon/flint/newflint = new/obj/item/weapon/flint' in rock:
        add('Gather flint from rocks','Flintlock preparation',[],[('/obj/item/weapon/flint',1)],rock_path,rock[:rock.index('/obj/structure/wild/rock/attack_hand')].count('\n')+1,'Grab intent; rock flint_amount > 0; 50-tick action; rock stock regenerates. Rock is a source, not consumed.', 'rock attack_hand finite stocked flint')
        records[-1]['inputs']=[dict(id='/obj/structure/wild/rock',name='stocked rock source (not consumed)',quantity='source')]
    if '/obj/item/weapon/flint/proc/sharpen()' in rock and 'icon_state = "sharpened_flint"' in rock:
        add('Sharpen flint against a rock','Flintlock preparation',[('/obj/item/weapon/flint',1)],[('/obj/item/weapon/flint/sharpened',1)],rock_path,rock[:rock.index('/obj/item/weapon/flint/proc/sharpen()')].count('\n')+1,'Use unsharpened flint against a rock; 20% chance per strike; rock is not consumed. State change retains the original flint object; output node denotes sharpened state.', 'flint sharpen() state transition')
bench_path='code/game/objects/structures/blacksmithing/component_workbench.dm'
bench=uncomment(files.get(bench_path,''))
if bench:
    for name,result in re.findall(r'"(Pickaxe|Shovel|Hatchet)"\s*=\s*(/obj/item/weapon/material/\w+)',bench):
        head={'Pickaxe':'pickaxe','Shovel':'shovel','Hatchet':'axehead/hatchet'}[name]
        add('Workbench '+name,'Tool assembly',[(f'/obj/item/weapon/material/part/{head}',1),('/obj/item/weapon/material/handle',1)],[(result,1)],bench_path,1,'Tool assembly workbench; usable matching head and handle acquired through native gates; 100 ticks; nearby conscious actor; cancellation retains inputs. Preserves component material, quality and wear. Legacy hand assembly remains available.', 'tool_recipes staged guarded finish_assembly')
for recipe in records:
    for resource in recipe['inputs']+recipe['outputs']:
        if resource['id'] in sprite_variants:
            resource['name']=sprite_variants[resource['id']]['name']
gate_map=dict(re.findall(r'"(/obj/[^"\n]+)"\s*=\s*"([^"\n]+)"',uncomment(nodes)))
for r in records:
    for o in r['outputs']:
        if o['id'] in gate_map:r['conditions']+=' Explicit research node: '+gate_map[o['id']]+'.'
data=dict(sha=SHA,recipes=records,issues=issues,production_sites=occurrence,files=len(files),sources=[],limitations=[
    'All loader-selected material catalog rows are included, including map/faction alternatives; they are not all simultaneously unlocked.',
    'Chemistry, anvil and native stack recipes are statically extracted. Inheritance, custom callbacks, runtime type choices and procedural crafting require source inspection.',
    'Every lexical object/reagent production site is indexed separately. These sites include loot, admin/test setup and effects; they are NOT all player acquisition paths.',
    'Finite terrain, seasonal plants, map stock, research, skill, tools, heat, power, fuel and RNG can restrict routes. This atlas does not prove map-level reachability.',
    'Catalog uses the checked-out source. Compiled inherited defaults supply genuine sprite previews without constructing game objects. Custom overlays and material recoloring remain dynamic.'
])
source_path=ROOT/'scripts/atlas/resource-sources.json'
if source_path.exists():
    data['sources']=json.loads(source_path.read_text(encoding='utf-8-sig'))
    data['sources']['audit_commit']=data['sources'].pop('source_commit')
    data['limitations'].append('Acquisition annotations were audited at '+data['sources']['audit_commit']+'; current recipes and sprites regenerate, procedural annotations require review when behavior changes.')
    for x in data['sources'].get('mechanisms',[]):
        for field in ('inputs','outputs'):
            x[field]=[canon(value) for value in x.get(field,[]) if isinstance(value,str)]
        outputs=[(o,'conditional yield') for o in x.get('outputs',[]) if isinstance(o,str)]
        inputs=[(i,'conditional') for i in x.get('inputs',[]) if isinstance(i,str)]
        if outputs:add(x['name'],'Acquisition / processing', inputs or [('source:'+x['name'],'see source inputs')],outputs,x['file'],x.get('line',1),x.get('conditions',x.get('gate',''))+'; '+x.get('status','')+'; outputs may be alternatives, not a simultaneous bundle.')
# Curated player acquisition routes, separate from raw production occurrences.
acquisition={}
for route in data['sources'].get('mechanisms',[]) if isinstance(data['sources'],dict) else []:
    entry={k:v for k,v in route.items() if k in ('name','file','line','conditions','status','tools','steps','map_notes','era','inputs','outputs')}
    entry['audit_commit']=route.get('source_commit',data['sources'].get('audit_commit',''))
    if isinstance(entry.get('tools'),list):entry['tools']=[label(tool) if isinstance(tool,str) and tool.startswith('/') else tool for tool in entry['tools']]
    for output in route.get('outputs',[]):
        if not isinstance(output,str):continue
        key='/material/'+output.split(':',1)[1] if output.startswith('material:') else output
        key=canon(key)
        acquisition.setdefault(key,[]).append(entry)
data['acquisition']=acquisition
resource_ids=sorted({x['id'] for r in records for x in r['inputs']+r['outputs']})
resource_names={x['id']:x['name'] for r in records for x in r['inputs']+r['outputs']}
if options.catalog_only:
    game=dict(acquisition=acquisition,recipes=[{k:v for k,v in r.items() if k not in ('raw',)} for r in records],resources={x:dict(name=resource_names[x],type=(material_stack(x) if x.startswith('/material/') else x),label='Initial sprite; runtime appearance may differ')|sprite_variants.get(x,{}) for x in resource_ids})
    game_text=json.dumps(game,separators=(',',':'),ensure_ascii=True)+'\n'
    if options.game_catalog:
        options.game_catalog.parent.mkdir(parents=True,exist_ok=True)
        options.game_catalog.write_text(game_text,encoding='utf-8')
    if options.check_game_catalog and options.check_game_catalog.read_text(encoding='utf-8')!=game_text:
        raise SystemExit('Stale game atlas')
    print('Generated '+str(len(records))+' current recipe records without starting gameplay')
    raise SystemExit(0)
if not options.byond_bin:
    parser.error('--byond-bin is required for compiled website sprites')
OUT.mkdir(parents=True,exist_ok=True)
assets=OUT/'sprites';assets.mkdir(exist_ok=True)
representatives={x:(sprite_variants[x]['type']+'#'+sprite_variants[x]['state'] if x in sprite_variants and 'state' in sprite_variants[x] else sprite_variants[x]['type'] if x in sprite_variants else material_stack(x) if x.startswith('/material/') else x) for x in resource_ids}
fallback='/obj/item/weapon/paper'
(assets/'requests.json').write_text(json.dumps(sorted(set(representatives.values())|{fallback})),encoding='utf-8')
subprocess.run([sys.executable,str(ROOT/'tests/sprites/run.py'),'--byond-bin',str(options.byond_bin),'--output',str(OUT/'compiled-sprites.json'),'--atlas-assets',str(assets)],check=True,cwd=ROOT)
rows={r['type']:r for r in json.loads((OUT/'compiled-sprites.json').read_text())}
exports=json.loads((assets/'exports.json').read_text())
from PIL import Image
exports={typepath:filename for typepath,filename in exports.items() if Image.open(assets/filename).convert('RGBA').getbbox() is not None}
assert fallback in exports, 'Missing genuine abstract-resource legend sprite'
data['resources']={}
for resource in resource_ids:
    candidate=representatives[resource]
    direct=candidate in exports
    typepath=candidate if direct else fallback
    row=rows[typepath.split('#')[0]]
    mode='source symbol; abstract or dynamic appearance unresolved' if not direct else 'reviewed state; runtime overlays may differ' if '#' in resource else 'material exemplar; runtime recoloring may differ' if resource.startswith('/material/') else 'compiled default'
    data['resources'][resource]=dict(type=typepath.split('#')[0],icon=row['icon'],state=typepath.split('#')[1] if '#' in typepath else row['state'],dir=row['dir'],image='sprites/'+exports[typepath],label=mode,source_symbol=not direct)
game=dict(acquisition=acquisition,recipes=[{k:v for k,v in r.items() if k not in ('raw',)} for r in records],resources={x:dict(name=resource_names[x],type=(material_stack(x) if x.startswith('/material/') else x),label='Initial sprite; runtime appearance may differ')|sprite_variants.get(x,{}) for x in resource_ids})
game_text=json.dumps(game,separators=(',',':'),ensure_ascii=True)+'\n'
if options.game_catalog:
    options.game_catalog.parent.mkdir(parents=True,exist_ok=True)
    options.game_catalog.write_text(game_text,encoding='utf-8')
if options.check_game_catalog:
    if options.check_game_catalog.read_text(encoding='utf-8')!=game_text:
        raise SystemExit('Stale game atlas: regenerate with --game-catalog '+str(options.check_game_catalog))
(OUT/'crafting-data.json').write_text(json.dumps(data,indent=2),encoding='utf-8')

def esc(s):return s.replace('\\','\\\\').replace('"','\\"').replace('\n',' ')
uml=['@startuml','left to right direction','skinparam classAttributeIconSize 0']
ids={}
for r in records:
    for x in r['inputs']+r['outputs']:
        if x['id'] not in ids:
            a='n'+str(len(ids));ids[x['id']]=a;uml.append(f'class "{esc(x["id"])}" as {a} <<resource>>')
    uml.append(f'class "{esc(r["name"])}" as {r["id"]} <<transformation>>')
    for x in r['inputs']:uml.append(f'{ids[x["id"]]} --> {r["id"]} : {esc(x["quantity"])} input')
    for x in r['outputs']:uml.append(f'{r["id"]} --> {ids[x["id"]]} : {esc(x["quantity"])} output')
uml.append('@enduml');(OUT/'all-recipes.puml').write_text('\n'.join(uml),encoding='utf-8')
template=Path(__file__).with_name('crafting-atlas-template.html').read_text(encoding='utf-8')
(OUT/'index.html').write_text(template.replace('/*DATA*/',json.dumps(data).replace('<','\\u003c')),encoding='utf-8')
print(json.dumps(dict(sha=SHA,recipes=len(records),resources=len(ids),production_sites=len(occurrence),unresolved=len(issues),output=str(OUT))))

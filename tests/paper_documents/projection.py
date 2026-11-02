"""Audited DM subset projected offline with inert object/list/clock seams.

This executes complete selected production procedure bodies, not native DM.
Unknown statements/call boundaries fail preparation. Dicts model associative
records and Python arrays model unassociated DM arrays in these fixtures.
"""
from pathlib import Path
import ast,copy,hashlib,json,math,re
ROOT=Path(__file__).resolve().parents[2]
SOURCE=(ROOT/'code/modules/paperwork/document.dm').read_text(encoding='utf-8')
LANG=(ROOT/'code/modules/paperwork/written_languages.dm').read_text(encoding='utf-8')
IDS=dict(re.findall(r'"(civ13:[a-z]+:v1)" = (/datum/language/\w+)',LANG))
MAXIMUM=int(re.search(r'#define MAX_PAPER_MESSAGE_LEN (\d+)',(ROOT/'code/__defines/__game.dm').read_text())[1])

def body(source,signature):
 found=re.search('^'+re.escape(signature)+r'\([^\n]*\)\n((?:\t[^\n]*\n|\n)*)',source,re.M)
 assert found,'Missing procedure '+signature
 return found[1]

def split_top(value,delimiter=','):
 result=[];start=0;depth=0;quote=False;escaped=False
 for i,c in enumerate(value):
  if quote:
   if escaped:escaped=False
   elif c=='\\':escaped=True
   elif c=='"':quote=False
   continue
  if c=='"':quote=True
  elif c in '([':depth+=1
  elif c in ')]':depth-=1
  elif c==delimiter and depth==0:result.append(value[start:i]);start=i+1
 result.append(value[start:]);return result

def expression(value):
 value=value.strip().replace('"section-[next["next_section"]]"','section_id(next)').replace('"[legacy_body][paper.stamps]"','dm_text(legacy_body)+dm_text(paper.stamps)').replace(r'"\[Unintelligible writing\]"','"[Unintelligible writing]"')
 # Convert innermost native lists recursively, preserving key names verbatim.
 match=re.search(r'\blist\(',value)
 if match:
  start=match.end();depth=1;quote=False;escaped=False;end=start
  while depth:
   c=value[end]
   if quote:
    if escaped:escaped=False
    elif c=='\\':escaped=True
    elif c=='"':quote=False
   elif c=='"':quote=True
   elif c=='(':depth+=1
   elif c==')':depth-=1
   end+=1
  inner=value[start:end-1];parts=split_top(inner) if inner else []
  pairs=[re.match(r'^\s*("[^"]+")\s*=\s*(.*)$',p,re.S) for p in parts]
  if parts and all(pairs):replacement='{'+','.join(p[1]+':'+expression(p[2]) for p in pairs)+'}'
  else:replacement='['+','.join(expression(p) for p in parts)+']'
  return expression(value[:match.start()]+replacement+value[end:])
 # DM ternary is used only at the expression's top level in this subset.
 parts=split_top(value,'?')
 if len(parts)==2:
  choices=split_top(parts[1],':');assert len(choices)==2,value
  return '('+expression(choices[0])+' if '+expression(parts[0])+' else '+expression(choices[1])+')'
 assert len(parts)==1,value
 value=value.replace('&&',' and ').replace('||',' or ')
 value=re.sub(r'!(?!=)','not ',value)
 value=re.sub(r'\bTRUE\b','True',value);value=re.sub(r'\bFALSE\b','False',value);value=re.sub(r'\bnull\b','None',value)
 value=re.sub(r'(?<![\w"\'])/(?:[a-zA-Z_]\w*/)*[a-zA-Z_]\w*',lambda m:repr(m[0]),value)
 value=re.sub(r'\b(\w+)\.len\b',r'len(\1)',value)
 value=value.replace('types[language_id]','types.get(language_id)')
 value=value.replace('P.document_record != current','P.document_record is not current').replace('paper.document_record != current','paper.document_record is not current')
 value=value.replace('istype(actor)','is_actor(actor)').replace('istype(pen)','is_pen(pen)').replace('istype(L)','is_living(L)')
 return value

ALLOWED={'len','range','round','length','isnull','isnum','ispath','istext','islist','lowertext','copytext','text2ascii','is_actor','is_pen','is_living','istype','isturf','isghost','json_encode','dm_text','section_id','copy_keys','copy_value','copy_append','copy_assoc','new_budget','new_record_budget','max','min','md5','stars','paper_document_copy','paper_document_legacy_snapshot','paper_document_keys','paper_document_ink','paper_document_section_valid','paper_document_record_valid','paper_document_prepare_edit','paper_document_commit_edit','paper_document_mint_id','paper_written_language_types','paper_written_language','paper_knows_written_language'}
METHODS={'get','append','can_speak','get_active_hand','restrained','Adjacent','get_signature','has_access','can_mutate'}
def project(source,signature,args,env,method=False):
 lines=['def projected('+args+'):']
 for raw in body(source,signature).splitlines():
  code=raw.strip()
  if not code or code.startswith('//'):continue
  indent=len(raw)-len(raw.lstrip('\t'))
  code=re.sub(r'\bvar/(?:\w+/)*(\w+)\b',r'\1',code)
  if code=='budget = new()':code='budget = new_budget()'
  elif code=='budget = new /datum/paper_document_budget/record()':code='budget = new_record_budget()'
  elif code=='result = list()':code='result = {} if isinstance(source,dict) else []'
  elif code=='key = source[index]':code='key = copy_keys(source)[index-1]'
  elif code=='result += list(copied_key)':code='copy_append(result,copied_key)'
  elif code=='result[copied_key] = paper_document_copy(source[key], budget, depth + 1)':code='copy_assoc(result,copied_key,paper_document_copy(copy_value(source,key),budget,depth+1))'
  elif code=='section = sections[index]':code='section = sections[index-1]'
  elif code=='ids += section["id"]':code='ids.append(section["id"])'
  else:
   if code.startswith('if ('):
    assert code.endswith(')'),code;code='if '+expression(code[4:-1])+':'
   elif code.startswith('for ('):
    counter=re.fullmatch(r'for \((\w+) = (\d+), \1 <= (.+), \1\+\+\)',code)
    if counter:code='for '+counter[1]+' in range('+counter[2]+','+expression(counter[3])+ '+1):'
    else:
     match=re.fullmatch(r'for \((\w+) in (.*)\)',code);assert match,code
     code='for '+match[1]+' in '+expression(match[2])+':'
   elif code=='else':code='else:'
   elif code in ('break','continue','return'):pass
   elif code.startswith('return '):code='return '+expression(code[7:])
   elif code.endswith('++'):code=expression(code[:-2])+' += 1'
   elif code.endswith('--'):code=expression(code[:-2])+' -= 1'
   elif '=' in code:
    match=re.fullmatch(r'(.+?) ([-+]?=) (.*)',code);assert match,code
    code=expression(match[1])+' '+match[2]+' '+expression(match[3])
   elif re.fullmatch(r'[\w_]+(?:\.[\w_]+)*\(.*\)',code):code=expression(code)
   else:raise AssertionError('Unsupported statement '+code)
  if method:
   pieces=re.split(r'("(?:[^"\\]|\\.)*")',code)
   for i in range(0,len(pieces),2):
    pieces[i]=re.sub(r'(?<![\w.])paper\b','self.paper',pieces[i])
    pieces[i]=re.sub(r'(?<![\w.])(controller|control_client)\b',lambda m:'self.'+m[1],pieces[i])
    pieces[i]=re.sub(r'(?<![\w.])(has_access|can_mutate)\(',lambda m:'self.'+m[1]+'(',pieces[i])
   code=''.join(pieces)
  lines.append('    '*indent+code)
 translated='\n'.join(lines)+'\n'
 try:tree=ast.parse(translated)
 except SyntaxError as error:raise AssertionError(translated) from error
 for node in ast.walk(tree):
  if isinstance(node,ast.Call):
   if isinstance(node.func,ast.Name):assert node.func.id in ALLOWED|{'isinstance','dict'},node.func.id
   elif isinstance(node.func,ast.Attribute):assert node.func.attr in METHODS,node.func.attr
   else:raise AssertionError('Unknown call boundary')
 exec(compile(tree,signature,'exec'),env)
 return env['projected']

class Ref:pass
class TypePath(str):pass
class Language(Ref):
 def __init__(self,path):self.type=path;self.name=path.rsplit('/',1)[-1];self.flags=0
class Actor(Ref):
 def __init__(self,kind='human'):
  self.kind=kind;self.client=Ref();self.client.mob=self;self.stat=0;self.bound=False;self.languages=[];self.universal_speak=False;self.muted=False;self.default_language=None;self.active=None
 def can_speak(self,L):return self.universal_speak or L in self.languages
 def restrained(self):return self.bound
 def get_active_hand(self):return self.active
class Pen(Ref):
 def __init__(self,actor,colour='#ffffff',signature='Forged fixture'):
  self.loc=actor;self.colour=colour;self.signature=signature;self.gc_destroyed=False;self.kind='pen';actor.active=self
 def get_signature(self,actor):return self.signature
class Paper(Ref):
 def __init__(self,actor,legacy):
  self.__dict__.update(copy.deepcopy(legacy));self.loc=actor;self.gc_destroyed=False;self.document_record=None
 def Adjacent(self,actor):return True

def environment(bytes_mode=False):
 length=lambda v:len(v.encode('utf-8')) if bytes_mode and isinstance(v,str) else len(v)
 langs={k:Language(v) for k,v in IDS.items()};counter=[0]
 class Budget:
  def __init__(self):
   self.valid=True
   self.nodes_left=int(re.search(r'var/nodes_left = (\d+)',SOURCE)[1])
   self.units_left=int(re.search(r'var/units_left = (\d+)',SOURCE)[1])
 class RecordBudget(Budget):
  def __init__(self):
   super().__init__()
   self.nodes_left=int(re.search(r'^/datum/paper_document_budget/record\n\tnodes_left = (\d+)',SOURCE,re.M)[1])
 def copy_append(out,key):
  if isinstance(out,dict):out[key]=None
  else:out.append(key)
 def copy_assoc(out,key,value):
  if isinstance(out,dict):out[key]=value
 def istype(value,path=None):
  if path=='/mob/living/human':return isinstance(value,Actor) and value.kind=='human'
  if path=='/obj/item/weapon/pen/crayon':return isinstance(value,Pen) and value.kind=='crayon'
  if path in ('/obj/item/weapon/clipboard','/obj/item/weapon/folder'):return getattr(value,'kind',None)==path.rsplit('/',1)[-1]
  return False
 def mint(paper):counter[0]+=1;return hashlib.md5(('fixture-'+str(counter[0])).encode()).hexdigest()
 env=dict(__builtins__={},len=len,range=range,round=math.floor,isinstance=isinstance,dict=dict,length=length,isnull=lambda v:v is None,isnum=lambda v:isinstance(v,(int,float)),ispath=lambda v:isinstance(v,TypePath),istext=lambda v:isinstance(v,str) and not isinstance(v,TypePath),islist=lambda v:isinstance(v,(dict,list)),lowertext=lambda v:v.lower(),copytext=lambda v,a=1,b=None:v[a-1:None if b is None else b-1],text2ascii=lambda v,i=1:ord(v[i-1]),dm_text=lambda v:'' if v is None else str(v),MAX_PAPER_MESSAGE_LEN=MAXIMUM,
  is_actor=lambda v:isinstance(v,Actor),is_pen=lambda v:isinstance(v,Pen),is_living=lambda v:isinstance(v,Actor) and v.kind!='ghost',istype=istype,isturf=lambda v:getattr(v,'kind',None)=='turf',isghost=lambda v:getattr(v,'kind',None)=='ghost',json_encode=lambda v:json.dumps(v,separators=(',',':'),ensure_ascii=False),section_id=lambda v:'section-'+str(v['next_section']),copy_keys=lambda v:list(v) if isinstance(v,dict) else v,copy_value=lambda v,k:v[k] if isinstance(v,dict) else None,copy_append=copy_append,copy_assoc=copy_assoc,new_budget=Budget,stars=lambda v:'*'*len(v or ''),paper_document_mint_id=mint,paper_written_language_types=lambda:dict(IDS),all_languages={v.name:v for v in langs.values()},INNATE=64,SIGNLANG=8,NONVERBAL=4,HIVEMIND=16)
 env['new_record_budget']=RecordBudget
 env['paper_written_language']=project(LANG,'/proc/paper_written_language','language_id',env)
 env['paper_knows_written_language']=project(LANG,'/proc/paper_knows_written_language','actor,language_id',env)
 env['paper_written_language_choices']=project(LANG,'/proc/paper_written_language_choices','actor',env)
 env['paper_written_default_language']=project(LANG,'/proc/paper_written_default_language','actor',env)
 for name,args in [('copy','value,budget,depth=0'),('legacy_snapshot','P'),('keys','value,keys'),('ink','value'),('section_valid','section'),('record_valid','record')]:
  env['paper_document_'+name]=project(SOURCE,'/proc/paper_document_'+name,args,env)
 for name,args in [('prepare_edit','P'),('commit_edit','P,edit')]:
  env['paper_document_'+name]=project(SOURCE,'/proc/paper_document_'+name,args,env)
 class Service:
  def __init__(self,paper,actor):self.paper=paper;self.controller=actor;self.control_client=actor.client
 for name,args in [('has_access','self,actor,writing=False'),('can_mutate','self,actor,pen'),('initialize','self,actor,pen'),('append','self,actor,pen,document_id,revision,language_id,kind,value'),('project','self,reader,forceshow=False'),('canonical_copy','self,actor')]:
  setattr(Service,name,project(SOURCE,'/datum/paper_document_service/proc/'+name,args,env,True))
 return env,Service,langs

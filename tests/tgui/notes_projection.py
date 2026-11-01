"""Fail-closed projections of the actual DM parser. Not a DM interpreter.

Two text-index adapters exercise Unicode boundaries without asserting native
length/JSON parity. Unknown source statements fail instead of being ignored.
"""
from pathlib import Path
import re
ROOT=Path(__file__).resolve().parents[2]
SOURCE=(ROOT/'code/datums/character_notes_ui.dm').read_text(encoding='utf-8')

def body(source,signature):
 match=re.search('^'+re.escape(signature)+r'\n((?:\t[^\n]*\n|\n)*)',source,re.M)
 if not match:raise AssertionError('Missing source proc '+signature)
 return match.group(1)

class Budget:
 def __init__(self,units=None,nodes=None,depth=None):
  defaults={name:int(value) for name,value in re.findall(r'var/(units_left|nodes_left|max_depth) = (\d+)',SOURCE)}
  assert set(defaults)=={'units_left','nodes_left','max_depth'},'Missing source budgets'
  self.units_left=defaults['units_left'] if units is None else units
  self.nodes_left=defaults['nodes_left'] if nodes is None else nodes
  self.max_depth=defaults['max_depth'] if depth is None else depth

class Text:
 def __init__(self,bytes_mode=False):self.bytes_mode=bytes_mode
 def length(self,value):return len(value.encode('utf-8')) if self.bytes_mode else len(value)
 def copy(self,value,start=1,end=None):
  if self.bytes_mode:return value.encode('utf-8')[start-1:None if end is None else end-1].decode('utf-8')
  return value[start-1:None if end is None else end-1]
 def find(self,value,needle,start=1):
  if self.bytes_mode:return value.encode().find(needle.encode(),start-1)+1
  return value.find(needle,start-1)+1
 def ascii(self,value,start=1):
  rest=self.copy(value,start);return ord(rest[0]) if rest else 0

def project(source,signature,args,mapping,env):
 lines=['def projected('+args+'):']
 for raw in body(source,signature).splitlines():
  statement=raw.strip()
  if not statement or statement.startswith('//'):continue
  if statement not in mapping:raise AssertionError('Unprojected source statement: '+statement)
  lines.append('    '*(len(raw)-len(raw.lstrip('\t')))+mapping[statement])
 exec('\n'.join(lines),env)
 return env['projected']

def parser(source=SOURCE,bytes_mode=False):
 ops=Text(bytes_mode);env=dict(length=ops.length,copytext=ops.copy,findtext=ops.find,text2ascii=ops.ascii)
 entities={
  'var/cursor = 1':'cursor = 1',
  'while (cursor <= length(value))':'while cursor <= length(value):',
  'var/amp = findtext(value, "&", cursor)':'amp = findtext(value, "&", cursor)',
  'if (!amp)':'if not amp:', 'break':'break', 'continue':'continue',
  'cursor = amp + 1':'cursor = amp + 1', 'if (cursor > length(value))':'if cursor > length(value):',
  'var/first = text2ascii(value, cursor)':'first = text2ascii(value, cursor)',
  'if (first != 35 && !(first >= 65 && first <= 90) && !(first >= 97 && first <= 122))':'if first != 35 and not (65 <= first <= 90) and not (97 <= first <= 122):',
  'var/ending = findtext(value, ";", cursor)':'ending = findtext(value, ";", cursor)',
  'if (!ending || ending - cursor > 16)':'if not ending or ending - cursor > 16:',
  'return FALSE':'return False', 'return TRUE':'return True',
  'var/entity = copytext(value, cursor, ending)':'entity = copytext(value, cursor, ending)',
  'if (!(entity in list("amp", "lt", "gt", "quot", "apos", "AMP", "LT", "GT", "QUOT")))':"if entity not in ('amp','lt','gt','quot','apos','AMP','LT','GT','QUOT'):",
  'if (copytext(entity, 1, 2) != "#")':'if copytext(entity, 1, 2) != "#":',
  'var/digits = copytext(entity, 2)':'digits = copytext(entity, 2)',
  'if (!length(digits) || length(digits) > 7)':'if not length(digits) or length(digits) > 7:',
  'for (var/index = 1, index <= length(digits), index++)':'for index in range(1, length(digits) + 1):',
  'var/code = text2ascii(digits, index)':'code = text2ascii(digits, index)',
  'if (code < 48 || code > 57)':'if code < 48 or code > 57:',
  'var/point = text2num(digits)':'point = int(digits, 10)',
  'if (point <= 0 || point > 1114111 || (point >= 55296 && point <= 57343) || (point >= 127 && point <= 159))':'if point <= 0 or point > 1114111 or 55296 <= point <= 57343 or 127 <= point <= 159:',
  'if (point < 32 && point != 9 && point != 10 && point != 13)':'if point < 32 and point not in (9, 10, 13):',
  'cursor = ending + 1':'cursor = ending + 1',
 }
 safe=project(source,'/proc/character_notes_entities_safe(value)','value',entities,env.copy())
 mapping={
  'if (!istext(value) || !budget || length(value) > budget.units_left || strip_improper(value) != value)':"if not isinstance(value,str) or budget is None or length(value) > budget.units_left or value.startswith('\xffimproper'):",
  'return null':'return None', 'budget.units_left -= length(value)':'budget.units_left -= length(value)',
  'var/nul = ascii2text(0)':"nul = chr(0)", 'if (length(nul) && findtext(value, nul))':'if length(nul) and findtext(value,nul):',
  'for (var/control = 1, control <= 31, control++)':'for control in range(1,32):',
  'if (control != 9 && control != 10 && control != 13 && findtext(value, ascii2text(control)))':'if control not in (9,10,13) and findtext(value,chr(control)):',
  'if (findtext(value, ascii2text(127)))':'if findtext(value,chr(127)):',
  'var/list/runs = list()':'runs = []', 'var/list/tags = list()':'tags = []',
  'var/bold = 0':'bold = 0', 'var/italic = 0':'italic = 0', 'var/cursor = 1':'cursor = 1',
  'while (cursor <= length(value))':'while cursor <= length(value):',
  'var/opening = findtext(value, "<", cursor)':'opening = findtext(value,"<",cursor)',
  'if (!opening)':'if not opening:', 'opening = length(value) + 1':'opening = length(value)+1',
  'if (opening > cursor)':'if opening > cursor:', 'var/chunk = copytext(value, cursor, opening)':'chunk = copytext(value,cursor,opening)',
  'if (!character_notes_entities_safe(chunk) || budget.nodes_left <= 0)':'if not entities_safe(chunk) or budget.nodes_left <= 0:',
  'budget.nodes_left--':'budget.nodes_left -= 1',
  'runs += list(list("text" = chunk, "bold" = (bold > 0), "italic" = (italic > 0)))':"runs.append(dict(text=chunk,bold=bold>0,italic=italic>0))",
  'if (opening > length(value))':'if opening > length(value):', 'break':'break',
  'var/ending = findtext(value, ">", opening + 1)':'ending = findtext(value,">",opening+1)',
  'if (!ending)':'if not ending:', 'var/first = text2ascii(value, opening + 1)':'first = text2ascii(value,opening+1)',
  'if (!(first in list(66, 73, 98, 105, 47)))':'if first not in (66,73,98,105,47):',
  'var/tag = lowertext(trim(copytext(value, opening + 1, ending)))':'tag = copytext(value,opening+1,ending).strip().lower()',
  'if (tag == "br" || tag == "br/" || (copytext(tag, 1, 3) == "br" && trim(copytext(tag, 3)) == "/"))':'if tag in ("br","br/") or (copytext(tag,1,3)=="br" and copytext(tag,3).strip()=="/"):',
  'if (budget.nodes_left <= 0)':'if budget.nodes_left <= 0:',
  'runs += list(list("br" = TRUE))':'runs.append(dict(br=True))',
  'else if (tag == "b" || tag == "i")':'elif tag in ("b","i"):',
  'if (tags.len >= budget.max_depth)':'if len(tags) >= budget.max_depth:',
  'tags += tag':'tags.append(tag)', 'if (tag == "b")':'if tag == "b":',
  'bold++':'bold += 1', 'italic++':'italic += 1', 'else':'else:',
  'else if (tag == "/b" || tag == "/i")':'elif tag in ("/b","/i"):',
  'var/expected = copytext(tag, 2)':'expected = copytext(tag,2)',
  'if (!tags.len || tags[tags.len] != expected)':'if not tags or tags[-1] != expected:',
  'tags.Cut(tags.len, tags.len + 1)':'tags.pop()',
  'if (expected == "b")':'if expected == "b":', 'bold--':'bold -= 1', 'italic--':'italic -= 1',
  'cursor = ending + 1':'cursor = ending+1', 'if (tags.len)':'if tags:', 'return runs':'return runs',
 }
 environment=env.copy();environment['entities_safe']=safe
 return project(source,'/proc/character_notes_parse(value, datum/character_notes_budget/budget)','value,budget',mapping,environment)

def view(mind,discovery_snapshot,parse=None,budget=None):
 """Model projection, preserving ordered reads and aggregate structural budget."""
 parse=parse or parser();budget=budget or Budget()
 # Every producer statement is checked; the shape/projection below only models
 # existing scalar interpolation and list reads, never native object lifetime.
 expected={
  'var/datum/character_notes_budget/budget = new()','var/list/character_runs = character_notes_parse("[current.real_name]", budget)',
  'if (isnull(character_runs))','return null','var/list/sections = list()','for (var/title in notes)',
  'if (budget.nodes_left <= 0)','budget.nodes_left--','var/list/title_runs = character_notes_parse("[title]", budget)',
  'if (isnull(title_runs))','var/list/entries = list()','var/list/notelist = notes[title]','if (!islist(notelist))',
  'for (var/index = 1, index <= notelist.len, index++)','var/list/entry_runs = character_notes_parse("[notelist[index]]", budget)',
  'if (isnull(entry_runs))','entries += list(list("runs" = entry_runs))','sections += list(list("title" = title_runs, "entries" = entries))',
  'var/list/memory_runs = character_notes_parse(memory ? "[memory]" : "No memories stored.", budget)',
  'var/list/discovery_runs = character_notes_parse(discovery_snapshot, budget)','if (isnull(memory_runs) || isnull(discovery_runs))',
  'return list("character" = character_runs, "sections" = sections, "memory" = memory_runs, "discoveries" = discovery_runs)',
 }
 statements={line.strip() for line in body(SOURCE,'/datum/mind/proc/character_notes_ui_data(discovery_snapshot)').splitlines() if line.strip() and not line.strip().startswith('//')}
 if statements != expected:raise AssertionError('Producer projection changed: '+repr(statements ^ expected))
 character=parse(mind['character'],budget)
 if character is None:return None
 sections=[]
 for title,notelist in mind['notes'].items():
  if budget.nodes_left<=0:return None
  budget.nodes_left-=1;title_runs=parse(title,budget)
  if title_runs is None or not isinstance(notelist,list):return None
  entries=[]
  for entry in notelist:
   if budget.nodes_left<=0:return None
   budget.nodes_left-=1;runs=parse(entry,budget)
   if runs is None:return None
   entries.append(dict(runs=runs))
  sections.append(dict(title=title_runs,entries=entries))
 memory=parse(mind['memory'] if mind['memory'] else 'No memories stored.',budget);discoveries=parse(discovery_snapshot,budget)
 if memory is None or discoveries is None:return None
 return dict(character=character,sections=sections,memory=memory,discoveries=discoveries)

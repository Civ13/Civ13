"""Fail-closed projections of the actual DM parser. Not a DM interpreter.

Two text-index adapters exercise Unicode boundaries without asserting native
length/JSON parity. Unknown source statements fail instead of being ignored.
"""
from pathlib import Path
import re
ROOT=Path(__file__).resolve().parents[2]
SOURCE=(ROOT/'code/modules/1713/book_reader.dm').read_text(encoding='utf-8')

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
 safe=project(source,'/proc/book_page_entities(value)','value',entities,env.copy())

 common={
  'return null':'return None', 'return FALSE':'return False','return TRUE':'return True',
  'break':'break', 'continue':'continue','else':'else:',
  'var/cursor = 1':'cursor=1','cursor++':'cursor+=1',
  'while (cursor <= length(value))':'while cursor<=length(value):',
  'while (cursor <= length(tag))':'while cursor<=length(tag):',
  'if (!istext(value))':'if not isinstance(value,str):',
  'value = lowertext(value)':'value=value.lower()',
  'return value':'return value',
  'var/code = text2ascii(value, index)':'code=text2ascii(value,index)',
  'var/code = text2ascii(tag, index)':'code=text2ascii(tag,index)',
  'var/code = text2ascii(tag, cursor)':'code=text2ascii(tag,cursor)',
  'for (var/index = 1, index <= length(tag), index++)':'for index in range(1,length(tag)+1):',
  'if (code > 126 || (code < 32 && !book_page_space(code)))':'if code>126 or (code<32 and not space(code)):',
  'if (!((code >= 65 && code <= 90) || (code >= 97 && code <= 122)))':'if not (65<=code<=90 or 97<=code<=122):',
  'var/list/attributes = list()':'attributes={}', 'var/cursor = 5':'cursor=5',
  'if (!book_page_space(text2ascii(tag, cursor)))':'if not space(text2ascii(tag,cursor)):',
  'while (cursor <= length(tag) && book_page_space(text2ascii(tag, cursor)))':'while cursor<=length(tag) and space(text2ascii(tag,cursor)):',
  'if (cursor > length(tag))':'if cursor>length(tag):',
  'var/start = cursor':'start=cursor','start = cursor':'start=cursor',
  'var/attribute = lowertext(copytext(tag, start, cursor))':'attribute=copytext(tag,start,cursor).lower()',
  'if (!(attribute in list("face", "color")) || (attribute in attributes))':'if attribute not in ("face","color") or attribute in attributes:',
  'if (cursor > length(tag) || text2ascii(tag, cursor) != 61)':'if cursor>length(tag) or text2ascii(tag,cursor)!=61:',
  'var/quote = text2ascii(tag, cursor)':'quote=text2ascii(tag,cursor)', 'var/value':'value=None',
  'if (quote == 34 || quote == 39)':'if quote in (34,39):',
  'var/ending = findtext(tag, ascii2text(quote), cursor)':'ending=findtext(tag,chr(quote),cursor)',
  'if (!ending)':'if not ending:', 'value = copytext(tag, cursor, ending)':'value=copytext(tag,cursor,ending)',
  'cursor = ending + 1':'cursor=ending+1',
  'while (cursor <= length(tag) && !book_page_space(text2ascii(tag, cursor)))':'while cursor<=length(tag) and not space(text2ascii(tag,cursor)):',
  'value = copytext(tag, start, cursor)':'value=copytext(tag,start,cursor)',
  'var/parsed = attribute == "face" ? book_page_face(value) : book_page_ink(value)':'parsed=face(value) if attribute=="face" else ink(value)',
  'if (isnull(parsed))':'if parsed is None:', 'attributes[attribute] = parsed':'attributes[attribute]=parsed','return attributes':'return attributes',
 }
 # All branches of the small mapping procedures remain source checked.
 inkmap=dict(common,**{
  'switch (value)':'if True:',
  'if ("black")':'if value=="black":','return "#000000"':'return "#000000"',
  'if ("blue")':'if value=="blue":','return "#0000ff"':'return "#0000ff"',
  'if ("red")':'if value=="red":','return "#ff0000"':'return "#ff0000"',
  'if ("white")':'if value=="white":','return "#ffffff"':'return "#ffffff"',
  'if (length(value) != 7 || copytext(value, 1, 2) != "#")':'if length(value)!=7 or copytext(value,1,2)!="#":',
  'for (var/index = 2, index <= 7, index++)':'for index in range(2,8):',
  'if (!((code >= 48 && code <= 57) || (code >= 97 && code <= 102)))':'if not (48<=code<=57 or 97<=code<=102):',
 })
 ink=project(source,'/proc/book_page_ink(value)','value',inkmap,env.copy())
 face=project(source,'/proc/book_page_face(value)','value',dict(common,**{
  'if (value == "verdana")':'if value=="verdana":', 'return "verdana"':'return "verdana"',
  'if (value == "times new roman")':'if value=="times new roman":','return "times"':'return "times"',
 }),env.copy())
 space=project(source,'/proc/book_page_space(code)','code',{
  'return code == 32 || code == 9 || code == 10 || code == 13':'return code in (32,9,10,13)',
 },env.copy())
 e=dict(env,space=space,face=face,ink=ink)
 font=project(source,'/proc/book_page_font(tag)','tag',common,e)
 mapping=dict(common,**{
  'if (!istext(value) || !budget || length(value) > budget.units_left || strip_improper(value) != value)':"if not isinstance(value,str) or budget is None or length(value)>budget.units_left or value.startswith('\\xffimproper'):",
  'budget.units_left -= length(value)':'budget.units_left-=length(value)',
  'var/nul = ascii2text(0)':'nul=chr(0)', 'if (length(nul) && findtext(value, nul))':'if length(nul) and findtext(value,nul):',
  'for (var/control = 1, control <= 31, control++)':'for control in range(1,32):',
  'if (control != 9 && control != 10 && control != 13 && findtext(value, ascii2text(control)))':'if control not in (9,10,13) and findtext(value,chr(control)):',
  'if (findtext(value, ascii2text(127)))':'if findtext(value,chr(127)):',
  'var/list/runs = list()':'runs=[]','var/list/stack = list()':'stack=[]',
  'var/ink = "#000000"':'ink="#000000"','var/face = "times"':'face="times"',
  'var/bold = FALSE':'bold=False','var/italic = FALSE':'italic=False',
  'var/opening = findtext(value, "<", cursor)':'opening=findtext(value,"<",cursor)',
  'if (!opening)':'if not opening:','opening = length(value) + 1':'opening=length(value)+1',
  'if (opening > cursor)':'if opening>cursor:','var/chunk = copytext(value, cursor, opening)':'chunk=copytext(value,cursor,opening)',
  'if (!book_page_entities(chunk) || budget.nodes_left <= 0)':'if not entities(chunk) or budget.nodes_left<=0:',
  'budget.nodes_left--':'budget.nodes_left-=1',
  'runs += list(list("text" = chunk, "ink" = ink, "face" = face, "bold" = bold, "italic" = italic))':'runs.append(dict(text=chunk,ink=ink,face=face,bold=bold,italic=italic))',
  'if (opening > length(value))':'if opening>length(value):',
  'var/ending = findtext(value, ">", opening + 1)':'ending=findtext(value,">",opening+1)',
  'var/first = text2ascii(value, opening + 1)':'first=text2ascii(value,opening+1)',
  'if (!(first in list(66, 73, 70, 98, 105, 102, 47)))':'if first not in (66,73,70,98,105,102,47):',
  'var/tag = trim(copytext(value, opening + 1, ending))':'tag=copytext(value,opening+1,ending).strip()',
  'var/lower_tag = lowertext(tag)':'lower_tag=tag.lower()',
  'if (lower_tag == "br" || lower_tag == "br/" || (copytext(lower_tag, 1, 3) == "br" && trim(copytext(lower_tag, 3)) == "/"))':'if lower_tag in ("br","br/") or (copytext(lower_tag,1,3)=="br" and copytext(lower_tag,3).strip()=="/"):',
  'if (budget.nodes_left <= 0)':'if budget.nodes_left<=0:',
  'runs += list(list("br" = TRUE, "ink" = ink, "face" = face, "bold" = bold, "italic" = italic))':'runs.append(dict(br=True,ink=ink,face=face,bold=bold,italic=italic))',
  'else if (lower_tag == "b" || lower_tag == "i" || lower_tag == "font" || (copytext(lower_tag, 1, 5) == "font" && book_page_space(text2ascii(tag, 5))))':'elif lower_tag in ("b","i","font") or (copytext(lower_tag,1,5)=="font" and space(text2ascii(tag,5))):',
  'if (stack.len >= budget.max_depth || budget.nodes_left <= 0)':'if len(stack)>=budget.max_depth or budget.nodes_left<=0:',
  'var/kind = copytext(lower_tag, 1, 5) == "font" ? "font" : lower_tag':'kind="font" if copytext(lower_tag,1,5)=="font" else lower_tag',
  'stack += list(list("tag" = kind, "ink" = ink, "face" = face, "bold" = bold, "italic" = italic))':'stack.append(dict(tag=kind,ink=ink,face=face,bold=bold,italic=italic))',
  'if (kind == "b")':'if kind=="b":','bold = TRUE':'bold=True',
  'else if (kind == "i")':'elif kind=="i":','italic = TRUE':'italic=True',
  'var/list/attributes = book_page_font(tag)':'attributes=font(tag)',
  'if (isnull(attributes))':'if attributes is None:',
  'if (attributes["color"])':'if attributes.get("color"):', 'ink = attributes["color"]':'ink=attributes["color"]',
  'if (attributes["face"])':'if attributes.get("face"):', 'face = attributes["face"]':'face=attributes["face"]',
  'else if (lower_tag == "/b" || lower_tag == "/i" || lower_tag == "/font")':'elif lower_tag in ("/b","/i","/font"):',
  'if (!stack.len)':'if not stack:', 'var/list/prior = stack[stack.len]':'prior=stack[-1]',
  'if (prior["tag"] != copytext(lower_tag, 2))':'if prior["tag"]!=copytext(lower_tag,2):',
  'ink = prior["ink"]':'ink=prior["ink"]','face = prior["face"]':'face=prior["face"]',
  'bold = prior["bold"]':'bold=prior["bold"]','italic = prior["italic"]':'italic=prior["italic"]',
  'stack.Cut(stack.len, stack.len + 1)':'stack.pop()',
  'if (stack.len)':'if stack:','return runs':'return runs',
 })
 parse=project(source,'/proc/book_page_parse(value, datum/book_page_budget/budget)','value,budget',mapping,dict(env,entities=safe,font=font,space=space))
 metadata=project(source,'/proc/book_page_metadata(value)','value',dict(common,**{
  'if (!istext(value) || length(value) > 256 || strip_improper(value) != value || findtext(value, "<") || findtext(value, "&"))':"if not isinstance(value,str) or length(value)>256 or value.startswith('\\xffimproper') or findtext(value,'<') or findtext(value,'&'):",
  'for (var/control = 1, control <= 31, control++)':'for control in range(1,32):',
  'if (findtext(value, ascii2text(control)))':'if findtext(value,chr(control)):',
  'var/nul = ascii2text(0)':'nul=chr(0)',
  'return !(length(nul) && findtext(value, nul)) && !findtext(value, ascii2text(127))':'return not(length(nul) and findtext(value,nul)) and not findtext(value,chr(127))',
 }),env.copy())
 return parse,font,metadata

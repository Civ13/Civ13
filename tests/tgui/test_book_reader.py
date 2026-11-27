"""Source-derived offline projections only; no native DM/client execution."""
from pathlib import Path
import json,re,unittest
import reader_base
from book_projection import SOURCE,ROOT,Budget,body,parser,project

BOOK=(ROOT/'code/modules/1713/book.dm').read_text(encoding='utf-8')
SIGNATURE='/obj/item/weapon/book/proc/show_content(var/mob/user, var/forceshow=0)'
SHOW=body(BOOK,SIGNATURE)
FIXTURE=ROOT/'tests/tgui/fixtures/book-page.json'

class BookReaderContract(unittest.TestCase):
 def test_use_dispatches_picture_only_books_through_examine(self):
  attack=body(BOOK,'/obj/item/weapon/book/attack_self(var/mob/user as mob)')
  match=re.fullmatch(
   r'\s*if \((?P<gate>[^\n]+)\)\n\t\tuser\.examinate\(src\)\n\t\treturn'
   r'\n\telse\n\t\tto_chat\(user, SPAN_WARNING\("This book is completely blank!"\)\)\s*',attack)
  self.assertIsNotNone(match)
  gates={'dat':lambda dat,drawings:bool(dat),
         'dat || length(drawings)':lambda dat,drawings:bool(dat or drawings)}
  self.assertIn(match['gate'],gates)
  gate=gates[match['gate']]
  for dat,drawings,expected in [
   (None,None,False),('',[],False),('Text',None,True),
   (None,[{'title':'Ink Hills'}],True),('Text',[{'title':'Ink Hills'}],True),
  ]:
   with self.subTest(dat=dat,drawings=drawings):
    self.assertEqual(gate(dat,drawings),expected)
  self.assertIn('show_drawings(user)',SHOW)
 def test_actual_parser_default_and_shared_browser_fixture(self):
  sample=json.loads(FIXTURE.read_text())
  for byte_mode in (False,True):
   parse,_,_=parser(bytes_mode=byte_mode)
   self.assertEqual(parse(sample['html'],Budget()),sample['runs'])
   self.assertEqual(parse('Plain',Budget()),[dict(text='Plain',ink='#000000',face='times',bold=False,italic=False)])
 def test_nested_ink_and_signature_inheritance_and_restore(self):
  parse,_,_=parser()
  value='<font face="Verdana" color=white>A<font face="Times New Roman"><i>Signed</i></font><font color=black>B</font>C</font>D'
  runs=parse(value,Budget())
  self.assertEqual([r['ink'] for r in runs],['#ffffff','#ffffff','#000000','#ffffff','#000000'])
  self.assertEqual([r['face'] for r in runs],['verdana','times','verdana','verdana','times'])
  self.assertTrue(runs[1]['italic']);self.assertFalse(runs[2]['italic'])
 def test_attributes_are_explicit_and_fail_closed(self):
  _,font,_=parser()
  self.assertEqual(font('FONT FACE = "Verdana" COLOR=\'#Ab12Ef\''),dict(face='verdana',color='#ab12ef'))
  self.assertEqual(font('font'),{})
  for tag in ['font color=white color=black','font COLOR=red color=blue','font face=Verdana size=4','font style="color:white"','font color=#fff','font color=transparent','font color=currentColor','font color=rgb(0,0,0)','font color=expression(x)','font color=white/','font face=Arial','font face="Verdana','font face="Verdana"color=red','font face','font color=','font face="Verdana "','font cölör=white','font color="white" x=y']:
   with self.subTest(tag=tag):self.assertIsNone(font(tag))
 def test_unsupported_subtree_never_returns_a_prefix(self):
  parse,_,_=parser()
  for invalid in ['<u>x</u>','<center>x</center>','<table>x</table>','<font size=3>x</font>','<img src=x>','<b><i>x</b></i>','<b>x','x</b>','x<font color=white','<script>x</script>','<!--x-->','<b title=x>x</b>','<br title=x>','&unknown;','&#x41;','&#0;','&#55296;','x\x00','x\x01']:
   with self.subTest(value=invalid):self.assertIsNone(parse('Before'+invalid+'After',Budget()))
 def test_complete_budget_and_unicode_boundaries(self):
  for byte_mode in (False,True):
   parse,_,_=parser(bytes_mode=byte_mode)
   self.assertEqual(parse('🚢 café',Budget())[0]['text'],'🚢 café')
   self.assertIsNone(parse('🚢'*65537,Budget()))
   self.assertIsNone(parse('<b>'*33+'x'+'</b>'*33,Budget()))
   self.assertIsNone(parse('A<br>B',Budget(nodes=2)))
   self.assertIsNone(parse('A<font>B</font>',Budget(nodes=2)))
   self.assertIsNotNone(parse('A<br>B',Budget(nodes=3)))
 def test_bare_page_divider_keeps_ink_order_and_uses_the_node_budget(self):
  writer=(ROOT/'code/modules/research_tree/book_pages.dm').read_text()
  self.assertIn('"<hr>"',writer)
  value='<font color=white>First</font><hr><font color=black>Second</font>'
  for byte_mode in (False,True):
   parse,_,_=parser(bytes_mode=byte_mode)
   runs=parse(value,Budget())
   self.assertEqual(runs,[dict(text='First',ink='#ffffff',face='times',bold=False,italic=False),
                          dict(divider=True),
                          dict(text='Second',ink='#000000',face='times',bold=False,italic=False)])
   self.assertIsNone(parse('A<hr>B',Budget(nodes=2)))
   self.assertIsNotNone(parse('A<hr>B',Budget(nodes=3)))
   for unsupported in ('<hr title=label>','<b><hr></b>','<hr/>','<hr><u>Later</u>'):
    self.assertIsNone(parse('Earlier'+unsupported,Budget()))
 def test_metadata_rejects_whole_view(self):
  _,_,metadata=parser()
  self.assertTrue(metadata('Ordinary title'))
  for invalid in ['<b>title</b>','A&amp;B','x'*257,'x\x00','x\n','x\x7f']:
   self.assertFalse(metadata(invalid))
  producer=body(SOURCE,'/obj/item/weapon/book/proc/present_book_reader(mob/reader, legacy_snapshot, visible_snapshot, title_snapshot, name_snapshot)')
  self.assertIn('if (book_page_metadata(title_snapshot) && book_page_metadata(name_snapshot))',producer)
  self.assertIn('budget.units_left -= length(title_snapshot) + length(name_snapshot)',producer)
  self.assertIn('ui.legacy_snapshot = legacy_snapshot',producer)
  self.assertIn('if (isnull(runs))\n\t\tui.plain_page = TRUE',producer)
  self.assertNotIn('plain_page = FALSE',producer)
 def test_admission_and_single_authorized_snapshot(self):
  mapping={
   'var/display_snapshot':'display_snapshot=None',
   'if (!(istype(user, /mob/living/human) || isghost(user) && !forceshow))':'if not (human or ghost and not forceshow):',
   'display_snapshot = stars(dat)':'display_snapshot=stars(dat)', 'else':'else:', 'display_snapshot = dat':'display_snapshot=dat',
   '// Optional sealed notes never enter dat, normal pages or copying APIs.':'# Optional server-authorized projection',
   'if (hascall(src, "divine_journal_html"))':'if has_journal:',
   'display_snapshot += call(src, "divine_journal_html")(user)':'display_snapshot += journal()',
  }
  selection=SHOW[:SHOW.index('\tvar/legacy_snapshot')]
  # Execute all actual selection statements; unknown statements fail closed.
  for human,ghost,force,full in [(1,0,0,1),(1,0,1,1),(0,1,0,1),(0,1,1,0),(0,0,0,0),(0,0,1,0)]:
   lines=['def choose():']
   for raw in selection.splitlines():
    if not raw.strip():continue
    self.assertIn(raw.strip(),mapping)
    lines.append('    '*(len(raw)-len(raw.lstrip('\t')))+mapping[raw.strip()])
   lines.append('    return display_snapshot')
   calls=[];env=dict(human=human,ghost=ghost,forceshow=force,dat='SECRET',stars=lambda v:calls.append(v) or '******',has_journal=True,journal=lambda:'')
   exec('\n'.join(lines),env);self.assertEqual(env['choose'](),'SECRET' if full else '******')
   self.assertEqual(len(calls),0 if full else 1)
   # Missing hook preserves old fixtures; a permitted projection uses the same
   # one snapshot passed to both renderers, never the public dat field.
   env['has_journal']=False
   self.assertEqual(env['choose'](),'SECRET' if full else '******')
   if human:
    env['has_journal']=True;env['journal']=lambda:'<p>SEALED</p>'
    self.assertEqual(env['choose'](),'SECRET<p>SEALED</p>')
    self.assertEqual(env['dat'],'SECRET')
  self.assertEqual(SHOW.count('stars(dat)'),1)
  self.assertIn('<BODY>[display_snapshot]</BODY>',SHOW)
  self.assertIn('(user, legacy_snapshot, "[display_snapshot]", "[title]", "[name]")',SHOW)
  self.assertNotIn('parse(dat',SHOW)
 def test_original_reader_contract_and_classic_window_retained(self):
  legacy=(ROOT/'tests/tgui/fixtures/book-legacy-show.dm.txt').read_text()
  self.assertIn('istype(user, /mob/living/human) || isghost(user) && !forceshow',legacy)
  self.assertIn('show_browse(user, legacy_snapshot, "window=[name]")',SHOW)
  self.assertIn('onclose(user, "[name]")',SHOW)
  writer=body(BOOK,'/obj/item/weapon/book/proc/parsepencode(var/t, var/obj/item/weapon/pen/P, mob/user as mob)')
  self.assertIn('color=[P ? P.colour : "black"]',writer)
  self.assertIn('[get_signature(P, user)]',writer)
 def test_detached_owner_lifecycle_and_close_noninterference(self):
  state=reader_base.STATE
  for token in ['!user.client','!subject','src_object != subject','user != reader','reader_allowed(user)','return STATUS_CLOSE']:
   self.assertIn(token,state)
  self.assertEqual(reader_base.rule(SOURCE,'book_reader'),'user.client == reader_client')
  self.assertNotIn('in_range',state);self.assertNotIn('ishuman',state)
  self.assertIn('fixed_classic_page = TRUE',SOURCE.split('/datum/nanoui/tgui/snapshot/book_reader\n',1)[1])
  update=reader_base.UPDATE
  self.assertIn('push_data(null, TRUE)',update);self.assertNotIn('dat',update.replace('push_data','').replace('update_status',''))
  self.assertIn('ui.use_on_close_logic(FALSE)',SOURCE)
  self.assertNotIn('using_object =',SOURCE)
  close=body(reader_base.BASE,'/datum/nanoui/tgui/snapshot/close()')
  self.assertLess(close.index('reader_closed = TRUE'),close.index('return ..()'))
  self.assertIn('legacy_snapshot = null',close)
  self.assertIn('if (reader_closed)\n\t\treturn',close)
  get_html=body(reader_base.BASE,'/datum/nanoui/tgui/snapshot/get_html()')
  self.assertIn('can_use_topic',get_html)
  self.assertIn('return legacy_snapshot',get_html)
  self.assertLess(get_html.index('can_use_topic'),get_html.index('return legacy_snapshot'))
 def test_projection_refuses_unmapped_source_changes(self):
  with self.assertRaisesRegex(AssertionError,'Unprojected'):
   parser(SOURCE.replace('var/cursor = 5','var/cursor = 6'))
 def test_projected_lease_rejects_logout_transfer_and_wrong_book(self):
  # The shared guard binds book and body; the book adds that the connection is the one that opened it.
  rule=reader_base.rule(SOURCE,'book_reader');self.assertEqual(rule,'user.client == reader_client')
  class Reader:
   def __init__(self,client):self.client=client
  book=object();linked_client=object();reader=Reader(linked_client)
  def closed(user,source=book,live_book=book):
   same=bool(user) and eval(rule.replace(' == ',' is '),{'__builtins__':{}},dict(user=user,reader_client=linked_client))
   return not reader_base.allowed(live_book,source,user,reader,connected=bool(user and user.client),rule=same)
  self.assertFalse(closed(reader)) # Same owner remains admitted, with no distance/type seam.
  self.assertTrue(closed(None));self.assertTrue(closed(reader,object()));self.assertTrue(closed(reader,live_book=None))
  self.assertTrue(closed(Reader(linked_client))) # Transfer to another body.
  reader.client=None;self.assertTrue(closed(reader)) # Logout.
  reader.client=object();self.assertTrue(closed(reader)) # New client cannot reuse old lease.
 def test_registration_and_inert_presentation(self):
  self.assertIn('#include "code\\modules\\1713\\book_reader.dm"',(ROOT/'civ13.dme').read_text())
  self.assertIn("'book_reader.tmpl': BookReader",(ROOT/'tgui/src/interfaces/index.tsx').read_text())
  frontend=(ROOT/'tgui/src/interfaces/BookReader.tsx').read_text()
  for forbidden in ['dangerouslySetInnerHTML','aria-label=','title=','textContent =','innerHTML','text-shadow:','clipboard','onCopy','onSelect']:
   self.assertNotIn(forbidden,frontend)
  self.assertIn("backgroundColor: '#FFFFFF'",frontend)
  self.assertIn("WebkitTextFillColor: run.ink",frontend)
  self.assertIn("userSelect: 'text'",frontend)
  self.assertIn('subtree: true, childList: true, attributes: true',frontend)
  self.assertIn('const resize = new ResizeObserver(verify)',frontend)
  self.assertNotIn('book_reader.tmpl',(ROOT/'code/modules/nano/tgui.dm').read_text().split('/datum/nanoui/tgui/proc/allowed_actions()',1)[1].split('/datum/nanoui/tgui/Topic',1)[0])

if __name__=='__main__':unittest.main()

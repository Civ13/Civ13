"""Source-derived offline projections only; no native DM/client execution."""
from pathlib import Path
import json,re,unittest
from book_projection import SOURCE,ROOT,Budget,body,parser,project

BOOK=(ROOT/'code/modules/1713/book.dm').read_text(encoding='utf-8')
SIGNATURE='/obj/item/weapon/book/proc/show_content(var/mob/user, var/forceshow=0)'
SHOW=body(BOOK,SIGNATURE)
FIXTURE=ROOT/'tests/tgui/fixtures/book-page.json'

class BookReaderContract(unittest.TestCase):
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
 def test_metadata_rejects_whole_view(self):
  _,_,metadata=parser()
  self.assertTrue(metadata('Ordinary title'))
  for invalid in ['<b>title</b>','A&amp;B','x'*257,'x\x00','x\n','x\x7f']:
   self.assertFalse(metadata(invalid))
  producer=body(SOURCE,'/obj/item/weapon/book/proc/present_book_reader(mob/reader, legacy_snapshot, visible_snapshot, title_snapshot, name_snapshot)')
  self.assertIn('if (book_page_metadata(title_snapshot) && book_page_metadata(name_snapshot))',producer)
  self.assertIn('budget.units_left -= length(title_snapshot) + length(name_snapshot)',producer)
  self.assertIn('ui.legacy_snapshot = legacy_snapshot',producer)
  self.assertIn('if (isnull(runs))\n\t\tui.legacy_renderer = TRUE',producer)
  self.assertNotIn('legacy_renderer = FALSE',producer)
 def test_admission_and_single_authorized_snapshot(self):
  mapping={
   'var/display_snapshot':'display_snapshot=None',
   'if (!(istype(user, /mob/living/human) || isghost(user) && !forceshow))':'if not (human or ghost and not forceshow):',
   'display_snapshot = stars(dat)':'display_snapshot=stars(dat)', 'else':'else:', 'display_snapshot = dat':'display_snapshot=dat',
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
   calls=[];env=dict(human=human,ghost=ghost,forceshow=force,dat='SECRET',stars=lambda v:calls.append(v) or '******')
   exec('\n'.join(lines),env);self.assertEqual(env['choose'](),'SECRET' if full else '******')
   self.assertEqual(len(calls),0 if full else 1)
  self.assertEqual(SHOW.count('stars(dat)'),1)
  self.assertIn('<BODY>[display_snapshot]</BODY>',SHOW)
  self.assertIn('(user, legacy_snapshot, "[display_snapshot]", "[title]", "[name]")',SHOW)
  self.assertNotIn('parse(dat',SHOW)
 def test_original_reader_contract_and_classic_window_retained(self):
  legacy=(ROOT/'tests/tgui/fixtures/book-legacy-show.dm.txt').read_text()
  self.assertIn('istype(user, /mob/living/human) || isghost(user) && !forceshow',legacy)
  self.assertIn('user << browse(legacy_snapshot, "window=[name]")',SHOW)
  self.assertIn('onclose(user, "[name]")',SHOW)
  writer=body(BOOK,'/obj/item/weapon/book/proc/parsepencode(var/t, var/obj/item/weapon/pen/P, mob/user as mob)')
  self.assertIn('color=[P ? P.colour : "black"]',writer)
  self.assertIn('[get_signature(P, user)]',writer)
 def test_detached_owner_lifecycle_and_close_noninterference(self):
  state=body(SOURCE,'/datum/topic_state/book_reader/can_use_topic(var/src_object, var/mob/user)')
  for token in ['!user.client','!book','src_object != book','user != reader','user.client != reader_client','return STATUS_CLOSE','return STATUS_UPDATE']:
   self.assertIn(token,state)
  self.assertNotIn('in_range',state);self.assertNotIn('ishuman',state)
  update=body(SOURCE,'/datum/nanoui/tgui/book_reader/update(var/force_open = FALSE)')
  self.assertIn('push_data(null, TRUE)',update);self.assertNotIn('dat',update.replace('push_data','').replace('update_status',''))
  self.assertIn('ui.use_on_close_logic(FALSE)',SOURCE)
  self.assertNotIn('using_object =',SOURCE)
  close=body(SOURCE,'/datum/nanoui/tgui/book_reader/close()')
  self.assertLess(close.index('reader_closed = TRUE'),close.index('return ..()'))
  self.assertIn('legacy_snapshot = null',close)
  self.assertIn('if (reader_closed)\n\t\treturn',close)
  get_html=body(SOURCE,'/datum/nanoui/tgui/book_reader/get_html()')
  self.assertIn('can_use_topic',get_html)
  self.assertIn('return legacy_snapshot',get_html)
  self.assertLess(get_html.index('can_use_topic'),get_html.index('return legacy_snapshot'))
 def test_projection_refuses_unmapped_source_changes(self):
  with self.assertRaisesRegex(AssertionError,'Unprojected'):
   parser(SOURCE.replace('var/cursor = 5','var/cursor = 6'))
 def test_projected_lease_rejects_logout_transfer_and_wrong_book(self):
  state=body(SOURCE,'/datum/topic_state/book_reader/can_use_topic(var/src_object, var/mob/user)')
  condition=re.search(r'if \((.+)\)',state)[1]
  expression=re.sub(r'!(?!=)','not ',condition.replace('||','or'))
  class Reader:
   def __init__(self,client):self.client=client
  book=object();linked_client=object();reader=Reader(linked_client)
  def closed(user,source=book,live_book=book):
   return bool(eval(expression,{'__builtins__':{}},dict(user=user,src_object=source,book=live_book,reader=reader,reader_client=linked_client)))
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

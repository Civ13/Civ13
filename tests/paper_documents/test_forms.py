"""Form fields (labelled blanks and their answers) through the real authoring,
record validation, projection and classic renderer bodies. Not native DM.
"""
import copy,importlib.util,json,unittest
from pathlib import Path
spec=importlib.util.spec_from_file_location('forms_authoring_fixture',Path(__file__).with_name('test_authoring.py'))
authoring=importlib.util.module_from_spec(spec);spec.loader.exec_module(authoring)
spec=importlib.util.spec_from_file_location('forms_editor_fixture',Path(__file__).with_name('test_editor.py'))
editor=importlib.util.module_from_spec(spec);spec.loader.exec_module(editor)
vm=authoring.vm;EN=authoring.EN;RU=authoring.RU
TSX=(vm.ROOT/'tgui/src/interfaces/PaperEditor.tsx').read_text(encoding='utf-8')

class Forms(authoring.Authoring):
 # Reuse the authoring fixture; only the tests below run in this class.
 def labelled(self,caption='Name'):
  self.start();self.assertTrue(self.write(caption,kind='field_label'))
  return self.paper.document_record['sections'][-1]['id']
 def answer(self,target,text='Ada',language=EN):
  return self.write(text,language,'field_answer',target=target)
 def test_label_then_answer_fills_the_blank_once(self):
  label=self.labelled();space=self.paper.free_space
  self.assertTrue(self.answer(label))
  record=self.paper.document_record;answer=record['sections'][-1]
  self.assertEqual((answer['kind'],answer['target'],answer['text']),('field_answer',label,'Ada'))
  self.assertEqual(self.paper.free_space,space-3);self.assertTrue(self.env['paper_document_record_valid'](record))
  before=self.state();self.assertFalse(self.answer(label,'Second'));self.assertEqual(self.state(),before)
 def test_answers_need_an_existing_open_label(self):
  self.start();self.assertTrue(self.write('Body text'))
  body=self.paper.document_record['sections'][-1]['id'];before=self.state()
  for target in (None,'',body,'section-99',7):
   with self.subTest(target=target):self.assertFalse(self.answer(target));self.assertEqual(self.state(),before)
 def test_first_write_cannot_be_an_answer_and_other_kinds_take_no_target(self):
  self.start();before=self.state()
  self.assertFalse(self.answer('section-1'));self.assertEqual(self.state(),before)
  self.assertFalse(self.write('Body',target='section-1'));self.assertEqual(self.state(),before)
 def test_labels_are_short_and_language_checked(self):
  self.start();before=self.state()
  self.assertFalse(self.write('x'*129,kind='field_label'));self.assertEqual(self.state(),before)
  self.assertTrue(self.write('x'*128,kind='field_label'))
  label=self.paper.document_record['sections'][-1]['id']
  self.assertFalse(self.answer(label,language='civ13:notreal:v1'))
 def test_record_validation_rejects_bad_targets(self):
  label=self.labelled();self.assertTrue(self.answer(label))
  valid=self.env['paper_document_record_valid']
  for change in ('missing','dangling','duplicate','on_body','forward'):
   with self.subTest(change=change):
    record=copy.deepcopy(self.paper.document_record);sections=record['sections'];answer=sections[-1]
    if change=='missing':del answer['target']
    elif change=='dangling':answer['target']='nowhere'
    elif change=='duplicate':sections.append(dict(answer,id='extra'))
    elif change=='on_body':sections[0]['target']=label
    elif change=='forward':sections.reverse()
    self.assertFalse(valid(record))
 def test_unknown_language_answer_keeps_target_but_not_text(self):
  label=self.labelled();self.assertTrue(self.answer(label,'SECRET_ANSWER',RU))
  self.actor.languages=[self.langs[EN]]
  view=self.session.snapshot(self.actor)['view']
  self.assertNotIn('SECRET_ANSWER',json.dumps(view))
  answer=view['sections'][-1];self.assertEqual(answer['target'],label);self.assertEqual(answer['text'],'[Unintelligible writing]')
  self.assertNotIn('target',view['sections'][0])
 def test_classic_reader_draws_answers_on_their_label_line(self):
  label=self.labelled('Name')
  self.assertTrue(self.write('Rank',kind='field_label'))
  self.assertTrue(self.answer(label,'Ada <b>'))
  html=self.render(self.session.projection_reader.project(self.actor),self.paper)
  self.assertIn('Name</font>: <u><font face="Verdana" color="#ffffff">Ada &lt;b&gt;</font></u>',html)
  self.assertIn('Rank</font>: <u>&nbsp;',html)
  self.assertEqual(html.count('Ada &lt;b&gt;'),1)

class EditorRequests(editor.Editor):
 def test_decoder_accepts_target_only_for_answers(self):
  decode=self.env['paper_editor_request']
  good=dict(self.request(),kind='field_answer',target='section-1')
  self.assertEqual(decode(json.dumps(good)),good)
  label=dict(self.request(),kind='field_label');self.assertEqual(decode(json.dumps(label)),label)
  for bad in (dict(good,target=''),dict(good,target=3),dict(good,target='x'*65),dict(self.request(),target='section-1'),dict(self.request(),kind='field_answer')):
   with self.subTest(bad=bad):self.assertIsNone(decode(json.dumps(bad)))

def load_tests(loader,tests,pattern):
 suite=unittest.TestSuite()
 for case in (Forms,EditorRequests,Sources):
  for name in loader.getTestCaseNames(case):
   if name.startswith('test_') and name in case.__dict__:suite.addTest(case(name))
 return suite

class Sources(unittest.TestCase):
 def test_editor_offers_blanks_and_filling(self):
  for needle in ("'field_label'","'field_answer'",'target'):self.assertIn(needle,TSX)

if __name__=='__main__':unittest.main()

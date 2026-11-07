"""Offline projection tests for deliberate paper study; not native DM."""
import importlib.util,json,re,unittest
from pathlib import Path
spec=importlib.util.spec_from_file_location('paper_document_projection',Path(__file__).with_name('projection.py'))
projection=importlib.util.module_from_spec(spec);spec.loader.exec_module(projection)
STUDY=(projection.ROOT/'code/modules/paperwork/study.dm').read_text(encoding='utf-8')
LEGACY=json.loads((Path(__file__).parent/'fixtures/legacy.json').read_text(encoding='utf-8'))
EN='civ13:english:v1';RU='civ13:russian:v1';LA='civ13:latin:v1'

class Study(unittest.TestCase):
 def setUp(self):
  self.env,Service,self.languages=projection.environment()
  self.env.update(max=max,min=min)
  for name,value in re.findall(r'#define (PAPER_STUDY_\w+) (\d+)',STUDY):self.env[name]=int(value)
  self.candidate=projection.project(STUDY,'/proc/paper_study_candidate','reader,record,studied',self.env)
  self.points=projection.project(STUDY,'/proc/paper_study_points','text',self.env)
  self.writer=projection.Actor();self.writer.languages=[self.languages[EN],self.languages[RU]]
  self.reader=projection.Actor();self.reader.languages=[self.languages[EN]]
  self.pen=projection.Pen(self.writer);self.paper=projection.Paper(self.writer,LEGACY);self.service=Service(self.paper,self.writer)
  self.assertTrue(self.service.initialize(self.writer,self.pen))
 def append(self,language,text):
  record=self.paper.document_record
  self.assertTrue(self.service.append(self.writer,self.pen,record['document_id'],record['revision'],language,'body',text))
  return self.paper.document_record['sections'][-1]
 def test_only_unknown_languages_are_studied(self):
  self.append(EN,'Hello there')
  self.assertIsNone(self.candidate(self.reader,self.paper.document_record,None))
  russian=self.append(RU,'Privet')
  self.assertEqual(self.candidate(self.reader,self.paper.document_record,None)['lineage'],russian['lineage'])
  self.reader.languages.append(self.languages[RU])
  self.assertIsNone(self.candidate(self.reader,self.paper.document_record,None))
 def test_each_section_version_is_credited_once(self):
  first=self.append(RU,'Privet');second=self.append(RU,'Do svidaniya')
  studied={first['lineage']:first['version']}
  self.assertEqual(self.candidate(self.reader,self.paper.document_record,studied)['lineage'],second['lineage'])
  studied[second['lineage']]=second['version']
  self.assertIsNone(self.candidate(self.reader,self.paper.document_record,studied))
  # An edit bumps the version, which can be studied again; older copies cannot.
  second['version']+=1
  self.assertEqual(self.candidate(self.reader,self.paper.document_record,studied)['lineage'],second['lineage'])
  studied[second['lineage']]=5
  self.assertIsNone(self.candidate(self.reader,self.paper.document_record,studied))
 def test_invalid_records_offer_nothing(self):
  self.assertIsNone(self.candidate(self.reader,None,None))
  self.assertIsNone(self.candidate(self.reader,{'sections':[]},None))
 def test_points_scale_with_length_and_are_bounded(self):
  self.assertEqual(self.points(''),1)
  self.assertEqual(self.points('x'*80),10)
  self.assertEqual(self.points('x'*10000),self.env['PAPER_STUDY_MAX_POINTS'])

if __name__=='__main__':unittest.main()

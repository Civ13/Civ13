"""Synthetic event XML only: no event-log access, native APIs or process launch."""
from datetime import timedelta
from pathlib import Path
import json
import unittest
import xml.etree.ElementTree as ET
from owned_crash import NS, EPOCH, binding, collect, hex_forms, parse_event, query_for

IDENTITY = {'pid':7656,'creation_filetime':134373776192282305,
            'image':r'D:\a\_temp\bakery-engine\byond\bin\dreamseeker.exe'}
CODE = 0xc0000005
BORN = EPOCH+timedelta(microseconds=IDENTITY['creation_filetime']//10)
UNTIL = BORN+timedelta(seconds=5)


def event(changes=None, stamp=None, provider='Application Error', event_id='1000'):
    values = {'AppPath':IDENTITY['image'],'ProcessId':hex(IDENTITY['pid']),
              'ProcessCreationTime':hex(IDENTITY['creation_filetime']),'ExceptionCode':'c0000005',
              'FaultingOffset':'0000000000123456','ModuleName':'byondwin.dll',
              'ModulePath':r'D:\private\unretained.dll','IntegratorReportId':'not-retained'}
    values.update(changes or {})
    root = ET.Element(NS+'Event'); system = ET.SubElement(root,NS+'System')
    ET.SubElement(system,NS+'Provider',Name=provider)
    ET.SubElement(system,NS+'EventID').text=event_id
    ET.SubElement(system,NS+'Channel').text='Application'
    ET.SubElement(system,NS+'TimeCreated',SystemTime=(stamp or UNTIL).isoformat())
    ET.SubElement(system,NS+'Computer').text='must-not-retain'
    ET.SubElement(system,NS+'Execution',ProcessID='9999')
    data = ET.SubElement(root,NS+'EventData')
    for k,v in values.items(): ET.SubElement(data,NS+'Data',Name=k).text=v
    return ET.tostring(root,encoding='unicode')


class Clock:
    value=0
    def read(self): return self.value
    def sleep(self,seconds): self.value+=seconds


class OwnedCrash(unittest.TestCase):
    def test_query_is_os_filtered_by_full_owned_identity_and_time(self):
        text=query_for(IDENTITY,CODE,UNTIL); tree=ET.fromstring(text)
        self.assertEqual(tree.find('Query').get('Path'),'Application')
        x=tree.find('Query/Select').text
        for token in ('Application Error','EventID=1000',"Data[@Name='ProcessId']", "Data[@Name='ProcessCreationTime']", "Data[@Name='AppPath']",IDENTITY['image'],"TimeCreated[@SystemTime >=",'and @SystemTime <='):
            self.assertIn(token,x)
        self.assertNotIn('Execution',x)
        self.assertIn(hex(IDENTITY['creation_filetime']),x)
        self.assertIn(hex(IDENTITY['pid']),x)

    def test_each_selector_is_exact_and_under_expression_cap(self):
        import re
        selectors=ET.fromstring(query_for(IDENTITY,CODE,UNTIL)).findall('Query/Select')
        self.assertEqual(len(selectors),2)
        for selector in selectors:
            x=selector.text
            self.assertIn(IDENTITY['image'],x)
            self.assertIn('Application Error',x);self.assertIn('EventID=1000',x)
            self.assertIn('@SystemTime >=',x);self.assertIn('@SystemTime <=',x)
            self.assertLessEqual(len(re.findall(r'(?<![<>])=|>=|<=',x)),32)

    def test_exact_event_has_only_bounded_fault_metadata(self):
        value=parse_event(event(),IDENTITY,CODE,UNTIL)
        self.assertEqual(value['faulting_module'],'byondwin.dll')
        self.assertEqual(value['module_offset'],'0x123456')
        self.assertEqual(value['exception_code'],'0xc0000005')
        self.assertFalse(value['root_cause_proven'])
        for word in ('must-not-retain','not-retained','ModulePath','Computer','Execution'):
            self.assertNotIn(word,json.dumps(value))
        self.assertLess(len(json.dumps(value)),2048)

    def test_exact_birth_pid_path_and_exception_required(self):
        for change in ({'ProcessId':'0x1'}, {'ProcessCreationTime':hex(IDENTITY['creation_filetime']+1)},
                       {'AppPath':r'C:\other\dreamseeker.exe'}, {'ExceptionCode':'c0000374'}):
            with self.subTest(change=change),self.assertRaises(ValueError):
                parse_event(event(change),IDENTITY,CODE,UNTIL)

    def test_birth_identity_decimal_hex_forms_are_explicit(self):
        for pid in hex_forms(IDENTITY['pid']):
            for birth in hex_forms(IDENTITY['creation_filetime']):
                parse_event(event({'ProcessId':pid,'ProcessCreationTime':birth}),IDENTITY,CODE,UNTIL)

    def test_named_birth_field_must_match_observed_schema(self):
        for xml in (event().replace('ProcessCreationTime','UnrecognizedBirth'),
                    event().replace('ProcessCreationTime','AppStartTime')):
            with self.assertRaises(ValueError):parse_event(xml,IDENTITY,CODE,UNTIL)
        self.assertIn("Data[@Name='ProcessCreationTime']",' '.join(e.text for e in ET.fromstring(query_for(IDENTITY,CODE,UNTIL)).findall('Query/Select')))

    def test_server2022_exact_classic_positions_and_hex(self):
        root=ET.fromstring(event()); system=root.find(NS+'System')
        system.find(NS+'EventID').set('Qualifiers','0')
        ET.SubElement(system,NS+'Version').text='0';ET.SubElement(system,NS+'Task').text='100'
        data=root.find(NS+'EventData');data.clear()
        values=['dreamseeker.exe','516.1688','0','byondwin.dll','516.1688','0','c0000005',
                '0000000000123456',format(IDENTITY['pid'],'x'),format(IDENTITY['creation_filetime'],'016x'),
                IDENTITY['image'],'unretained','unretained','','']
        for value in values:ET.SubElement(data,NS+'Data').text=value
        xml=ET.tostring(root,encoding='unicode')
        result=parse_event(xml,IDENTITY,CODE,UNTIL)
        self.assertEqual(result['event_schema'],'classic_15_position')
        for index,value in ((8,'1234'),(9,'0000000000000001'),(10,r'C:\other\dreamseeker.exe')):
            saved=data[index].text;data[index].text=value
            with self.assertRaises(ValueError):parse_event(ET.tostring(root,encoding='unicode'),IDENTITY,CODE,UNTIL)
            data[index].text=saved
        ET.SubElement(data,NS+'Data').text='extra'
        with self.assertRaises(ValueError):parse_event(ET.tostring(root,encoding='unicode'),IDENTITY,CODE,UNTIL)
        x=' '.join(e.text for e in ET.fromstring(query_for(IDENTITY,CODE,UNTIL)).findall('Query/Select'))
        for token in ('Data[9]','Data[10]','Data[11]'):self.assertIn(token,x)

    def test_late_os_result_is_rejected_not_claimed_within_budget(self):
        clock=Clock()
        def late(query):clock.value=3;return event()
        result=collect(IDENTITY,CODE,reader=late,now=lambda:UNTIL,monotonic=clock.read,sleep=clock.sleep)
        self.assertEqual(result['reason'],'diagnostic_budget_exceeded')
        self.assertNotIn('faulting_module',result)

    def test_provider_event_time_schema_and_fields_fail_closed(self):
        bad=[event(provider='Other'),event(event_id='1001'),event(stamp=BORN-timedelta(seconds=1)),
             event(stamp=UNTIL+timedelta(seconds=1)),event({'ModuleName':r'C:\private\x.dll'}),
             event({'FaultingOffset':'not-hex'}),event({'ModuleName':'x'*129}),'<x/>',
             '<!DOCTYPE Event>'+event(),event()+' '*65536]
        for xml in bad:
            with self.subTest(length=len(xml)),self.assertRaises((ValueError,AttributeError)):
                parse_event(xml,IDENTITY,CODE,UNTIL)

    def test_no_event_has_no_broader_query_and_bounded_wait(self):
        clock=Clock(); queries=[]
        value=collect(IDENTITY,CODE,reader=lambda q:queries.append(q),now=lambda:UNTIL,
                      monotonic=clock.read,sleep=clock.sleep)
        self.assertEqual(value['status'],'owned_crash_evidence_unavailable')
        self.assertEqual(value['reason'],'no_exact_event_within_bound')
        self.assertLessEqual(len(queries),11);self.assertLessEqual(clock.value,2)
        self.assertTrue(all(q==queries[0] for q in queries))

    def test_permission_denial_stops_first_query_without_retry(self):
        calls=[]
        def denied(query):
            calls.append(query);raise PermissionError(5,'unretained-detail')
        value=collect(IDENTITY,CODE,reader=denied,now=lambda:UNTIL)
        self.assertEqual(value,{'status':'owned_crash_evidence_unavailable','reason':'access_denied','winerror':5})
        self.assertEqual(len(calls),1)

    def test_mismatch_stops_without_fallback_or_raw_xml(self):
        calls=[]
        def mismatch(query):
            calls.append(query);return event({'ProcessCreationTime':'0x123'})
        value=collect(IDENTITY,CODE,reader=mismatch,now=lambda:UNTIL)
        self.assertEqual(value['status'],'owned_crash_evidence_unavailable')
        self.assertEqual(len(calls),1)
        self.assertNotIn('0x123',json.dumps(value))

    def test_match_stops_immediately(self):
        calls=[]
        def found(query): calls.append(query);return event()
        value=collect(IDENTITY,CODE,reader=found,now=lambda:UNTIL)
        self.assertEqual(value['status'],'matched_owned_crash_event');self.assertEqual(len(calls),1)

    def test_no_budget_no_normal_exit_no_old_identity_query(self):
        for seconds,code,until in ((0,CODE,UNTIL),(3,CODE,UNTIL),(2,1,UNTIL),(2,CODE,BORN+timedelta(seconds=181))):
            calls=[]
            value=collect(IDENTITY,code,seconds,reader=lambda q:calls.append(q),now=lambda:until)
            self.assertEqual(value['status'],'owned_crash_evidence_unavailable');self.assertEqual(calls,[])
        for key,value in (('pid',True),('creation_filetime',0),('image',r"C:\bad'\dreamseeker.exe")):
            with self.assertRaises(ValueError):binding({**IDENTITY,key:value},CODE)

    def test_controller_collects_only_after_confirmed_cleanup(self):
        text=(Path(__file__).parent/'run_scene.py').read_text()
        self.assertLess(text.index('row = adapter.cleanup('),text.index('from owned_crash import collect'))
        self.assertIn("all(row['all_exited'] for row in result['cleanup'])",text)
        self.assertIn("exits[0].get('wait_signaled') and exits[0].get('exit_code_read')",text)
        self.assertIn('179-(time.monotonic()-started)',text)
        self.assertIn('first_frame_ready_at = time.monotonic() + 2',text)

    def test_no_debug_or_system_setting_mutation_routes(self):
        text=(Path(__file__).parent/'owned_crash.py').read_text()
        for token in ('ReadProcessMemory','MiniDumpWriteDump','DebugActiveProcess','SetErrorMode','EvtClearLog','RegSetValue','subprocess'):
            self.assertNotIn(token,text)
        self.assertIn('api.EvtQuery(None,',text)
        self.assertIn('api.EvtNext(handle, 2, events, 0, 0',text)
        self.assertIn('api.EvtClose(handle)',text)


if __name__=='__main__': unittest.main()

"""Offline diagnostics: never launch binaries, preserve every rejection."""
import json
import unittest
from unittest.mock import patch
import directx_setup as dx
import test_directx_setup as controls

ROW={'protocol':'tcp','address':'127.0.0.1','remote':'0.0.0.0','port':54321,'state':'listen'}
class Adapter:
 def exited(self,p):return False
 def identity(self,p):return {'pid':123,'creation_filetime':456,'image':'PRIVATE-PATH'}
class Diagnostic(unittest.TestCase):
 def test_first_row_only_no_extra_or_private_fields(self):
  result=dx.socket_diagnostic(Adapter(),None,[dict(ROW,secret='PRIVATE'),dict(ROW,port=123)])
  self.assertEqual(result['first_row'],ROW)
  self.assertEqual(result['owned_rows_count'],2)
  self.assertEqual(result['pid'],123)
  self.assertNotIn('PRIVATE',json.dumps(result))
  self.assertLess(len(json.dumps(result)),1024)
 def test_outbound_tcp_udp_and_ipv6_all_observed_without_permission(self):
  for row in [dict(ROW,address='10.0.0.1',remote='192.0.2.1',state='5'),dict(ROW,address='::1',remote='::',state='listen'),dict(ROW,protocol='udp',remote=None,state='None')]:
   self.assertEqual(dx.socket_diagnostic(Adapter(),None,[row])['status'],'observed')
 def test_malformed_and_oversize_data_not_exported(self):
  cases=[[],{},[{}],[dict(ROW,port=True)],[dict(ROW,port=65536)],[dict(ROW,state='secret')],[dict(ROW,protocol='http')],[dict(ROW,address='x'*10000)],[dict(ROW,remote='::1')],[dict(ROW,protocol='udp')],[ROW]*65537]
  for rows in cases:
   with self.subTest(rows_type=type(rows).__name__):self.assertEqual(dx.socket_diagnostic(Adapter(),None,rows),{'status':'unavailable'})
 def test_stale_or_changed_identity_not_exported(self):
  a=Adapter()
  with patch.object(a,'exited',return_value=True):self.assertEqual(dx.socket_diagnostic(a,None,[ROW]),{'status':'unavailable'})
  with patch.object(a,'identity',side_effect=[{'pid':123,'creation_filetime':456},{'pid':124,'creation_filetime':456}]):self.assertEqual(dx.socket_diagnostic(a,None,[ROW]),{'status':'unavailable'})
  with patch.object(a,'exited',side_effect=[False,True]):self.assertEqual(dx.socket_diagnostic(a,None,[ROW]),{'status':'unavailable'})
 def test_cleanup_primitive_allowlist_omits_identity_and_errors(self):
  raw={'all_exited':True,'primitives':{'terminate_job':True,'close_job':True,'secret':'PRIVATE'},'exits':[{'wait_result':0,'wait_signaled':True,'exit_code_read':True,'exit_code':1,'thread_handle_closed':True,'process_handle_closed':True,'identity':{'image':'PRIVATE'},'error':'PRIVATE'}],'errors':[]}
  result=dx.cleanup_diagnostic(raw)
  self.assertTrue(result['all_exited']);self.assertEqual(result['exits'][0]['exit_code'],1)
  self.assertNotIn('PRIVATE',json.dumps(result));self.assertNotIn('identity',json.dumps(result));self.assertLess(len(json.dumps(result)),2048)
 def test_malformed_cleanup_cannot_claim_success(self):
  for raw in [None,{'all_exited':1},{'all_exited':True,'exits':[{},{}]},{'all_exited':True,'primitives':{'close_job':'yes'}},{'all_exited':True,'errors':['x']*17}]:
   self.assertFalse(dx.cleanup_diagnostic(raw)['all_exited'])

class RuntimeRejection(unittest.TestCase):
 def setUp(self):
  self.case=controls.SetupControls(methodName='test_exact_single_silent_command_and_confirmed_cleanup')
  self.case.setUp();self.addCleanup(self.case.doCleanups)
  self.case.fake.identity=lambda process:{'pid':123,'creation_filetime':456,'image':'PRIVATE'}
 def test_valid_socket_evidence_still_fails_and_cleans(self):
  self.case.fake.rows=[ROW]
  with self.assertRaisesRegex(RuntimeError,'^setup_socket_rejected$'):self.case.run_setup()
  r=json.loads((self.case.out/'directx-setup-receipt.json').read_text())
  self.assertEqual(r['status'],'FAILED');self.assertEqual(r['error'],'setup_socket_rejected')
  self.assertEqual(r['socket_diagnostic']['first_row'],ROW)
  self.assertTrue(r['cleanup']['all_exited']);self.assertEqual(self.case.fake.cleaned,5)
 def test_malformed_socket_evidence_still_fails_and_cleans(self):
  self.case.fake.rows=[{'secret':'PRIVATE'}]
  with self.assertRaisesRegex(RuntimeError,'^setup_socket_rejected$'):self.case.run_setup()
  r=json.loads((self.case.out/'directx-setup-receipt.json').read_text())
  self.assertEqual(r['socket_diagnostic'],{'status':'unavailable'})
  self.assertEqual(r['status'],'FAILED');self.assertTrue(r['cleanup']['all_exited'])
  self.assertNotIn('PRIVATE',json.dumps(r));self.assertEqual(self.case.fake.cleaned,5)
if __name__=='__main__':unittest.main()

"""Offline sampled TCP policy tests. No Windows API or installer execution."""
import json
import unittest
from unittest.mock import patch
import directx_setup as dx
import test_directx_setup as controls
ROW={'protocol':'tcp','address':'10.1.0.20','remote':'150.171.110.195','port':60167,'state':'5'}
class Adapter:
 def __init__(self,rows):self.rows=rows
 def sockets(self,p):return self.rows
 def exited(self,p):return False
 def identity(self,p):return {'pid':123,'creation_filetime':456,'image':'PRIVATE'}
class Policy(unittest.TestCase):
 def test_only_explicit_nonlistener_states_allowed(self):
  self.assertEqual(dx.ALLOWED_SETUP_TCP_STATES,{'3','5','6','7','8','9','10','11'})
  for state in dx.ALLOWED_SETUP_TCP_STATES:
   r={};dx.check_setup_sockets(Adapter([dict(ROW,state=state)]),None,r)
   self.assertEqual(r['sampled_tcp_observations'][0]['first_row']['state'],state)
 def test_listener_synreceived_closed_delete_unknown_udp_rejected(self):
  for row in [*[dict(ROW,state=s) for s in ('listen','2','4','1','12','13')],dict(ROW,protocol='udp',remote=None,state='None')]:
   with self.subTest(row=row),self.assertRaisesRegex(RuntimeError,'setup_socket_rejected'):dx.check_setup_sockets(Adapter([row]),None,{})
 def test_unspecified_multicast_invalid_peer_or_local_and_zero_port_rejected(self):
  for row in [dict(ROW,remote='0.0.0.0'),dict(ROW,address='0.0.0.0'),dict(ROW,remote='224.1.1.1'),dict(ROW,address='224.1.1.1'),dict(ROW,remote='::1'),dict(ROW,port=0)]:
   with self.subTest(row=row),self.assertRaisesRegex(RuntimeError,'setup_socket_rejected'):dx.check_setup_sockets(Adapter([row]),None,{})
 def test_ipv6_tcp_checked_without_claiming_initiator(self):
  r={};dx.check_setup_sockets(Adapter([dict(ROW,address='2001:db8::1',remote='2001:db8::2')]),None,r)
  self.assertEqual(r['sampled_tcp_observations'][0]['first_row']['address'],'2001:db8::1')
 def test_malformed_rows_and_row_limit_fail_closed(self):
  for rows in ({},None,(),[{}],[ROW]*65):
   with self.subTest(rows_type=type(rows).__name__),self.assertRaisesRegex(RuntimeError,'setup_socket_rejected'):dx.check_setup_sockets(Adapter(rows),None,{})
 def test_stale_binding_rejected(self):
  a=Adapter([ROW])
  with patch.object(a,'exited',return_value=True),self.assertRaisesRegex(RuntimeError,'setup_socket_rejected'):dx.check_setup_sockets(a,None,{})
 def test_observations_bounded_but_later_disallowed_row_still_rejected(self):
  r={};a=Adapter([dict(ROW,port=n) for n in range(10000,10064)])
  dx.check_setup_sockets(a,None,r);self.assertEqual(len(r['sampled_tcp_observations']),8)
  a.rows=[ROW,dict(ROW,protocol='udp',state='None',remote=None)]
  with self.assertRaisesRegex(RuntimeError,'setup_socket_rejected'):dx.check_setup_sockets(a,None,r)
  self.assertEqual(r['socket_diagnostic']['first_row']['protocol'],'udp')
  self.assertLess(len(json.dumps(r)),10000)
 def test_source_preserves_installer_budget_and_sampling_disclosure(self):
  from pathlib import Path
  s=Path(dx.__file__).read_text()
  self.assertIn("[str(executable), '/silent']",s)
  self.assertEqual(dx.WORK_SECONDS,60);self.assertEqual(dx.CLEANUP_SECONDS,5)
  self.assertIn("'continuous_os_network_isolation': False",s)
class RuntimePolicy(unittest.TestCase):
 def setUp(self):
  self.case=controls.SetupControls(methodName='test_exact_single_silent_command_and_confirmed_cleanup');self.case.setUp();self.addCleanup(self.case.doCleanups)
  self.case.fake.identity=lambda p:{'pid':123,'creation_filetime':456}
 def test_exact_observed_tcp_now_passes_fake_setup_and_cleans(self):
  self.case.fake.rows=[ROW];r=self.case.run_setup()
  self.assertEqual(r['status'],'PASSED');self.assertTrue(r['cleanup']['all_exited']);self.assertEqual(self.case.fake.cleaned,5)
  self.assertEqual(r['sampled_tcp_observations'][0]['first_row'],ROW)
 def test_listener_and_udp_still_fail_and_clean(self):
  for i,row in enumerate([dict(ROW,state='listen'),dict(ROW,protocol='udp',state='None',remote=None)]):
   self.case.out=self.case.root/str(i);self.case.fake.rows=[row];self.case.fake.ticks=0
   with self.assertRaisesRegex(RuntimeError,'setup_socket_rejected'):self.case.run_setup()
   r=json.loads((self.case.out/'directx-setup-receipt.json').read_text());self.assertEqual(r['status'],'FAILED');self.assertTrue(r['cleanup']['all_exited'])
if __name__=='__main__':unittest.main()

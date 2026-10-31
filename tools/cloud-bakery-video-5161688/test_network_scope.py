"""Sampled socket contract and pre-launch holds; does not test isolation."""
import json, os, unittest
from pathlib import Path
from unittest.mock import patch
import directx_setup
import run_scene
import client_debug

def row(address='127.0.0.1',remote='127.0.0.1',port=55555,state='5',protocol='tcp'):
    return dict(address=address,remote=remote,port=port,state=state,protocol=protocol)

class FakeAdapter:
    def __init__(self,rows): self.rows=rows
    def sockets(self,p): return self.rows
    def identity(self,p): return {'pid':123,'creation_filetime':456}
    def exited(self,p): return False

class NetworkScope(unittest.TestCase):
    def test_loopback_and_only_owned_expected_listener(self):
        run_scene.socket_contract([row(remote='0.0.0.0',port=55000,state='listen'),row(port=55000)],server=True,port=55000)
        run_scene.socket_contract([row(remote='0.0.0.0',port=55001,state='listen')],port=55000,allow_client_listener=True)
    def test_unlisted_peers_protocol_and_listener_rejected(self):
        for bad in (row(address='10.0.0.1',remote='69.39.237.88'),row(remote='104.21.51.125'),row(protocol='udp'),row(remote='0.0.0.0',port=22,state='listen'),row(remote='0.0.0.0',port=55000,state='listen')):
            with self.subTest(row=bad),self.assertRaises(run_scene.OwnedSocketViolation):
                run_scene.socket_contract([bad],port=55000,allow_client_listener=True)
        with self.assertRaises(run_scene.OwnedSocketViolation):
            run_scene.socket_contract([row(remote='0.0.0.0',port=55001,state='listen'),row(remote='0.0.0.0',port=55002,state='listen')],port=55000,allow_client_listener=True)
    def test_installer_sample_checks_and_unconditional_prelaunch_hold(self):
        directx_setup.check_setup_sockets(FakeAdapter([row()]),object(),{})
        with self.assertRaisesRegex(RuntimeError,'setup_socket_rejected'):
            directx_setup.check_setup_sockets(FakeAdapter([row(address='10.0.0.1',remote='69.39.237.88')]),object(),{})
        with patch.object(directx_setup,'binding',side_effect=AssertionError('must not reach binding')):
            with self.assertRaisesRegex(RuntimeError,'setup_network_scope_unresolved_pre_launch'):
                directx_setup.run(Path('unused'),Path('unused'),accept_terms=True)
    def test_scene_hold_before_process_creation(self):
        env={'GITHUB_ACTIONS':'true','RUNNER_ENVIRONMENT':'github-hosted','GITHUB_REPOSITORY':'Civ13/Civ13','GITHUB_RUN_ATTEMPT':'1','GITHUB_REF':'refs/heads/ci/cloud-client-startup-diagnostic-5161688-20261031-r1'}
        with patch.dict(os.environ,env),patch('activation.require_runtime',return_value={'client_startup_diagnostic':False}),patch.object(client_debug,'CLIENT_STARTUP_DIAGNOSTIC_ENABLED',False),patch.object(run_scene,'require_admission_window'),patch.object(run_scene,'NETWORK_RUNTIME_ADMITTED',False):
            with self.assertRaisesRegex(RuntimeError,'native network containment'):
                run_scene.run(Path('unused'),Path('unused'),Path('unused'))
    def test_signature_step_uses_pwsh_and_launch_state_matches_activation(self):
        released=json.loads((Path(__file__).parent/'activation.json').read_text(encoding='utf-8'))['released']
        self.assertIs(run_scene.NETWORK_RUNTIME_ADMITTED,released)
        text=(Path(__file__).parent/'workflow.reference.txt').read_text(encoding='utf-8')
        step=text.split('- name: Check Microsoft x86 DLL signatures',1)[1].split('- name:',1)[0]
        self.assertIn('shell: pwsh',step)
        self.assertIn('verify_nuget_signatures.ps1',step)

if __name__=='__main__':unittest.main()

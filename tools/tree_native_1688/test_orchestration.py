"""Fully injected phase orchestration, not native or real Git evidence."""
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from audit_offline import install
install()
import backend_proposal as backend
from prepare import ADAPTER, VERSION, HEAD, TREE, digest, dump
from oracle import expected, SUCCESS
from test_proposal import process_receipt


class OrchestrationTests(unittest.TestCase):
    def scenario(self, fail_phase=None):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            source, prepared, binary, output = [root / name for name in ('source', 'prepared', 'bin', 'runs')]
            for p in (source, prepared, binary): p.mkdir()
            raw = b'synthetic manifest only'
            binding = digest(raw)
            source_bytes = {'code/names.dm': b'var/list/n = file2list("config/names/first.txt")',
                            'config/names/first.txt': b'Alice\n'}
            manifest = {}
            for name, data in source_bytes.items():
                target = source/name; target.parent.mkdir(parents=True, exist_ok=True); target.write_bytes(data)
                manifest[name] = {'sha256': digest(data), 'size': len(data)}
            receipt = {'candidate_manifest_sha256': binding, 'git_head': HEAD, 'git_tree': TREE, 'inputs': {}}
            dump(prepared/'preparation.json', receipt)
            for variant in ('baseline', 'clock', 'duration', 'payment', 'uprooting'):
                p=prepared/'generated'/variant;p.mkdir(parents=True);(p/'tree1688.dme').write_bytes(b'injected fixture')
            seen = []

            def run(command, work, log, wall, log_limit, environment, limits, sample, started):
                phase = work.name
                seen.append(phase)
                started(123, None)
                if phase.endswith('-compile'):
                    log.write_text('DM compiler version 516.1688\n0 errors, 0 warnings\n')
                    (work/'tree1688.dmb').write_bytes(b'injected DMB')
                    (work/'tree1688.rsc').write_bytes(b'injected RSC')
                else:
                    variant, mode = next((v,m) for p,r,v,m in backend.PHASES if p==phase)
                    rows=expected(variant,mode)
                    failure=None if variant=='baseline' else backend.CONTROLS[variant][3] if hasattr(backend,'CONTROLS') else rows[-1]['name']
                    result={'schema':1,'adapter':ADAPTER,'version':VERSION,'head':HEAD,'tree':TREE,
                            'candidate_manifest_sha256':binding,'variant':variant,'phase':mode,'port':0,
                            'status':'passed' if failure is None else 'assertion-rejected',
                            'failure':failure,'legacy_result':SUCCESS[mode] if failure is None else 'FAIL: '+failure,
                            'assertions':rows}
                    dump(work/'tree-native-result.json',result)
                    text='\n'.join('TREE1688_ASSERT '+json.dumps(row) for row in rows)+'\nTREE1688_RESULT '+variant+':'+mode+'\n'
                    log.write_text(text);(work/'runtime.log').write_text(text)
                    self.assertEqual((work/'config/names/first.txt').read_bytes(),b'Alice\n')
                    if mode=='writer':
                        (work/'tree-restart.sav').write_bytes(b'injected save')
                        (work/'tree-restart-entry.txt').write_text('synthetic entry')
                    if mode=='reader': self.assertEqual((work/'tree-restart.sav').read_bytes(),b'injected save')
                response=process_receipt()
                if phase==fail_phase:response['cleanup_verified']=False
                return response

            with patch.object(backend,'candidate_manifest',return_value=(raw,manifest)), \
                 patch.object(backend,'verify_prepared'), \
                 patch.object(backend,'controller_hashes',return_value={}), \
                 patch.object(backend,'binaries',return_value={}), \
                 patch.object(backend,'generated_files',return_value={'tree1688.dme':b'injected fixture'}), \
                 patch.object(backend,'listener_ack',return_value=(None,{'acknowledged':True})), \
                 patch('owned_process_1688.run_bounded',side_effect=run):
                if fail_phase:
                    with self.assertRaisesRegex(ValueError,'Process or cleanup failed'):
                        backend.run_native(source,root/'unused',prepared,output,binary,root/'unused.zip',reviewed_native=True)
                else:
                    backend.run_native(source,root/'unused',prepared,output,binary,root/'unused.zip',reviewed_native=True)
            state=json.loads((output/'result.json').read_text())
            if fail_phase:
                self.assertEqual(seen[-1],fail_phase)
                self.assertEqual(state['status'],'failed')
                self.assertTrue(state['native_executed']) # injected successful spawn fact only
                self.assertFalse((output/fail_phase/'retired-inputs.json').exists())
                self.assertTrue((output/fail_phase/'tree1688.dmb').exists())
            else:
                self.assertEqual(seen,[p for p,*_ in backend.PHASES])
                self.assertEqual(state['status'],'completed')
                for phase,role,variant,mode in backend.PHASES:
                    self.assertTrue((output/phase/'retired-inputs.json').exists())
                    self.assertEqual((output/phase/'tree1688.dmb').exists(),role=='compiler')
                self.assertTrue((output/'baseline-writer/tree-restart.sav').exists())
                self.assertTrue((output/'baseline-reader/tree-restart.sav').exists())

    def test_all_ten_injected_phases_and_restart(self):self.scenario()
    def test_cleanup_failure_stops_before_retirement_or_next_phase(self):self.scenario('baseline-roundtrip')


if __name__=='__main__': unittest.main()

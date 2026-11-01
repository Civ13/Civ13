"""Pure manual-job admission tests; no dispatch, toolchain or native process."""
from copy import deepcopy
from datetime import datetime, timedelta, timezone
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
spec=importlib.util.spec_from_file_location('mount_hosted_admission_test',HERE/'hosted_entry.py')
entry=importlib.util.module_from_spec(spec)
spec.loader.exec_module(entry)
NOW=datetime(2026,11,1,23,40,tzinfo=timezone.utc)

def request(mode='prepare'):
    return dict(source_sha='a'*40,dispatch_sha='a'*40,workflow_sha='a'*40,
                ref='refs/heads/reviewed-mount-fixture',mode=mode,approved=mode=='execute',
                manifest_sha='b'*64 if mode=='execute' else '',
                until=(NOW+timedelta(minutes=20)).isoformat() if mode=='execute' else '',
                repository='Civ13/Civ13',event='workflow_dispatch',now=NOW)

class HostedEntryTests(unittest.TestCase):
    def test_default_prepare_has_no_native_request(self):
        self.assertFalse(entry.validate(**request())['native_requested'])
    def test_execute_binds_all_heads_hash_intent_and_renewed_time(self):
        result=entry.validate(**request('execute'))
        self.assertTrue(result['native_requested'])
        self.assertEqual(result['source_sha'],'a'*40)
        self.assertEqual(result['manifest_sha256'],'b'*64)
    def test_stale_partial_or_different_implementation_and_nonmanual_events_refused(self):
        for changes in (dict(source_sha='a'*39),dict(source_sha='A'*40),
                        dict(dispatch_sha='b'*40),dict(workflow_sha='c'*40),
                        dict(event='push'),dict(event='pull_request'),dict(ref='refs/tags/fixture'),
                        dict(repository='other/Civ13'),dict(mode='automatic')):
            values=request()
            values.update(changes)
            with self.subTest(changes=changes),self.assertRaises(ValueError):
                entry.validate(**values)
    def test_prepare_refuses_stale_execution_fields(self):
        for changes in (dict(approved=True),dict(manifest_sha='b'*64),
                        dict(until=(NOW+timedelta(hours=1)).isoformat())):
            values=request()
            values.update(changes)
            with self.assertRaises(ValueError): entry.validate(**values)
    def test_execute_requires_specific_intent_full_hash_and_whole_window(self):
        for changes in (dict(approved=False),dict(approved='true'),dict(manifest_sha='b'*63),
                        dict(until=''),dict(until='2026-11-02T00:00:00'),
                        dict(until='2026-11-01T23:46:26Z')):
            values=request('execute')
            values.update(changes)
            with self.subTest(changes=changes),self.assertRaises(ValueError): entry.validate(**values)
    def test_review_artifact_rejects_wrong_head_or_manifest_before_execution(self):
        with tempfile.TemporaryDirectory(prefix='mount-hosted-review-') as temp:
            root=Path(temp)
            data=dict(head='a'*40,fixture='mount_lifecycle',mount_manifest_schema=2,
                      sequence=['none'],variants={},bounds={})
            path=root/'mount-native-manifest.json'
            path.write_text(json.dumps(data))
            prepared=entry.review(root,'a'*40,'prepare','')
            self.assertFalse(prepared['native_executed'])
            self.assertEqual(entry.review(root,'a'*40,'execute',prepared['manifest_sha256'])['head'],'a'*40)
            with self.assertRaises(ValueError): entry.review(root,'c'*40,'prepare','')
            with self.assertRaises(ValueError): entry.review(root,'a'*40,'execute','b'*64)
    def test_workflow_is_manual_only_defaults_prepare_and_has_real_guarded_runner(self):
        text=(ROOT/'.github/workflows/mount-lifecycle-native.yml').read_text()
        triggers=text.split('permissions:',1)[0]
        self.assertIn('  workflow_dispatch:',triggers)
        self.assertNotIn('  push:',triggers)
        self.assertNotIn('  pull_request:',triggers)
        self.assertIn('default: prepare',triggers)
        self.assertIn('default: false',triggers)
        self.assertIn('test "$SOURCE_SHA" = "$WORKFLOW_SHA"',text)
        self.assertIn('persist-credentials: false',text)
        self.assertIn('permissions:\n  contents: read',text)
        self.assertEqual(text.count("if: inputs.mode == 'execute' && inputs.execution_approved"),2)
        self.assertIn('tests/mount_lifecycle_native/run_linux.py',text)
        self.assertNotIn('run-diagonal.py',text)
        self.assertIn('--manifest-sha256 "$MANIFEST_SHA"',text)
        self.assertIn("if: always() && env.PREPARED != '' && env.OUTPUT != ''",text)
        self.assertNotIn('runner.temp', text.split('    steps:',1)[0])
        self.assertIn('>> "$GITHUB_ENV"',text)
        self.assertIn('PREPARED=$RUNNER_TEMP/mount-prepared-$GITHUB_RUN_ID-$GITHUB_RUN_ATTEMPT',text)
        self.assertIn('    timeout-minutes: 35',text)
        self.assertIn('        timeout-minutes: 16',text)
        self.assertIn('compile-*-supervision.json',text)
    def test_workflow_pin_matches_canonical_source_and_inputs_use_env(self):
        text=(ROOT/'.github/workflows/mount-lifecycle-native.yml').read_text()
        version=json.loads((ROOT/'tools/byond/version.json').read_text())['version']
        major,minor=version.split('.')
        self.assertIn('BYOND_MAJOR: "'+major+'"',text)
        self.assertIn('BYOND_MINOR: "'+minor+'"',text)
        for block in text.split('run: |')[1:]:
            script=block.split('\n      - ',1)[0]
            self.assertNotIn(chr(36)+'{{ inputs.',script)
        runner=(HERE/'run_linux.py').read_text()
        self.assertIn("os.environ.get('GITHUB_EVENT_NAME') == 'workflow_dispatch'",runner)
        self.assertIn('GITHUB_WORKFLOW_SHA',runner)
        self.assertIn('GITHUB_WORKFLOW_REF',runner)
        self.assertIn('mkdir "$TOOLCHAIN"',text)
        self.assertIn('--byond-bin "$TOOLCHAIN/byond/bin"',text)
        self.assertNotIn('$GITHUB_WORKSPACE/BYOND',text)
        self.assertIn("resolve(strict=True)/'mount-toolchain'",runner)

if __name__=='__main__': unittest.main()

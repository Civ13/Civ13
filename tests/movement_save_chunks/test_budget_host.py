"""Offline hosted-route gates. No network, timeout tool or BYOND executes."""
from datetime import datetime, timedelta, timezone
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import types
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location('test_fixed_budget_host', Path(__file__).with_name('budget_host.py'))
host = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = host
with patch('subprocess.Popen', side_effect=AssertionError('No process on import')):
    SPEC.loader.exec_module(host)
HEAD = 'a'*40
SCOPE = 'b'*64
WHEN = datetime(2026,11,2,14,tzinfo=timezone.utc)
FROZEN_CONDITIONS={'isolated-native': "github.event_name != 'workflow_dispatch' || (inputs.human_spatial_only != true && inputs.human_scale_only != true && inputs.lighting_interleave_only != true && inputs.debug_lossy_only != true) && inputs.debug_combined_only != true", 'lighting-interleave': "github.event_name == 'workflow_dispatch' && inputs.lighting_interleave_only == true && inputs.debug_combined_only != true && inputs.debug_lossy_only != true", 'human-spatial': "github.event_name == 'workflow_dispatch' && inputs.human_spatial_only == true && inputs.debug_combined_only != true && inputs.debug_lossy_only != true && inputs.human_scale_only != true && inputs.lighting_interleave_only != true", 'human-scale': "github.event_name == 'workflow_dispatch' && inputs.human_scale_only == true && inputs.debug_combined_only != true && inputs.debug_lossy_only != true && inputs.lighting_interleave_only != true", 'debug-lossy': "github.event_name == 'workflow_dispatch' && inputs.debug_lossy_only == true && inputs.debug_combined_only != true", 'debug-combined': "github.event_name == 'workflow_dispatch' && inputs.debug_combined_only == true"}


class HostTests(unittest.TestCase):
    def environment(self, root):
        return dict(GITHUB_REPOSITORY='Civ13/Civ13', GITHUB_EVENT_NAME='workflow_dispatch',
                    GITHUB_SHA=HEAD, GITHUB_WORKFLOW_SHA=HEAD, GITHUB_RUN_ATTEMPT='1',
                    GITHUB_RUN_ID='12345', RUNNER_TEMP=str(root),
                    AUTHORIZED_UNTIL=host.stamp(WHEN+timedelta(hours=1)),
                    PILOT_OTHER_SELECTORS=json.dumps(dict(capture_budget_pilot=True,budget_pilot_mode='execute',
                        debug_combined_only=False,debug_lossy_only=False,human_spatial_only=False,
                        human_scale_only=False,lighting_interleave_only=False)))

    def run_case(self, phase='pilot', verdict='completed_no_breach_observed', code=0, elapsed=0, error=None, corrupt=False):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp); output=root/'budget-pilot-evidence'; output.mkdir()
            commands=[]
            def run(argv, **kwargs):
                commands.append((argv, kwargs['timeout']))
                if error:
                    raise error
                if phase == 'pilot':
                    folder=output/'cases'; folder.mkdir()
                    receipt=dict(diagnostic_verdict=verdict, execution='diagnostic_only',
                                 acceptance_status='not_established', fixed_order=list(host.pilot.ORDER),
                                 results=[dict(pilot_index=i,case=c,passed=(verdict!='completed_with_breaches' or i!=1))
                                          for i,c in enumerate(host.pilot.plan())])
                    if corrupt:
                        receipt['results']=[]
                    (folder/'receipt.json').write_text(json.dumps(receipt))
                return types.SimpleNamespace(returncode=code)
            with patch.dict(host.os.environ,self.environment(root),clear=True), patch.object(host.sys,'platform','linux'), patch.object(host,'check_scope',return_value={}), patch.object(host,'now',return_value=WHEN), patch.object(host.subprocess,'run',side_effect=run), patch.object(host.subprocess,'Popen',side_effect=AssertionError('No native execution')):
                admission = host.admit(output,HEAD,SCOPE,host.stamp(WHEN+timedelta(hours=1)))
                if phase == 'pilot':
                    (output/'outer-bootstrap.json').write_text(json.dumps(dict(
                        status='bootstrap_completed',returncode=0,head=HEAD,scope=SCOPE,
                        overall_until=admission['overall_until'])))
                with patch.object(host,'now',return_value=WHEN+timedelta(seconds=elapsed)):
                    observed=None
                    try:
                        row=host.run_phase(output,HEAD,SCOPE,phase)
                    except BaseException as exc:
                        observed=exc
                        row=json.loads((output/('outer-'+phase+'.json')).read_text())
            return row,commands,observed

    def test_fixed_timeout_deadline_and_pilot_command(self):
        row,commands,error=self.run_case()
        self.assertIsNone(error)
        argv,timeout=commands[0]
        self.assertEqual(argv[:4],['timeout','-k','5','915'])
        self.assertEqual(timeout,925)
        self.assertIn('--authorized-until',argv)
        self.assertEqual(argv[argv.index('--authorized-until')+1],host.stamp(WHEN+timedelta(seconds=1190)))
        self.assertEqual(row['status'],'diagnostic_completed_no_breach_observed')
        self.assertEqual(row['acceptance_status'],'not_established')
        self.assertEqual(row['cleanup'],'not_established')

    def test_stale_not_run_and_invalid_completion_are_inconclusive(self):
        for verdict,corrupt in (('not_run',False),('running',False),('inconclusive_stopped',False),('completed_no_breach_observed',True)):
            with self.subTest(verdict=verdict,corrupt=corrupt):
                row,commands,error=self.run_case(verdict=verdict,corrupt=corrupt)
                self.assertIsNone(error)
                self.assertEqual(len(commands),1)
                self.assertTrue(row['controller_invocation_attempted'])
                self.assertEqual(row['status'],'unfinalized_or_inconclusive')

    def test_completed_breaches_remain_failed_diagnostic(self):
        row,commands,error=self.run_case(verdict='completed_with_breaches',code=1)
        self.assertEqual(row['status'],'diagnostic_completed_with_failures')
        self.assertEqual(row['returncode'],1)
        self.assertEqual(row['acceptance_status'],'not_established')

    def test_insufficient_remaining_budget_refuses_before_invocation(self):
        row,commands,error=self.run_case(elapsed=300)
        self.assertIsInstance(error,ValueError)
        self.assertEqual(commands,[])
        self.assertFalse(row['controller_invocation_attempted'])
        self.assertEqual(row['status'],'inconclusive')

    def test_timeout_exception_and_failure_receipt_retained(self):
        primary=subprocess.TimeoutExpired('outer timeout',925)
        row,commands,error=self.run_case(error=primary)
        self.assertIs(error,primary)
        self.assertEqual(row['error']['type'],'TimeoutExpired')
        self.assertEqual(row['status'],'inconclusive')
        self.assertIn('descendant cleanup is not established',row['qualifications'])

    def test_existing_bootstrap_is_reused_and_clamped(self):
        row,commands,error=self.run_case(phase='bootstrap',elapsed=500)
        self.assertIsNone(error)
        self.assertEqual(commands[0][0],['timeout','-k','5','670','bash','scripts/travis_pre_byond.sh'])
        self.assertEqual(commands[0][1],680)
        self.assertEqual(row['status'],'bootstrap_completed')

    def test_expired_and_short_authorization_refused(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp); output=root/'budget-pilot-evidence'; output.mkdir()
            with patch.dict(host.os.environ,self.environment(root),clear=True), patch.object(host.sys,'platform','linux'), patch.object(host,'check_scope',return_value={}), patch.object(host,'now',return_value=WHEN):
                for seconds in (-1,2099):
                    with self.subTest(seconds=seconds), self.assertRaises(ValueError):
                        host.admit(output,HEAD,SCOPE,host.stamp(WHEN+timedelta(seconds=seconds)))
                self.assertFalse((output/'admission.json').exists())

    def test_wrong_context_retries_and_nonrunner_output_refused(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp); env=self.environment(root)
            for key,value in (('GITHUB_RUN_ATTEMPT','2'),('GITHUB_EVENT_NAME','pull_request'),('GITHUB_WORKFLOW_SHA','c'*40),('GITHUB_REPOSITORY','other/repo')):
                with self.subTest(key=key), patch.dict(host.os.environ,{**env,key:value},clear=True), patch.object(host.sys,'platform','linux'):
                    with self.assertRaises(ValueError):
                        host.context(HEAD)
            with patch.dict(host.os.environ,env,clear=True):
                with self.assertRaises(ValueError):
                    host.bind_output(root/'other')

    def test_scope_binds_git_head_and_every_runtime_file(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp)
            for name in host.FILES:
                p=root/name; p.parent.mkdir(parents=True,exist_ok=True); p.write_bytes(('input:'+name).encode())
            def git(*args):
                if args==('rev-parse','HEAD'):return HEAD.encode()
                if args==('rev-parse','HEAD^{tree}'):return ('c'*40).encode()
                if args==('diff','--binary','HEAD'):return b''
                if args[0]=='show':return ('input:'+args[1].split(':',1)[1]).encode()
                raise AssertionError(args)
            with patch.object(host,'ROOT',root),patch.object(host,'git',side_effect=git):
                scope=host.digest(host.canonical(host.manifest(HEAD)))
                self.assertEqual(host.check_scope(HEAD,scope)['head'],HEAD)
                (root/host.FILES[0]).write_bytes(b'changed')
                with self.assertRaises(ValueError):
                    host.check_scope(HEAD,scope)

    def test_pilot_job_is_manual_only_with_retention_and_existing_limits(self):
        whole=(Path(__file__).resolve().parents[2]/'.github/workflows/moving-save-chunks.yml').read_text()
        text=whole.split('  capture-budget-pilot:\n',1)[1]
        self.assertIn("github.event_name == 'workflow_dispatch'",text)
        self.assertNotIn('pull_request:',text)
        self.assertNotIn('push:',text)
        self.assertIn('default: prepare',whole)
        self.assertIn('timeout-minutes: 30',text)
        self.assertIn('if: always()',text)
        self.assertIn('persist-credentials: false',text)
        self.assertEqual(host.pilot.LIMITS,dict(case_seconds=90,job_seconds=900,rss_mib=1024,sample_ms=20))



    def test_original_job_conditions_preserve_all_ordinary_cases(self):
        import ast,itertools,re
        original=FROZEN_CONDITIONS
        whole=(Path(__file__).resolve().parents[2]/'.github/workflows/moving-save-chunks.yml').read_text()
        current={}
        job=None
        for line in whole.splitlines():
            match=re.fullmatch(r'  ([a-z-]+):',line)
            if match:job=match[1]
            if line.startswith('    if: ') and 'github.event_name' in line:
                current[job]=line.split('if: ',1)[1].strip().removeprefix('${{').removesuffix('}}').strip()
        flags=('debug_combined_only','debug_lossy_only','human_spatial_only','human_scale_only','lighting_interleave_only')
        def evaluate(expression,event,values):
            text=expression.replace('github.event_name',repr(event))
            text=re.sub(r'inputs\.([a-z_]+)',lambda m:repr(values[m[1]]),text)
            text=re.sub(r'\btrue\b','True',text).replace('&&',' and ').replace('||',' or ')
            tree=ast.parse(text.strip(),mode='eval')
            allowed=(ast.Expression,ast.BoolOp,ast.And,ast.Or,ast.Compare,ast.Eq,ast.NotEq,ast.Constant)
            self.assertTrue(all(isinstance(n,allowed) for n in ast.walk(tree)))
            return eval(compile(tree,'<fixed condition>','eval'),{'__builtins__':{}},{})
        for bits in itertools.product((False,True),repeat=len(flags)):
            values=dict(zip(flags,bits),capture_budget_pilot=False)
            for event in ('pull_request','workflow_dispatch'):
                for job,expression in original.items():
                    self.assertEqual(evaluate(expression,event,values),evaluate(current[job],event,values))
            values['capture_budget_pilot']=True
            for job in original:
                self.assertFalse(evaluate(current[job],'workflow_dispatch',values))
                self.assertEqual(evaluate(original[job],'pull_request',values),evaluate(current[job],'pull_request',values))

    def test_admission_is_one_shot_and_selector_combinations_are_refused(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp); output=root/'budget-pilot-evidence'; output.mkdir()
            env=self.environment(root)
            with patch.dict(host.os.environ,env,clear=True),patch.object(host.sys,'platform','linux'),patch.object(host,'check_scope',return_value={}),patch.object(host,'now',return_value=WHEN):
                host.admit(output,HEAD,SCOPE,host.stamp(WHEN+timedelta(hours=1)))
                with self.assertRaises(ValueError):
                    host.admit(output,HEAD,SCOPE,host.stamp(WHEN+timedelta(hours=2)))
                selectors=json.loads(env['PILOT_OTHER_SELECTORS']);selectors['human_spatial_only']=True
                with patch.dict(host.os.environ,{'PILOT_OTHER_SELECTORS':json.dumps(selectors)}):
                    with self.assertRaises(ValueError):
                        host.context(HEAD)


    def test_phase_evidence_is_not_overwritten_or_retried(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp); output=root/'budget-pilot-evidence'; output.mkdir()
            with patch.dict(host.os.environ,self.environment(root),clear=True),patch.object(host.sys,'platform','linux'),patch.object(host,'check_scope',return_value={}),patch.object(host,'now',return_value=WHEN),patch.object(host.subprocess,'run',side_effect=AssertionError('No replacement run')) as run:
                host.admit(output,HEAD,SCOPE,host.stamp(WHEN+timedelta(hours=1)))
                evidence=output/'outer-pilot.json'
                evidence.write_text('{"status":"previous failure"}')
                original=evidence.read_bytes()
                with self.assertRaises(ValueError):
                    host.run_phase(output,HEAD,SCOPE,'pilot')
                self.assertEqual(evidence.read_bytes(),original)
                run.assert_not_called()

    def test_approved_deadline_input_cannot_be_replaced_by_admission_data(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp); output=root/'budget-pilot-evidence'; output.mkdir()
            with patch.dict(host.os.environ,self.environment(root),clear=True),patch.object(host.sys,'platform','linux'),patch.object(host,'check_scope',return_value={}),patch.object(host,'now',return_value=WHEN),patch.object(host.subprocess,'run',side_effect=AssertionError('No launch')) as run:
                admission=host.admit(output,HEAD,SCOPE,host.stamp(WHEN+timedelta(hours=1)))
                admission['authorized_until']=host.stamp(WHEN+timedelta(hours=2))
                (output/'admission.json').write_text(json.dumps(admission))
                (output/'admission.sha256').write_text(host.digest(host.canonical(admission)))
                with self.assertRaises(ValueError):
                    host.run_phase(output,HEAD,SCOPE,'bootstrap')
                run.assert_not_called()

    def test_documentation_disclaims_stale_not_run_and_is_cleanly_encoded(self):
        text=(Path(__file__).resolve().parents[2]/'tests/movement_save_chunks/memory-benchmark.md').read_text(encoding='utf-8')
        self.assertIn('animals times',text)
        self.assertNotIn('\ufffd',text)
        self.assertIn('never proof that no process launched',text)


if __name__=='__main__':
    unittest.main()

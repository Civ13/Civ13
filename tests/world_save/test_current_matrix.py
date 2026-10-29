"""Selected current-runtime paths with inert tools, mocked launches and no sockets."""
import ast
from copy import deepcopy
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shlex
import socket
import subprocess
import sys
import tempfile
from types import SimpleNamespace as NS
import unittest
from unittest.mock import Mock, patch

ROOT = Path(__file__).resolve().parents[2]
WORKFLOW_SPEC = importlib.util.spec_from_file_location('reviewed_workflow_contract', ROOT/'tests/world_save/workflow_contract.py')
WORKFLOW_CONTRACT = importlib.util.module_from_spec(WORKFLOW_SPEC)
WORKFLOW_SPEC.loader.exec_module(WORKFLOW_CONTRACT)
HERE = ROOT/'tests/world_save'


def load(path):
    spec = importlib.util.spec_from_file_location('matrix_'+path.stem.replace('-', '_'), path)
    module = importlib.util.module_from_spec(spec)
    if path.name == 'inspect-partial-save.py' and sys.platform != 'linux':
        # Import the Linux-only source for injected checks, never apply rlimits here.
        with patch.dict(sys.modules, resource=NS()): spec.loader.exec_module(module)
    else: spec.loader.exec_module(module)
    return module


CURRENT = load(HERE/'current_runtime.py')
CONTRACT = load(ROOT/'tests/new_z_budget/z_budget_evidence.py')
IDENTITY = dict(version='516.1688', archive=dict(sha256='a'*64),
                members={name: dict(sha256='b'*64) for name in
                         ('DreamMaker','DreamDaemon','libbyond.so','libext.so')})
STEPS = ('Verify protected sleep transfers and bounded save compatibility',
         'Offline world-save round-trip regression',
         'Verify bounded admitted save traversal and backup recovery')
DRIVERS = ('run-sleep-transfer.py','run-cross-level.py','inspect-partial-save.py',
           'run-dimension-bootstrap.py','run-durable-world.py','run-durable-graph.py',
           'run-string-path.py','tests/save_latency/run.py')


def selected_calls(workflow):
    """Expand only the fixed shell for-loops; never execute shell or Python."""
    result = []
    def walk(lines, env):
        i = 0
        while i < len(lines):
            line = lines[i].strip()
            if line.startswith('for ') and line.endswith('; do'):
                header = shlex.split(line[:-4]); depth = 1; end = i+1
                while depth:
                    current = lines[end].strip()
                    if current.startswith('for ') and current.endswith('; do'): depth += 1
                    if current == 'done': depth -= 1
                    end += 1
                for value in header[3:]: walk(lines[i+1:end-1], dict(env, **{header[1]: value}))
                i = end; continue
            line = line.removeprefix('if ! ').removesuffix('; then')
            if line.startswith('python3 tests/') and any(name in line for name in DRIVERS):
                tokens = shlex.split(line)
                tokens = [env.get(token.removeprefix('$'), token) for token in tokens]
                result.append((tokens[1], tokens[2:]))
            i += 1
    for step in STEPS:
        block = workflow.split('      - name: '+step+'\n',1)[1].split('      - name:',1)[0]
        walk(block.splitlines(), {})
    return result


class CurrentMatrix(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # Immutable source reads only, before all launch prohibitions.
        def old(path): return subprocess.check_output(['git','show','5b004d68:'+path],cwd=ROOT).decode()
        cls.old_workflow = old('.github/workflows/test.yml')
        cls.old_graph = old('tests/world_save/run-durable-graph.py')
        cls.old_dimension_probe = old('tests/world_save/dimension_bootstrap_probe.dm')
        cls.old_sources = {path: old(path) for path in (
            'tests/world_save/run-durable-world.py','tests/world_save/run-string-path.py',
            'tests/save_latency/run.py','tests/world_save/partial_save_inspector/inspect-partial-save.py')}
        cls.historical = {path: subprocess.check_output(['git','show','d0ffbfb2335eb735756b998f3f2ff617c28f144b:'+path],cwd=ROOT)
                          for path in ('code/modules/persistence/loading.dm','code/modules/organs/wound.dm')}
        cls.old_reader = subprocess.check_output(['git','show','75890d883190355e430f9958fd102864ee88429a:code/modules/persistence/loading.dm'],cwd=ROOT)
        cls.master_workflow = subprocess.check_output(['git','show',
            'eedc9862fcb7b2b7c3617c6972965fafa650e51a:.github/workflows/test.yml'],cwd=ROOT,text=True)
        cls.feature_durable = subprocess.check_output(['git','show',
            'f97c2940b0b1202ed97f5f413bd1a4a6f24e0962:tests/world_save/run-durable-world.py'],cwd=ROOT,text=True)

    def setUp(self):
        self.enterContext(patch.object(socket,'socket',side_effect=AssertionError('Socket forbidden')))
        self.enterContext(patch.object(subprocess,'Popen',side_effect=AssertionError('Native launch forbidden')))
        self.enterContext(patch.object(subprocess,'run',side_effect=AssertionError('Native run forbidden')))

    def runtime(self):
        verifier = NS(verify_linux=Mock(return_value=deepcopy(IDENTITY)))
        with patch.object(CURRENT.sys,'platform','linux'), patch.object(CURRENT,'load',side_effect=[verifier,CONTRACT]):
            return CURRENT.CurrentRuntime('unused', 'unused.zip')

    def git(self, command, **kwargs):
        self.assertEqual(command[0],'git')
        if command[1] == 'show':
            path = command[2].split(':',1)[1]
            data = self.old_reader if command[2].startswith('75890d') else self.historical[path]
            return data.decode() if kwargs.get('text') else data
        return 'a'*40+'\n' if kwargs.get('text') else b''

    def tools(self, root):
        tools = root/'tools'; tools.mkdir()
        for name in ('dm.exe','dd.exe','DreamMaker','DreamDaemon'): (tools/name).write_bytes(b'inert; never executed')
        return tools

    def compile(self, command, cwd, runtime, artifact=None):
        self.assertEqual(runtime.checks[-1], 'compile')
        dme = Path(cwd)/command[-1]
        for suffix in ('.dmb','.rsc'): dme.with_suffix(suffix).write_bytes(b'inert mock artifact')
        return 'DM compiler version 516.1688\n'+(artifact or dme.with_suffix('.dmb').name)+' - 0 errors, 0 warnings\n'

    def child(self):
        return NS(pid=123,wait=lambda timeout:None,poll=lambda:0,terminate=lambda:None,kill=lambda:None)

    def test_workflow_only_threads_identity_and_every_selected_case_reaches_identity_gate(self):
        workflow = (ROOT/'.github/workflows/test.yml').read_text()
        WORKFLOW_CONTRACT.assert_workflow_contract(workflow)
        master = self.master_workflow
        for step in STEPS:
            marker='      - name: '+step+'\n'
            self.assertEqual(workflow.split(marker,1)[1].split('\n',1)[0],
                             master.split(marker,1)[1].split('\n',1)[0])
        calls=selected_calls(workflow)
        self.assertEqual(len(calls),58)
        for path,args in calls:
            with self.subTest(path=path,args=args):
                module=load(ROOT/path)
                target=module.BASE if path.endswith('run-sleep-transfer.py') else module
                self.assertIn('--byond-archive',args)
                with patch.object(sys,'argv',[path,*args]), patch.object(target,'selected_runtime',side_effect=RuntimeError('identity gate')), \
                        patch.object(os,'geteuid',return_value=1000,create=True), patch('sys.stderr'), self.assertRaisesRegex(RuntimeError,'identity gate'):
                    module.main()

    def test_current_mode_rejects_other_versions_and_all_unselected_or_held_flags_before_effects(self):
        with patch.object(CURRENT.sys,'platform','linux'), patch.object(CURRENT,'load',side_effect=[
                NS(verify_linux=Mock(return_value=dict(IDENTITY,version='516.1681'))),CONTRACT]), self.assertRaisesRegex(ValueError,'exactly 516.1688'):
            CURRENT.CurrentRuntime('unused','unused.zip')
        rejected = {
            'run-durable-world.py': (['--roof-areas'],['--zone-topology'],['--persistence-year'],['--prepare-only'],
                                     ['--wounds','--profile','europe'],['--profile','europe','--negative-control','season']),
            'run-cross-level.py': (['--prepare-only'],['--compile-only'],['--run-native'],['--run-native','--expect-current-defects'],
                                   ['--run-native','--case','pins'],['--run-native','--negative-control','binder']),
            'run-sleep-transfer.py': (['--prepare-only'],['--compile-only'],['--run-native','--case','entry']),
            'run-dimension-bootstrap.py': (['--prepare-only'],['--negative-control','memory-admission'],['--negative-control','budget-hold']),
            'run-durable-graph.py': (['--prepare-only'],['--alist','--negative-control','generation'],['--contracts','--negative-control','alias']),
            'run-string-path.py': (['--prepare-only'],['--phase-profile','--progress'],['--player-ui'],['--negative-control'],
                                   ['--progress'],['--progress','--progress-fault-stage','save_entered','--progress-fault-operation','write'])}
        for name,rows in rejected.items():
            for flags in rows:
                module=load(HERE/name); target=module.BASE if name=='run-sleep-transfer.py' else module
                args=[name,'--byond-bin','unused','--byond-archive','unused.zip',*flags]
                if name=='run-string-path.py': args+=['--expected-saving-sha256','unused']
                with self.subTest(name=name,flags=flags), patch.object(sys,'argv',args), \
                        patch.object(target,'selected_runtime') as selected, patch('sys.stderr'), self.assertRaises(SystemExit): module.main()
                selected.assert_not_called()
        latency=load(ROOT/'tests/save_latency/run.py')
        for flags in ([],['--large'],['--benchmark-only'],['--prepare-only'],['--timeout-seconds','1','--verify-backup'],
                      ['--large','--dimension','2'],['--dense','--scenario','movement']):
            with self.subTest(flags=flags), patch.object(sys,'argv',['latency','--byond-bin','unused','--byond-archive','unused.zip',*flags]), \
                    patch.object(latency,'selected_runtime') as selected, patch('sys.stderr'), self.assertRaises(SystemExit): latency.main()
            selected.assert_not_called()

    def test_dimension_projection_is_exact_hashed_and_keeps_legacy_input(self):
        module=load(HERE/'run-dimension-bootstrap.py'); historical=self.old_dimension_probe
        self.assertEqual(hashlib.sha256(historical.encode()).hexdigest(), '06bd4862bed6c66e735b4bfdf1f5d8d65786e40b5c396490be26bfc2622cbd5a')
        with self.assertRaisesRegex(RuntimeError, 'hash or runtime assertion'): module.current_probe(historical)
        old=(HERE/'dimension_bootstrap_probe.dm').read_text()
        self.assertEqual(hashlib.sha256(old.encode()).hexdigest(), '8d8ed1aee114c8d4bf837b969e25dac779b8d1f1887c91d6afb5574bf73225d7')
        projected,receipt=module.current_probe(old)
        self.assertEqual(projected,old.replace('world.byond_build == 1681','world.byond_build == 1688',1))
        self.assertEqual(receipt['original_sha256'],hashlib.sha256(old.encode()).hexdigest())
        self.assertEqual(receipt['projected_sha256'],hashlib.sha256(projected.encode()).hexdigest())
        for bad in (old+'\n',old.replace('1681','1688'),old.replace('1681','1681 || TRUE'),old+old):
            with self.subTest(), self.assertRaisesRegex(RuntimeError,'hash or runtime assertion'): module.current_probe(bad)
        self.assertEqual((HERE/'dimension_bootstrap_probe.dm').read_text(),old)

    def test_cross_and_sleep_actual_cases_recheck_before_every_child_and_preserve_oracles(self):
        cases=[(HERE/'run-cross-level.py',['--case','field-direct']),
               (HERE/'run-cross-level.py',['--case','move-direct']),
               (HERE/'run-cross-level.py',['--negative-control','first-capture'])]
        sleep=load(HERE/'run-sleep-transfer.py')
        cases += [(HERE/'run-sleep-transfer.py',([] if control is None else ['--negative-control',control])) for control in (None,*sleep.CONTROLS)]
        for path,flags in cases:
            with self.subTest(path=path.name,flags=flags), tempfile.TemporaryDirectory() as directory:
                root=Path(directory); tools=self.tools(root); output=root/'packet'; output.mkdir(); module=load(path)
                base=module.BASE if path.name=='run-sleep-transfer.py' else module
                runtime=self.runtime(); launched=[]
                def popen(command,**kwargs):
                    cwd=Path(kwargs['cwd']); compiler=Path(command[0]).name in ('dm.exe','DreamMaker')
                    label='compile' if compiler else 'daemon:'+cwd.name
                    self.assertEqual(runtime.checks[-1],label); launched.append(label)
                    if compiler: kwargs['stdout'].write(self.compile(command,cwd,runtime))
                    else:
                        receipt=json.loads((output/'receipt.json').read_text()); case=cwd.name
                        result=receipt['expected_results'].get(case,'PASS')
                        if isinstance(result,dict): result=result['pattern'].replace('[1-9][0-9]*','1')
                        (cwd/'native.log').write_text('clean')
                        (cwd/'result.json').write_text(json.dumps(dict(case=case,done=1,runtime_failed=0,checks=100,port=0,result=result)))
                    return self.child()
                with patch.object(sys,'argv',[str(path),'--run-native','--byond-bin',str(tools),'--byond-archive','inert.zip',*flags]), \
                        patch.object(base,'selected_runtime',return_value=runtime), patch.object(module.tempfile,'mkdtemp',return_value=str(output)), \
                        patch.object(subprocess,'check_output',side_effect=self.git), patch.object(subprocess,'Popen',side_effect=popen), patch('builtins.print'):
                    module.main()
                self.assertEqual(launched,runtime.checks)
                self.assertTrue(json.loads((output/'receipt.json').read_text())['native_verified'])

    def dimension(self, control=None, wrong_build=False, drift=False):
        module=load(HERE/'run-dimension-bootstrap.py'); runtime=self.runtime(); launched=[]
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory); tools=self.tools(root); output=root/'packet'; output.mkdir()
            def popen(command,**kwargs):
                cwd=Path(kwargs['cwd']); compiler=Path(command[0]).name in ('dm.exe','DreamMaker')
                label='compile' if compiler else cwd.name
                self.assertEqual(runtime.checks[-1],label); launched.append(label)
                if compiler:
                    kwargs['stdout'].write(self.compile(command,cwd,runtime))
                    if drift: runtime.verifier.verify_linux.side_effect=ValueError('member changed')
                else:
                    writer=cwd.name.startswith('write'); count=int(cwd.name[-1]) if writer else 3 if cwd.name in ('positive','custody-positive','allocation-failure','exact-post') or control else 2
                    (cwd/'map_saves').mkdir(exist_ok=True); (cwd/'map_saves/seed.sav').write_bytes(b'synthetic seed')
                    (cwd/'runtime.log').write_text('clean')
                    (cwd/'result.txt').write_text('FAIL: rejected save allocated levels' if control and not writer else 'PASS')
                    (cwd/'receipt.json').write_text(json.dumps(dict(checks=4 if writer else 20,maxz=count,
                        allocations=0 if writer else int(count==3),byond_version=516,byond_build=1681 if wrong_build else 1688)))
                return self.child()
            args=['dimension','--byond-bin',str(tools),'--byond-archive','inert.zip']
            if control: args+=['--negative-control',control]
            error=None
            with patch.object(sys,'argv',args), patch.object(module,'selected_runtime',return_value=runtime), \
                    patch.object(module.tempfile,'mkdtemp',return_value=str(output)), patch.object(subprocess,'Popen',side_effect=popen), patch('builtins.print'):
                try: module.main()
                except Exception as caught: error=caught
            return error,launched,runtime.checks,json.loads((output/'summary.json').read_text())

    def test_dimension_actual_matrix_and_preflight_control_require_current_observed_build(self):
        for control in (None,'preflight'):
            error,launched,checks,receipt=self.dimension(control)
            self.assertIsNone(error); self.assertEqual(launched,checks)
            self.assertEqual(len(launched),31 if control is None else 5)
            self.assertEqual(receipt['runtime_projection']['contract'],'current-516.1688')
        error,launched,checks,_=self.dimension(wrong_build=True)
        self.assertIsInstance(error,RuntimeError); self.assertEqual(len(launched),2)
        error,launched,checks,_=self.dimension(drift=True)
        self.assertIsInstance(error,ValueError); self.assertEqual(launched,['compile'])

    def test_durable_actual_selected_matrix_rechecks_every_variant_and_keeps_results(self):
        calls=[args for path,args in selected_calls((ROOT/'.github/workflows/test.yml').read_text())
               if path.endswith('run-durable-world.py')]
        self.assertEqual(len(calls),18)
        errors={'season':'environment phase reset','preflight':'malformed artillery sentinel mutated world',
                'reachability':'orphan metadata reference accepted','callback':'restored callback duplicated',
                'timer-restore':'persisted callback was not restored',
                'reclaim-order':'waiting authenticated client not reclaimed after recovery'}
        for flags in calls:
            with self.subTest(flags=flags), tempfile.TemporaryDirectory() as directory:
                root=Path(directory); tools=self.tools(root); output=root/'packet'; output.mkdir()
                module=load(HERE/'run-durable-world.py'); runtime=self.runtime(); launched=[]
                control=flags[flags.index('--negative-control')+1] if '--negative-control' in flags else None
                def run(command,**kwargs):
                    cwd=Path(kwargs['cwd']); compiler=Path(command[0]).name in ('dm.exe','DreamMaker')
                    mode=next((part.split('dimension_mode=')[1] for part in command if 'dimension_mode=' in part),None)
                    label='compile' if compiler else 'daemon:'+mode if mode else 'daemon'
                    self.assertEqual(runtime.checks[-1],label); launched.append(label)
                    if compiler:
                        return NS(returncode=0,stdout=self.compile(command,cwd,runtime),stderr='')
                    saves=output/'map_saves'; saves.mkdir(exist_ok=True)
                    (saves/'restart_intent.json').write_text('{"generation":"fixture"}')
                    (saves/'save_complete.txt').write_text('fixture')
                    (output/command[command.index('-log')+1]).write_text('Native shutdown returned without closing the world' if control=='shutdown-return' else 'clean')
                    result=dict(done=1,checks=20)
                    if '--startup-only' in flags: (output/'startup-result.json').write_text('{"startup_only":1}')
                    if '--wounds' in flags:
                        result=dict(done=1,checks=142,roundtrips=18)
                        if control:
                            receipt=json.loads((output/'receipt.json').read_text())
                            result=dict(done=0,checks=5,error='Cannot read null.max_damage',source=receipt['wound_control_source'],line=394)
                    elif '--lifecycle-shutdown' in flags:
                        result.update(intent_hash=hashlib.md5((saves/'restart_intent.json').read_bytes()).hexdigest(),generation='fixture')
                        if control: (saves/'restart_intent.json').unlink()
                    elif control:
                        result=dict(done=0,checks=12 if control=='preflight' else 10 if control=='reclaim-order' else 20,error=errors[control])
                    (output/'metadata-result.json').write_text(json.dumps(result))
                    return NS(returncode=0,stdout='',stderr='')
                flags=[str(tools) if token=='$PWD/BYOND/byond/bin' else token for token in flags]
                with patch.object(sys,'argv',['durable',*flags]), patch.object(module,'selected_runtime',return_value=runtime), \
                        patch.object(module.tempfile,'mkdtemp',return_value=str(output)), patch.object(subprocess,'check_output',side_effect=self.git), \
                        patch.object(subprocess,'run',side_effect=run), patch('builtins.print'):
                    module.main()
                self.assertEqual(launched,runtime.checks)
                self.assertEqual(len(launched),7 if '--dimension-bootstrap' in flags else 2)
                if control=='wound-restore':
                    self.assertEqual((output/'receipt.json').exists(),True)

    def test_graph_current_driver_rechecks_before_compiler_and_daemon(self):
        module=load(HERE/'run-durable-graph.py'); runtime=self.runtime(); launched=[]
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory); tools=self.tools(root); output=root/'packet'; output.mkdir()
            def run(command,**kwargs):
                compiler=Path(command[0]).name in ('dm.exe','DreamMaker'); role='compile' if compiler else 'daemon'
                self.assertEqual(runtime.checks[-1],role); launched.append(role)
                if compiler: return NS(returncode=0,stdout=self.compile(command,output,runtime),stderr='')
                (output/'native.log').write_text('clean'); (output/'result.json').write_text('{"done":1,"checks":16,"failures":0}')
                return NS(returncode=0,stdout='',stderr='')
            with patch.object(sys,'argv',['graph','--byond-bin',str(tools),'--byond-archive','inert.zip']), \
                    patch.object(module,'selected_runtime',return_value=runtime), patch.object(module.tempfile,'mkdtemp',return_value=str(output)), \
                    patch.object(subprocess,'run',side_effect=run), patch('builtins.print'):
                module.main()
            self.assertEqual(launched,['compile','daemon'])
            self.assertEqual(json.loads((output/'receipt.json').read_text())['result']['checks'],16)

    def test_string_actual_selected_matrix_rechecks_and_preserves_publication_oracle(self):
        calls=[args for path,args in selected_calls((ROOT/'.github/workflows/test.yml').read_text()) if path.endswith('run-string-path.py')]
        self.assertEqual(len(calls),4)
        for flags in calls:
            with self.subTest(flags=flags), tempfile.TemporaryDirectory() as directory:
                root=Path(directory); tools=self.tools(root); output=root/'packet'; output.mkdir()
                module=load(HERE/'run-string-path.py'); runtime=self.runtime(); launched=[]
                def popen(command,**kwargs):
                    compiler=Path(command[0]).name in ('dm.exe','DreamMaker'); role='compile' if compiler else 'daemon'
                    self.assertEqual(runtime.checks[-1],role); launched.append(role)
                    if compiler: kwargs['stdout'].write(self.compile(command,output,runtime))
                    else:
                        (output/'runtime.log').write_text('clean')
                        control='--publication-negative-control' in flags
                        (output/'result.txt').write_text('FAIL: '+module.PUBLICATION_FAILURE if control else 'PASS')
                        if control: (output/'failure-name.txt').write_text(module.PUBLICATION_FAILURE)
                    return self.child()
                digest=hashlib.sha256((ROOT/'code/modules/persistence/saving.dm').read_bytes()).hexdigest()
                flags=[str(tools) if token=='$PWD/BYOND/byond/bin' else digest if token=='$saving_sha' else token for token in flags]
                with patch.object(sys,'argv',['string',*flags]), patch.object(module,'selected_runtime',return_value=runtime), \
                        patch.object(module.tempfile,'mkdtemp',return_value=str(output)), patch.object(subprocess,'Popen',side_effect=popen), patch('builtins.print'):
                    module.main()
                self.assertEqual(launched,['compile','daemon'])
                self.assertEqual(json.loads((output/'summary.json').read_text())['publication_negative_control'],'--publication-negative-control' in flags)

    def latency(self, flags, exhaust=False, drift=False):
        module=load(ROOT/'tests/save_latency/run.py'); runtime=self.runtime(); launched=[]; elapsed=[0]
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory); tools=self.tools(root); output=root/'packet'; output.mkdir()
            verify=runtime.before_launch
            def before(role,destination):
                verify(role,destination)
                if exhaust and role=='daemon:backup': elapsed[0]=1800
            runtime.before_launch=before
            def write_result(command):
                role=runtime.checks[-1]; launched.append(role)
                if '-max_errors' in command:
                    text=self.compile(command,output,runtime)
                    if drift: runtime.verifier.verify_linux.side_effect=ValueError('runtime drift')
                    return NS(returncode=0,stdout=text,stderr='')
                (output/'map_saves').mkdir(exist_ok=True); (output/'map_saves/active.sav').write_bytes(b'synthetic active')
                (output/'map_backups').mkdir(exist_ok=True); (output/'map_backups/backup.sav').write_bytes(b'synthetic backup')
                control=flags[-1] if '--negative-control' in flags else None
                result='FAIL: dense graph prevented heartbeat progress' if control=='yield' else 'FAIL: save preflight failed' if control=='old-reader' else 'PASS'
                (output/'result.txt').write_text(result)
                log='World-save preflight rejected: Unsupported save version 3 on :\n' if control=='old-reader' else 'clean'
                (output/'runtime.log').write_text(log)
                return NS(returncode=0,stdout='',stderr='')
            def run(command,**kwargs):
                self.assertGreater(kwargs['timeout'],0); self.assertLessEqual(kwargs['timeout'],1800)
                return write_result(command)
            def popen(command,**kwargs):
                self.assertEqual(runtime.checks[-1],'daemon:interrupted-writer')
                write_result(command); (output/'interruption_ready.txt').write_text('ready')
                child=self.child(); child.poll=lambda: None; return child
            error=None
            with patch.object(sys,'argv',['latency','--byond-bin',str(tools),'--byond-archive','inert.zip',*flags]), \
                    patch.object(module,'selected_runtime',return_value=runtime), patch.object(module.tempfile,'mkdtemp',return_value=str(output)), \
                    patch.object(subprocess,'check_output',side_effect=self.git), patch.object(subprocess,'run',side_effect=run), \
                    patch.object(subprocess,'Popen',side_effect=popen), patch.object(module.time,'monotonic',side_effect=lambda:elapsed[0]), patch('builtins.print'):
                try: module.main()
                except Exception as caught: error=caught
            return error,launched,runtime.checks

    def test_bounded_save_all_selected_paths_recheck_recovery_and_preserve_remaining_budget(self):
        cases=[['--verify-backup'],['--dense','--verify-backup'],['--interrupt'],['--negative-control','yield'],['--negative-control','old-reader']]
        cases += [['--scenario',name] for name in ('movement','concurrent','parent-deletion')]
        for flags in cases:
            with self.subTest(flags=flags):
                error,launched,checks=self.latency(flags)
                self.assertIsNone(error); self.assertEqual(launched,checks)
                self.assertEqual(len(launched),4 if '--interrupt' in flags else 3 if '--verify-backup' in flags else 2)
        error,launched,checks=self.latency(['--verify-backup'],exhaust=True)
        self.assertIsInstance(error,RuntimeError); self.assertEqual(launched,['compile','daemon'])
        self.assertEqual(checks[-1],'daemon:backup')
        error,launched,_=self.latency(['--verify-backup'],drift=True)
        self.assertIsInstance(error,ValueError); self.assertEqual(launched,['compile'])

    def test_inspector_current_selftest_checks_every_child_and_keeps_private_mode_held(self):
        module=load(HERE/'partial_save_inspector/inspect-partial-save.py'); runtime=self.runtime(); launched=[]
        for flags in ([],['--source','/private/map_saves/2.sav'],['--self-test-only','--source','/private/map_saves/2.sav']):
            with patch.object(sys,'argv',['inspector','--byond-archive','inert.zip',*flags]), \
                    patch.object(module,'selected_runtime') as selected, self.assertRaises(RuntimeError): module.main()
            selected.assert_not_called()
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory); tools=self.tools(root); stage=root/'packet'; stage.mkdir()
            def run(command,**kwargs):
                label=runtime.checks[-1]; launched.append(label)
                if label.endswith('-compile'):
                    artifact=Path(command[-1]).with_suffix('.dmb').name
                    self.compile([command[0],command[-1]],stage,runtime=NS(checks=['compile']),artifact=artifact)
                    kwargs['stdout'].write(('DM compiler version 516.1688\n'+artifact+' - 0 errors, 0 warnings\n').encode())
                elif label=='writer-fixture':
                    (stage/'fixture.sav').write_bytes(b'synthetic fixture'); (stage/'malformed.sav').write_bytes(b'malformed synthetic fixture')
                    (stage/'writer-ok.txt').write_text('WRITER_OK')
                elif label=='reader-selftest':
                    records=[dict(entry=i,type_export='. = /'+type+'/inspector_fixture\n',fields=['original_target','type'] if i==513 else ['type'])
                             for i,type in ((513,'obj'),(2,'mob'),(1,'obj'))]
                    (stage/'native-selftest.json').write_text(json.dumps(dict(schema_version_export='2',port=0,highest_entry=513,records=records)))
                elif label=='reader-reject': (stage/'native-error.txt').write_text('NATIVE_ERROR')
                return NS(returncode=0)
            with patch.object(sys,'argv',['inspector','--self-test-only','--byond-bin',str(tools),'--byond-archive','inert.zip']), \
                    patch.object(module,'selected_runtime',return_value=runtime), patch.object(os,'geteuid',return_value=1000,create=True), \
                    patch.object(os,'access',return_value=True), patch.object(os,'umask'), patch.object(Path,'home',return_value=root), \
                    patch.object(module,'digest',side_effect=lambda path:hashlib.sha256(path.read_bytes()).hexdigest()), \
                    patch.object(module.tempfile,'mkdtemp',return_value=str(stage)), patch.object(subprocess,'run',side_effect=run), patch('builtins.print'):
                module.main()
            self.assertEqual(launched,['writer-compile','reader-compile','writer-fixture','reader-selftest','reader-reject'])
            self.assertEqual(json.loads((stage/'selftest-summary.json').read_text())['compiler_required'],'516.1688')

    def test_oracle_tails_and_historical_refusals_are_unchanged(self):
        markers={'tests/world_save/run-durable-world.py':"        result_path = output / 'metadata-result.json'",
                 'tests/world_save/run-string-path.py':"    actual = read(output / 'result.txt').strip()"}
        for path,marker in markers.items():
            reference = self.old_sources[path]
            if path.endswith('run-durable-world.py'):
                # Master and feature differ only by the added offline-client
                # check in these result counts; preserve every other oracle.
                master_tail = reference.split(marker,1)[1]
                changes = (
                    ("        if args.wounds and not args.negative_control:\n", "        # 141 wound assertions plus the generated offline-client startup check.\n        if args.wounds and not args.negative_control:\n"),
                    ("result.get('checks') != 141", "result.get('checks') != 142"),
                    ("result.get('checks') != 4:", "result.get('checks') != 5:"),
                    ("# Four operation-admission checks precede the malformed-wire guard.\n            if args.negative_control == 'preflight' and result.get('checks') != 11:", "# Includes four operation-admission checks and the offline startup check.\n            if args.negative_control == 'preflight' and result.get('checks') != 12:"),
                    ("# Includes the export operation-release assertion before recovery.\n            if args.negative_control == 'reclaim-order' and result.get('checks') != 9:", "# Includes export operation-release and offline startup checks before recovery.\n            if args.negative_control == 'reclaim-order' and result.get('checks') != 10:"),
                )
                for before, after in changes:
                    self.assertEqual(master_tail.count(before), 1)
                    master_tail = master_tail.replace(before, after, 1)
                self.assertEqual(master_tail, self.feature_durable.split(marker,1)[1])
                reference = self.feature_durable
            self.assertEqual(reference.split(marker,1)[1],(ROOT/path).read_text().split(marker,1)[1])
        def function(source,name):
            return ast.dump(next(n for n in ast.parse(source).body if isinstance(n,ast.FunctionDef) and n.name==name))
        self.assertEqual(function(self.old_graph,'adjudicate'),function((HERE/'run-durable-graph.py').read_text(),'adjudicate'))
        for name in ('old_reader_helpers','require_old_reader_preflight'):
            self.assertEqual(function(self.old_sources['tests/save_latency/run.py'],name),function((ROOT/'tests/save_latency/run.py').read_text(),name))
        inspector='tests/world_save/partial_save_inspector/inspect-partial-save.py'
        for name in ('limits','selftest','sanitize_report','stable_copy'):
            self.assertEqual(function(self.old_sources[inspector],name),function((ROOT/inspector).read_text(),name))


if __name__=='__main__': unittest.main()

"""Exercise the actual workflow artifact block with mocked filesystem commands."""
import json
import subprocess
import tempfile
import textwrap
import unittest
from pathlib import Path

HERE=Path(__file__).parent
RUN='123456789'
PREFIX='civ13-preflight-'+RUN+'-1-'+'a'*32+'-'
RULES=[PREFIX+role+'-'+family for role in ('dm-exe','dd-exe','dreamseeker-exe') for family in ('v4','v6')]
ROOT=['receipt.json','cleanup-receipt.json','witness-receipt.json','source-receipt.json','intro-take.json','intro-checks.txt','intro-stop.txt','intro-cadence-admission.json','intro-cadence-start.json','intro-cadence-end.json','intro-action-start.json','intro-state-before.json','intro-state-after.json','cadence-recording.json','compiler.stdout.log','compiler.stderr.log','server.stdout.log','server.stderr.log','client.stdout.log','client.stderr.log','city-route-receipt.json','city-route-steps.txt','city-bakery-receipt.json','city-train-before.json','city-train-after.json','city-preflight-complete.txt','nuget-module-receipt.json']
ENGINE=['acquisition-receipt.json','dependency-receipt.json','acquisition-failure.json','nuget-preparation-receipt.json','nuget-signature-receipt.json','nuget-runtime-receipt.json']
ENCODER=['encoder-proof-receipt.json','encode.stdout.log','encode.stderr.log','probe.stdout.log','probe.stderr.log','decode.stdout.log','decode.stderr.log']


class ArtifactAdmission(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        workflow=(HERE/'workflow.reference.txt').read_text(encoding='utf-8')
        actual=HERE.parent.parent/'.github/workflows/cloud-bakery-video-5161688.yml'
        if actual.exists():
            assert workflow==actual.read_text(encoding='utf-8')
        start=workflow.index("          $root = Join-Path")
        end=workflow.index('      - name: Retain native scene evidence',start)
        cls.block=textwrap.dedent(workflow[start:end])
        # Substitute fixture variables only in this filesystem-only block. Never
        # set/spoof real GitHub admission environment variables or run the entry.
        for a,b in [('$env:RUNNER_TEMP','$fixtureTemp'),('$env:GITHUB_RUN_ID','$fixtureRunId'),('$env:GITHUB_OUTPUT','$fixtureOutput')]:
            cls.block=cls.block.replace(a,b)

    def check(self,firewall=(),root=('receipt.json',),engine=(),encoder=(),sizes=None,flags=None):
        sizes=sizes or {};flags=flags or {}
        groups={}
        for group,names in [('root',root),('engine',engine),('encoder',encoder),('firewall',firewall)]:
            groups[group]=[dict(Name=n,FullName='C:\\mock-only\\'+group+'\\'+n,Length=sizes.get(n,100),
                                PSIsContainer=flags.get(n,{}).get('directory',False),
                                Attributes=flags.get(n,{}).get('attributes',0)) for n in names]
        fixture={'groups':groups,'run':RUN}
        script=r'''
param([string]$fixtureFile)
$ErrorActionPreference='Stop'
$fixture=[IO.File]::ReadAllText($fixtureFile) | ConvertFrom-Json
$fixtureTemp='C:\mock-only'
$fixtureRunId=$fixture.run
$fixtureOutput='C:\mock-only\output'
$script:groups=$fixture.groups
$script:copied=[Collections.Generic.List[string]]::new()
$script:ready=$false
function GroupFor($path) {
 if ($path -eq (Join-Path $fixtureTemp 'bakery-evidence')) { return 'root' }
 if ($path -eq (Join-Path $fixtureTemp 'firewall-evidence')) { return 'firewall' }
 if ($path -eq (Join-Path $fixtureTemp 'bakery-engine/encoder-evidence')) { return 'encoder' }
 return $null
}
function Test-Path { param($LiteralPath)
 $group=GroupFor $LiteralPath
 if ($null -ne $group) { return (@($script:groups.$group).Count -gt 0) }
 if ($LiteralPath -eq (Join-Path $fixtureTemp 'bakery-artifact')) { return $false }
 return (@($script:groups.engine | Where-Object { (Join-Path (Join-Path $fixtureTemp 'bakery-engine') $_.Name) -eq $LiteralPath }).Count -gt 0)
}
function Get-ChildItem { param($LiteralPath,[switch]$Force)
 $group=GroupFor $LiteralPath
 if ($null -eq $group) { throw 'unexpected_fixture_directory' }
 $script:groups.$group
}
function Get-Item { param($LiteralPath)
 $script:groups.engine | Where-Object { (Join-Path (Join-Path $fixtureTemp 'bakery-engine') $_.Name) -eq $LiteralPath }
}
function New-Item { param($ItemType,$Path) if ($ItemType -ne 'Directory') { throw 'unexpected_fixture_write' } }
function Copy-Item { param($LiteralPath,$Destination) [void]$script:copied.Add($LiteralPath) }
function Add-Content { param($LiteralPath,$Value,$Encoding) $script:ready=($Value -eq 'ready=true') }
$status='PASS'
try {
''' + self.block + r'''
} catch { $status='FAIL:'+$_.Exception.Message }
@{status=$status;ready=$script:ready;copied=@($script:copied.ToArray())} | ConvertTo-Json -Compress
'''
        with tempfile.TemporaryDirectory() as temp:
            p=Path(temp);(p/'fixture.json').write_text(json.dumps(fixture),encoding='utf-8')
            (p/'check.ps1').write_text(script,encoding='utf-8')
            result=subprocess.run(['pwsh','-NoLogo','-NoProfile','-NonInteractive','-File',str(p/'check.ps1'),str(p/'fixture.json')],
                                  text=True,capture_output=True,check=True,timeout=15)
        return json.loads(result.stdout) if result.stdout.strip() else {'status':'EMPTY_NO_UPLOAD','ready':False,'copied':[]}

    def success_files(self):
        return ['planned.json','active.json','cleanup.json']+[r+'.created.json' for r in RULES]+[r+'.PersistentStore.cleanup.json' for r in RULES]

    def accepted(self,files,**kwargs):
        result=self.check(files,**kwargs)
        self.assertEqual(result['status'],'PASS')
        self.assertTrue(result['ready'])
        self.assertTrue(all(any(p.endswith('\\'+f) for p in result['copied']) for f in files))
        return result

    def test_success_manifest_including_full_scene_and_dependency_evidence(self):
        result=self.accepted(self.success_files(),root=ROOT,engine=ENGINE,encoder=ENCODER)
        self.assertEqual(len(result['copied']),55)

    def test_creation_validation_failure_at_every_rule_and_store(self):
        for count in range(1,7):
            for store in ('PersistentStore','ActiveStore'):
                with self.subTest(count=count,store=store):
                    files=['planned.json','cleanup.json']+[r+'.created.json' for r in RULES[:count]]+[r+'.PersistentStore.cleanup.json' for r in RULES[:count]]+[RULES[count-1]+'.'+store+'.validation.json']
                    self.accepted(files)

    def test_runtime_validation_failure_is_the_sixteen_file_upper_bound(self):
        for store in ('PersistentStore','ActiveStore'):
            with self.subTest(store=store):
                files=self.success_files()+[RULES[-1]+'.'+store+'.validation.json']
                self.assertEqual(len(files),16)
                self.accepted(files,root=ROOT,engine=ENGINE,encoder=ENCODER)

    def test_cleanup_failures_and_unknown_ownership_retain_partial_manifests(self):
        # Failure before cleanup readback, unknown native cleanup, failed creation
        # identity, and partial receipt writes all retain the evidence that exists.
        for files in [[],['planned.json','cleanup.json'],
                      ['planned.json','active.json','cleanup.json']+[r+'.created.json' for r in RULES],
                      ['planned.json','cleanup.json']+[RULES[0]+'.created.json'],
                      self.success_files()[:-1],self.success_files()[:-2]]:
            with self.subTest(files=len(files)):
                self.accepted(files)
        for store in ('PersistentStore','ActiveStore'):
            # Native failure with unverified cleanup retains rules and the first
            # validation readback, without inventing cleanup readback files.
            files=['planned.json','active.json','cleanup.json']+[r+'.created.json' for r in RULES]+[RULES[0]+'.'+store+'.validation.json']
            self.accepted(files)
        files=self.success_files()+[RULES[0]+'.ActiveStore.validation.json']
        self.accepted(files,sizes={n:0 for n in files})

    def test_reject_disallowed_names_and_wrong_job_bindings(self):
        bad=[RULES[0]+'.ActiveStore.cleanup.json',RULES[0]+'.PersistentStore.other.json',
             RULES[0]+'.validation.json',RULES[0]+'.created.json.bak','unexpected.json',
             RULES[0].replace(RUN,'987654321')+'.created.json',
             RULES[0].replace('-1-','-2-')+'.created.json',
             RULES[0].replace('dm-exe','unrelated-exe')+'.created.json',
             RULES[0].replace('-v4','-v5')+'.created.json']
        for name in bad:
            with self.subTest(name=name):
                result=self.check([name])
                self.assertEqual(result['status'],'FAIL:Unexpected firewall evidence name.')
                self.assertFalse(result['ready']);self.assertEqual(result['copied'],[])

    def test_count_overflow_and_multiple_validation_failures_are_rejected(self):
        files=self.success_files()+[RULES[0]+'.PersistentStore.validation.json',RULES[1]+'.ActiveStore.validation.json']
        self.assertEqual(self.check(files)['status'],'FAIL:Firewall evidence count exceeded.')
        self.assertEqual(self.check(files[-2:])['status'],'FAIL:Multiple firewall validation failures.')

    def test_per_file_total_byte_and_metadata_limits_remain(self):
        self.accepted([],root=ROOT[:16],sizes={n:1048576 for n in ROOT[:16]})
        result=self.check([],root=ROOT[:17],sizes={n:1048576 for n in ROOT[:17]})
        self.assertEqual(result['status'],'FAIL:Artifact size/count bound.')
        self.assertEqual(self.check([],sizes={'receipt.json':1048577})['status'],'FAIL:Unexpected artifact data.')
        name=RULES[0]+'.PersistentStore.cleanup.json'
        for flag in ({'directory':True},{'attributes':1024}):
            with self.subTest(flag=flag):
                self.assertEqual(self.check([name],flags={name:flag})['status'],'FAIL:Unexpected artifact data.')

    def test_existing_global_count_bound_and_empty_artifact_behavior(self):
        # Synthetic boundary fixtures exercise the unchanged global count guard.
        all_allowed=ROOT+ENGINE+ENCODER
        eleven=self.success_files()[:11]
        self.accepted(eleven,root=all_allowed,engine=ENGINE,encoder=ENCODER)
        result=self.check(eleven+[self.success_files()[11]],root=all_allowed,engine=ENGINE,encoder=ENCODER)
        self.assertEqual(result['status'],'FAIL:Artifact size/count bound.')
        self.assertEqual(self.check([],root=[])['status'],'EMPTY_NO_UPLOAD')


if __name__=='__main__': unittest.main()

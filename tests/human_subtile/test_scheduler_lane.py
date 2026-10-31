"""Offline tests of paired scheduler evidence and workflow selection only."""
import copy
import hashlib
import importlib.util
import io
import itertools
import json
from pathlib import Path
import re
import tarfile
import unittest

HERE=Path(__file__).parent
def load(name,path):
    spec=importlib.util.spec_from_file_location(name,path)
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    return module
controller=load('scheduler_controller',HERE/'cloud_npc_controller.py')
scheduler=load('scheduler_contract',HERE/'cloud_wildlife_scheduler_draft.py')
sample=load('scheduler_samples',HERE/'test_wildlife_scheduler_draft.py')
HEAD='a'*40

def archive_pair(mutate=None):
    legacy=sample.receipt(False);smooth=sample.receipt(True)
    resource=dict(bytes=1,sha256='b'*64,mode=0o600)
    states={name:dict(before=resource,after=resource,changed=False,integrity_verified=True) for name in ('legacy','smooth')}
    phase=lambda deadline:dict(returncode=0,timed_out=False,oversized_log=False,deadline=deadline)
    summary=dict(head=HEAD,accepted=True,suite='scheduler',fixture_dme_only=True,scope=scheduler.SCOPE,
                 resource_states=states,artifacts={'human_subtile.rsc':resource},compile=phase(120),
                 comparison=scheduler.compare_pair(legacy,smooth,HEAD),results={
                     'legacy':dict(daemon=phase(90)),'smooth':dict(daemon=phase(90))})
    status=dict(head=HEAD,outcome='passed',phase='complete',fixture_dme_only=True,suite='scheduler',
                resource_copies_independent=True,runtime_resources=states)
    if mutate: mutate(legacy,smooth,status,summary)
    raws={k:json.dumps(v).encode() for k,v in (('legacy',legacy),('smooth',smooth))}
    for k in raws:summary['results'][k]['receipt_sha256']=hashlib.sha256(raws[k]).hexdigest()
    entries={'harness-status.json':json.dumps(status).encode(),'smoke-summary.json':json.dumps(summary).encode(),
             'npc-smoke/cloud-manifest.json':json.dumps(dict(head=HEAD,scheduler_scope=scheduler.SCOPE)).encode(),
             'npc-smoke/stage/compile-stdout.log':b'DM compiler version 516.1688\nhuman_subtile.dmb - 0 errors, 0 warnings\n',
             'npc-smoke/stage/compile-stderr.log':b''}
    for label,folder in (('legacy','runtime'),('smooth','runtime-wildlife')):
        prefix='npc-smoke/'+folder+'/'
        entries.update({prefix+'result.txt':b'PASS\n',prefix+'port-closed.txt':b'closed\n',prefix+'receipt.json':raws[label]})
    output=io.BytesIO()
    with tarfile.open(fileobj=output,mode='w:') as archive:
        for name,data in entries.items():
            info=tarfile.TarInfo(name);info.size=len(data);archive.addfile(info,io.BytesIO(data))
    return output.getvalue()

class SchedulerLaneTests(unittest.TestCase):
    def test_host_rechecks_both_receipts_and_comparison(self):
        controller.validate_scheduler_evidence(archive_pair(),HEAD)
        def corrupt_comparison(_legacy,_smooth,_status,summary):
            summary['comparison']['mosquito']['bite_count']+=1
        def truncate_samples(_legacy,smooth,_status,_summary):
            events=smooth['scheduler_rows'][0]['events']
            events[:]=[e for e in events if not (e['event']=='position_sample' and e['at']>75)]
        def merged_resources(_legacy,_smooth,status,_summary):
            status['resource_copies_independent']=False
        def bad_deadline(_legacy,_smooth,_status,summary):
            summary['results']['smooth']['daemon']['deadline']=91
        for mutate in (corrupt_comparison,truncate_samples,merged_resources,bad_deadline):
            with self.subTest(mutate=mutate.__name__):
                with self.assertRaises(RuntimeError):controller.validate_scheduler_evidence(archive_pair(mutate),HEAD)

    def test_selector_runs_only_one_manual_suite(self):
        text=(HERE.parents[1]/'.github/workflows/moving-save-chunks.yml').read_text()
        line=next(line for line in text.splitlines() if "github.repository == 'Civ13/Civ13'" in line)
        expression=line.split(' && ((',1)[1].split(')) && github.repository',1)[0]
        names=('wildlife_smoke','wildlife_extended','wildlife_bridge','wildlife_scheduler','wildlife_production_compile')
        for values in itertools.product((False,True),repeat=len(names)):
            candidate=expression
            for name,value in zip(names,values):candidate=candidate.replace('inputs.'+name,str(value))
            candidate=candidate.replace('true','True').replace('false','False').replace('&&','and').replace('||','or')
            self.assertEqual(bool(eval('((' + candidate + '))',{'__builtins__':{}})),sum(values)==1)
        self.assertIn("inputs.wildlife_scheduler == true && 'scheduler'",text)
        self.assertIn("inputs.wildlife_scheduler != true && inputs.wildlife_production_compile != true",text)

if __name__=='__main__':unittest.main()

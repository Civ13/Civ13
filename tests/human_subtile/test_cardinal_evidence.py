"""Synthetic host evidence checks. Never launches a native or Docker process."""
import copy
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import re
import tarfile
import tempfile
import types
import unittest
from unittest.mock import patch

HERE=Path(__file__).resolve().parent
ROOT=Path(os.environ.get('CARDINAL_OFFLINE_SOURCE_ROOT',HERE.parents[1])).resolve()
def load(name,path):
    spec=importlib.util.spec_from_file_location(name,path); result=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result); return result
stage=load('cardinal_stage',HERE/'cardinal_stage.py')
contract=load('cardinal_contract',HERE/'cardinal_contract.py')
random=load('random_cadence_contract',ROOT/'tests/human_subtile/random_cadence_contract.py')
evidence=load('cardinal_evidence',HERE/'cardinal_evidence.py')
rows=load('cardinal_rows',HERE/'test_cardinal_contract.py')
HEAD='a'*40


class Adaptor:
    @staticmethod
    def adapt(out,manifest,rel,old,new):
        path=out/'stage'/rel; text=path.read_text(encoding='utf-8')
        if text.count(old)!=1: raise ValueError('preimage')
        path.write_text(text.replace(old,new,1),encoding='utf-8',newline='\n')


def test_data():
    sources={rel:(ROOT/rel).read_bytes() for rel in (stage.MOVEMENT,*stage.EXPECTED_SPECIES_BLOBS,
             stage.PROBE,stage.RANDOM_FIXTURE,stage.CORE)}
    sources[stage.CARDINAL_FIXTURE]=(HERE/'cardinal_probe.dm').read_bytes()
    sources['civ13.dme']=b'#include "code/world.dm"\n#include "maps/unused.dmm"\n'
    with tempfile.TemporaryDirectory() as tmp:
        out=Path(tmp); dest=out/'stage'; dest.mkdir()
        for rel,raw in sources.items():
            target=dest/rel; target.parent.mkdir(parents=True,exist_ok=True); target.write_bytes(raw)
        probe=dest/stage.PROBE; text=probe.read_text()
        text=text.replace('\t\t\thuman_subtile_fixture_headless()','\t\t\tnpc_subtile_fixture()',1)
        text=text.replace('"checks" = human_subtile_fixture_checks,',
             '"checks" = human_subtile_fixture_checks, "npc_checks" = npc_subtile_checks, "npc_rows" = npc_subtile_rows,',1)
        probe.write_text(text,encoding='utf-8',newline='\n')
        dme=re.sub(r'^#include ".*\.dmm"\s*$', '', sources['civ13.dme'].decode(),flags=re.M)
        dme+='\n#include "tests\\human_subtile\\mining.dm"\n#include "tests\\human_subtile\\probe.dm"\n'
        dme+='\n#include "tests\\human_subtile\\npc.dm"\n'
        (dest/'human_subtile.dme').write_text(dme,encoding='utf-8',newline='\n')
        manifest={'head':HEAD,'dme':'stage/human_subtile.dme','stage_files':{
            rel:{'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest()} for rel,raw in sources.items()}}
        stage.adapt(out,manifest,Adaptor,random,contract.SCOPE)
    def whole(mode):
        cases=[rows.receipt(mode,.5,lag) for lag in contract.LAGS]
        for row in cases:
            row['started']+=1; row['ended']+=1
            for event in row['events']: event['at']+=1
        return {'head':HEAD,'error':None,'port':0,'byond_version':516,'byond_build':1688,'scope':contract.SCOPE,
                'mode':mode,'tick':.5,'overflow':False,'movement_blob':contract.SOURCE_MOVEMENT_BLOB,
                'setup':{'requested_tick':.5,'actual_tick':.5,'startup_time':0,'ready_time':.5,
                         'startup_usage':10000,'ready_usage':1},'rows':cases}
    receipts={mode:whole(mode) for mode in contract.MODES}
    resource={'bytes':3,'sha256':'b'*64,'mode':0o600}
    states={mode:{'before':resource,'after':resource,'changed':False,'integrity_verified':True} for mode in contract.MODES}
    phase=lambda deadline: {'returncode':0,'timed_out':False,'oversized_log':False,'deadline':deadline,'seconds':1}
    encoded={mode:json.dumps(receipts[mode]).encode() for mode in contract.MODES}
    results={mode:{'daemon':phase(60),'receipt_sha256':hashlib.sha256(encoded[mode]).hexdigest()} for mode in contract.MODES}
    summary={'head':HEAD,'suite':'cardinal05','tick':.5,'fixture_dme_only':True,'observation_complete':True,
             'parity_established':False,'scope':contract.SCOPE,'compile':phase(90),'resource_states':states,
             'artifacts':{'human_subtile.rsc':resource},'results':results,'comparison':contract.compare(receipts,HEAD,.5),
             'limits':{'compile_seconds':90,'daemon_seconds':60,'setup_seconds':60,'work_seconds':490,'whole_seconds':600},
             'child_elapsed':3,'comparison_elapsed':4,'setup_seconds':1}
    status={'head':HEAD,'suite':'cardinal05','phase':'complete','outcome':'passed','fixture_dme_only':True,
            'runtime_resources':states}
    files={'harness-status.json':json.dumps(status).encode(),'smoke-summary.json':json.dumps(summary).encode(),
           'npc-smoke/cloud-manifest.json':json.dumps(manifest).encode(),
           'npc-smoke/stage/compile-stdout.log':b'0 errors, 0 warnings\n','npc-smoke/stage/compile-stderr.log':b''}
    for mode,folder in (('legacy','runtime'),('smooth','runtime-wildlife')):
        prefix='npc-smoke/'+folder+'/'
        for name,value in (('receipt.json',encoded[mode]),('result.txt',b'PASS\n'),('port-closed.txt',b'closed\n'),
                           ('runtime.log',b''),('daemon-stdout.log',b''),('daemon-stderr.log',b'')): files[prefix+name]=value
    files.update({f'abi/abi-{i}-{part}.log':b'' for i in range(6) for part in ('stdout','stderr')})
    return sources,files


def package(files):
    result=io.BytesIO()
    with tarfile.open(fileobj=result,mode='w') as tar:
        for name,data in files.items():
            row=tarfile.TarInfo(name); row.size=len(data); tar.addfile(row,io.BytesIO(data))
    return result.getvalue()


class CardinalEvidenceTests(unittest.TestCase):
    def test_complete_and_negative_packages(self):
        sources,files=test_data()
        fake_npc=types.SimpleNamespace(current=types.SimpleNamespace(legacy=types.SimpleNamespace(validate_compile=lambda *_:None)))
        modules={'cardinal_stage':stage,'cardinal_contract':contract,'random_cadence_contract':random,'run-npc':fake_npc}
        def source(cmd,**kwargs): return sources[cmd[-1].split(':',1)[1]]
        with patch.object(evidence,'module',side_effect=lambda name:modules[name]), patch.object(evidence.subprocess,'check_output',side_effect=source), \
             patch.object(contract,'validate_source',return_value=True) as binding:
            evidence.validate(package(files),HEAD,'cardinal05',['git'],{})
            binding.assert_called_once_with(['git'],{},HEAD)
            for mutate in (lambda x:x.pop('npc-smoke/runtime/receipt.json'),
                           lambda x:x.update({'npc-smoke/runtime/unexpected.txt':b'x'}),
                           lambda x:x.update({'npc-smoke/runtime/receipt.json':b'{}'}),
                           lambda x:x.update({'npc-smoke/cloud-manifest.json':b'{}'})):
                bad=copy.deepcopy(files); mutate(bad)
                with self.assertRaises((ValueError,KeyError)): evidence.validate(package(bad),HEAD,'cardinal05',['git'],{})


if __name__=='__main__': unittest.main()

"""Copy bounded diagnostic/receipt allowlist only. Never retain source trees/saves/binaries."""
import argparse,hashlib,json
from pathlib import Path
MAX_FILE=8*1024**2
MAX_TOTAL=64*1024**2
MAX_FILES=512
TOP=('preparation.json','result.json','runtime-binding.json','compiled.json','mode-results.json')
COMPILE=('compile-start.json','compile-started.json','compile-process.json','compile.log','zone-1688.dme','zone-1688-probe.dm','zone-1688-startup-0.dm','zone-1688-startup-1.dm')
MODE_FILES=('daemon-start.json','daemon-started.json','daemon-process.json','zone-result.json','zone-failure.txt','probe-port-closed.json','listener-census.json','negative-prediction.json','zone-negative-setup.json','input-hashes.json','output-hashes.json','runtime.log','daemon.log')
MODES=('write','read','write-sequence','read-sequence','legacy-write','legacy-read','duplicate-spawn','stale-zone','wrong-z','fractional','duplicate-zone','absent-zone','incomplete','overlong')
ACQUISITION=('source-identity.txt','controller-identity.txt','controller-paths.txt','download.json','archive.sha256')
TOOLING=('run.py','prepare.py','oracle.py','owned_process_1688.py','collect_evidence.py','test_proposal.py','test_workflow.py')

def collect(evidence,acquisition,tooling,output):
 if output.exists():raise ValueError('Fresh retained directory required')
 output.mkdir(parents=True);candidates=[]
 for name in TOP:candidates.append((evidence/name,'receipts/'+name))
 for name in ACQUISITION:candidates.append((acquisition/name,'acquisition/'+name))
 for name in TOOLING:candidates.append((tooling/name,'tooling/'+name))
 for name in COMPILE:candidates.append((evidence/'source'/name,'compile/'+name))
 for mode in MODES:
  root=evidence/'runs'/mode
  for name in MODE_FILES:candidates.append((root/name,'runs/'+mode+'/'+name))
 # Fixed receipts precede optional extra logs, so extras cannot crowd them out.
 extras_truncated=False
 for mode in MODES:
  root=evidence/'runs'/mode
  if root.is_dir() and not root.is_symlink():
   for p in root.rglob('*.log'):
    if p.parent==root and p.name in MODE_FILES:continue
    if len(candidates)>=MAX_FILES:
     extras_truncated=True;break
    candidates.append((p,'runs/'+mode+'/'+p.relative_to(root).as_posix()))
 kept=[];missing=[];rejected=[{'path':'extra-log-inventory','reason':'candidate count bound reached'}] if extras_truncated else [];total=0
 for source,relative in candidates:
  if not source.exists() and not source.is_symlink():missing.append(relative);continue
  try:
   if source.is_symlink() or any(p.is_symlink() for p in source.parents) or not source.is_file():raise ValueError('not a regular non-symlink file')
   if len(relative.encode())>512:raise ValueError('evidence path length bound exceeded')
   size=source.stat().st_size
   if size>MAX_FILE or total+size>MAX_TOTAL-1024**2 or len(kept)>=MAX_FILES:raise ValueError('evidence bound exceeded')
   data=source.read_bytes()
   if len(data)!=size:raise ValueError('file changed during staging')
   target=output/relative;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(data);total+=size
   kept.append({'path':relative,'bytes':size,'sha256':hashlib.sha256(data).hexdigest()})
  except (OSError,ValueError) as error:rejected.append({'path':relative[:200],'reason':str(error)[:200]})
 report={'status':'bounded-evidence-staged' if not rejected else 'partial-evidence-rejected','bytes':total,'limits':{'file':MAX_FILE,'total':MAX_TOTAL,'files':MAX_FILES},'files':kept,'missing':missing,'rejected':rejected,'native_execution_performed_by_collector':False}
 (output/'retention.json').write_text(json.dumps(report,indent=2))
 return report

def main():
 p=argparse.ArgumentParser(description=__doc__)
 for name in ('evidence','acquisition','tooling','output'):p.add_argument('--'+name,required=True,type=Path)
 a=p.parse_args();report=collect(a.evidence,a.acquisition,a.tooling,a.output)
 if report['rejected']:raise SystemExit(1)
if __name__=='__main__':main()

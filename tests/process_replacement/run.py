"""Production scheduler replacement regression, with compiler-free preparation."""
import argparse, hashlib, json, os, re, subprocess, tempfile
from pathlib import Path
BASELINE = "112e80ba4bc0f5af417b46532a4718aba9601ca5"
PATHS = ["code/processes/__processScheduler.dm", "code/processes/_process.dm", "code/processes/chemistry.dm", "code/processes/___defines.dm"]
def proc(source, header):
    match = re.search(r"^" + re.escape(header) + r"[^\n]*\n[\s\S]*?(?=^/[^/]|\Z)", source, re.M)
    if not match: raise RuntimeError("Missing production procedure: " + header)
    return match.group().rstrip()+"\n"
def prepare(repo, baseline=False, control=None):
    raw = [subprocess.check_output(["git","show",BASELINE+":"+path],cwd=repo,text=True) if baseline else (repo/path).read_text() for path in PATHS]
    scheduler = "\n".join(proc(raw[0], "/processScheduler/proc/"+name+"(") for name in ["addProcess","replaceProcess","restartProcess","setIdleProcessState","setQueuedProcessState","setRunningProcessState","recordStart","recordEnd","recordRunTime","calculate_run_time_allowance","get_priority_ordered_processes"])
    process = "\n".join(proc(raw[1], "/process/proc/"+name+"(") for name in ["_copyStateFrom","idle","running","queued","setStatus","kill"])
    chemistry = "\n".join(proc(raw[2], "/process/chemistry/"+name+"(") for name in ["setup","fire","reset_current_list"])
    # Observe setup calls, without changing any setup effect.
    chemistry = chemistry.replace("/process/chemistry/setup()\n", "/process/chemistry/setup()\n\tsetup_calls++\n",1)
    if "/process/chemistry/copyStateFrom(" in raw[2]:
        chemistry += proc(raw[2], "/process/chemistry/copyStateFrom(")
    if control:
        marker = {"bookkeeping": "replacement owners", "configuration": "replacement configuration", "chemistry": "replacement chemistry"}[control]
        combined = scheduler+process+chemistry
        begin,end = "\t// BEGIN "+marker, "\t// END "+marker
        assert combined.count(begin)==combined.count(end)==1, "Control anchors changed"
        combined = re.sub(re.escape(begin)+r"[\s\S]*?"+re.escape(end), "", combined, count=1)
    else: combined = scheduler+process+chemistry
    defines = "\n".join(line for line in raw[3].splitlines() if line.startswith("#define"))
    return raw,defines,combined

def main():
    p=argparse.ArgumentParser()
    p.add_argument("--byond-bin",type=Path)
    p.add_argument("--baseline",action="store_true")
    p.add_argument("--negative-control",choices=["bookkeeping","configuration","chemistry"])
    p.add_argument("--prepare-only",action="store_true")
    p.add_argument("--evidence-dir",type=Path)
    a=p.parse_args()
    if a.baseline and a.negative_control: p.error("Choose one control")
    if not a.prepare_only and not a.byond_bin: p.error("Native execution requires --byond-bin")
    repo=Path(__file__).resolve().parents[2]
    raw,defines,source=prepare(repo,a.baseline,a.negative_control)
    head=subprocess.check_output(["git","rev-parse","HEAD"],cwd=repo,text=True).strip()
    status=subprocess.check_output(["git","status","--porcelain"],cwd=repo,text=True)
    patch=subprocess.check_output(["git","diff","HEAD"],cwd=repo)
    with tempfile.TemporaryDirectory(prefix="civ13-process-replacement-") as directory:
        out=a.evidence_dir or Path(directory)
        out.mkdir(parents=True,exist_ok=True)
        if any(out.iterdir()): p.error("Evidence directory must be fresh")
        fixture=Path(__file__).with_name("probe.dm").read_text()
        for name,data in [("production.dm",source),("defines.dm",defines),("probe.dm",fixture),("probe.dme",'#include "defines.dm"\n#include "probe.dm"\n#include "production.dm"\n')]:
            (out/name).write_text(data)
        for path,data in zip(PATHS,raw): (out/("original-"+Path(path).name)).write_text(data)
        (out/"dirty.patch").write_bytes(patch)
        (out/"metadata.json").write_text(json.dumps({"head":head,"source_commit":BASELINE if a.baseline else head,"status":status,"baseline":a.baseline,"control":a.negative_control,"prepare_only":a.prepare_only,"source_hashes":dict(zip(PATHS,[hashlib.sha256(x.encode()).hexdigest() for x in raw])),"compiled_source_hash":hashlib.sha256(source.encode()).hexdigest(),"fixture_hash":hashlib.sha256(fixture.encode()).hexdigest()},indent=2))
        if a.prepare_only:
            print("PREPARED ONLY: no native compilation or execution",out)
            return
        flags=subprocess.CREATE_NO_WINDOW if os.name=="nt" else 0
        compiler=a.byond_bin/("dm.exe" if os.name=="nt" else "DreamMaker")
        daemon=a.byond_bin/("dd.exe" if os.name=="nt" else "DreamDaemon")
        build=subprocess.run([str(compiler),"-max_errors","0","probe.dme"],cwd=out,capture_output=True,text=True,timeout=60,creationflags=flags)
        log=build.stdout+build.stderr
        (out/"compile.log").write_text(log);print(log,flush=True)
        assert build.returncode==0 and "516.1681" in log and "0 errors, 0 warnings" in log,"Pinned native compilation failed"
        run=subprocess.run([str(daemon),"probe.dmb","-invisible","-close","-safe","-log","runtime.log"],cwd=out,capture_output=True,timeout=30,creationflags=flags)
        (out/"daemon.log").write_bytes(run.stdout+run.stderr)
        log=(out/"runtime.log").read_text(errors="replace")+(run.stdout+run.stderr).decode(errors="replace")
        print(log,flush=True)
        assert run.returncode==0 and not re.search(r"runtime error|RUNTIME|Bad ref|Bad loc|BUG:|## ERROR:|Cannot read null|Cannot execute null|Infinite loop suspected",log,re.I),"Native diagnostics invalidate evidence"
        result=json.loads((out/"native-result.json").read_text())
        expected={"baseline":{"owners","config","chemistry","snapshot"},"bookkeeping":{"owners"},"configuration":{"config"},"chemistry":{"chemistry","snapshot"}}
        mode="baseline" if a.baseline else a.negative_control
        assert result["replacements"]==39 and result["checks"]>=300 and set(result["faults"])==(expected[mode] if mode else set()),result
        print("PASS expected historical/omission faults" if mode else "PASS production replacement")
if __name__=="__main__": main()

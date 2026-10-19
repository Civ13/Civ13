"""Prepare typed gather fixtures only. Never import an adapter or launch native code."""
import argparse
import hashlib
import json
from pathlib import Path
import re

from compile_check import compile_dme, prepare as prepare_closure
from prepare_native import git, without_comments
from wait_overlay import unguarded_source

PROFILES = ("stock", "disabled", "enabled_null", "enabled", "omit_entry",
            "omit_wake", "omit_final", "reacquire", "ambient", "omit_forward")
FAILURES = {"omit_entry": "entry_denied_before_callbacks",
            "omit_wake": "wake_cancel_before_completion",
            "omit_final": "zero_delay_final_denied",
            "reacquire": "old_context_stays_revoked",
            "ambient": "ordinary_wait_isolated",
            "omit_forward": "cancelled_canonical_gather_stops_early"}
ADAPTER_HASHES = {"windows.py": "dfeea950337a2176468a4a1ff62674b71652c1789e1cfae0e2bb410edfef122a",
                  "guard_config.py": "ee5db97cabe3bcb2d8acb6660d67bbb56ee1f82052f96da00d54b13756615d35"}
DRIVER_COMMIT = "22e2f57edeffe7a4d8d3a5e7c0236e92239313e0"
DRIVER_PATH = "tests/world_save/run-contained-dimension.py"
DRIVER_HASH = "19c2987130e6b62c9d05f33c8b0a59644ba716d62052700fc24df16d360a412e"
BINARIES = {"dm.exe": "8ad7537fc1329ada04e8e1e8835ec9cf205f3e5029461a3ead1f8f4ced7b0bb8",
            "dd.exe": "7b148eceaaae483395b636fab817609b37f8fb852f1d5aad12d29bbcaf1585ae"}
LIMITS = {"compile_seconds": 120, "runtime_seconds": 90, "cleanup_seconds": 10,
          "total_seconds": 2400, "compile_cpu_seconds": 60, "runtime_cpu_seconds": 30,
          "compile_private_bytes": 1024**3, "runtime_private_bytes": 512*1024**2, "watcher_private_bytes": 128*1024**2,
          "log_bytes": 2*1024**2, "world_tick_ceiling": 800, "active_processes": 1}
PORT = 59477
NAMES_SOURCE = "code/names.dm"
NAME_FILE_LIMIT = 128*1024
NAME_TOTAL_LIMIT = 2*1024**2


def digest(data):
    return hashlib.sha256(data).hexdigest()


def name_dependencies(source):
    """Restricted audit of unconditional public preload calls, not arbitrary paths."""
    source = without_comments(source)
    if re.search(r"\b(file2text|return_file_text|flist|file)\s*\(", source):
        raise ValueError("unreviewed public preload reader")
    calls = re.findall(r"\bfile2list\s*\(", source)
    paths = []
    for line in source.splitlines():
        if not re.search(r"\bfile2list\s*\(", line):
            continue
        match = re.fullmatch(r'var/list/[a-zA-Z_0-9]+\s*=\s*file2list\s*\(\s*"(config/names/[a-z_]+\.txt)"\s*\)\s*', line)
        if not match:
            raise ValueError("public name preload syntax/path drift")
        paths.append(match[1])
    if not 1 <= len(calls) == len(paths) <= 192:
        raise ValueError("public name preload count/bound drift")
    return tuple(sorted(set(paths)))


def runtime_inputs(read, names_source):
    """Read only exact frozen Git blobs. No working-tree config or credentials."""
    files = {path: read(path) for path in (*name_dependencies(names_source), "rust_g.dll")}
    names = [data for path, data in files.items() if path != "rust_g.dll"]
    if (not all(data.strip() and len(data) <= NAME_FILE_LIMIT for data in names)
            or sum(map(len, names)) > NAME_TOTAL_LIMIT or not files["rust_g.dll"]):
        raise ValueError("public runtime dependency empty or exceeds bound")
    return files


def replace_once(source, old, new):
    if source.count(old) != 1:
        raise ValueError("gather fixture anchor drift: " + old[:70])
    return source.replace(old, new, 1)


def variants(helper, grass, profile):
    if profile not in PROFILES:
        raise ValueError("unknown typed gather profile")
    unguarded_source(helper)  # Exact reviewed helper, including supplied-only capture.
    grass = replace_once(grass, "\treturn user && user.client\n",
                         "\treturn istype(user, /mob/living/human/gather_probe) // HEADLESS CLIENT SEAM\n")
    guards = {"omit_entry": "\t\tif (!gameplay_lease.claim_gather_wait(user, target))\n\t\t\treturn FALSE\n",
              "omit_wake": "\t\tif (gameplay_lease && !gameplay_lease.valid())\n\t\t\t. = FALSE\n\t\t\tbreak\n",
              "omit_final": "\tif (gameplay_lease && !gameplay_lease.valid())\n\t\t. = FALSE\n"}
    if profile in guards:
        helper = replace_once(helper, guards[profile], "")
    elif profile == "reacquire":
        # Deliberately unsafe: rescues an old invocation with a new service lease.
        start = helper.index("/mob/var/may_do_after = TRUE\n")
        helper = helper[:start] + replace_once(helper[start:], "\t\tsleep(0.1)\n", "\t\tsleep(0.1)\n#ifdef CIV13_GAMEPLAY_BRIDGE\n\t\tgameplay_lease = gameplay_bridge.action_lease\n#endif\n")
    elif profile == "ambient":
        helper = replace_once(helper, "\tif (!isnull(gameplay_context))\n",
                              "\tif (isnull(gameplay_context))\n\t\tgameplay_context = gameplay_bridge.action_lease\n\tif (!isnull(gameplay_context))\n")
    elif profile == "omit_forward":
        grass = replace_once(grass, "\tvar/completed = grass_cutting_wait(user, gameplay_context)\n",
                             "\tvar/completed = grass_cutting_wait(user)\n")
    return helper, grass


def fixture_dme(dme, profile):
    mode = profile if profile in ("stock", "disabled") else "enabled"
    result = compile_dme(dme, "gather_"+mode)
    result = replace_once(result, "code\\_helpers\\mobs.dm", "gather_generated/"+profile+"_mobs.dm")
    return replace_once(result, "code\\game\\turfs\\floor_attackby.dm", "gather_generated/"+profile+"_grass.dm")


def bindings(adapter_dir, contained_repo):
    adapter_dir, contained_repo = Path(adapter_dir).resolve(), Path(contained_repo).resolve()
    files = {}
    for name, expected in ADAPTER_HASHES.items():
        path = adapter_dir / name
        if digest(path.read_bytes()) != expected:
            raise ValueError("reviewed Windows Job adapter drift: " + name)
        files[name] = {"path": str(path), "sha256": expected}
    raw = git(contained_repo, "show", DRIVER_COMMIT+":"+DRIVER_PATH)
    if digest(raw) != DRIVER_HASH:
        raise ValueError("reviewed containment driver drift")
    return {"adapter": files, "reference_driver": {"repository": str(contained_repo),
            "commit": DRIVER_COMMIT, "path": DRIVER_PATH, "sha256": DRIVER_HASH},
            "binaries": BINARIES, "limits": LIMITS,
            "contract": ["core-only separately granted execution", "fresh runtime identity/census before admission",
                         "exact frozen packet and executable hashes", "retained image/creation identity",
                         "create suspended; assign and verify Job before resume", "one-active-process/no-breakaway/kill-on-close",
                         "only owned fixed127.0.0.1:59477 TCP LISTEN permitted; strict OS socket guard throughout",
                         "deny actual client.New before all production game-entry hooks",
                         "record UDP/account traffic residual risk", "no network isolation claim",
                         "phase CPU/wall/memory/log budgets and cleanup reserve", "sequential profiles; no child workers",
                         "exit plus settled Job active0; retained-handle cleanup and receipt even on failure",
                         "existing held game is never targeted; no process-name kill or fallback"]}


def prepare(root, output, expected, adapter_dir, contained_repo):
    root, output = Path(root).resolve(), Path(output).resolve()
    external = bindings(adapter_dir, contained_repo)  # Read/hash only; no adapter import.
    source = prepare_closure(root, output, expected)
    read = lambda p: git(root, "show", expected+":"+p).decode("utf-8-sig").replace("\r\n", "\n")
    helper, grass, dme = (read(p) for p in ("code/_helpers/mobs.dm", "code/game/turfs/floor_attackby.dm", "civ13.dme"))
    dependencies = runtime_inputs(lambda p: git(root, "show", expected+":"+p), read(NAMES_SOURCE))
    generated = source / "gather_generated"
    generated.mkdir()
    plans = []
    for profile in PROFILES:
        h, g = variants(helper, grass, profile)
        (generated/(profile+"_mobs.dm")).write_text(h, encoding="utf-8", newline="\n")
        (generated/(profile+"_grass.dm")).write_text(g, encoding="utf-8", newline="\n")
        (source/("gather_"+profile+".dme")).write_text(fixture_dme(dme, profile), encoding="utf-8", newline="\n")
        runtime = output / "runtime" / profile
        runtime.mkdir(parents=True)
        # Global name preloads run before isolated world.New. Exact public blobs only.
        for relative, data in dependencies.items():
            target = runtime / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
        plans.append({"name":profile, "status":"not_run", "dme":"source/gather_"+profile+".dme",
                      "runtime_cwd":"runtime/"+profile, "expected_failure":FAILURES.get(profile),
                      "compiler_argv":["<pinned-dm.exe>","-max_errors","0","gather_"+profile+".dme"],
                      "copy_after_compile":["gather_"+profile+".dmb","gather_"+profile+".rsc"],
                      "daemon_argv_after_separate_grant":["<pinned-dd.exe>","gather_"+profile+".dmb",str(PORT),"-ip","127.0.0.1","-invisible","-close","-safe","-params","tested_commit="+expected+"&profile="+profile,"-log","runtime.log"]})
    if git(root,"rev-parse","HEAD").decode().strip() != expected or git(root,"status","--porcelain","--untracked-files=no").strip():
        raise ValueError("source changed while preparing typed gather packet")
    files = {p.relative_to(output).as_posix():digest(p.read_bytes()) for p in sorted(output.rglob("*")) if p.is_file() and p != output/"manifest.json"}
    manifest = {"schema":2, "kind":"typed_gather", "commit":expected, "state":"prepared_not_executed",
                "native_lease":None, "compiler":"not_run", "runtime":"not_run", "dimensions":[9,9,1],
                "positive_client_acceptance":False, "profiles":plans, "executor":external, "sha256":files,
                "runtime_dependencies":{path:digest(data) for path,data in dependencies.items()},
                "seams":["isolated global/world startup", "original client.New definitions removed in generated copies; one denied fixture entry",
                         "human New returns without parent; no production constructor/anatomy/Life",
                         "generated grass connected-client predicate only", "headless service active/visible identity only",
                         "callback observer calls actual parent before final-phase cancellation"],
                "unsupported":["agent Join", "normal non-admin consent/bootstrap/E2E", "native filtering/LOS", "water/craft waits", "whole-game survival"],
                "budget_status":"2400seconds aggregate proposed only; no prior grant inherited",
                "requires_new_grant":["exact packet digest and current held-host PID/creation census", "fixed loopback59477 socket guard",
                                     "explicit account/UDP residual-risk disposition", "existing core retained-handle executor contract"]}
    (output/"manifest.json").write_text(json.dumps(manifest,indent=2),encoding="utf-8")
    return manifest


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output",type=Path,required=True)
    parser.add_argument("--expected-commit",required=True)
    parser.add_argument("--adapter-dir",type=Path,required=True)
    parser.add_argument("--contained-repo",type=Path,required=True)
    args=parser.parse_args()
    manifest=prepare(Path(__file__).resolve().parents[2],args.output,args.expected_commit,args.adapter_dir,args.contained_repo)
    print(json.dumps({"commit":manifest["commit"],"state":manifest["state"],"files":len(manifest["sha256"])}))


if __name__ == "__main__": main()

"""Hash and assertion-content checks only. No native launch or execution authority."""
import argparse
import hashlib
import json
from pathlib import Path

from check_native_packet import inside, require
from prepare_gather import PROFILES, FAILURES, LIMITS, ADAPTER_HASHES, DRIVER_HASH, BINARIES

ORDINARY = {"closed_port", "headless_setup", "ordinary_paid_gather", "ordinary_zero_delay",
            "ordinary_false_first_returns", "stock_false_first_early_unlock",
            "stock_overlap_after_early_unlock", "ordinary_overlap_balanced"}
TYPED = {"typed_gather_setup", "forged_type_denied", "one_use_first_claim", "one_use_replay_denied",
         "one_use_nested_denied", "entry_denied_before_callbacks", "wake_cancel_before_completion",
         "first_wake_cancelled", "zero_delay_final_denied", "positive_delay_final_denied",
         "old_context_stays_revoked", "new_context_not_claimed", "ordinary_wait_isolated",
         "cancelled_canonical_gather_stops_early", "cancelled_canonical_no_late_effect", "explicit_gather_paid_output"}
TYPED |= {"invalid_"+fault+"_denied" for fault in ("body","target","kind","owner","generation","pointer","request")}
STATE = {"duration_at_least_30":1, "cuttings_added":2, "turf_is_dirt":1,
         "tool_retained":1, "callback_starts":5, "callback_finishes":5, "balanced":1}


def verify_packet(root, commit, manifest_sha256):
    root=Path(root).resolve()
    raw=(root/"manifest.json").read_bytes()
    require(hashlib.sha256(raw).hexdigest()==manifest_sha256,"manifest digest mismatch")
    manifest=json.loads(raw)
    require(manifest["schema"]==2 and manifest["kind"]=="typed_gather" and manifest["commit"]==commit,"packet provenance")
    require(manifest["state"]=="prepared_not_executed" and manifest["native_lease"] is None and
            manifest["compiler"]=="not_run" and manifest["runtime"]=="not_run" and
            manifest["positive_client_acceptance"] is False,"preparation must not claim execution")
    plans=manifest["profiles"]
    require(len(plans)==len(PROFILES) and [p["name"] for p in plans]==list(PROFILES),"exact ordered profiles required")
    for p in plans:
        name=p["name"]
        require(p["status"]=="not_run" and p["expected_failure"]==FAILURES.get(name) and
                p["dme"]=="source/gather_"+name+".dme" and p["runtime_cwd"]=="runtime/"+name,"profile drift")
    executor=manifest["executor"]
    require(executor["limits"]==LIMITS and executor["binaries"]==BINARIES and
            {name:row["sha256"] for name,row in executor["adapter"].items()}==ADAPTER_HASHES and
            executor["reference_driver"]["sha256"]==DRIVER_HASH,"executor binding drift")
    for relative,expected in manifest["sha256"].items():
        path=inside(root,relative)
        require(path.is_file() and hashlib.sha256(path.read_bytes()).hexdigest()==expected,"file binding drift: "+relative)
    require(any(p.endswith("/gather_probe.dm") for p in manifest["sha256"]),"fixture missing")
    require(not any(p.startswith("source/config/") for p in manifest["sha256"]),"server config forbidden")
    return manifest


def verify_result(result, profile, commit):
    require(profile in PROFILES and result["commit"]==commit and result["profile"]==profile,"result provenance")
    require(all(type(result[key]) in (bool,int) and result[key] in (0,1)
                for key in ("passed","runtime_error","positive_client_acceptance")),"malformed result flags")
    require(result["byond_version"]==516 and result["byond_build"]==1681 and
            result["dimensions"]==[9,9,1] and not result["port"] and not result["runtime_error"] and
            not result["positive_client_acceptance"],"version/isolation/runtime/client claim")
    rows=result["checks"]
    require(type(rows) is list and 1<=len(rows)<=64,"bounded assertions required")
    require(all(type(r["tick"]) in (int,float) and 0<=r["tick"]<800 and
                type(r["passed"]) in (bool,int) and r["passed"] in (0,1) and
                r["assertion"] in ORDINARY|TYPED for r in rows),"unknown or out-of-budget assertion")
    require(all(rows[i]["tick"]<=rows[i+1]["tick"] for i in range(len(rows)-1)),"nonmonotonic assertions")
    names=[r["assertion"] for r in rows]
    require(len(names)==len(set(names)),"duplicate assertion")
    passed={r["assertion"] for r in rows if r["passed"]}
    failed=[r["assertion"] for r in rows if not r["passed"]]
    require(ORDINARY<=passed and result["ordinary_state"]==STATE,"ordinary setup/parity state incomplete")
    metrics=result["metrics"]
    require(type(metrics) is dict and len(metrics)<=12 and
            all(type(v) in (int,float) and 0<=v<800 for v in metrics.values()) and
            metrics.get("ordinary_gather_ticks",0)>=30,"missing paid duration metrics")
    if profile in FAILURES:
        expected=FAILURES[profile]
        require("typed_gather_setup" in passed and not result["passed"] and
                result["failed_assertion"]==expected and failed==[expected] and names[-1]==expected,
                "mutation did not fail its exact oracle")
    else:
        require(result["passed"] and not result["failed_assertion"] and not failed and
                (profile!="enabled" or TYPED<=passed),"missing or failed positive oracle")
        if profile=="enabled":
            require(metrics.get("explicit_gather_ticks",0)>=30 and metrics.get("entry_ticks")==0 and
                    metrics.get("final_ticks")==0 and metrics.get("final_wait_ticks",0)>=30 and
                    0<metrics.get("first_wake_ticks",800)<3 and 0<metrics.get("wake_ticks",800)<30 and
                    0<metrics.get("old_new_ticks",800)<30 and 0<metrics.get("canonical_cancel_ticks",800)<30,
                    "missing cancellation phase/duration metrics")


def verify_results(root, manifest):
    # Content checks do not verify process containment or authorize execution.
    results={}
    for profile in PROFILES:
        path=Path(root)/"runtime"/profile/"result.json"
        require(path.stat().st_size<=32768,"result byte bound")
        result=json.loads(path.read_text(encoding="utf-8"))
        verify_result(result,profile,manifest["commit"])
        results[profile]=result
    require(results["stock"]["ordinary_state"]==results["disabled"]["ordinary_state"]==results["enabled_null"]["ordinary_state"],"stock/disabled/enabled-null parity failed")
    return sorted(results)


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("packet",type=Path)
    p.add_argument("--expected-commit",required=True)
    p.add_argument("--manifest-sha256",required=True)
    p.add_argument("--result-content-only",action="store_true")
    args=p.parse_args()
    manifest=verify_packet(args.packet,args.expected_commit,args.manifest_sha256)
    result={"state":"prepared_not_executed", "process_execution_verified":False, "client_acceptance":False}
    if args.result_content_only:
        result["oracle_contents_validated"]=verify_results(args.packet,manifest)
    print(json.dumps(result))


if __name__=="__main__":main()

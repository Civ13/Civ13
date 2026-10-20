"""Read local packet hashes/results only. Never execute the prepared commands."""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
from prepare_native import PROFILES, profile_contract

CONTROL_FAILURE = {"omit_entry": "entry_revoke_immediate", "omit_final": "zero_delay_final_revoke",
                   "omit_wake": "old_cancelled_new_lease_never_borrowed", "reacquire": "old_cancelled_new_lease_never_borrowed"}
ORDINARY = {"closed_port_refuses_reopen", "disconnected_fail_closed_only", "ordinary_zero_wait",
            "ordinary_move_cancels_and_releases_lock", "ordinary_two_cuttings_one_twine", "ordinary_sharpen_real_80_tick_handler"}
CORE = {"enabled_implementation_marker", "entry_revoke_immediate", "zero_delay_final_revoke",
        "old_lease_initially_valid", "old_cancelled_new_lease_never_borrowed", "real_sharpen_lease_entry", "wake_revoke_immediate",
        "no_sharpen_effect_or_receipt_after_stop", "production_canopy_recipe_available", "real_canopy_lease_entry",
        "stop_preserves_material_no_late_canopy", "production_canopy_pays_five_real_duration", "stop_no_late_deployment",
        "production_deployment_roof_inside_real_duration", "exact_canopy_clutter_admitted_not_movement_proof"}


def require(condition, reason):
    if not condition:
        raise ValueError(reason)


def inside(root, relative):
    rel = PurePosixPath(relative)
    require(not rel.is_absolute() and ".." not in rel.parts and "\\" not in relative, "unsafe packet path")
    result = root.joinpath(*rel.parts).resolve()
    require(root in result.parents, "packet path escaped")
    return result


def verify_prepared(root, expected_commit):
    root = root.resolve()
    manifest = json.loads((root / "manifest.json").read_text(encoding="utf-8"))
    require(manifest["commit"] == expected_commit and manifest["state"] == "prepared_not_executed", "packet provenance")
    require(manifest["native_lease"] is None, "preparation must not claim a native lease")
    profiles = manifest["profiles"]
    require(type(profiles) is list and len(profiles) == len(PROFILES) and {p["name"] for p in profiles} == set(PROFILES), "exact unique profile set required")
    for profile in profiles:
        require(all(profile.get(key) == value for key,value in profile_contract(profile["name"]).items()), "profile contract mismatch: " + profile["name"])
    for rel, digest in manifest["sha256"].items():
        file = inside(root, rel)
        require(file.is_file() and hashlib.sha256(file.read_bytes()).hexdigest() == digest, "hash mismatch: " + rel)
    require(all(p["status"] == "not_run" for p in profiles), "preparation must not claim test results")
    return manifest


def verify_result(result, profile, commit):
    require(result["commit"] == commit and result["profile"] == profile, "result provenance")
    require(result["byond_version"] == 516 and result["byond_build"] == 1681, "runtime version")
    require(result["dimensions"] == [9, 9, 1] and not result["port"] and not result["runtime_error"], "runtime isolation/error")
    require(not result["positive_client_acceptance"], "headless cannot claim clients")
    rows = result["checks"]
    require(isinstance(rows, list) and rows and all(type(r["tick"]) in (int,float) and 0 <= r["tick"] <= 800 for r in rows), "bounded assertions")
    passed = {r["assertion"] for r in rows if r["passed"]}
    failed = [r["assertion"] for r in rows if not r["passed"]]
    if profile in CONTROL_FAILURE:
        expected = CONTROL_FAILURE[profile]
        prefix = ORDINARY | {"enabled_implementation_marker"}
        if profile != "omit_entry":
            prefix |= {"entry_revoke_immediate"}
        if profile in ("omit_wake","reacquire"):
            prefix |= {"zero_delay_final_revoke","old_lease_initially_valid"}
        require(prefix <= passed and not result["passed"] and result["failed_assertion"] == expected and failed == [expected] and rows[-1]["assertion"] == expected, "negative control missed setup/prefix or exact assertion")
    else:
        required = ORDINARY | (CORE if profile == "headless" else set())
        if profile == "no_hook":
            required |= {"missing_hook_timed_affordances_fail_closed"}
        if profile in ("baseline", "disabled"):
            required |= {"disabled_marker_absent"}
        require(result["passed"] and not failed and required <= passed, "missing/failed production assertions")


def verify_evidence(root, manifest):
    """Future evidence only: compiler failures never satisfy a mutation control."""
    results = {}
    for profile in manifest["profiles"]:
        name = profile["name"]
        runtime = inside(root, profile["runtime_cwd"])
        execution = json.loads((runtime / "execution.json").read_text(encoding="utf-8"))
        require(execution["commit"] == manifest["commit"] and execution["profile"] == name, "execution provenance: " + name)
        compiler = execution["compiler"]
        require(type(compiler["pid"]) is int and compiler["pid"] > 0 and compiler["created_utc"] and compiler["executable"] and compiler["exit_code"] == 0 and 0 < compiler["elapsed_seconds"] <= 180, "compiler identity/budget: " + name)
        log = (runtime / "compile.log").read_text(encoding="utf-8", errors="replace")
        require("DM compiler version 516.1681" in log and "0 errors, 0 warnings" in log, "pinned clean compilation missing: " + name)
        require(hashlib.sha256((runtime/"compile.log").read_bytes()).hexdigest() == compiler["log_sha256"], "compiler log hash: " + name)
        for extension in (".dmb", ".rsc"):
            file = runtime / (name + extension)
            require(file.is_file() and hashlib.sha256(file.read_bytes()).hexdigest() == execution["artifacts_sha256"][file.name], "compiled artifact hash: " + name + extension)
        if profile["expected"] == "compile_only":
            require(execution["daemon"] is None, "compile-only target must not launch")
            continue
        daemon = execution["daemon"]
        require(type(daemon["pid"]) is int and daemon["pid"] > 0 and daemon["created_utc"] and daemon["executable"] and daemon["exit_code"] == 0 and 0 < daemon["elapsed_seconds"] <= 90, "daemon identity/budget: " + name)
        runtime_log = (runtime / "runtime.log").read_text(encoding="utf-8", errors="replace")
        require(hashlib.sha256((runtime/"runtime.log").read_bytes()).hexdigest() == daemon["log_sha256"], "runtime log hash: " + name)
        require(not any(s in runtime_log.lower() for s in ("runtime error", "## error:", "bug:")), "runtime errors: " + name)
        result = json.loads((runtime / "result.json").read_text(encoding="utf-8"))
        verify_result(result, name, manifest["commit"])
        results[name] = result
    require(results["baseline"]["ordinary_state"] == results["disabled"]["ordinary_state"], "disabled ordinary state differs from baseline")
    # This validates evidence shape/assertions, not execution provenance or clients.
    return sorted(results)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("packet", type=Path)
    parser.add_argument("--expected-commit", required=True)
    parser.add_argument("--with-execution-evidence", action="store_true")
    args = parser.parse_args()
    root = args.packet.resolve()
    manifest = verify_prepared(root, args.expected_commit)
    if args.with_execution_evidence:
        print(json.dumps({"validated_headless_profiles": verify_evidence(root,manifest), "client_acceptance": "not_established"}))
    else:
        require(not any(p.suffix in (".dmb", ".rsc") or p.name in ("runtime.log", "result.json") for p in root.rglob("*") if p.is_file()), "unexpected execution artifacts in prepared-only packet")
        print(json.dumps({"hashes_valid": len(manifest["sha256"]), "execution": "not_run", "commit": manifest["commit"]}))


if __name__ == "__main__":
    main()

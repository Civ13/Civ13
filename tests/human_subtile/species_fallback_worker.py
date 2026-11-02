"""One bounded species-fallback fixture compile and one fresh daemon.

Source-only candidate: no launcher may select this worker until the matching
host evidence validator, exact source binding, and workflow are reviewed.
"""
import json
import os
import time


def run(shared, args, scratch, binary, archive, group, envelope, identity, abi, began, npc, runtime, legacy):
    stage_tools = shared.load_module("species_fallback_stage", shared.HERE / "species_fallback_stage.py")
    contract = shared.load_module("species_fallback_contract", shared.HERE / "species_fallback_contract.py")
    binding = shared.load_module("species_fallback_binding", shared.HERE / "species_fallback_binding.py")
    compile_limit, daemon_limit, setup_limit, work_limit = 90, 60, 60, 490
    shared.require(args.suite == "species05" and args.work_deadline is not None
                   and time.monotonic() + compile_limit + daemon_limit + setup_limit <= args.work_deadline,
                   "Insufficient species shared work deadline")
    binding.validate_source(["git", "-C", str(shared.ROOT)], None, args.head, args.work_deadline - 210)
    started = time.monotonic()
    child_elapsed = 0.0

    def check_setup():
        used = time.monotonic() - started - child_elapsed
        shared.require(0 <= used <= setup_limit, "Species setup allowance exceeded")
        return used

    shared.checkpoint("species-staging", suite=args.suite)
    out = scratch / "npc-smoke"
    manifest = npc.prepare_source(shared.ROOT, out)
    shared.require(manifest["head"] == args.head, "Species source head mismatch")
    stage_tools.adapt(out, manifest, npc.current)
    (out / "cloud-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    stage, dme = out / "stage", out / manifest["dme"]

    def check_inputs():
        for rel, expected in manifest["stage_files"].items():
            path = stage / rel
            shared.require(path.is_file() and path.stat().st_size == expected["bytes"]
                           and shared.file_hash(path) == expected["sha256"],
                           "Species fixture input changed: " + rel)

    check_inputs()
    check_setup()
    shared.checkpoint("species-compile")
    runtime.verify_linux(binary, archive)
    build = shared.run_owned_phase(legacy, group,
        [str(binary / "DreamMaker"), "-max_errors", "0", str(dme)], stage, "compile", compile_limit)
    shared.require(contract.number(build.get("seconds")) and 0 <= build["seconds"] <= compile_limit,
                   "Species compile duration")
    child_elapsed += build["seconds"]
    log = "".join((stage / ("compile-" + part + ".log")).read_text(errors="replace")
                  for part in ("stdout", "stderr"))
    legacy.validate_compile(log, dme.with_suffix(".dmb").name)
    check_inputs()
    check_setup()
    work, dmb, artifacts = shared.prepare_linked_runtime(out, stage, dme, "runtime")
    peer, peer_dmb, peer_artifacts = shared.prepare_linked_runtime(out, stage, dme, "runtime-wildlife")
    resource = dme.with_suffix(".rsc").name
    shared.require(artifacts == peer_artifacts
                   and not os.path.samefile(dmb.with_suffix(".rsc"), peer_dmb.with_suffix(".rsc")),
                   "Species resource copies not isolated")
    shared.checkpoint("species-runtime-staged", runtime_artifacts=artifacts,
                      resource_copies_independent=True)
    shared.require(not any(work.rglob("*.sav")), "Species runtime must start with fresh saves")
    runtime.verify_linux(binary, archive)
    states = {}
    params = "tested_commit=" + args.head + ";fallback_tick=0.5"
    result = shared.run_checked_runtime(legacy, group,
        [str(binary / "DreamDaemon"), str(dmb), "59474", "-ip", "127.0.0.1", "-trusted",
         "-params", params, "-log", "runtime.log"],
        work, dme, peer, artifacts, dict(artifacts[resource]), "species", states, timeout=daemon_limit)
    shared.require(contract.number(result.get("seconds")) and 0 <= result["seconds"] <= daemon_limit,
                   "Species daemon duration")
    child_elapsed += result["seconds"]
    legacy.inspect_logs(work)
    shared.require((work / "port-closed.txt").read_bytes() == b"closed\n"
                   and (work / "result.txt").read_bytes() == b"PASS\n", "Species fixture failed")
    receipt = work / "receipt.json"
    shared.require(receipt.stat().st_size <= 4 * 1024**2, "Species receipt bound")
    observed = contract.validate(json.loads(receipt.read_text(encoding="utf-8")), args.head)
    check_inputs()
    check_setup()
    elapsed = time.monotonic() - started
    setup = elapsed - child_elapsed
    shared.require(0 <= setup <= setup_limit, "Species final setup allowance exceeded")
    summary = dict(head=args.head, suite=args.suite, fixture_dme_only=True, observation_complete=True,
        parity_established=False, tick=0.5, compile=build, artifacts=artifacts, resource_states=states,
        identity=identity, abi=abi, envelope=envelope,
        result={"daemon": result, "receipt_sha256": shared.file_hash(receipt)},
        observation=observed, scope=stage_tools.SCOPE,
        limits={"compile_seconds": compile_limit, "daemon_seconds": daemon_limit,
                "setup_seconds": setup_limit, "work_seconds": work_limit, "whole_seconds": 600},
        setup_seconds=setup, comparison_elapsed=elapsed, child_elapsed=child_elapsed,
        seconds=time.monotonic() - began)
    (scratch / "smoke-summary.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    shared.checkpoint("complete", outcome="passed", fixture_dme_only=True, suite=args.suite)
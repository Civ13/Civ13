"""Opt-in isolated visibility execution using the existing contained supervisor.

This launcher never enables agent control, reads production config, or starts
Civ13. Maintainer authorization for trusted native execution is required.
"""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import shutil
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path.insert(0, str(ROOT / "scripts"))
import fixture_toolchain
from native_fixture import Session, no_port_args, run_native, read_bounded
_spec = importlib.util.spec_from_file_location("agent_visibility_projection", HERE / "prepare.py")
prepare = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(prepare)

MODES = ("invisibility", "observer threshold", "occlusion", "distance", "z-level", "container")


def expected_labels():
    labels = ["fixture listening port is closed", "fixture refuses to reopen a listening port",
              "first observation is a full baseline", "nameless atom excluded", "observer excluded from nearby"]

    def pair(label, name):
        for kind in ("player", "object"):
            for field in ("nearby", "remembered signature"):
                labels.append(f"{label}: {name} {kind} {field}")

    for label, name in (
        ("visible atoms included", "visible"), ("see_invisible equality included", "boundary"),
        ("higher invisibility excluded", "invisible"), ("opaque wall excluded", "occluded"),
        ("outside radius excluded", "distant"), ("other z-level excluded", "other level"),
        ("container contents excluded", "contained"),
        ("zero threshold visible atoms included", "visible"),
        ("lower threshold hides former boundary", "boundary"),
    ):
        pair(label, name)
    for mode in MODES:
        for state in ("initially visible", "hidden rows and signatures absent",
                      "stale baseline does not leak hidden atoms", "visible again appears in delta"):
            pair(f"{mode} {state}", mode)
        for suffix in ("unchanged observation empty", "uses matching baseline",
                       "removes exactly the player and object", "hidden rows do not reappear or remove twice",
                       "stale revision receives full baseline", "reappearance does not remove anything"):
            labels.append(f"{mode} {suffix}")
        for kind in ("player", "object"):
            labels.append(f"{mode} previously seen {mode} {kind} removed")
    return labels


def validate_result(result, source_sha256, version):
    major, build = map(int, version.split("."))
    if (result.get("source_sha256") != source_sha256
            or (result.get("byond_version"), result.get("byond_build")) != (major, build)
            or result.get("failures") != 0 or result.get("runtime_error") != 0):
        raise ValueError("Native source, version, failure or runtime receipt mismatch")
    checks = result.get("checks")
    expected = expected_labels()
    if (not isinstance(checks, list) or len(checks) != len(expected)
            or any(not isinstance(row, dict) or row.get("ok") != 1 for row in checks)
            or sorted(row.get("label", "") for row in checks) != sorted(expected)):
        raise ValueError("Native visibility assertions are incomplete or failed")


def windows_backend():
    # Reuse the reviewed current-pin facade, binary allowlist, owned handles,
    # one-process Job, hidden launch, resource limits and zero-socket census.
    spec = importlib.util.spec_from_file_location("visibility_current_backend", ROOT / "tests/human_subtile/run-diagonal.py")
    helper = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(helper)
    return helper.current_backend()


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run-native", action="store_true", help="explicit opt-in; requires maintainer authorization")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--byond-bin", type=Path, required=True)
    args = parser.parse_args(argv)
    if not args.run_native:
        parser.error("Native execution needs --run-native; prepare.py never starts a daemon")
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=False)
    source, runtime = out / "source", out / "runtime"
    manifest = prepare.prepare(source)
    runtime.mkdir()
    identity = manifest["inputs_sha256"]["production_observe.dm"]
    session = Session(out / "supervisor", identity, backend_factory=windows_backend) if os.name == "nt" else None
    binary = args.byond_bin.resolve()
    compiler = binary / ("dm.exe" if os.name == "nt" else "DreamMaker")
    daemon = binary / ("dd.exe" if os.name == "nt" else "DreamDaemon")
    if os.name != "nt":
        fixture_toolchain.verify(compiler)
    compiled = run_native(session, [str(compiler), "-max_errors", "0", "visibility.dme"],
                          cwd=source, phase="compile", timeout=120,
                          artifacts=[source / "visibility.dmb", source / "visibility.rsc"])
    (out / "compile.log").write_text(compiled.stdout + compiled.stderr, encoding="utf-8")
    fixture_toolchain.validate_compiler(compiled)
    for suffix in (".dmb", ".rsc"):
        artifact = source / ("visibility" + suffix)
        if artifact.exists():
            shutil.copy2(artifact, runtime / artifact.name)
    if os.name != "nt":
        fixture_toolchain.verify(daemon)
    executed = None
    log = ""
    try:
        executed = run_native(session, [str(daemon), "visibility.dmb",
                              *(["-invisible", "-close"] if os.name == "nt" else []),
                              *no_port_args(), "-trusted", "-params", f"tested_source={identity}",
                              "-log", "runtime.log"], cwd=runtime, phase="runtime", timeout=30,
                              state_directory=runtime)
    finally:
        # Retain available diagnostics after owned cleanup even if the native
        # supervisor rejected a socket/process. Never turn that failure green.
        try:
            if executed is not None:
                log = executed.stdout + executed.stderr
            elif session is not None:
                for suffix in ("stdout", "stderr"):
                    path = out / "supervisor/runtime" / f"runtime.{suffix}.log"
                    if path.exists():
                        log += read_bounded(path)
            if (runtime / "runtime.log").exists():
                log += read_bounded(runtime / "runtime.log")
            (out / "runtime.log").write_text(log, encoding="utf-8")
        except Exception as error:
            if executed is not None:
                raise
            print(f"Secondary diagnostic retention error: {error}", file=sys.stderr)
    if executed.returncode or fixture_toolchain.DIAGNOSTIC.search(log):
        raise RuntimeError("Native visibility runtime exit or diagnostic failure: " + log)
    result = json.loads(read_bounded(runtime / "result.json"))
    validate_result(result, identity, manifest["byond_version"])
    (out / "accepted.json").write_text(json.dumps({
        "source_sha256": identity, "checks": len(result["checks"]), "failures": 0,
        "byond_version": manifest["byond_version"], "runtime_verified": True,
        "scope": "source-extracted nearby visibility; not a full game or graphical test",
        "network_evidence": "Windows contained supervisor samples sockets" if os.name == "nt" else
                            "Linux bounded subprocess; no OS socket census claim",
    }, indent=2) + "\n", encoding="utf-8")
    print(f"PASS {len(result['checks'])} native visibility assertions; evidence: {out}")


if __name__ == "__main__":
    main()

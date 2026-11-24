"""Prepare and compile the whole-world hull save fixture without launching it."""
from argparse import ArgumentParser
from hashlib import sha256
from pathlib import Path
import json
import re
import subprocess
import uuid


ROOT = Path(__file__).resolve().parents[2]
PROBES = {
    "roundtrip": Path("tests/naval_carrier/salvage_roundtrip_probe.dm"),
    "pressure": Path("tests/naval_carrier/pressure_probe.dm"),
}


def splice_once(source, old, new):
    if source.count(old) != 1:
        raise RuntimeError(f"Fixture projection anchor changed: {old}")
    return source.replace(old, new)


def digest_dm_tree(probe):
    # HEAD alone is not provenance for a fixture compiled from a working tree.
    digest = sha256()
    paths = [ROOT / "civ13.dme", ROOT / probe, *sorted((ROOT / "code").rglob("*.dm"))]
    for path in paths:
        digest.update(path.relative_to(ROOT).as_posix().encode() + b"\0")
        digest.update(sha256(path.read_bytes()).digest())
    return digest.hexdigest()


def compile_fixture(compiler, output, probe_name):
    probe = PROBES[probe_name]
    output.mkdir()  # Unique receipt and no stale binary can satisfy this run.
    prefix = ".salvage_rr_" + uuid.uuid4().hex
    files = [ROOT / (prefix + suffix) for suffix in
             ("_world.dm", "_globals.dm", ".dme", ".dmb", ".rsc", ".int", ".dyn.rsc", ".lk")]
    pin = json.loads((ROOT / "tools/byond/version.json").read_text())["version"]
    inputs = digest_dm_tree(probe)
    try:
        world = (ROOT / "code/world.dm").read_text()
        world = splice_once(world, "/world/New()", "/world/proc/unused_salvage_roundtrip_startup()")
        i = world.index("/world/proc/unused_salvage_roundtrip_startup()")
        m = re.search(r"(?m)^\t\.\.\(\)$", world[i:])
        if not m:
            raise RuntimeError("Fixture cannot safely project game startup")
        world = world[:i + m.start()] + world[i + m.end():]
        world = splice_once(world, "/datum/global_init/New()", "/datum/global_init/New()\n\treturn")
        files[0].write_text(world)
        globals_src = (ROOT / "code/controllers/mc/globals.dm").read_text()
        files[1].write_text(splice_once(globals_src, "/datum/controller/global_vars/New()",
                                       "/datum/controller/global_vars/New()\n\tGLOB = src\n\treturn"))
        dme = (ROOT / "civ13.dme").read_text()
        dme = splice_once(dme, r"code\world.dm", files[0].name)
        dme = splice_once(dme, r"code\controllers\mc\globals.dm", files[1].name)
        dme = re.sub(r'(?m)^#include ".*\.dmm"\s*$', "", dme)
        files[2].write_text(dme + f'\n#include "{probe.as_posix()}"\n')
        result = subprocess.run([compiler, "-max_errors", "0", files[2].name], cwd=ROOT,
                                text=True, capture_output=True, timeout=300, check=False)
        log = result.stdout + result.stderr
        (output / "compile.log").write_text(log)
        print(log, end="")
        if result.returncode or f"DM compiler version {pin}" not in log or "0 errors, 0 warnings" not in log:
            raise SystemExit("Compile failed or compiler does not match pin")
        if digest_dm_tree(probe) != inputs:
            raise RuntimeError("DM sources changed during the compile; rerun after edits settle")
        artifacts = {}
        for f in files[3:5]:
            artifact = output / f"probe{f.suffix}"
            artifact.write_bytes(f.read_bytes())
            artifacts[artifact.name] = sha256(artifact.read_bytes()).hexdigest()
        (output / "receipt.json").write_text(json.dumps({
            "compiler": pin,
            "source_head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
            "dm_source_sha256": inputs,
            "probe": probe_name,
            "fixture_sha256": sha256((ROOT / probe).read_bytes()).hexdigest(),
            "startup_projection_sha256": {f.name.removeprefix(prefix): sha256(f.read_bytes()).hexdigest()
                                         for f in files[:3]},
            "artifacts_sha256": artifacts,
            "runtime_started": False,
        }, indent=2) + "\n")
    finally:
        for f in files:
            f.unlink(missing_ok=True)


if __name__ == "__main__":
    parser = ArgumentParser(description=__doc__)
    parser.add_argument("--compiler", default="DreamMaker")
    parser.add_argument("--probe", choices=tuple(PROBES), default="roundtrip")
    parser.add_argument("--output", required=True, type=Path)
    opts = parser.parse_args()
    compile_fixture(opts.compiler, opts.output.resolve(), opts.probe)

"""Prepare exact-source species fixture; never launches BYOND."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
SCOPE = "manual crab Life and mosquito helper; no scheduler/client parity"


def load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def adapt(out, manifest, current):
    """Apply only fixed fixture entrypoint/receipt overlays to staged sources."""
    out = Path(out)
    stage = out / "stage"
    fixture = stage / "tests/human_subtile/species_fallback_fixture.dm"
    if not fixture.is_file():
        raise ValueError("species fixture absent from exact Git archive")
    changes = (
        ('\t\t\thuman_subtile_fixture_headless()', '\t\t\tspecies_fallback_main()'),
        ('"checks" = human_subtile_fixture_checks,', '"checks" = human_subtile_fixture_checks, "species_checks" = species_fallback_checks, "species_rows" = species_fallback_rows, "species_case" = species_fallback_case, "species_partial" = species_fallback_events,'),
        ('"scope" = "actual human/codec; headless authority adapter"', '"scope" = "' + SCOPE + '"'),
    )
    for before, after in changes:
        current.adapt(out, manifest, "tests/human_subtile/probe.dm", before, after)
    dme = out / manifest["dme"]
    with dme.open("a", encoding="utf-8", newline="\n") as stream:
        stream.write('\n#include "tests\\human_subtile\\species_fallback_fixture.dm"\n')
    for relative in ("tests/human_subtile/probe.dm", dme.relative_to(stage).as_posix()):
        path = stage / relative
        raw = path.read_bytes()
        manifest["stage_files"][relative] = {"bytes": len(raw), "sha256": hashlib.sha256(raw).hexdigest()}
    manifest["species_scope"] = SCOPE
    manifest["native_executed"] = False
    (out / "species-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--prepare-only", action="store_true", required=True)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    npc = load(HERE / "run-npc.py", "species_npc_stage")
    out = args.output.resolve()
    manifest = npc.prepare_source(ROOT, out)
    adapt(out, manifest, npc.current)
    print("Prepared exact Git " + manifest["head"] + "; no compiler or native execution")


if __name__ == "__main__":
    main()

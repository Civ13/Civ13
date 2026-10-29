"""Prepare a reviewable native fixture packet. There is deliberately no run mode."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
CONTROLS = {
    "mode": ("advance_decay && persistence && !persistence_save_in_progress", "advance_decay && !persistence_save_in_progress"),
    "replay": ("src != map || construction_last_season == season", "src != map"),
    "save-debt": ("seasonal_construction_due += elapsed", "seasonal_construction_due = 0"),
    "paired": ("if (R.building_pair_id)", "if (FALSE && R.building_pair_id)"),
    "contents": ("\t// Debit debt before normal qdel hooks; no sleep or direct Destroy call.",
                 "\tif (damage >= seasonal_construction_health() && contents.len)\n\t\treturn\n\t// Debit debt before normal qdel hooks; no sleep or direct Destroy call."),
}


def prepare(output, control=None):
    output = Path(output).resolve()
    output.mkdir(parents=True, exist_ok=True)
    if any(output.iterdir()):
        raise ValueError("Use an empty packet directory")
    source = (ROOT / "civ13.dme").read_text(encoding="utf-8")
    source = re.sub(r'^#include ".*\.dmm"[^\n]*$', "", source, flags=re.M)
    source = source.replace("#define FILE_DIR .", '#define FILE_DIR "' + ROOT.as_posix() + '"')
    hashes, adapted = {}, {}

    def include(match):
        relative = match.group(1).replace(chr(92), "/")
        original = ROOT / relative
        data = original.read_bytes()
        hashes[relative] = hashlib.sha256(data).hexdigest()
        text = data.decode("utf-8-sig") if relative in (
            "code/world.dm", "code/controllers/mc/globals.dm", "code/processes/seasonal_construction.dm") else None
        if relative == "code/world.dm":
            start = text.index("/world/New()")
            parent = text.index("\n\t..()", start)
            text = text[:parent] + text[parent:].replace("\n\t..()", "", 1)
            text = text.replace("/world/New()", "/world/proc/unused_construction_startup()", 1)
            anchor = "/datum/global_init/New()\n"
            if text.count(anchor) != 1:
                raise ValueError("Global startup anchor changed")
            text = text.replace(anchor, anchor + "\treturn\n", 1)
        elif relative == "code/controllers/mc/globals.dm":
            anchor = "/datum/controller/global_vars/New()\n"
            if text.count(anchor) != 1:
                raise ValueError("Global controller anchor changed")
            text = text.replace(anchor, anchor + "\treturn\n", 1)
        elif relative == "code/processes/seasonal_construction.dm" and control:
            before, after = CONTROLS[control]
            if text.count(before) != 1:
                raise ValueError("Mutation anchor changed: " + control)
            text = text.replace(before, after, 1)
        else:
            return '#include "' + original.as_posix() + '"'
        destination = output / (str(len(adapted)) + "_" + original.name)
        destination.write_text(text, encoding="utf-8", newline="\n")
        adapted[relative] = destination.name
        return '#include "' + destination.as_posix() + '"'

    source = re.sub(r'^#include "([^"]+)"', include, source, flags=re.M)
    base_path = ROOT / "tests/world_save/durable_world_probe.dm"
    base = base_path.read_text(encoding="utf-8")
    probe_path = ROOT / "tests/seasonal_construction/probe.dm"
    # Keep the historical fixture immutable; adapt only its obsolete policy case.
    policy_path = ROOT / "tests/seasonal_construction/collapse_policy_contents.dm"
    historical = probe_path.read_text(encoding="utf-8")
    policy = policy_path.read_text(encoding="utf-8")
    adapted_probe, replacements = re.subn(r'^/proc/construction_probe_contents\(\)\n.*?(?=^/|\Z)',
                                         lambda _: policy + "\n", historical, flags=re.M | re.S)
    if replacements != 1:
        raise ValueError("Historical contents probe anchor changed")
    probe = base[:base.index("/world/New()")] + adapted_probe
    (output / "probe.dm").write_text(probe, encoding="utf-8", newline="\n")
    source += '\n#include "' + (output / "probe.dm").as_posix() + '"\n'
    (output / "probe.dme").write_text(source, encoding="utf-8", newline="\n")
    for path in (base_path, probe_path, policy_path):
        hashes[path.relative_to(ROOT).as_posix()] = hashlib.sha256(path.read_bytes()).hexdigest()
    commit = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    diff = subprocess.check_output(["git", "diff", "--binary", "HEAD"], cwd=ROOT)
    (output / "tested.patch").write_bytes(diff)
    receipt = {"head_sha": commit, "prepared_only": True, "control": control,
               "contents_policy": "normal destruction; no occupancy deferral",
               "scope": "synthetic 8x8x1; production construction and entry save/load; not compiled or run",
               "production_hashes": hashes, "adapted_sources": adapted,
               "patch_sha256": hashlib.sha256(diff).hexdigest(),
               "generated_hashes": {p.name: hashlib.sha256(p.read_bytes()).hexdigest()
                                    for p in output.iterdir() if p.suffix in (".dm", ".dme")}}
    (output / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    return receipt


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--control", choices=tuple(CONTROLS))
    args = parser.parse_args()
    target = args.output or Path(tempfile.mkdtemp(prefix="civ13-construction-source-"))
    prepare(target, args.control)
    print("PREPARED ONLY: " + str(target))

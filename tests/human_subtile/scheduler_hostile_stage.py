"""Unwired hostile fixture adapter; retain the accepted headless gate."""
import hashlib
import importlib.util
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("hostile_transition_stage", HERE / "scheduler_transition_stage.py")
base = importlib.util.module_from_spec(spec)
spec.loader.exec_module(base)

SCOPE = "controlled mosquito towards idle-slot; no Life, contact or client parity"
FIXTURE = "tests/human_subtile/scheduler_hostile_draft.dm"
PROBE = base.PROBE


def adapted_probe(original):
    text = base.adapt_probe(original)
    replacements = (
        ("fixture_scheduler_transition_main()", "fixture_scheduler_hostile_main()"),
        ('"scope" = "' + base.SCOPE + '"', '"scope" = "' + SCOPE + '"'),
    )
    for before, after in replacements:
        if text.count(before) != 1:
            raise ValueError("hostile probe preimage")
        text = text.replace(before, after, 1)
    return text


def adapted_dme(original):
    include = '#include "tests\\human_subtile\\scheduler_hostile_draft.dm"'
    if '#include "tests\\human_subtile\\scheduler_core_draft.dm"' not in original or include in original:
        raise ValueError("hostile DME preimage")
    return original + "\n" + include + "\n"


def adapt(out, manifest, current):
    out = Path(out)
    base.adapt(out, manifest, current)
    stage = out / "stage"
    probe = stage / PROBE
    before = probe.read_text(encoding="utf-8")
    old_call = "fixture_scheduler_transition_main()"
    old_scope = '"scope" = "' + base.SCOPE + '"'
    if before.count(old_call) != 1 or before.count(old_scope) != 1:
        raise ValueError("hostile staged probe preimage")
    after = before.replace(old_call, "fixture_scheduler_hostile_main()", 1).replace(
        old_scope, '"scope" = "' + SCOPE + '"', 1)
    dme = out / manifest["dme"]
    new_dme = adapted_dme(dme.read_text(encoding="utf-8"))
    if not (stage / FIXTURE).is_file():
        raise ValueError("hostile fixture absent")
    current.adapt(out, manifest, PROBE, before, after)
    dme.write_text(new_dme, encoding="utf-8", newline="\n")
    for path in (PROBE, dme.relative_to(stage).as_posix(), FIXTURE):
        raw = (stage / path).read_bytes()
        manifest["stage_files"][path] = {"bytes": len(raw), "sha256": hashlib.sha256(raw).hexdigest()}
    manifest["hostile_scope"] = SCOPE
    manifest["native_executed"] = False
    (out / "hostile-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
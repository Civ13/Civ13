"""Prepare exact production datums and native assertions. Never launch a process."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CORE = Path("code/modules/1713/backrooms/gateway_core.dm")
FIXTURE = Path("tests/backrooms_gateway/fixture.dm")
CONTROLS = {
    "outage": ("&& supply.connected && source_epoch == supply.epoch", ""),
    "debit": ("charge -= units", "charge -= 0"),
    "restore": ("\t\tstop()\n\t\tlast_now = 0", '\t\tstate = "READY"\n\t\tlast_now = 0'),
}


def prepare(output: Path, control: str | None = None) -> dict:
    # Refuse existing output, including an empty directory; never overwrite data.
    output.mkdir(parents=True, exist_ok=False)
    source = (ROOT / CORE).read_bytes()
    fixture = (ROOT / FIXTURE).read_bytes()
    text = source.decode("utf-8").replace("\r\n", "\n")
    if control:
        before, after = CONTROLS[control]
        if text.count(before) != 1:
            raise ValueError("control source anchor drift")
        source = text.replace(before, after).encode("utf-8")
    (output / "gateway_core.dm").write_bytes(source)
    (output / "fixture.dm").write_bytes(fixture)
    (output / "probe.dme").write_text(
        '#define TRUE 1\n#define FALSE 0\n#include "gateway_core.dm"\n#include "fixture.dm"\n',
        encoding="utf-8",
    )
    manifest = {
        "scope": "prepared_only_not_native_execution",
        "control": control,
        "production_source": CORE.as_posix(),
        "production_sha256": hashlib.sha256((ROOT / CORE).read_bytes()).hexdigest(),
        "prepared_sha256": hashlib.sha256(source).hexdigest(),
        "fixture_sha256": hashlib.sha256(fixture).hexdigest(),
        "target": json.loads((ROOT / "tools/byond/version.json").read_text())["version"],
    }
    (output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    return manifest


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--control", choices=CONTROLS)
    args = parser.parse_args()
    print(json.dumps(prepare(args.output, args.control), indent=2))

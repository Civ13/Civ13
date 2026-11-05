#!/usr/bin/env python3
"""Native round trip for the stream save prototype (Linux, pinned BYOND).

Builds the i386 shim and x86_64 helper (tools/savestream/build.sh linux),
compiles tests/savestream/roundtrip/roundtrip.dme and runs it in Dream Daemon
with -trusted in a scratch directory. Requires gcc-multilib and the pinned
BYOND install (bash scripts/cloud_byond_setup.sh).

    python3 tests/savestream/run_native.py
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FIXTURE = Path(__file__).resolve().parent / "roundtrip"


def byond_bin() -> Path:
    for candidate in (os.environ.get("BYOND_BIN"), str(Path.home() / "byond-516.1688" / "byond" / "bin")):
        if candidate and (Path(candidate) / "DreamDaemon").exists():
            return Path(candidate)
    raise SystemExit("pinned BYOND not found; run bash scripts/cloud_byond_setup.sh")


def main() -> int:
    bin_dir = byond_bin()
    env = dict(os.environ)
    env["BYOND_SYSTEM"] = str(bin_dir.parent)
    env["LD_LIBRARY_PATH"] = f"{bin_dir}:{env.get('LD_LIBRARY_PATH', '')}"
    env["PATH"] = f"{bin_dir}:{env['PATH']}"
    subprocess.run(["bash", str(ROOT / "tools/savestream/build.sh"), "linux"], check=True, stdout=subprocess.DEVNULL)
    built = ROOT / "tools/savestream/bin/linux"
    work = Path(tempfile.mkdtemp(prefix="savestream-native-"))
    # Keep the fixture's relative include of the stream module valid.
    shutil.copytree(FIXTURE, work / "tests/savestream/roundtrip")
    shutil.copytree(ROOT / "code/modules/persistence/stream", work / "code/modules/persistence/stream")
    run = work / "tests/savestream/roundtrip"
    compile_log = subprocess.run(["DreamMaker", "-max_errors", "0", "roundtrip.dme"], cwd=run, env=env, capture_output=True, text=True)
    print(compile_log.stdout.strip().splitlines()[-2] if compile_log.stdout else compile_log.stderr)
    if compile_log.returncode != 0 or "0 errors" not in compile_log.stdout:
        print(compile_log.stdout)
        return 1
    shutil.copy(built / "libsavestream.so", run)
    shutil.copy(built / "savestream_helper", run)
    daemon = subprocess.run(["DreamDaemon", "roundtrip.dmb", "-trusted", "-invisible", "-close"], cwd=run, env=env,
                            capture_output=True, text=True, timeout=300)
    result_path = run / "result.json"
    if not result_path.exists():
        print(daemon.stdout, daemon.stderr)
        return 1
    result = json.loads(result_path.read_text())
    print(json.dumps(result, indent=1))
    return 0 if result.get("ok") else 1


if __name__ == "__main__":
    sys.exit(main())

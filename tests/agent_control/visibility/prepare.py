"""Prepare or compile the exact production observe proc in a tiny isolated world.

No daemon is launched by this script, including when --compile is selected.
Run prepared native inputs only through an approved isolated fixture supervisor.
"""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
SOURCE = Path("code/modules/agent_control/agent_characters.dm")
DECLARATION = "/datum/agent_control/proc/act_character_observe(datum/agent_identity/A, list/req)"


def extract_observe(source):
    """Copy the complete proc verbatim (apart from normalized file newlines)."""
    lines = source.splitlines(keepends=True)
    starts = [i for i, line in enumerate(lines) if line.rstrip("\r\n") == DECLARATION]
    if len(starts) != 1:
        raise ValueError("Expected exactly one production act_character_observe declaration")
    start = starts[0]
    end = start + 1
    while end < len(lines) and (not lines[end].strip() or lines[end].startswith("\t")):
        end += 1
    result = "".join(lines[start:end]).rstrip() + "\n"
    if not result.endswith("\treturn out\n"):
        raise ValueError("Production observe proc has an unexpected end")
    return result


def check_contract(source):
    """Security-relevant contracts, checked on production, never a Python LOS model."""
    observe = extract_observe(source)
    active = "\n".join(line.split(" //", 1)[0] for line in observe.splitlines()
                       if not line.lstrip().startswith("//"))
    required = [
        "\tvar/list/signatures = list()",
        "\tvar/list/nearby = list()",
        "\t\tfor (var/atom/movable/AM in view(radius, M))",
        "\t\t\tif (AM == M || !isturf(AM.loc) || AM.invisibility > M.see_invisible || !AM.name)\n\t\t\t\tcontinue",
        'signatures[row["ref"]] = "[json_encode(signature)]@[T.x],[T.y],[T.z]"',
        "\t\t\tnearby += list(row)",
        'if (isnum(since_rev) && since_rev > 0 && since_rev == C.seen_rev && islist(C.seen))',
        '\t\tfor (var/ref in C.seen)\n\t\t\tif (!(ref in signatures))\n\t\t\t\tgone += ref',
        '\t\tout["nearby_removed"] = gone',
        '\tC.seen = signatures',
        '\tout["rev"] = ++C.seen_rev',
    ]
    for text in required:
        if active.count(text) != 1:
            raise ValueError("Visibility contract changed: " + text)
    guard = active.index(required[3])
    row = active.index('\t\t\tvar/list/row = list("ref" = agent_ref(AM)')
    signature = active.index(required[4])
    append = active.index(required[5])
    reset = active.index(required[9])
    if not guard < row < signature < append < reset:
        raise ValueError("Visibility filtering must precede encoding and remembered signatures")
    return observe


def generated_sources(root=ROOT):
    source = (root / SOURCE).read_text(encoding="utf-8")
    observe = check_contract(source)
    constants = []
    for name, path in (("DEAD", "code/predefines.dm"), ("AREA_INSIDE", "code/game/area/areas.dm")):
        text = (root / path).read_text(encoding="utf-8")
        matches = re.findall(r"^#define\s+" + name + r"\s+[^\n]+", text, re.M)
        if len(matches) != 1:
            raise ValueError("Expected one production constant " + name)
        constants.append(matches[0])
    files = {
        "constants.dm": "\n".join(constants) + "\n",
        "production_observe.dm": observe,
        "adapters.dm": (HERE / "adapters.dm").read_text(encoding="utf-8"),
        "probe.dm": (HERE / "probe.dm").read_text(encoding="utf-8"),
        "visibility.dme": '#include "constants.dm"\n#include "adapters.dm"\n#include "production_observe.dm"\n#include "probe.dm"\n',
    }
    manifest = {
        "schema": 1,
        "production_path": SOURCE.as_posix(),
        "production_sha256": hashlib.sha256(source.encode()).hexdigest(),
        "projection": "complete unmodified act_character_observe proc, LF normalized",
        "byond_version": json.loads((root / "tools/byond/version.json").read_text())["version"],
        "inputs_sha256": {name: hashlib.sha256(text.encode()).hexdigest() for name, text in files.items()},
        "runtime_verified": False,
    }
    return files, manifest


def prepare(output, root=ROOT):
    files, manifest = generated_sources(root)
    output = Path(output)
    output.mkdir(parents=True, exist_ok=False)
    for name, text in files.items():
        (output / name).write_text(text, encoding="utf-8", newline="\n")
    (output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    return manifest


def compile_fixture(output, byond_bin):
    """Use the shared exact-banner/zero-diagnostic validator; never run a daemon."""
    spec = importlib.util.spec_from_file_location("visibility_toolchain", ROOT / "scripts/fixture_toolchain.py")
    toolchain = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(toolchain)
    compiler = Path(byond_bin).resolve() / ("dm.exe" if os.name == "nt" else "DreamMaker")
    # The shared installed-member verifier is Linux-only. Windows compilation
    # records the selected binary hash plus its exact current-pin banner.
    if os.name != "nt":
        toolchain.verify(compiler)
    command = [str(compiler), "-max_errors", "0", "visibility.dme"]
    result = subprocess.run(command, cwd=output, capture_output=True, text=True,
                            timeout=120, creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0)
    (output / "compile.log").write_text(result.stdout + result.stderr, encoding="utf-8")
    (output / "compiler.json").write_text(json.dumps({
        "command": command, "returncode": result.returncode,
        "sha256": hashlib.sha256(compiler.read_bytes()).hexdigest(),
        "runtime_launched": False,
    }, indent=2) + "\n", encoding="utf-8")
    toolchain.validate_compiler(result)
    return result


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True, help="fresh isolated output directory")
    parser.add_argument("--compile", action="store_true", help="also compile, never launch DreamDaemon")
    parser.add_argument("--byond-bin", type=Path)
    args = parser.parse_args(argv)
    if args.compile and not args.byond_bin:
        parser.error("--compile needs --byond-bin")
    output = args.output.resolve()
    prepare(output)
    if args.compile:
        result = compile_fixture(output, args.byond_bin)
        print(result.stdout, end="")
    print(f"Prepared {output}; native runtime NOT run")


if __name__ == "__main__":
    main()

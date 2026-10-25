"""Exact-input snow fixture preparation. This module never launches BYOND."""
import difflib
import hashlib
import json
import re
import subprocess
from pathlib import Path

HEAD = "e87eae1d411e276ce2ae3f0b871829a1911c114c"
TREE = "cb0db4de48f271ca3a694583b17904c410d7dce1"
VERSION = "516.1688"
ADAPTER = "snow-native-5161688-v1"
MODES = ("baseline", "overlay-omission", "melt-omission", "generation-omission",
         "reload-generation-omission", "reload-sampling", "del-unregister-omission")
REQUIRED = ("AGENTS.md", "code/modules/1713/snowfall_ground.dm",
            "code/processes/snowfall_ground.dm", "code/game/turfs/floor_icon.dm",
            "code/game/turfs/turf.dm", "code/modules/persistence/functions.dm",
            "tests/snowfall_ground/native_probe.dm", "icons/turf/snow.dmi")
HERE = Path(__file__).resolve().parent


def digest(data):
    return hashlib.sha256(data).hexdigest()


def blob(data):
    return hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()


def dump(path, value):
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n")


def regular(path):
    if path.is_symlink() or any(p.is_symlink() for p in path.parents) or not path.is_file():
        raise ValueError("Regular non-symlink file required: " + str(path))
    if path.stat().st_size > 2 * 1024**2:
        raise ValueError("Input file exceeds 2 MiB bound: " + str(path))
    return path.read_bytes()


def bindings():
    value = json.loads(regular(HERE / "source-bindings.json"))
    if value.get("head") != HEAD or value.get("tree") != TREE:
        raise ValueError("Source identity constants differ")
    rows = value.get("inputs", [])
    if len(rows) != len(REQUIRED) or {r.get("path") for r in rows} != set(REQUIRED):
        raise ValueError("Unexpected source input inventory")
    if any(r.get("type") != "blob" or r.get("mode") not in ("100644", "100755")
           or not re.fullmatch("[a-f0-9]{40}", r.get("sha", "")) for r in rows):
        raise ValueError("Unsupported source binding")
    return {row["path"]: row for row in rows}


def git(source, *args):
    return subprocess.check_output(["git", *args], cwd=source, timeout=15,
                                   stderr=subprocess.PIPE)


def input_inventory(source, require_git):
    source = source.absolute()
    if ".." in source.parts:
        raise ValueError("Source path must not contain parent traversal")
    if source.is_symlink() or any(p.is_symlink() for p in source.parents):
        raise ValueError("Source path contains a symlink")
    expected = bindings()
    if require_git:
        if (git(source, "rev-parse", "HEAD").decode().strip() != HEAD or
                git(source, "rev-parse", "HEAD^{tree}").decode().strip() != TREE):
            raise ValueError("Wrong source HEAD/tree")
        if git(source, "status", "--porcelain", "--untracked-files=normal").strip():
            raise ValueError("Dirty or untracked source checkout")
        tracked = {}
        for entry in git(source, "ls-tree", "-z", "HEAD", "--", *REQUIRED).split(b"\0"):
            if not entry:
                continue
            info, name = entry.split(b"\t", 1)
            mode, kind, sha = info.decode().split()
            tracked[name.decode()] = (mode, kind, sha)
        if tracked != {name: (row["mode"], "blob", row["sha"]) for name, row in expected.items()}:
            raise ValueError("Checked-out Git input inventory differs")
    result = {}
    for name, row in expected.items():
        data = regular(source / name)
        if blob(data) != row["sha"] or len(data) != row["size"]:
            raise ValueError("Source blob mismatch: " + name)
        result[name] = {"blob": row["sha"], "sha256": digest(data), "bytes": len(data)}
    return result


def unique_replace(text, old, new):
    if text.count(old) != 1:
        raise ValueError("Expected one mutation/extraction anchor: " + old)
    return text.replace(old, new, 1)


def procedure(text, signature):
    pattern = re.compile(r"^" + re.escape(signature) + r"\n.*?(?=^/(?![/*])|\Z)", re.M | re.S)
    matches = pattern.findall(text)
    if len(matches) != 1:
        raise ValueError("Expected one production procedure: " + signature)
    return matches[0]


def mutate(source, mode):
    if mode not in MODES:
        raise ValueError("Unknown mode")
    if mode == "baseline":
        return source
    if mode == "overlay-omission":
        return unique_replace(source, "\t\toverlays += weather_snow_overlay",
                              "\t\t// Causal control: omit snow appearance publication.")
    if mode == "melt-omission":
        return unique_replace(source, "if (local_c > SNOWFALL_MELT_C)", "if (FALSE)")
    if mode == "generation-omission":
        return unique_replace(source,
            "if (isnull(expected_generation) || isnull(generated_source) || expected_generation != snowfall_ground_generation)",
            "if (isnull(expected_generation) || isnull(generated_source))")
    if mode == "reload-generation-omission":
        return unique_replace(source,
            "\tif (snowfall_ground_eligible())\n\t\tsnowfall_ground_generation = ++next_snowfall_ground_generation\n",
            "\t// Causal control: omit the after-load lifetime change.\n")
    if mode == "reload-sampling":
        return unique_replace(source,
            "\tsnowfall_ground_icon() // No weather sampling or accumulation during restore.",
            "\tsnowfall_ground_check() // Causal control: sample during restore.")
    return unique_replace(source,
        "/turf/floor/Del()\n\tsnowfall_ground_unregister()\n\t..()",
        "/turf/floor/Del()\n\t// Causal control: omit native replacement unregister.\n\t..()")


def build_fixture(source, output, require_git=True):
    """Export mode authenticates bytes, never invents a Git checkout or HEAD."""
    source = source.absolute()
    output = output.absolute()
    if ".." in source.parts or ".." in output.parts:
        raise ValueError("Preparation paths must not contain parent traversal")
    if output.is_symlink() or any(p.is_symlink() for p in output.parents):
        raise ValueError("Output path contains a symlink")
    if output.exists() or source == output or source in output.parents:
        raise ValueError("Fresh output outside source required")
    rows = input_inventory(source, require_git)
    output.mkdir(parents=True)
    originals = output / "inputs"
    for name, row in rows.items():
        data = regular(source / name)
        if digest(data) != row["sha256"]:
            raise ValueError("Source changed during preparation")
        dest = originals / name
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(data)
    module = regular(originals / "code/modules/1713/snowfall_ground.dm").decode()
    process = regular(originals / "code/processes/snowfall_ground.dm")
    hooks = procedure(regular(originals / "code/game/turfs/floor_icon.dm").decode(), "/turf/floor/New()")
    hooks += "\n" + procedure(regular(originals / "code/modules/persistence/functions.dm").decode(),
                               "/turf/persistence_runtime_var(key)")
    fixture_inputs = {name: regular(HERE / "fixtures" / name)
                      for name in ("stubs.dm", "probe.dm")}
    generated = {}
    for mode in MODES:
        root = output / "cases" / mode / "source"
        root.mkdir(parents=True)
        binding = "".join('#define SNOW_NATIVE_' + key + ' "' + value + '"\n'
                          for key, value in (("HEAD", HEAD), ("TREE", TREE), ("VERSION", VERSION),
                                             ("ADAPTER", ADAPTER), ("MODE", mode)))
        variant = mutate(module, mode)
        content = {"binding.dm": binding.encode(), "stubs.dm": fixture_inputs["stubs.dm"],
                   "production-snow.dm": variant.encode(), "production-process.dm": process,
                   "production-hooks.dm": hooks.encode(), "probe.dm": fixture_inputs["probe.dm"],
                   "icons/turf/snow.dmi": regular(originals / "icons/turf/snow.dmi")}
        content["snow-native.dme"] = ("// Isolated synthetic module lane, not a game boot.\n" +
            "".join('#include "' + f + '"\n' for f in ("binding.dm", "stubs.dm", "production-snow.dm",
                                                       "production-process.dm", "production-hooks.dm", "probe.dm"))).encode()
        diff = "".join(difflib.unified_diff(module.splitlines(keepends=True), variant.splitlines(keepends=True),
                                           fromfile="source/code/modules/1713/snowfall_ground.dm",
                                           tofile="generated/" + mode + "/production-snow.dm"))
        content["mutation.diff"] = diff.encode()
        for name, data in content.items():
            target = root / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
            generated[str(target.relative_to(output))] = digest(data)
    receipt = {"head": HEAD, "tree": TREE, "version": VERSION, "adapter": ADAPTER,
               "source_authentication": "clean-git" if require_git else "git-blob-export",
               "inputs": rows, "generated": generated, "dimensions": [18, 18, 3],
               "modes": list(MODES), "native_executed": False,
               "temperature_provider": "injected", "topology_provider": "injected",
               "custom_serializer_executed": False, "clients_admitted": False}
    dump(output / "preparation.json", receipt)
    return receipt


def verify_fixture(output, receipt):
    for name, row in receipt["inputs"].items():
        if digest(regular(output / "inputs" / name)) != row["sha256"]:
            raise ValueError("Original input changed: " + name)
    for name, expected in receipt["generated"].items():
        if digest(regular(output / name)) != expected:
            raise ValueError("Generated fixture changed: " + name)

"""Exact-checkout tree adapter. Only fixed read-only Git commands, no native dispatch.
Generated DME overlays require the full immutable production source.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import stat

VERSION = "516.1688"
ADAPTER = "winter-growth-linux-516.1688-ae99e2b-v1"
from admission import HEAD, TREE, verify_checkout
VARIANTS = ("baseline",)
INPUTS = ("civ13.dme", "code/world.dm", "code/controllers/mc/globals.dm",
          "code/game/objects/farming.dm", "code/game/turfs/floor_attackby.dm")
CONTROLS = {}
CANDIDATE_INVENTORY_SHA256 = "76b33c58b31a75f24955838c72b38ab9486aca429faeea9aa9cff0b0a3815543"
FIXTURE_HASHES = {'probe.dm': '1b0128ee1bda581674bdc7e3927c1ce1e2829cb4be73bf991b15ad57a9e5f6bb', 'food-save.dm': 'be65e094561b3d77f38750bbd93f7429b2ccf70d49545588a185ea6fbd63b987', 'wrapper.dm': '3b6da0548f09347491338080b00339de8b2e6d65ac42a2fd9c6f8edd75d6fe49'}
IGNORED_BYTECODE = set()
MAX_FILE = 128 * 1024**2
MAX_TOTAL = 1024**3


def digest(data):
    return hashlib.sha256(data).hexdigest()


def canonical(value):
    return (json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=True) + "\n").encode()


def dump(path, value):
    path.write_bytes(canonical(value))


def replace_once(source, old, new):
    if source.count(old) != 1:
        raise ValueError("Unique source adapter anchor changed: " + old)
    return source.replace(old, new, 1)


def safe_root(path):
    path = path.absolute()
    if ".." in path.parts or any(parent.is_symlink() for parent in (path, *path.parents)):
        raise ValueError("Linked or traversing root")
    if not path.is_dir():
        raise ValueError("Source root is not a directory")
    return path


def bounded_file(path, cap=MAX_FILE):
    if any(parent.is_symlink() for parent in (path, *path.parents)):
        raise ValueError("Linked file: " + str(path))
    before = path.stat(follow_symlinks=False)
    if not stat.S_ISREG(before.st_mode) or before.st_nlink != 1 or before.st_size > cap:
        raise ValueError("Nonregular, hardlinked, or oversized file: " + str(path))
    with path.open("rb") as stream:
        data = stream.read(cap + 1)
    after = path.stat(follow_symlinks=False)
    identity = lambda row: (row.st_dev, row.st_ino, row.st_size, row.st_mtime_ns, row.st_ctime_ns)
    if len(data) > cap or identity(before) != identity(after) or len(data) != after.st_size:
        raise ValueError("File changed while reading: " + str(path))
    return data


def validate_inventory_bytes(raw, expected_digest=CANDIDATE_INVENTORY_SHA256):
    if digest(raw) != expected_digest:
        raise ValueError("Candidate manifest exact bytes changed")
    entries = json.loads(raw)
    if not isinstance(entries, list) or not entries:
        raise ValueError("Candidate inventory is not a nonempty list")
    rows = {}
    for row in entries:
        if not isinstance(row, dict) or set(row) != {"path", "type", "mode", "sha", "sha256", "size"}:
            raise ValueError("Unexpected candidate row schema")
        name = row["path"]
        if (not isinstance(name, str) or Path(name).is_absolute() or ".." in Path(name).parts or
                "\\" in name or name in rows or ".git" in Path(name).parts or
                row["type"] != "blob" or row["mode"] not in ("100644", "100755") or
                type(row["size"]) is not int or not 0 <= row["size"] <= MAX_FILE or
                not re.fullmatch(r"[0-9a-f]{40}", row["sha"]) or
                not re.fullmatch(r"[0-9a-f]{64}", row["sha256"])):
            raise ValueError("Invalid candidate row")
        rows[name] = row
    if sum(row["size"] for row in rows.values()) > MAX_TOTAL or len(rows) > 20000:
        raise ValueError("Candidate exceeds source bounds")
    return rows


def candidate_manifest(source, manifest_path):
    source = safe_root(source)
    raw = bounded_file(manifest_path, 16 * 1024**2)
    rows = validate_inventory_bytes(raw)
    if len(rows) != 5089:
        raise ValueError("Wrong integrated candidate file count")
    verify_checkout(source, rows)
    seen = set()
    for folder, dirs, files in os.walk(source, followlinks=False):
        if Path(folder) == source and ".git" in dirs:
            if (source / ".git").is_symlink():
                raise ValueError("Linked Git metadata")
            dirs.remove(".git")
        for name in dirs:
            if name == ".git" or (Path(folder) / name).is_symlink():
                raise ValueError("Nested Git metadata or symlink directories are forbidden")
        for name in files:
            file = Path(folder) / name
            relative = file.relative_to(source).as_posix()
            if relative in IGNORED_BYTECODE:
                if file.is_symlink() or not file.is_file():
                    raise ValueError("Linked/nonregular ignored bytecode")
                continue
            if relative not in rows:
                raise ValueError("Unmanifested source member: " + relative)
            data = bounded_file(file)
            row = rows[relative]
            blob = hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()
            if len(data) != row["size"] or digest(data) != row["sha256"] or blob != row["sha"]:
                raise ValueError("Candidate source bytes changed: " + relative)
            seen.add(relative)
    if seen != set(rows):
        raise ValueError("Candidate source inventory is incomplete")
    verify_checkout(source, rows)
    return raw, rows


def normalized(data):
    return data.decode("utf-8").replace("\r\n", "\n")


def startup_sources(world, globals_source):
    # Same canonical isolation as the historical fixture, with closed Topic too.
    at = world.index('/world/New()')
    parent = world.index('\n\t..()', at)
    world = world[:parent] + world[parent:].replace('\n\t..()', '', 1)
    world = replace_once(world, '/world/New()', '/world/proc/unused_winter1688_startup()')
    world = replace_once(world, '/world/Topic(T, addr, master, key)',
                         '/world/proc/unused_winter1688_topic(T, addr, master, key)')
    world = replace_once(world, '/datum/global_init/New()\n',
                         '/datum/global_init/New()\n\tworld.OpenPort("none")\n\treturn\n')
    globals_source = replace_once(globals_source, '/datum/controller/global_vars/New()\n',
                                  '/datum/controller/global_vars/New()\n\treturn\n')
    return world, globals_source


def adapt_probe(binding, variant):
    if not re.fullmatch(r"[0-9a-f]{64}", binding) or variant not in VARIANTS:
        raise ValueError("Invalid candidate/variant binding")
    root = Path(__file__).parent
    sources = {}
    for name, expected in FIXTURE_HASHES.items():
        data = bounded_file(root / name)
        if digest(data) != expected:
            raise ValueError("Fixture source changed: " + name)
        sources[name] = normalized(data)
    wrapper = sources["wrapper.dm"]
    for old, new in (("@HEAD@", HEAD), ("@TREE@", TREE), ("@BINDING@", binding), ("@VARIANT@", variant), ("@ADAPTER@", ADAPTER)):
        wrapper = wrapper.replace(old, new)
    return sources["probe.dm"] + "\n" + sources["food-save.dm"] + "\n" + wrapper


def generated_files(inputs, binding, variant):
    world, global_vars = startup_sources(normalized(inputs['code/world.dm']),
                                         normalized(inputs['code/controllers/mc/globals.dm']))
    generated = {'winter1688-world.dm': world, 'winter1688-globals.dm': global_vars,
                 'winter1688-probe.dm': adapt_probe(binding, variant)}
    dme = normalized(inputs['civ13.dme'])
    dme = re.sub(r'^#include ".*\.dmm"[^\n]*$', '', dme, flags=re.M)
    for old, new in (('code\\world.dm', 'winter1688-world.dm'),
                     ('code\\controllers\\mc\\globals.dm', 'winter1688-globals.dm')):
        dme = replace_once(dme, old, new)
    if variant != 'baseline':
        relative, old, new, target = CONTROLS[variant]
        generated['winter1688-control.dm'] = replace_once(normalized(inputs[relative]), old, new)
        dme = replace_once(dme, relative.replace('/', '\\'), 'winter1688-control.dm')
    generated['winter1688.dme'] = dme + '\n#include "winter1688-probe.dm"\n'
    return {name: text.encode('utf-8') for name, text in generated.items()}


def prepare(source, output, manifest_path):
    source = safe_root(source)
    output = output.absolute()
    if output.exists() or source == output or source in output.parents:
        raise ValueError('Use a fresh output outside the source checkout')
    if any(parent.is_symlink() for parent in output.parents):
        raise ValueError('Linked output parent')
    manifest_bytes, manifest = candidate_manifest(source, manifest_path)
    binding = digest(manifest_bytes)
    inputs = {}
    for name in INPUTS:
        data = bounded_file(source / name)
        if digest(data) != manifest[name]['sha256']:
            raise ValueError('Input changed after candidate capture: ' + name)
        inputs[name] = data
    output.mkdir(parents=True)
    (output / 'candidate-manifest.json').write_bytes(manifest_bytes)
    for name, data in inputs.items():
        target = output / 'inputs' / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
    generated_rows = {}
    for variant in VARIANTS:
        generated = generated_files(inputs, binding, variant)
        for name, data in generated.items():
            target = output / 'generated' / variant / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
            generated_rows[target.relative_to(output).as_posix()] = {'sha256': digest(data), 'bytes': len(data)}
    # Detect source edits during capture, rather than bless a torn candidate.
    if candidate_manifest(source, manifest_path) != (manifest_bytes, manifest):
        raise ValueError('Source checkout changed during preparation; partial output retained')
    receipt = {'schema': 1, 'adapter': ADAPTER, 'version': VERSION,
               'candidate_manifest_sha256': binding, 'git_head': HEAD, 'git_tree': TREE,
               'native_activation': 'requires-explicit-reviewed-native-and-actual-checkout',
               'portable_or_compile_ready': False, 'normal_startup': False, 'dimensions': [10, 8, 1],
               'native_executed': False, 'compiler_attempted': False, 'compiler_started': False,
               'compiler_completed': False, 'daemon_attempted': False, 'daemon_started': False,
               'daemon_completed': False, 'inputs': {name: {'sha256': manifest[name]['sha256'], 'bytes': manifest[name]['size']} for name in INPUTS},
               'generated': generated_rows}
    dump(output / 'source-identity.json', {'head': HEAD, 'tree': TREE, 'actual_git_checked': True,
         'candidate_manifest_sha256': binding, 'tracked_files': len(manifest)})
    dump(output / 'preparation.json', receipt)
    verify_prepared(output, receipt)
    return receipt


def verify_prepared(output, receipt):
    output = safe_root(output)
    raw = bounded_file(output / 'candidate-manifest.json', 16 * 1024**2)
    manifest = validate_inventory_bytes(raw)
    if digest(raw) != receipt['candidate_manifest_sha256']:
        raise ValueError('Candidate manifest binding changed')
    if (receipt['git_head'], receipt['git_tree']) not in ((None, None), (HEAD, TREE)):
        raise ValueError('Unexpected prepared Git identity')
    if receipt.get('adapter') != ADAPTER or receipt.get('version') != VERSION:
        raise ValueError('Wrong preparation adapter/version')
    for flag in ('native_executed', 'compiler_attempted', 'compiler_started', 'compiler_completed',
                 'daemon_attempted', 'daemon_started', 'daemon_completed', 'portable_or_compile_ready', 'normal_startup'):
        if receipt.get(flag) is not False:
            raise ValueError('Preparation cannot claim execution/startup: ' + flag)
    if set(receipt['inputs']) != set(INPUTS):
        raise ValueError('Preparation input inventory changed')
    inputs = {}
    for name in INPUTS:
        data = bounded_file(output / 'inputs' / name)
        wanted = {'sha256': manifest[name]['sha256'], 'bytes': manifest[name]['size']}
        if receipt['inputs'][name] != wanted or len(data) != wanted['bytes'] or digest(data) != wanted['sha256']:
            raise ValueError('Retained input differs from candidate: ' + name)
        inputs[name] = data
    expected_rows = {}
    for variant in VARIANTS:
        for name, data in generated_files(inputs, digest(raw), variant).items():
            relative = 'generated/' + variant + '/' + name
            expected_rows[relative] = {'bytes': len(data), 'sha256': digest(data)}
            if bounded_file(output / relative) != data:
                raise ValueError('Generated overlay is not reproducible: ' + relative)
    if receipt['generated'] != expected_rows:
        raise ValueError('Generated receipt inventory changed')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--inventory', required=True, type=Path)
    args = parser.parse_args()
    print(json.dumps(prepare(args.source, args.output, args.inventory), indent=2))


if __name__ == '__main__':
    main()

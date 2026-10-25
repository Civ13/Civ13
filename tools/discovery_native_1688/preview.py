"""Offline source-export preview. Not actual checkout admission or runnable evidence."""
from audit_offline import install
install()
import argparse
import hashlib
import os
from pathlib import Path
from prepare import (bounded_file, safe_root, validate_inventory_bytes, digest, dump,
                     generated_files, INPUTS, VARIANTS, HEAD, TREE, ADAPTER)
from plan import proposed_plan


def tree_hash(rows):
    children = {}
    for row in rows:
        name, _, tail = row['path'].partition('/')
        if tail:
            children.setdefault(name, []).append(dict(row, path=tail))
        else:
            children[name] = row
    data = b''
    for name, child in sorted(children.items(), key=lambda item: item[0] + ('/' if isinstance(item[1], list) else '')):
        mode, sha = ('40000', tree_hash(child)) if isinstance(child, list) else (child['mode'], child['sha'])
        data += mode.encode() + b' ' + name.encode() + b'\0' + bytes.fromhex(sha)
    return hashlib.sha1(b'tree ' + str(len(data)).encode() + b'\0' + data).hexdigest()


def preview(source, output):
    source = safe_root(source)
    output = output.absolute()
    if output.exists() or source in output.parents or output in source.parents or any(p.is_symlink() for p in output.parents):
        raise ValueError('Fresh separate preview output required')
    raw = bounded_file(Path(__file__).with_name('source-manifest.json'), 16 * 1024**2)
    rows = validate_inventory_bytes(raw)
    if tree_hash(list(rows.values())) != TREE:
        raise ValueError('Manifest does not reconstruct exact published tree')
    seen = set()
    for folder, dirs, names in os.walk(source, followlinks=False):
        if any((Path(folder)/name).is_symlink() for name in dirs):
            raise ValueError('Linked export directory')
        for name in names:
            path = Path(folder)/name
            relative = path.relative_to(source).as_posix()
            if relative not in rows:
                raise ValueError('Unmanifested export member: ' + relative)
            row = rows[relative]
            data = bounded_file(path)
            sha = hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest()
            if (len(data), digest(data), sha) != (row['size'], row['sha256'], row['sha']):
                raise ValueError('Export bytes differ: ' + relative)
            seen.add(relative)
    if seen != set(rows):
        raise ValueError('Incomplete source export')
    inputs = {name: bounded_file(source/name) for name in INPUTS}
    output.mkdir(parents=True)
    generated = {}
    for variant in VARIANTS:
        for name, data in generated_files(inputs, digest(raw), variant).items():
            path = output/variant/name
            path.parent.mkdir(exist_ok=True)
            path.write_bytes(data)
            generated[path.relative_to(output).as_posix()] = {'sha256': digest(data), 'bytes': len(data)}
    report = dict(status='offline-export-preview-only', adapter=ADAPTER, published_head=HEAD,
                  reconstructed_tree=TREE, candidate_manifest_sha256=digest(raw), files=len(rows),
                  actual_git_checked=False, native_executed=False, compiler_attempted=False,
                  backend_admissible=False, generated=generated)
    dump(output/'preview.json', report)
    dump(output/'phase-plan.json', proposed_plan(digest(raw)))
    return report


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-export', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    result = preview(args.source_export, args.output)
    print(result['status'], result['reconstructed_tree'], result['files'])

"""Real source-only admission regression. No mock Git, compiler or daemon.

Must be a separate interpreter before the injected offline tests' audit fence.
A source export is not an authentic checkout and must fail this regression.
"""
import argparse
from pathlib import Path
from prepare import (candidate_manifest, prepare, verify_prepared, bounded_file,
                     canonical, digest, HEAD, TREE, CANDIDATE_INVENTORY_SHA256)

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source',required=True,type=Path)
    parser.add_argument('--output',required=True,type=Path)
    args=parser.parse_args()
    manifest=Path(__file__).with_name('source-manifest.json')
    # Call the exact production admission function, not merely its inventory
    # parser or generated_files. verify_checkout executes real read-only Git.
    raw,rows=candidate_manifest(args.source.absolute(),manifest)
    if len(rows)!=5089 or digest(raw)!=CANDIDATE_INVENTORY_SHA256:
        raise ValueError('Exact candidate admission identity differs')
    receipt=prepare(args.source.absolute(),args.output.absolute(),manifest)
    verify_prepared(args.output.absolute(),receipt)
    if receipt['dimensions']!=[10,8,1] or receipt['native_executed'] is not False:
        raise ValueError('Prepared fixture identity or native state differs')
    print(canonical(dict(status='passed-real-checkout-source-only',head=HEAD,tree=TREE,
                         actual_git_checked=True,tracked_files=len(rows),
                         candidate_manifest_sha256=digest(raw),dimensions=receipt['dimensions'],
                         native_executed=False)).decode(),end='')
if __name__=='__main__':main()

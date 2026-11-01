"""Pure hosted admission/review metadata. Flags bind intent, not human approval."""
import argparse
from datetime import datetime, timedelta, timezone
import hashlib
import json
from pathlib import Path
import re

MODES = ('prepare', 'execute')

def need(value, reason):
    if not value:
        raise ValueError(reason)

def validate(source_sha, dispatch_sha, ref, mode, approved, manifest_sha, until, *,
             repository, event, workflow_sha, now=None):
    now = now or datetime.now(timezone.utc)
    need(repository == 'Civ13/Civ13' and event == 'workflow_dispatch',
         'Dedicated manual Civ13 dispatch required')
    need(type(source_sha) is str and re.fullmatch('[0-9a-f]{40}', source_sha)
         and source_sha == dispatch_sha == workflow_sha,
         'Dispatch workflow and requested source must be the same immutable head')
    need(type(ref) is str and ref.startswith('refs/heads/') and len(ref) > len('refs/heads/'),
         'Reviewed branch ref required')
    need(mode in MODES and type(approved) is bool and type(manifest_sha) is str and type(until) is str,
         'Explicit supported mode/intent required')
    if mode == 'prepare':
        need(not approved and not manifest_sha and not until,
             'Preparation cannot carry execution intent or stale admission data')
        return dict(mode=mode, source_sha=source_sha, native_requested=False)
    need(approved and re.fullmatch('[0-9a-f]{64}', manifest_sha),
         'Execution requires explicit intent and reviewed manifest hash')
    try:
        deadline = datetime.fromisoformat(until.replace('Z', '+00:00'))
    except (ValueError, AttributeError):
        raise ValueError('Explicit aware authorization deadline required')
    need(deadline.tzinfo is not None and now + timedelta(seconds=900) <= deadline,
         'A full renewed 900-second window must remain')
    return dict(mode=mode, source_sha=source_sha, native_requested=True,
                manifest_sha256=manifest_sha, authorized_until=deadline.isoformat())

def review(prepared, source_sha, mode, expected_manifest):
    path=prepared/'mount-native-manifest.json'
    need(path.is_file() and not path.is_symlink() and path.stat().st_size <= 2*1024**2,
         'Bounded prepared manifest required')
    raw=path.read_bytes()
    manifest=json.loads(raw)
    digest=hashlib.sha256(raw).hexdigest()
    need(manifest.get('head') == source_sha and manifest.get('fixture') == 'mount_lifecycle'
         and manifest.get('mount_manifest_schema') == 2,
         'Prepared source/fixture/schema mismatch')
    if mode == 'execute':
        need(digest == expected_manifest, 'Prepared manifest differs from reviewed Linux artifact')
    return dict(head=source_sha, mode=mode, manifest_sha256=digest,
                native_executed=False, sequence=manifest['sequence'],
                variants=manifest['variants'], bounds=manifest['bounds'],
                runner='tests/mount_lifecycle_native/run_linux.py',
                note='Identity/intent checks are not a grant of human authorization')

if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-sha', required=True)
    parser.add_argument('--dispatch-sha', required=True)
    parser.add_argument('--workflow-sha', required=True)
    parser.add_argument('--ref', required=True)
    parser.add_argument('--mode', choices=MODES, required=True)
    parser.add_argument('--approved', choices=('true','false'), required=True)
    parser.add_argument('--manifest-sha', default='')
    parser.add_argument('--authorized-until', default='')
    parser.add_argument('--repository', required=True)
    parser.add_argument('--event', required=True)
    parser.add_argument('--prepared', type=Path)
    args=parser.parse_args()
    result=validate(args.source_sha,args.dispatch_sha,args.ref,args.mode,args.approved=='true',
                    args.manifest_sha,args.authorized_until,
                    repository=args.repository,event=args.event,workflow_sha=args.workflow_sha)
    if args.prepared:
        result['review']=review(args.prepared,args.source_sha,args.mode,args.manifest_sha)
        target=args.prepared/'hosted-review.json'
        target.write_text(json.dumps(result,indent=2,sort_keys=True)+'\n',encoding='utf-8')
    print(json.dumps(result,sort_keys=True))

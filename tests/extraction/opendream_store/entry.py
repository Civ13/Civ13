"""Default-OFF manual hosted entry. No effects unless a frozen allocated route passes."""
import argparse
import json
import os
from pathlib import Path
import sys
import time

import backend as b
import hosted
import run as r


def main(argv=None,effects_factory=b.PosixEffects,environ=None):
    entered=time.monotonic(); entered_utc=time.time()
    parser=argparse.ArgumentParser()
    source=parser.add_mutually_exclusive_group(required=True)
    source.add_argument('--route-packet')
    source.add_argument('--route-json-env')
    parser.add_argument('--expected-route-sha256',required=True)
    parser.add_argument('--root',required=True)
    parser.add_argument('--claim-dir',required=True)
    args=parser.parse_args(argv)
    env=os.environ if environ is None else environ
    if args.route_json_env:
        raw=env.get(args.route_json_env,'').encode('utf-8')
    else:
        r.need(Path(args.route_packet).stat().st_size<=1024**2,'route packet too large')
        raw=Path(args.route_packet).read_bytes()
    r.need(len(raw)<=1024**2,'route packet too large')
    route=json.loads(raw)
    # Disabled documents return without constructing the native effect adapter.
    if route.get('enabled') is not True:
        print('SOURCE ONLY: route disabled'); return 0
    hosted.check_route(route)
    r.need(r.sha(b.encoded(route))==args.expected_route_sha256,'frozen route differs')
    r.need(env.get('GITHUB_ACTIONS')=='true' and env.get('GITHUB_REPOSITORY')=='Civ13/Civ13',
           'wrong execution host')
    r.need(route['run_id']=='bind-current-run' and route['run_attempt']=='1' and
           env.get('GITHUB_RUN_ID','').isdigit() and env.get('GITHUB_RUN_ATTEMPT')=='1',
           'allocation binding/rerun differs')
    r.need(env.get('RUNNER_OS')=='Linux' and env.get('RUNNER_ARCH')=='X64','wrong runner architecture')
    r.need(sys.version_info>=(3,11),'Python3.11+ required')
    driver=str(Path(__file__).resolve().parent)
    fx=effects_factory()
    remaining=min(2190,route['expires_utc']-entered_utc)
    def fresh(): r.need(fx.clock()<entered+remaining-30 and fx.utc()<route['expires_utc'],'entry budget/expiry')
    r.need(remaining>30,'expired entry')
    # Job-local private shared claim root. Re-running the same path fails closed.
    fresh(); fx.mkdir(args.claim_dir); fresh()
    startup=Path(driver,'startup.dm').read_bytes(); fresh()
    backend=hosted.SourceBuildBackend(fx,args.root,args.claim_dir,driver,sys.executable,startup)
    # Preserve the pre-directory/driver-read anchor: execute must not reset it.
    # Dispatch's run_id does not exist when policy is frozen. Bind it exactly
    # once to a derived allocation, preserving the pre-dispatch policy digest.
    route=dict(route,parent_route_sha256=args.expected_route_sha256,
               run_id=env['GITHUB_RUN_ID'],run_attempt=env['GITHUB_RUN_ATTEMPT'])
    effective_digest=r.sha(b.encoded(route))
    hosted.execute(route,effective_digest,backend,fx.clock,fx.utc,
                   entered=entered,entered_utc=entered_utc)
    print('PASS: five source-built extraction store cases; native BYOND/gameplay not established')
    return 0


if __name__=='__main__': raise SystemExit(main())

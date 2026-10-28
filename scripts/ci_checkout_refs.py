"""Fetch only the exact event comparison commit without changing HEAD."""
import argparse
import os
import re
import subprocess
import sys

SHA = re.compile(r'^[0-9a-f]{40}$')


def git(*args, check=True):
    env = os.environ.copy()
    env['GIT_TERMINAL_PROMPT'] = '0'
    result = subprocess.run(['git', *args], capture_output=True, text=True, timeout=90, env=env)
    if check and result.returncode:
        raise RuntimeError('Git preparation failed: ' + (result.stderr or result.stdout)[-2000:])
    return result


def prepare(head, base, event):
    if not SHA.fullmatch(head) or head == '0' * 40:
        raise ValueError('Expected a nonzero full head SHA')
    if git('rev-parse', '--verify', 'HEAD^{commit}').stdout.strip() != head:
        raise ValueError('Checked-out head differs from event head')
    if not base or base == '0' * 40:
        if event == 'pull_request':
            raise ValueError('Pull request requires an immutable base SHA')
        return
    if not SHA.fullmatch(base):
        raise ValueError('Expected a full comparison SHA')
    if git('cat-file', '-e', base + '^{commit}', check=False).returncode:
        git('fetch', '--no-tags', '--depth=1', 'origin', base)
    if git('cat-file', '-e', base + '^{commit}', check=False).returncode:
        raise RuntimeError('Comparison commit unavailable after fetch')
    if git('rev-parse', '--verify', 'HEAD^{commit}').stdout.strip() != head:
        raise RuntimeError('Git preparation changed the checked-out head')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--head', required=True)
    parser.add_argument('--base', default='')
    parser.add_argument('--event', required=True)
    args = parser.parse_args()
    try:
        prepare(args.head, args.base, args.event)
    except (ValueError, RuntimeError, subprocess.TimeoutExpired) as error:
        print('CI checkout preparation failed: ' + str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())

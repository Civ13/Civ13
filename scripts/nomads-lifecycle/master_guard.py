"""Fail-closed local Civ13 master checkout verification. Never launches a game."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import subprocess

ORIGIN = 'https://github.com/Civ13/Civ13.git'


def verified_master(repository, git='git', *, update=False, expected_origin=ORIGIN):
    repository = Path(repository).resolve(strict=True)

    def command(*arguments):
        result = subprocess.run([git, '-C', str(repository), *arguments],
                                capture_output=True, text=True, timeout=180)
        if result.returncode:
            raise RuntimeError(f'Master guard refused: git {arguments[0]} failed; checkout retained')
        return result.stdout.strip()

    # git config --get returns 1 for an unset value; handle this optional read
    # separately, without relaxing failures from the required commands.
    sparse = subprocess.run([git, '-C', str(repository), 'config', '--bool',
                             '--get', 'core.sparseCheckout'], capture_output=True,
                            text=True, timeout=30)
    if sparse.returncode not in (0, 1) or sparse.stdout.strip() == 'true':
        raise RuntimeError('Master guard refused: sparse checkout is unsupported')
    if command('symbolic-ref', '--quiet', '--short', 'HEAD') != 'master':
        raise RuntimeError('Master guard refused: checkout must be on branch master')
    if command('rev-parse', '--abbrev-ref', '--symbolic-full-name', '@{upstream}') != 'origin/master':
        raise RuntimeError('Master guard refused: expected upstream origin/master')
    if command('symbolic-ref', '--quiet', 'refs/remotes/origin/HEAD') != 'refs/remotes/origin/master':
        raise RuntimeError('Master guard refused: expected local origin default master')
    if command('status', '--porcelain=v1', '--untracked-files=all'):
        raise RuntimeError('Master guard refused: checkout has local changes or untracked files')
    flags = command('ls-files', '-v').splitlines()
    if any(line[:1].islower() or line.startswith('S ') for line in flags):
        raise RuntimeError('Master guard refused: hidden index entries are unsupported')
    urls = command('remote', 'get-url', '--all', 'origin').splitlines()
    if urls != [expected_origin]:
        raise RuntimeError('Master guard refused: origin does not match the verified Civ13 repository')
    before = command('rev-parse', '--verify', 'HEAD^{commit}')
    command('fetch', '--no-tags', 'origin',
            'refs/heads/master:refs/remotes/origin/master')
    target = command('rev-parse', '--verify', 'refs/remotes/origin/master^{commit}')
    advertised = [line.split() for line in command('ls-remote', '--symref', '--exit-code', 'origin', 'HEAD', 'refs/heads/master').splitlines()]
    if ['ref:', 'refs/heads/master', 'HEAD'] not in advertised:
        raise RuntimeError('Master guard refused: expected remote default branch master')
    remote = [line for line in advertised if not line or line[0] != 'ref:']
    if sorted(remote) != sorted([[target, 'HEAD'], [target, 'refs/heads/master']]):
        raise RuntimeError('Master guard refused: fetched and advertised master differ; retry later')
    if len(target) != 40 or any(c not in '0123456789abcdef' for c in target):
        raise RuntimeError('Master guard refused: invalid fetched master identity')
    # No reset, stash, force checkout, or merge commit. A divergence/ahead branch
    # is an operator decision; a behind clean master can advance only explicitly.
    if before != target:
        ancestor = subprocess.run([git, '-C', str(repository), 'merge-base',
                                   '--is-ancestor', before, target],
                                  capture_output=True, timeout=30)
        if ancestor.returncode != 0:
            raise RuntimeError('Master guard refused: local master is ahead or diverged')
        if not update:
            raise RuntimeError('Master guard refused: master is behind; run the explicit safe update')
        if command('symbolic-ref', '--quiet', '--short', 'HEAD') != 'master' or command('status', '--porcelain=v1', '--untracked-files=all'):
            raise RuntimeError('Master guard refused: checkout changed during verification')
        command('merge', '--ff-only', target)
    if command('symbolic-ref', '--quiet', '--short', 'HEAD') != 'master' or command('rev-parse', 'HEAD') != target or command('status', '--porcelain=v1', '--untracked-files=all'):
        raise RuntimeError('Master guard refused: final master identity or clean state changed')
    return {'repository': str(repository), 'branch': 'master', 'upstream': 'origin/master', 'default_branch': 'master', 'before': before,
            'commit': target, 'origin': expected_origin, 'fresh_remote_verified': True}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repository', required=True)
    parser.add_argument('--git', default='git')
    parser.add_argument('--update', action='store_true', help='Allow only a clean fast-forward')
    args = parser.parse_args()
    print(json.dumps(verified_master(args.repository, args.git, update=args.update), indent=2))

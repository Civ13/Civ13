"""Actual, fixed Git checkout admission. No native program or network is invoked."""
import os
import subprocess
from pathlib import Path

HEAD = 'e773c2fae4b196ad6c7afc025235e90f488f7db8'
TREE = '4800aac2e81b45b6fb215bcf23f8ed3761186fe3'


def git(source, *args):
    # Ignore inherited alternate-index/object-directory/config injection. Git is
    # invoked only with fixed read-only commands, never shell/network commands.
    environment = {key: value for key, value in os.environ.items() if not key.startswith('GIT_')}
    environment.update(GIT_CONFIG_NOSYSTEM='1', GIT_CONFIG_GLOBAL=os.devnull,
                       GIT_OPTIONAL_LOCKS='0', GIT_TERMINAL_PROMPT='0', GIT_NO_REPLACE_OBJECTS='1')
    result = subprocess.run(['git', '--no-replace-objects', '-c', 'core.fsmonitor=false',
                             '-c', 'core.untrackedCache=false', *args], cwd=source,
                            env=environment, check=True, capture_output=True, timeout=30)
    if len(result.stdout) > 16 * 1024**2 or len(result.stderr) > 1024**2:
        raise ValueError('Git admission output exceeds bound')
    return result.stdout


def verify_checkout(source, manifest):
    if git(source, 'rev-parse', '--show-toplevel').decode().strip() != str(source.absolute()):
        raise ValueError('Source is not the actual checkout root')
    if git(source, 'rev-parse', 'HEAD').decode().strip() != HEAD:
        raise ValueError('Wrong actual source HEAD')
    if git(source, 'rev-parse', 'HEAD^{tree}').decode().strip() != TREE:
        raise ValueError('Wrong actual source tree')
    if git(source, 'status', '--porcelain', '--untracked-files=all').strip():
        raise ValueError('Source checkout is not clean')
    raw = git(source, 'ls-tree', '-rz', '--full-tree', 'HEAD')
    found = {}
    for entry in raw.split(b'\0'):
        if not entry:
            continue
        info, name = entry.split(b'\t', 1)
        mode, kind, sha = info.decode('ascii').split()
        name = name.decode('utf-8')
        if name in found:
            raise ValueError('Duplicate tracked path')
        found[name] = (mode, kind, sha)
    expected = {name: (row['mode'], row['type'], row['sha']) for name, row in manifest.items()}
    if found != expected:
        raise ValueError('Actual HEAD tree differs from exact source manifest')
    return {'head': HEAD, 'tree': TREE, 'tracked_files': len(found), 'actual_git_checked': True}

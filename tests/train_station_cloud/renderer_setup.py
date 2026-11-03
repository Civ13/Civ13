"""Provision only locked Ubuntu renderer packages on an ephemeral hosted runner.

Not a general installer: no repository/key changes, upgrades, removals or fallback.
The station host and replay remain read-only consumers of /usr/bin tools.
Installation executes official package maintainer scripts/triggers as root.
The timeout bounds its foreground process group, not escaped services or a
rollback. Only the disposable hosted runner is an admitted installation target.
"""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import selectors
import shlex
import subprocess
import sys
import time
import urllib.request
import urllib.parse

MAX_SECONDS = 210
MAX_LOG = 2 * 1024 * 1024
SNAPSHOT = '20261103T000000Z'
BASE = 'https://snapshot.ubuntu.com/ubuntu/' + SNAPSHOT + '/'

def require(ok, message):
    if not ok:
        raise RuntimeError(message)

def transaction(text, packages):
    """Accept only newly installed, exact locked packages. Reject state changes."""
    result = {}
    for line in text.splitlines():
        if line.startswith(('Remv ', 'Purg ')):
            raise RuntimeError('Package removal rejected')
        if not line.startswith('Inst '):
            continue
        match = re.fullmatch(r'Inst ([a-z0-9+.-]+)(?::amd64)? \((\S+) .+\)(?: \[\])?', line)
        require(match is not None, 'Upgrade or unrecognized transaction rejected: ' + line)
        name, version = match.groups()
        require(name in packages and packages[name]['version'] == version,
                'Unlisted package/version rejected: ' + name)
        require(name not in result, 'Duplicate package transaction')
        result[name] = packages[name]
    for line in text.splitlines():
        if line.startswith('Conf '):
            name = line.split()[1].removesuffix(':amd64')
            require(name in result, 'Pre-existing package configuration rejected')
    return result

def download_plan(text, planned):
    expected = {BASE + row['filename']: row for row in planned.values()}
    result = []
    for line in text.splitlines():
        if not line.startswith("'"):
            continue
        fields = shlex.split(line)
        require(len(fields) == 4 and urllib.parse.unquote(fields[0]) in expected, 'Unexpected package URI')
        url, target, size, _ = fields
        row = expected.pop(urllib.parse.unquote(url))
        require(target == Path(target).name and target.endswith('.deb'), 'Unsafe cache filename')
        require(int(size) == row['bytes'], 'Package byte count drift')
        result.append((url, target, row))
    require(not expected, 'Incomplete package download plan')
    return result

def package_state(text):
    """Read package identity/status only; no dependency solving or mutation."""
    result = {}
    for line in text.splitlines():
        fields = line.split('\t')
        require(len(fields) == 4, 'Unrecognized package status record')
        name, arch, version, status = fields
        name = name.removesuffix(':' + arch)
        key = (name, arch)
        require(key not in result, 'Duplicate package status record')
        result[key] = (version, status)
    return result

def verify_package_delta(before, after, planned):
    expected = {}
    for name, row in planned.items():
        arch = 'all' if row['filename'].endswith('_all.deb') else 'amd64'
        key = (name, arch)
        require(key not in before, 'Planned package already has existing status: ' + name)
        expected[key] = (row['version'], 'ii ')
    require(all(after.get(key) == value for key, value in before.items()),
            'Pre-existing package version/status changed')
    require({key: value for key, value in after.items() if key not in before} == expected,
            'Installed packages differ from exact planned versions/status')

def verify_release_metadata(lists, lock):
    result = []
    for suite in ('noble', 'noble-updates', 'noble-security'):
        expected = next(row for row in lock['metadata'] if row['name'] == suite + '.InRelease')
        matches = list(lists.glob('*_dists_' + suite + '_InRelease'))
        require(len(matches) == 1, 'Missing/ambiguous signed release metadata: ' + suite)
        data = matches[0].read_bytes()
        digest = hashlib.sha256(data).hexdigest()
        require(len(data) == expected['bytes'] and digest == expected['sha256'],
                'Signed release metadata differs from reviewed snapshot: ' + suite)
        result.append({'suite': suite, 'bytes': len(data), 'sha256': digest})
    return result

def finish_command(proc, privileged, until, now=time.monotonic):
    """Never kill sudo and mistake wrapper exit for privileged completion.

    Root-owned timeout is independent of this helper. Await its foreground
    completion within the reserved grace. Failure to observe it is uncertain
    completion and fails the setup; escaped descendants are not certified.
    """
    if proc.poll() is not None:
        return
    if privileged:
        proc.wait(timeout=max(0.1, until - now()))
    else:
        proc.kill()
        proc.wait(timeout=2)

def install_command(apt, config, install, planned):
    return ['/usr/bin/env', 'APT_CONFIG=' + str(config), 'DEBIAN_FRONTEND=noninteractive',
            'PATH=/usr/sbin:/usr/bin:/sbin:/bin', *apt, '--no-download', '--no-upgrade', *install,
            *[name + '=' + row['version'] for name, row in planned.items() if name != 'ffmpeg']]

def apt_configuration(out, sources):
    return ('Dir::Etc::parts "-";\nDir::Etc::main "-";\n'
            + 'Dir::Etc::sourcelist "' + str(sources) + '";\n'
            + 'Dir::Etc::sourceparts "-";\nDir::Etc::preferences "-";\nDir::Etc::preferencesparts "-";\n'
            + 'Dir::State::lists "' + str(out / 'lists') + '";\n'
            + 'Dir::Cache "' + str(out) + '";\n'
            + 'Dir::Cache::pkgcache "";\nDir::Cache::srcpkgcache "";\n'
            + 'Dir::Cache::archives "' + str(out / 'archives') + '";\n'
            + 'APT::Get::List-Cleanup "false";\nAcquire::Languages "none";\n'
            + 'Acquire::Retries "0";\nAcquire::https::Timeout "15";\n'
            + 'Acquire::http::Timeout "15";\nAPT::Install-Recommends "false";\n')

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--lock', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    require(sys.platform == 'linux' and os.geteuid() != 0, 'Unprivileged Linux runner required')
    require(os.environ.get('GITHUB_ACTIONS') == 'true' and os.environ.get('RUNNER_OS') == 'Linux',
            'GitHub hosted Linux context required')
    require('VERSION_ID="24.04"' in Path('/etc/os-release').read_text(), 'Ubuntu 24.04 required')
    require(not args.output.exists(), 'New evidence directory required')
    out = args.output.resolve(); out.mkdir(parents=True)
    lock_data = args.lock.read_bytes(); lock = json.loads(lock_data)
    require(lock['snapshot'] == SNAPSHOT and lock['architecture'] == 'amd64', 'Lock target mismatch')
    packages = {p['name']: p for p in lock['packages']}
    require(len(packages) == len(lock['packages']) and 'ffmpeg' in packages, 'Invalid package lock')
    require(len(packages) == lock['package_count'] == 233 and
            sum(p['bytes'] for p in packages.values()) == lock['total_archive_bytes'] == 145446530,
            'Reviewed package count/byte ceiling differs')
    receipt = {'status': 'running', 'lock_sha256': hashlib.sha256(lock_data).hexdigest(),
               'snapshot': SNAPSHOT, 'runner_image': os.environ.get('ImageVersion'),
               'commands': [], 'installation_started': False}
    deadline = time.monotonic() + MAX_SECONDS
    env = {'PATH': '/usr/bin:/bin', 'HOME': str(out), 'LANG': 'C.UTF-8',
           'DEBIAN_FRONTEND': 'noninteractive'}
    def save():
        (out / 'renderer-setup.json').write_text(json.dumps(receipt, indent=2) + '\n')
    def command(argv, seconds=30, privileged=False):
        remaining = int(deadline - time.monotonic())
        require(remaining > 15, 'Renderer provisioning total deadline')
        limit = min(seconds, remaining - 10)
        # Root-owned timeout controls its foreground group. Maintainer scripts
        # can escape it; this is not a universal descendant-absence claim.
        bounded = (['/usr/bin/sudo', '-n'] if privileged else []) + [
            '/usr/bin/timeout', '--signal=TERM', '--kill-after=5s', str(limit) + 's', *argv]
        row = {'argv': bounded, 'wall_limit': limit, 'privileged': privileged}
        receipt['commands'].append(row); save()
        index = len(receipt['commands'])
        size = 0; capture = bytearray(); until = time.monotonic() + limit + 8
        failure = None; completion_failure = None
        with (out / ('command-%02d.log' % index)).open('wb') as log:
            proc = subprocess.Popen(bounded, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
            row['supervised_wrapper_pid'] = proc.pid
            with selectors.DefaultSelector() as selector:
                selector.register(proc.stdout, selectors.EVENT_READ)
                try:
                    while selector.get_map():
                        require(time.monotonic() < until, 'Timeout supervisor did not finish')
                        for key, _ in selector.select(timeout=0.25):
                            chunk = os.read(key.fd, 65536)
                            if not chunk:
                                selector.unregister(key.fd); continue
                            size += len(chunk)
                            retained = chunk[:max(0, MAX_LOG - len(capture))]
                            capture.extend(retained); log.write(retained)
                    proc.wait(timeout=max(0.1, until - time.monotonic()))
                except BaseException as exc:
                    failure = exc
                finally:
                    try:
                        finish_command(proc, privileged, until)
                    except BaseException as exc:
                        completion_failure = exc
                    proc.stdout.close()
        data = bytes(capture)
        row.update(returncode=proc.returncode, bytes=size, truncated=size > MAX_LOG,
                   sha256=hashlib.sha256(data).hexdigest(), foreground_completion_confirmed=proc.poll() is not None)
        if failure is not None: row['error'] = type(failure).__name__ + ': ' + str(failure)[:1000]
        if completion_failure is not None:
            row['completion_error'] = type(completion_failure).__name__ + ': ' + str(completion_failure)[:1000]
        save()
        require(completion_failure is None, 'Provisioning foreground completion uncertain; retained primary/completion errors')
        if failure is not None: raise failure
        require(size <= MAX_LOG, 'Provisioning command output bound')
        require(proc.returncode == 0, 'Provisioning command failed; retained command log')
        return data.decode('utf8', errors='strict')
    try:
        spec = importlib.util.spec_from_file_location('station_cloud', Path(__file__).with_name('cloud.py'))
        cloud = importlib.util.module_from_spec(spec); spec.loader.exec_module(cloud)
        head, tree = os.environ.get('EXPECTED_HEAD'), os.environ.get('EXPECTED_TREE')
        receipt['run_provenance'] = cloud.github_binding(head, tree, os.environ)
        require(command(['/usr/bin/git', 'rev-parse', 'HEAD']).strip() == head, 'Checkout head mismatch')
        require(command(['/usr/bin/git', 'rev-parse', 'HEAD^{tree}']).strip() == tree, 'Checkout tree mismatch')
        require(not command(['/usr/bin/git', 'status', '--porcelain=v1', '--untracked-files=all']).strip(),
                'Clean reviewed checkout required')
        require(not command(['/usr/bin/dpkg', '--audit']).strip(), 'Clean package state required')
        require(command(['/usr/bin/dpkg', '--print-architecture']).strip() == 'amd64', 'amd64 required')
        query = ['/usr/bin/dpkg-query', '-W', '-f=${binary:Package}\t${Architecture}\t${Version}\t${db:Status-Abbrev}\n']
        original_versions = command(query)
        before = package_state(original_versions)
        receipt['package_status_before_sha256'] = hashlib.sha256(original_versions.encode()).hexdigest()
        for directory in ('lists/partial', 'archives/partial', 'empty'):
            (out / directory).mkdir(parents=True)
        sources = out / 'sources.list'
        sources.write_text(''.join('deb [arch=amd64 signed-by=/usr/share/keyrings/ubuntu-archive-keyring.gpg] '
                                  + BASE + ' ' + suite + ' main universe\n'
                                  for suite in ('noble', 'noble-updates', 'noble-security')))
        # Private configuration excludes ambient apt hooks and additional sources.
        config = out / 'apt.conf'
        config.write_text(apt_configuration(out, sources))
        # -c is read after default config, so bootstrap APT_CONFIG disables defaults too.
        env['APT_CONFIG'] = str(config)
        apt = ['/usr/bin/apt-get', '-c', str(config)]
        command(apt + ['update'], seconds=60)
        receipt['signed_release_metadata'] = verify_release_metadata(out / 'lists', lock); save()
        install = ['--yes', '--no-install-recommends', '--no-remove', 'install',
                   'ffmpeg=' + packages['ffmpeg']['version']]
        planned = transaction(command(apt + ['--simulate', *install]), packages)
        receipt['new_packages'] = [{'name': n, **p} for n, p in sorted(planned.items())]
        receipt['download_bytes'] = sum(p['bytes'] for p in planned.values()); save()
        uris = download_plan(command(apt + ['--print-uris', *install]), planned)
        for url, target, package in uris:
            require(time.monotonic() < deadline - 40, 'Insufficient time before installation')
            path = out / 'archives' / target
            digest = hashlib.sha256(); size = 0
            with urllib.request.urlopen(url, timeout=15) as response, path.open('xb') as dest:
                require(response.geturl() == url, 'Unexpected package redirect')
                while True:
                    require(time.monotonic() < deadline - 40, 'Package download deadline')
                    chunk = response.read(65536)
                    if not chunk: break
                    size += len(chunk); require(size <= package['bytes'], 'Oversized package')
                    digest.update(chunk); dest.write(chunk)
            require(size == package['bytes'] and digest.hexdigest() == package['sha256'], 'Package integrity mismatch')
        require(transaction(command(apt + ['--simulate', *install]), packages) == planned,
                'Package state changed before installation')
        require(package_state(command(query)) == before, 'Package status changed before installation')
        for name, row in planned.items():
            key = (name, 'all' if row['filename'].endswith('_all.deb') else 'amd64')
            require(key not in before, 'Planned package already has existing status: ' + name)
        if planned:
            receipt['installation_started'] = True; save()
            # Only verified cached packages are available. Never acquire more during install.
            command(install_command(apt, config, install, planned), seconds=90, privileged=True)
        versions = command(query)
        verify_package_delta(before, package_state(versions), planned)
        receipt['package_status_after_sha256'] = hashlib.sha256(versions.encode()).hexdigest()
        receipt['exact_package_delta_verified'] = True
        receipt['installed_dependency_versions'] = [line for line in versions.splitlines()
                                                    if line.split('\t')[0].removesuffix(':amd64') in packages]
        for name in ('ffmpeg', 'ffprobe'):
            path = Path('/usr/bin') / name
            require(path.is_file(), 'Missing renderer executable: ' + name)
            digest = hashlib.sha256(path.read_bytes()).hexdigest()
            require(digest == lock['executable_sha256'][name], 'Installed executable identity mismatch: ' + name)
            receipt[name] = {'path': str(path), 'sha256': digest}
        receipt['status'] = 'passed'
    except BaseException as exc:
        receipt.update(status='failed', error=type(exc).__name__ + ': ' + str(exc)[:1000])
        raise
    finally:
        save()

if __name__ == '__main__':
    main()

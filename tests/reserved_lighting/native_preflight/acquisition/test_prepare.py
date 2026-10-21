"""Acquisition source oracles only: injected network/storage/private-image adapters."""
import copy
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import tarfile
import unittest
import zipfile
from unittest.mock import patch

ROOT = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('acquisition_source_test', ROOT / 'prepare.py')
a = importlib.util.module_from_spec(spec); spec.loader.exec_module(a)
OWNER = 'a' * 32
RECIPE = ('FROM ' + a.BASE + '\nCOPY toolchain-rootfs/ /\nENV X=1\nUSER 65534:65534\nWORKDIR /work\nENTRYPOINT ["/usr/local/bin/python3.12", "-B"]\n').encode()


def ar_part(name, data):
    header = (name + '/').ljust(16) + '0'.ljust(12) + '0'.ljust(6) + '0'.ljust(6) + '100644'.ljust(8) + str(len(data)).ljust(10) + '`\n'
    return header.encode() + data + (b'\n' if len(data) % 2 else b'')


def fixture():
    plan = json.loads((ROOT / 'plan.json').read_text())
    plan.update(status='INDEPENDENTLY_REVIEWED', head='b' * 40, executor='injected-owner', recipe_sha256=a.digest(RECIPE),
                dependency_closure_provenance='INJECTED ONLY', network_provenance='INJECTED ONLY', artifact_handoff_provenance='INJECTED ONLY')
    compiler, daemon, loader = b'compiler data, never executed', b'daemon data, never executed', b'loader data, never executed'
    archive = io.BytesIO()
    with zipfile.ZipFile(archive, 'w') as output:
        output.writestr('byond/bin/DreamMaker', compiler)
        output.writestr('byond/bin/DreamDaemon', daemon)
    plan['archive'].update(bytes=len(archive.getvalue()), sha256=a.digest(archive.getvalue()), members={
        'byond/bin/DreamMaker': {'path': 'opt/byond/bin/DreamMaker', 'sha256': a.digest(compiler), 'bytes': len(compiler)},
        'byond/bin/DreamDaemon': {'path': 'opt/byond/bin/DreamDaemon', 'sha256': a.digest(daemon), 'bytes': len(daemon)}})
    tar = io.BytesIO()
    with tarfile.open(fileobj=tar, mode='w:gz') as output:
        row = tarfile.TarInfo('./lib/i386-linux-gnu/ld.so'); row.size = len(loader)
        output.addfile(row, io.BytesIO(loader))
    deb = b'!<arch>\n' + ar_part('debian-binary', b'2.0\n') + ar_part('data.tar.gz', tar.getvalue())
    dependency = {'kind': 'deb', 'url': 'https://deb.debian.org/debian/pool/main/l/loader/loader_i386.deb',
                  'sha256': a.digest(deb), 'bytes': len(deb), 'package': 'injected-loader', 'version': '1.0', 'architecture': 'i386',
                  'package_metadata_provenance': 'INJECTED ONLY',
                  'members': {'lib/i386-linux-gnu/ld.so': {'path': 'lib/ld-linux.so.2', 'sha256': a.digest(loader), 'bytes': len(loader)}}}
    plan['dependencies'] = [dependency]
    plan['routes'] = [plan['archive']['url'], dependency['url']]
    data = {plan['archive']['url']: archive.getvalue(), dependency['url']: deb}
    return plan, data


class Response:
    def __init__(self, url, data):
        self.url, self.data, self.status, self.closed = url, io.BytesIO(data), 200, False
        self.headers = {'Content-Length': str(len(data))}
    def read(self, size, timeout): return self.data.read(size)
    def close(self): self.closed = True


class Network:
    def __init__(self, data, transform=lambda x: None): self.data, self.calls, self.transform = data, [], transform
    def open(self, url, timeout, redirects):
        self.calls.append((url, timeout, redirects))
        response = Response(url, self.data[url]); self.transform(response)
        return response


class Storage:
    def __init__(self): self.files, self.calls, self.claimed = {}, [], False
    def claim(self, owner, sha): self.claimed = True; self.calls.append('claim')
    def reconcile_owned(self, owner, sha): return self.claimed
    def assert_owned(self, owner):
        if not self.claimed: raise ValueError('unowned volume')
    def proofs(self, owner):
        return {'hard_capacities': {key: a.LIMITS[key+'_bytes'] for key in ('source', 'daemon', 'evidence', 'export')},
                'separate_filesystems': True, 'no_links_or_escapes': True, 'enospc_controls': True}
    def create(self, owner, volume, name):
        key = (volume, name)
        if key in self.files: raise FileExistsError('exclusive collision')
        self.files[key] = bytearray(); self.calls.append(('create', key)); return key
    def write(self, key, value): self.files[key].extend(value)
    def close(self, key): pass
    def read_verified(self, owner, volume, name, sha, size):
        data = bytes(self.files[volume, name])
        if a.digest(data) != sha or len(data) != size: raise ValueError('storage mutation')
        return data
    def save(self, owner, volume, name, value, limit, timeout=None):
        data = json.dumps(value).encode()
        if len(data) > limit: raise ValueError('receipt bound')
        self.files[volume, name] = data
    def recipe_bytes(self, owner): return RECIPE
    def inventory(self, owner, volume, prefix):
        return {name[len(prefix)+1:]: {'sha256': a.digest(bytes(data)), 'bytes': len(data)}
                for (vol, name), data in self.files.items() if vol == volume and name.startswith(prefix+'/')}
    def cleanup_owned(self, owner, preserve, timeout):
        self.calls.append(('cleanup', preserve, timeout))
        return {'owned_scratch_retired': True}


class Image:
    def __init__(self): self.calls = []
    def preflight(self, owner, base, base_id, routes, timeout):
        self.calls.append('inspect-only')
        return {'accepted_private_daemon': True, 'native_commands': 0}
    def build_owned(self, owner, plan, storage, timeout):
        self.calls.append(('build', timeout))
        return {'image_id': 'sha256:' + 'e' * 64, 'base_id': a.BASE_ID, 'native_commands': 0, 'rootfs_verified': True}
    def export_owned(self, owner, storage, timeout):
        self.calls.append(('export', timeout))
        return {'bytes': 100, 'sha256': 'f' * 64}
    def cleanup_owned(self, owner, timeout):
        self.calls.append(('cleanup', timeout)); return {'all_exited': True, 'owned_state_retired': True}


class Acquisition(unittest.TestCase):
    def test_exact_official_origin_is_admitted_without_mirror_fallback(self):
        url = 'https://www.byond.com/download/build/516/516.1681_byond_linux.zip'
        try: a.route(url)
        except ValueError as failure: self.fail('Exact official route was rejected: '+str(failure))
        plan = json.loads((ROOT/'plan.json').read_text())
        self.assertEqual(plan['archive']['url'], url)
        self.assertEqual(plan['archive']['bytes'], 4884042)
        self.assertEqual(plan['archive']['sha256'], '614c126b9d0073c67558172c2c2fcb92c31298cf36092208ed55a416326bede3')
        self.assertEqual(len(plan['archive']['members']), 4)
        self.assertEqual(plan['status'], 'UNRESOLVED_SOURCE_ONLY')
        with self.assertRaisesRegex(ValueError, 'Unresolved acquisition plan'): a.validate(plan)

    def test_unapproved_official_aliases_and_expired_mirror_fail_before_effects(self):
        official = 'https://www.byond.com/download/build/516/516.1681_byond_linux.zip'
        for url in ['https://civ13.com/downloads/516.1681_byond_linux.zip',
                    official.replace('https:', 'http:'), official+'?token=x', official+'#fragment',
                    official.replace('www.byond.com', 'byond.com'),
                    official.replace('516.1681', '516.1682'), official.replace('www.byond.com', 'www.byond.com.evil.invalid'),
                    official.replace('/516/', '/516/../516/'), official.replace('www.byond.com', 'user@www.byond.com')]:
            with self.subTest(url=url):
                plan, data = fixture(); plan['archive']['url'] = url; plan['routes'][0] = url
                network, storage, image = Network(data), Storage(), Image()
                data[url] = data.pop(official)
                with self.assertRaisesRegex(ValueError, 'route|HTTPS'):
                    self.execute(plan=plan, network=network, storage=storage, image=image)
                self.assertEqual((network.calls,storage.calls,image.calls), ([],[],[]))

    def test_preexisting_claim_is_never_adopted_or_removed(self):
        class Existing(Storage):
            def claim(self, owner, sha): raise FileExistsError('existing operator claim')
            def reconcile_owned(self, *args): raise AssertionError('Must not adopt known preexisting claim')
        storage = Existing()
        result, network, _, image = self.execute(storage=storage)
        self.assertFalse(result['complete']); self.assertIn('existing operator claim', result['error'])
        self.assertEqual((network.calls, storage.calls, image.calls), ([], [], []))

    def test_transport_cleanup_failure_preserves_original_hash_error(self):
        plan, data = fixture()
        def corrupt(response):
            response.data = io.BytesIO(b'X' * len(data[response.url]))
            def close(): raise ValueError('close failed')
            response.close = close
        result, _, _, _ = self.execute(network=Network(data, corrupt))
        self.assertIn('hash/length mismatch', result['error'])
        self.assertTrue(any('close failed' in note for note in result['error_notes']))

    def test_bad_recipe_prevents_network_and_shared_quota_overflow_stops_second_stream(self):
        storage = Storage(); storage.recipe_bytes = lambda owner: RECIPE + b'RUN evil\n'
        result, network, _, _ = self.execute(storage=storage)
        self.assertFalse(result['complete']); self.assertEqual(network.calls, [])
        class Full(Storage):
            def write(self, key, value):
                if key[1].startswith('downloads/') and any(name == 'rootfs/opt/byond/bin/DreamMaker' for _, name in self.files):
                    raise OSError(28, 'aggregate hard source quota exhausted')
                return super().write(key, value)
        result, network, _, image = self.execute(storage=Full())
        self.assertFalse(result['complete']); self.assertEqual(len(network.calls), 2)
        self.assertIn('quota exhausted', result['error'])
        self.assertFalse(any(call[0] == 'build' for call in image.calls))

    def test_uncertain_storage_claim_reconciles_only_its_exact_owner(self):
        class Uncertain(Storage):
            def claim(self, owner, sha):
                super().claim(owner, sha)
                raise ValueError('uncertain owned claim')
        result, network, storage, _ = self.execute(storage=Uncertain())
        self.assertFalse(result['complete']); self.assertIn('uncertain owned claim', result['error'])
        self.assertEqual(network.calls, [])
        self.assertTrue(any(call[0] == 'cleanup' for call in storage.calls if isinstance(call, tuple)))

    def test_coherent_rootfs_change_during_build_is_rejected(self):
        image = Image()
        original = image.build_owned
        def mutate(owner, plan, storage, timeout):
            value = original(owner, plan, storage, timeout)
            storage.files['source', 'rootfs/opt/byond/bin/DreamMaker'] = b'changed compiler'
            return value
        image.build_owned = mutate
        result, _, _, _ = self.execute(image=image)
        self.assertFalse(result['complete']); self.assertIn('rootfs/recipe changed', result['error'])
    def execute(self, plan=None, network=None, storage=None, image=None, grant_change=lambda x: None, clock=lambda: 0, utc=lambda: 20):
        default, data = fixture()
        plan = plan or default
        grant = {'scope': a.SCOPE, 'head': plan['head'], 'executor': plan['executor'], 'granted': True, 'starts': 0, 'ends': 10000,
                 'plan_sha256': a.digest(json.dumps(plan, sort_keys=True, separators=(',', ':')).encode()),
                 'storage_accepted': True, 'network_accepted': True, 'private_daemon_accepted': True}
        grant_change(grant)
        network, storage, image = network or Network(data), storage or Storage(), image or Image()
        result = a.acquire(plan, grant, OWNER, network, storage, image, clock=clock, utc=utc)
        return result, network, storage, image

    def test_unresolved_template_has_zero_adapter_effects(self):
        storage, network, image = Storage(), Network({}), Image()
        with self.assertRaisesRegex(ValueError, 'Unresolved'):
            self.execute(plan=json.loads((ROOT / 'plan.json').read_text()), network=network, storage=storage, image=image)
        self.assertEqual((storage.calls, network.calls, image.calls), ([], [], []))

    def test_actual_acquire_reserves_both_cleanups_and_final_persistence(self):
        clock, storage, image = [0.0], Storage(), Image()
        export = image.export_owned
        def near_end(*args):
            value = export(*args); clock[0] = 569; return value
        image.export_owned = near_end
        timeouts = []
        def retire_image(owner, timeout):
            timeouts.append(timeout); clock[0] += timeout
            return {'all_exited': True}
        def retire_storage(owner, preserve, timeout):
            timeouts.append(timeout); clock[0] += timeout
            return {'owned_scratch_retired': True}
        image.cleanup_owned, storage.cleanup_owned = retire_image, retire_storage
        saved = storage.save
        def save(*args, **kw):
            if kw.get('timeout') is not None: clock[0] += .001
            return saved(*args, **kw)
        storage.save = save
        result, *_ = self.execute(storage=storage, image=image, clock=lambda: clock[0])
        self.assertTrue(result['complete']); self.assertLess(clock[0], 600)
        self.assertEqual(timeouts, [15, 10])

    def test_actual_acquire_never_passes_cleanup_utc_or_final_save_overrun(self):
        for fault in ('cleanup', 'utc', 'save'):
            with self.subTest(fault=fault):
                clock, utc, storage, image = [0.0], [20], Storage(), Image()
                export = image.export_owned
                def near_end(*args):
                    value = export(*args); clock[0] = 569; return value
                image.export_owned = near_end
                if fault == 'cleanup':
                    def retire(*args):
                        clock[0] = 601; return {'all_exited': True}
                    image.cleanup_owned = retire
                original = storage.save
                def save(*args, **kw):
                    value = args[3]
                    if value['complete']:
                        if fault == 'save': clock[0] = 600.001
                        if fault == 'utc': utc[0] = 10001
                    return original(*args, **kw)
                storage.save = save
                result, *_ = self.execute(storage=storage, image=image, clock=lambda: clock[0], utc=lambda: utc[0])
                self.assertFalse(result['complete'])
                self.assertFalse(json.loads(storage.files['evidence', 'acquisition.json'])['complete'])

    def test_raw_pax_gnu_and_unselected_data_are_bounded_before_metadata(self):
        plan, _ = fixture()
        loader = b'loader data, never executed'
        for kind in ('pax', 'gnu-name', 'gnu-link', 'unselected'):
            with self.subTest(kind=kind):
                stream = io.BytesIO()
                with tarfile.open(fileobj=stream, mode='w:gz', format=tarfile.PAX_FORMAT) as tar:
                    if kind in ('gnu-name', 'gnu-link'):
                        extra = tarfile.TarInfo('././@LongLink')
                        extra.type = tarfile.GNUTYPE_LONGNAME if kind == 'gnu-name' else tarfile.GNUTYPE_LONGLINK
                        body = b'./lib/i386-linux-gnu/ld.so\0' + b'X'*20000
                        extra.size = len(body); tar.addfile(extra, io.BytesIO(body))
                    if kind == 'unselected':
                        extra = tarfile.TarInfo('unselected'); extra.size = 20000; tar.addfile(extra, io.BytesIO(b'X'*20000))
                    row = tarfile.TarInfo('./lib/i386-linux-gnu/ld.so'); row.size = len(loader)
                    if kind == 'pax': row.pax_headers = {'comment': 'X'*20000}
                    tar.addfile(row, io.BytesIO(loader))
                deb = b'!<arch>\n' + ar_part('debian-binary', b'2.0\n') + ar_part('data.tar.gz', stream.getvalue())
                storage = Storage(); storage.claimed = True
                with patch.dict(a.LIMITS, {'rootfs_bytes': 1024}):
                    with self.assertRaisesRegex(ValueError, 'Raw archive expansion|Unsupported PAX/GNU|aggregate expansion'):
                        a.extract(plan['dependencies'][0], deb, storage, a.Budget(1000, lambda: 0, lambda: 20), OWNER)
                self.assertNotIn(('source', 'rootfs/lib/ld-linux.so.2'), storage.files)

    def test_injected_candidate_complete_is_not_native_admission(self):
        result, network, storage, image = self.execute()
        self.assertTrue(result['complete'])
        self.assertEqual(result['native_count'], 0)
        self.assertIn('CANDIDATE', result['artifact_status'])
        self.assertEqual(len(network.calls), 2)
        self.assertTrue(all(timeout <= 10 and redirects is False for _, timeout, redirects in network.calls))
        self.assertEqual(len([call for call in image.calls if call[0] == 'build']), 1)
        self.assertTrue(result['cleanup']['daemon']['all_exited'])

    def test_routes_hashes_dependencies_and_bounds_fail_before_claim(self):
        plan, _ = fixture()
        changes = [lambda p: p['archive'].update(sha256=None), lambda p: p['limits'].update(daemon_bytes=16*1024**3),
                   lambda p: p['archive'].update(url='http://civ13.com/downloads/516.1681_byond_linux.zip'),
                   lambda p: p['dependencies'][0].update(architecture='arm64'), lambda p: p.update(registry_hosts=['*']),
                   lambda p: p['dependencies'][0]['members']['lib/i386-linux-gnu/ld.so'].update(path='../private'),
                   lambda p: p['dependencies'][0]['members']['lib/i386-linux-gnu/ld.so'].update(path='root/.ssh/key')]
        for change in changes:
            candidate = copy.deepcopy(plan); change(candidate)
            storage = Storage()
            with self.assertRaises(ValueError): self.execute(candidate, storage=storage)
            self.assertEqual(storage.calls, [])

    def test_bad_grant_and_expiry_prevent_transport(self):
        for change in (lambda g: g.update(plan_sha256='0'*64), lambda g: g.update(ends=10), lambda g: g.update(ends=float('inf')),
                       lambda g: g.update(private_daemon_accepted=False)):
            network = Network({})
            with self.assertRaises(ValueError): self.execute(network=network, grant_change=change)
            self.assertEqual(network.calls, [])

    def test_storage_hard_cap_control_prevents_any_download(self):
        storage = Storage(); storage.proofs = lambda owner: {'hard_capacities': {}, 'separate_filesystems': True}
        result, network, _, image = self.execute(storage=storage)
        self.assertFalse(result['complete']); self.assertEqual(network.calls, []); self.assertEqual(image.calls, [])

    def test_redirect_length_encoding_and_hash_stop_before_image_build(self):
        plan, data = fixture()
        changes = [lambda r: setattr(r, 'status', 302), lambda r: setattr(r, 'url', 'https://evil.invalid/'),
                   lambda r: r.headers.update({'Content-Length': '999999999'}), lambda r: r.headers.update({'Content-Encoding': 'gzip'}),
                   lambda r: setattr(r, 'data', io.BytesIO(b'X' * len(data[r.url])))]
        for change in changes:
            result, network, _, image = self.execute(network=Network(data, change))
            self.assertFalse(result['complete'])
            self.assertEqual(len(network.calls), 1)
            self.assertFalse(any(call[0] == 'build' for call in image.calls))

    def test_duplicate_or_traversal_archive_never_extracts_unexpected_target(self):
        plan, _ = fixture()
        for bad in ('../escape', '/absolute', 'C:/live', 'byond/bin/DreamMaker'):
            output = io.BytesIO()
            with zipfile.ZipFile(output, 'w') as archive:
                archive.writestr(bad, b'data')
            storage = Storage(); storage.claimed = True
            with self.assertRaises(ValueError):
                a.extract(plan['archive'], output.getvalue(), storage, a.Budget(1000, lambda: 0, lambda: 20), OWNER)
            self.assertFalse(any('escape' in str(key) for key in storage.files))

    def test_deb_parser_never_invokes_package_scripts_and_rejects_bad_framing(self):
        plan, data = fixture()
        self.assertTrue(a.deb_data(data[plan['dependencies'][0]['url']]))
        for bad in (b'bad', b'!<arch>\n' + b'x'*60, data[plan['dependencies'][0]['url']][:-1]):
            with self.assertRaises((ValueError, UnicodeError)): a.deb_data(bad)

    def test_deadline_expiry_during_stream_preserves_original_error(self):
        plan, data = fixture(); clock = [0]
        class Slow(Response):
            def read(self, size, timeout): clock[0] = 580; return super().read(size, timeout)
        network = Network(data); network.open = lambda url, **kw: Slow(url, data[url])
        result, _, _, image = self.execute(network=network, clock=lambda: clock[0])
        self.assertFalse(result['complete']); self.assertIn('deadline', result['error'])
        self.assertFalse(any(call[0] == 'build' for call in image.calls))

    def test_uncertain_build_preserves_error_and_uses_only_owned_cleanup(self):
        image = Image()
        def fail(*args): image.calls.append(('build', 1)); raise ValueError('uncertain private daemon create')
        image.build_owned = fail
        result, _, storage, _ = self.execute(image=image)
        self.assertIn('uncertain private daemon create', result['error'])
        self.assertFalse(result['complete'])
        self.assertEqual(len([call for call in image.calls if call[0] == 'build']), 1)
        self.assertEqual(len([call for call in image.calls if call[0] == 'cleanup']), 1)

    def test_failed_daemon_retirement_preserves_storage_and_original_error(self):
        image = Image(); image.cleanup_owned = lambda *args: {'all_exited': False, 'identity_unknown': True}
        result, _, storage, _ = self.execute(image=image)
        self.assertFalse(result['complete'])
        self.assertFalse(any(call[0] == 'cleanup' for call in storage.calls if isinstance(call, tuple)))
        self.assertIn('unconfirmed', result['cleanup']['storage']['error'])

    def test_aggregate_member_targets_and_download_bytes_cannot_expand(self):
        plan, _ = fixture()
        plan['dependencies'][0]['members']['lib/i386-linux-gnu/ld.so']['path'] = 'opt/byond/bin/DreamMaker'
        with self.assertRaisesRegex(ValueError, 'collision'): a.validate(plan)


if __name__ == '__main__': unittest.main()

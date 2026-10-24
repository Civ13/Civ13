"""Reviewed offline pin/download/receipt controls. No sockets, DLLs or native tools."""
from copy import deepcopy
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import unittest
import urllib.error
from unittest.mock import patch
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('tested_byond_pin', ROOT / 'scripts/byond_toolchain.py')
pin = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pin)


class Response(io.BytesIO):
    status = 200

    def __init__(self, body, url, length=None):
        super().__init__(body)
        self.url = url
        self.headers = {} if length is None else {'Content-Length': str(length)}

    def geturl(self):
        return self.url


class ByondToolchainTests(unittest.TestCase):
    def setUp(self):
        self.value = pin.load()
        self.temp = self.enterContext(tempfile.TemporaryDirectory(prefix='byond-pin-offline-'))
        self.root = Path(self.temp)

    def read_value(self, value):
        path = self.root / 'pin.json'
        path.write_text(json.dumps(value))
        return pin.load(path)

    def test_canonical_manifest_embedded_directly_and_version_configuration_agrees(self):
        self.assertEqual(self.value['version'], '516.1688')
        self.assertEqual(self.value['minimumCompiler'], '516.1681')
        self.assertEqual(self.value['savefileMajor'], 516)
        native = ROOT / 'tools/opendream-client/native'
        project = ET.parse(native / 'Civ13.Launcher.csproj').getroot()
        resource = next(item for item in project.iter('EmbeddedResource') if item.get('LogicalName') == 'byond.json')
        self.assertEqual((native / resource.get('Include')).resolve(), pin.MANIFEST)
        self.assertFalse((native / 'byond.json').exists())
        self.assertEqual(project.find('PropertyGroup/Version').text, json.loads((native / 'version.json').read_text())['version'])
        self.assertEqual(project.find('PropertyGroup/Version').text, '1.0.8')

    def test_missing_malformed_and_noncanonical_versions_reject(self):
        for value in (None, True, 516.1688, '', '516', '516.01688', '0516.1688', ' 516.1688', '516.1688\n',
                      '516.1688.1', '516.-1', '65535.1688', '516.65535', '516.1688;echo unsafe'):
            with self.subTest(value=value), self.assertRaises(ValueError):
                pin.version(value)
        for key in ('version', 'minimumCompiler', 'savefileMajor'):
            value = deepcopy(self.value)
            del value[key]
            with self.subTest(missing=key), self.assertRaises(ValueError):
                self.read_value(value)
        value = deepcopy(self.value)
        value['minimumCompiler'] = '516.1689'
        with self.assertRaises(ValueError):
            self.read_value(value)

    def test_invalid_duplicate_or_oversized_metadata_rejects(self):
        path = self.root / 'bad.json'
        for text in ('null', '[]', '{}', '{', '{"schema":1,"schema":1}', ' ' * 32769):
            path.write_text(text)
            with self.subTest(text=text[:30]), self.assertRaises(ValueError):
                pin.load(path)
        with self.assertRaises(FileNotFoundError):
            pin.load(self.root / 'missing.json')
        for key, value in (('schema', True), ('savefileMajor', True), ('linux', None)):
            metadata = deepcopy(self.value)
            metadata[key] = value
            with self.subTest(key=key), self.assertRaises(ValueError):
                self.read_value(metadata)

    def test_exact_official_urls_only_and_external_text_never_becomes_code(self):
        for url in ('http://www.byond.com/download/build/516/516.1688_byond.exe',
                    self.value['url'] + '?x=1', self.value['url'] + '#fragment',
                    self.value['url'].replace('www.byond.com', 'www.byond.com:443'),
                    self.value['url'].replace('www.byond.com', 'user@www.byond.com'),
                    self.value['url'].replace('1688', '1681'), 'https://example.com/archive.exe',
                    '$(echo unsafe)', 'https://www.byond.com/download/build/LATEST/latest.exe'):
            metadata = deepcopy(self.value)
            metadata['url'] = url
            with self.subTest(url=url), self.assertRaises(ValueError):
                self.read_value(metadata)
        metadata = deepcopy(self.value)
        metadata['linux']['url'] = metadata['url']
        with self.assertRaises(ValueError):
            self.read_value(metadata)

    def test_hash_size_and_observed_provenance_are_required(self):
        for key, value in (('sha256', None), ('sha256', 'A' * 64), ('sha256', '0' * 63),
                           ('bytes', True), ('bytes', 0), ('bytes', pin.MAX_BYTES + 1),
                           ('integritySource', 'BYOND-published authenticated checksum'),
                           ('integritySource', self.value['integritySource'].replace('2026-10-24', '2026-99-99'))):
            metadata = deepcopy(self.value)
            metadata[key] = value
            with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                self.read_value(metadata)

    def fixture_download(self, body=b'offline archive fixture', **kwargs):
        metadata = deepcopy(self.value)
        metadata['linux'].update(bytes=len(body), sha256=hashlib.sha256(body).hexdigest())
        response = Response(body, metadata['linux']['url'], len(body))
        return metadata, response

    def test_download_checks_bytes_before_exclusive_publication(self):
        metadata, response = self.fixture_download()
        output = self.root / 'archive.zip'
        with patch.object(pin, 'load', return_value=metadata):
            receipt = pin.download('linux', output, opener=lambda *_args, **_kw: response)
        self.assertEqual(output.read_bytes(), b'offline archive fixture')
        self.assertEqual(receipt['sha256'], metadata['linux']['sha256'])
        self.assertIn('not BYOND-published', receipt['integritySource'])
        self.assertFalse(output.with_suffix('.zip.part').exists())

    def test_bad_response_hash_size_and_deadline_never_publish(self):
        for bad in ('status', 'url', 'length', 'short', 'long', 'hash', 'deadline'):
            metadata, response = self.fixture_download()
            if bad == 'status': response.status = 302
            if bad == 'url': response.url = 'https://example.com/archive.zip'
            if bad == 'length': response.headers['Content-Length'] = '999'
            if bad == 'short': metadata['linux']['bytes'] += 1; response.headers = {}
            if bad == 'long': metadata['linux']['bytes'] -= 1; response.headers = {}
            if bad == 'hash': metadata['linux']['sha256'] = '0' * 64
            ticks = iter((0, 61)) if bad == 'deadline' else None
            output = self.root / (bad + '.zip')
            with self.subTest(bad=bad), patch.object(pin, 'load', return_value=metadata), self.assertRaises(ValueError):
                pin.download('linux', output, opener=lambda *_a, **_k: response,
                             clock=(lambda: next(ticks)) if ticks else lambda: 0)
            self.assertFalse(output.exists())
            # Rejected response metadata never starts a body/partial; failed
            # byte/deadline verification retains its exclusive partial evidence.
            self.assertEqual(output.with_suffix('.zip.part').exists(), bad not in {'status', 'url', 'length'})

    def test_preexisting_output_and_partial_are_preserved_without_fetch(self):
        for suffix in ('.zip', '.zip.part'):
            output = self.root / ('existing' + suffix.replace('.', '_') + '.zip')
            existing = output if suffix == '.zip' else output.with_suffix('.zip.part')
            existing.write_bytes(b'preserve')
            with self.assertRaises((ValueError, FileExistsError)):
                pin.download('linux', output, opener=lambda *_a, **_k: self.fail('Unexpected network adapter'))
            self.assertEqual(existing.read_bytes(), b'preserve')
        with self.assertRaises(ValueError):
            pin.NoRedirect().redirect_request(None, None, None, None, None, None)

    def test_compiler_log_requires_one_exact_target_banner_and_clean_summary(self):
        clean = 'DM compiler version 516.1688\nciv13.dmb - 0 errors, 0 warnings\n'
        pin.compiler_log(clean, self.value['version'])
        for text in ('', clean.replace('1688', '1681'), clean.replace('1688', '1689'),
                     clean.replace('0 warnings', '1 warnings'), clean + 'DM compiler version 516.1688\n',
                     clean.replace('516.1688', '516.1688 extra')):
            with self.subTest(text=text), self.assertRaises(ValueError):
                pin.compiler_log(text, self.value['version'])

    def test_compile_receipts_reject_wrong_or_missing_actual_version(self):
        spec = importlib.util.spec_from_file_location('receipt_byond_test', ROOT / 'scripts/ci_baseline.py')
        ci = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(ci)
        plan = dict(head='a' * 40, base='b' * 40, requested_base='b' * 40, run_id='1', run_attempt='1',
                    compile={'selected': True, 'reason': 'source change'})
        for actual in ('516.1688', '516.1681', None):
            folder = self.root / str(actual)
            folder.mkdir()
            if actual is not None:
                (folder / 'byond-version.txt').write_text(actual + '\n')
            (folder / 'compiler.log').write_text('DM compiler version 516.1688\nciv13.dmb - 0 errors, 0 warnings\n')
            (folder / 'byond-download.json').write_text(json.dumps(self.receipt(self.value)))
            with self.subTest(actual=actual), patch.object(ci, 'git', return_value='tree'), patch.object(ci.subprocess, 'check_output', return_value=b''):
                status = ci.compile_receipt(plan, 'success', folder / 'receipt.json')
            receipt = json.loads((folder / 'receipt.json').read_text())
            self.assertEqual(status, 0 if actual == '516.1688' else 1)
            self.assertEqual(receipt['toolchain'], 'BYOND 516.1688')
            self.assertEqual(receipt['status'], 'passed' if actual == '516.1688' else 'failed')
        with patch.object(ci, 'git', return_value='tree'), patch.object(ci.subprocess, 'check_output', return_value=b''), patch.object(ci.toolchain, 'load', side_effect=ValueError('Malformed version metadata')):
            self.assertEqual(ci.compile_receipt(plan, 'success', self.root / 'invalid.json'), 1)

    def test_field_cli_reads_data_only_and_rejects_unknown_field(self):
        command = [sys.executable, '-B', str(ROOT / 'scripts/byond_toolchain.py'), 'field']
        for field, expected in (('version', '516.1688'), ('build', '1688'), ('linux-bin', '/opt/civ13-byond-516.1688/byond/bin')):
            result = subprocess.run([*command, field], capture_output=True, text=True, timeout=5)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout.strip(), expected)
        self.assertNotEqual(subprocess.run([*command, 'url;echo unsafe'], capture_output=True, timeout=5).returncode, 0)

    def test_legacy_workflow_selection_is_explicit_and_separate(self):
        for name in ('component-tools.yml', 'train-collision.yml'):
            text = (ROOT / '.github/workflows' / name).read_text()
            self.assertIn('travis_pre_byond.sh --legacy-fixture-5161681', text)
            self.assertIn("BYOND_MINOR: '1681'", text)
        workflow = (ROOT / '.github/workflows/test.yml').read_text()
        self.assertIn('BYOND_MINOR: "1688"', workflow)
        extraction = workflow.split('  extraction-instances:\n')[1].split('\n  build:')[0]
        self.assertIn('BYOND_MINOR: "1681"', extraction)

    def test_default_workflow_literals_match_the_central_manifest(self):
        # GitHub top-level env cannot read a checkout file. Keep this deliberate
        # projection checked in the always-run bootstrap suite, independently
        # of explicit job-local historical fixture exceptions.
        workflow = (ROOT / '.github/workflows/test.yml').read_text()
        global_env = workflow.split('\nenv:\n', 1)[1].split('\njobs:\n', 1)[0]
        values = {}
        for key in ('BYOND_MAJOR', 'BYOND_MINOR'):
            matches = re.findall(r'^  ' + key + r': "([0-9]+)"$', global_env, re.M)
            self.assertEqual(len(matches), 1, 'Missing or duplicate global BYOND literal: ' + key)
            values[key] = int(matches[0])
        self.assertEqual((values['BYOND_MAJOR'], values['BYOND_MINOR']), pin.version(self.value['version']),
                         'Global CI version literals differ from tools/byond/version.json')

    def receipt(self, value, source='official', cache_status='disabled'):
        archive = value['linux']
        url = pin.source_url(value, 'linux', source)
        return dict(version=value['version'], platform='linux', url=url, sha256=archive['sha256'],
                    bytes=archive['bytes'], integritySource=value['integritySource'], source=source,
                    requested_source=source, upstream_source=source, upstream_url=url,
                    cache_key=pin.cache_key(value, 'linux'), cache_status=cache_status)

    def test_reviewed_mirror_url_is_exact_and_original_official_bytes_stay_pinned(self):
        self.assertEqual(self.value['linux']['sha256'], '16278f318cdeb4b77c57868dd7135032fde717ea6226269d22b2a1a50968e7f9')
        self.assertEqual(self.value['linux']['bytes'], 4887281)
        url = self.value['linux']['communityMirrorUrl']
        self.assertEqual(url, 'https://byond-builds.dm-lang.org/516/516.1688_byond_linux.zip')
        for bad in (url.replace('1688', '1681'), url.replace('1688', 'latest'), url+'?x=1', url+'#part',
                    url.replace('https:', 'http:'), url.replace('dm-lang.org', 'dm-lang.org:443'),
                    url.replace('byond-builds.dm-lang.org', 'example.com'), url.replace('/516/', '/515/')):
            value = deepcopy(self.value)
            value['linux']['communityMirrorUrl'] = bad
            with self.subTest(url=bad), self.assertRaises(ValueError):
                self.read_value(value)

    def test_cold_and_warm_archive_cache_are_verified_with_exact_source_receipts(self):
        metadata, _ = self.fixture_download()
        url = metadata['linux']['communityMirrorUrl']
        calls = []
        def fetch(actual, **kwargs):
            calls.append((actual, kwargs))
            return Response(b'offline archive fixture', url, metadata['linux']['bytes'])
        cache = self.root/'cache'
        with patch.object(pin, 'load', return_value=metadata):
            cold = pin.download('linux', self.root/'cold.zip', source='community-mirror', cache_dir=cache, opener=fetch)
            warm = pin.download('linux', self.root/'warm.zip', source='community-mirror', cache_dir=cache,
                                opener=lambda *_a, **_k:self.fail('Warm cache must not fetch'))
        self.assertEqual(calls, [(url, {'timeout':15})])
        self.assertEqual(cold, self.receipt(metadata, 'community-mirror', 'miss'))
        self.assertEqual(warm, dict(cold, source='cache', url=None, cache_status='hit'))
        self.assertEqual((self.root/'warm.zip').read_bytes(), b'offline archive fixture')
        self.assertIn('-linux-516.1688-'+metadata['linux']['sha256'], warm['cache_key'])
        self.assertEqual({p.name for p in cache.iterdir()}, {cold['cache_key']+'.zip', cold['cache_key']+'.json'})

    def test_cache_key_changes_with_platform_version_and_expected_hash(self):
        original = pin.cache_key(self.value, 'linux')
        for change in ('version', 'hash', 'platform'):
            metadata = deepcopy(self.value)
            platform = 'linux'
            if change == 'version': metadata['version'] = '516.1689'
            if change == 'hash': metadata['linux']['sha256'] = '1'*64
            if change == 'platform': platform = 'windows'
            self.assertNotEqual(original, pin.cache_key(metadata, platform))

    def test_corrupt_cache_is_preserved_and_never_falls_back_to_network(self):
        metadata, _ = self.fixture_download()
        for bad in ('hash', 'size', 'receipt', 'missing-receipt', 'origin'):
            cache = self.root/bad
            cache.mkdir()
            archive = cache/(pin.cache_key(metadata, 'linux')+'.zip')
            body = b'X'*metadata['linux']['bytes'] if bad == 'hash' else b'offline archive fixture'
            if bad == 'size': body += b'X'
            archive.write_bytes(body)
            receipt = self.receipt(metadata, 'community-mirror', 'miss')
            if bad == 'receipt': receipt['version'] = '516.1681'
            if bad == 'origin': receipt['upstream_url'] = 'https://example.com/archive.zip'
            if bad != 'missing-receipt': archive.with_suffix('.json').write_text(json.dumps(receipt))
            with self.subTest(bad=bad), patch.object(pin, 'load', return_value=metadata), self.assertRaises((ValueError, OSError)):
                pin.download('linux', self.root/(bad+'.zip'), source='community-mirror', cache_dir=cache,
                             opener=lambda *_a, **_k:self.fail('No corrupt-cache network fallback'))
            self.assertEqual(archive.read_bytes(), body)
            self.assertFalse((self.root/(bad+'.zip')).exists())

    def test_mirror_wrong_version_origin_hash_and_size_never_publish_or_cache(self):
        for bad in ('version', 'origin', 'redirect', 'length', 'short', 'long', 'hash'):
            metadata, _ = self.fixture_download()
            url = metadata['linux']['communityMirrorUrl']
            response = Response(b'offline archive fixture', url, metadata['linux']['bytes'])
            if bad == 'version': response.url = url.replace('1688', '1681')
            if bad == 'origin': response.url = 'https://example.com/archive.zip'
            if bad == 'redirect': response.status = 302
            if bad == 'length': response.headers['Content-Length'] = '999'
            if bad == 'short': metadata['linux']['bytes'] += 1; response.headers = {}
            if bad == 'long': metadata['linux']['bytes'] -= 1; response.headers = {}
            if bad == 'hash': metadata['linux']['sha256'] = '0'*64
            cache, output = self.root/('cache-'+bad), self.root/(bad+'.zip')
            calls = []
            def fetch(actual, **_kwargs): calls.append(actual); return response
            with self.subTest(bad=bad), patch.object(pin, 'load', return_value=metadata), self.assertRaises(ValueError):
                pin.download('linux', output, source='community-mirror', cache_dir=cache, opener=fetch)
            self.assertEqual(calls, [url])
            self.assertFalse(output.exists())
            self.assertEqual(list(cache.iterdir()), [])

    def test_network_failure_has_no_automatic_official_or_arbitrary_fallback(self):
        calls = []
        def fail(url, **_kwargs):
            calls.append(url)
            raise urllib.error.HTTPError(url, 403, 'offline denied fixture', {}, None)
        with self.assertRaises(urllib.error.HTTPError):
            pin.download('linux', self.root/'unavailable.zip', source='community-mirror', opener=fail)
        self.assertEqual(calls, [self.value['linux']['communityMirrorUrl']])
        for source, platform in (('https://example.com', 'linux'), ('community-mirror', 'windows'), ('fallback', 'linux')):
            with self.subTest(source=source, platform=platform), self.assertRaises(ValueError):
                pin.download(platform, self.root/'no.zip', source=source, opener=lambda *_a, **_k:self.fail('Unreviewed source fetched'))

    def test_cache_receipt_metadata_is_bounded_duplicate_free_and_exact_source(self):
        valid = self.receipt(self.value, 'community-mirror', 'miss')
        pin.validate_download_receipt(valid, self.value, 'linux')
        for key, bad in (('version','516.1681'), ('platform','windows'), ('sha256','0'*64), ('bytes',True),
                         ('cache_key','byond-latest'), ('source','cache'), ('url','https://example.com'),
                         ('upstream_source','unknown'), ('upstream_url',valid['url']+'?x=1'),
                         ('integritySource','vendor authenticated'), ('cache_status',[])):
            broken = dict(valid, **{key:bad})
            with self.subTest(key=key), self.assertRaises(ValueError):
                pin.validate_download_receipt(broken, self.value, 'linux')
        path = self.root/'receipt.json'
        for text in ('{}', ' '*32769, '{"source":"official","source":"cache"}'):
            path.write_text(text)
            with self.assertRaises(ValueError): pin.read_download_receipt(path, self.value, 'linux')

    def test_workflow_uses_archive_only_exact_cache_and_never_skips_target_compile_on_hit(self):
        text = (ROOT/'.github/workflows/test.yml').read_text().split('\n  build:\n')[1]
        self.assertIn('field linux-cache-key', text)
        self.assertIn('actions/cache/restore@5a3ec84eff668545956fd18022155c47e93e2684', text)
        self.assertIn('actions/cache/save@5a3ec84eff668545956fd18022155c47e93e2684', text)
        self.assertNotIn('restore-keys:', text)
        self.assertIn('BYOND_ARCHIVE_SOURCE: community-mirror', text)
        compile_step = text.split('- name: Compile selected exact-head game')[1].split('\n      - name:')[0]
        self.assertIn("if: needs.changes.outputs.game == 'true'", compile_step)
        self.assertNotIn('cache-hit', compile_step)
        self.assertIn('bash ./scripts/travis_pre_byond.sh', compile_step)

    def test_warm_cache_deadline_preserves_cache_and_never_publishes_output(self):
        metadata, _ = self.fixture_download()
        cache = self.root/'deadline-cache'
        cache.mkdir()
        archive = cache/(pin.cache_key(metadata,'linux')+'.zip')
        archive.write_bytes(b'offline archive fixture')
        archive.with_suffix('.json').write_text(json.dumps(self.receipt(metadata,'community-mirror','miss')))
        ticks = iter((0,61))
        with patch.object(pin,'load',return_value=metadata), self.assertRaisesRegex(ValueError,'deadline'):
            pin.download('linux',self.root/'deadline.zip',source='community-mirror',cache_dir=cache,
                         clock=lambda:next(ticks),opener=lambda *_a,**_k:self.fail('Warm deadline triggered network'))
        self.assertEqual(archive.read_bytes(),b'offline archive fixture')
        self.assertFalse((self.root/'deadline.zip').exists())

    def test_incomplete_cache_partial_refuses_network_and_preserves_evidence(self):
        cache=self.root/'incomplete-cache'
        cache.mkdir()
        partial=cache/(pin.cache_key(self.value,'linux')+'.zip.part')
        partial.write_bytes(b'failed cached transfer')
        with self.assertRaisesRegex(ValueError,'Incomplete cached'):
            pin.download('linux',self.root/'incomplete.zip',source='community-mirror',cache_dir=cache,
                         opener=lambda *_a,**_k:self.fail('Incomplete cache caused network fallback'))
        self.assertEqual(partial.read_bytes(),b'failed cached transfer')

    def test_compile_receipt_requires_valid_acquisition_despite_clean_mock_compiler_log(self):
        spec = importlib.util.spec_from_file_location('acquisition_receipt_test',ROOT/'scripts/ci_baseline.py')
        ci = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(ci)
        plan=dict(head='a'*40,base='b'*40,requested_base='b'*40,run_id='1',run_attempt='1',compile={'selected':True,'reason':'changed source'})
        for bad in ('missing','malformed','wrong-version','mirror','cache'):
            directory=self.root/bad
            directory.mkdir()
            (directory/'byond-version.txt').write_text('516.1688\n')
            (directory/'compiler.log').write_text('DM compiler version 516.1688\nciv13.dmb - 0 errors, 0 warnings\n')
            receipt=self.receipt(self.value,'community-mirror','miss')
            if bad=='wrong-version': receipt['version']='516.1681'
            if bad=='cache': receipt.update(source='cache',url=None,cache_status='hit')
            if bad!='missing': (directory/'byond-download.json').write_text('{' if bad=='malformed' else json.dumps(receipt))
            with self.subTest(case=bad),patch.object(ci,'git',return_value='tree'),patch.object(ci.subprocess,'check_output',return_value=b''):
                result=ci.compile_receipt(plan,'success',directory/'compile.json')
            expected=bad in {'mirror','cache'}
            self.assertEqual(result,0 if expected else 1)
            actual=json.loads((directory/'compile.json').read_text())
            self.assertEqual(actual['status'],'passed' if expected else 'failed')
            if expected: self.assertEqual(actual['acquisition'],receipt)


if __name__ == '__main__':
    unittest.main()

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
            self.assertTrue(output.with_suffix('.zip.part').exists())

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


if __name__ == '__main__':
    unittest.main()

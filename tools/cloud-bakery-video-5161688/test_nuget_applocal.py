"""Offline fixtures for pinned app-local staging and owned-module validation."""
import hashlib
import ctypes as c
from ctypes import wintypes as w
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import zipfile

import acquire
import nuget_local_runtime as runtime
import nuget_pins as pins
import owned_nuget_modules as modules
import prepare_nuget_toolchain as prepare


def fixture_pins():
    return {'d3dx9_43.dll': {'member':'build/native/release/bin/x86/D3DX9_43.dll', 'bytes':4,
                              'sha256':hashlib.sha256(b'd3dx').hexdigest()},
            'd3dcompiler_43.dll': {'member':'build/native/release/bin/x86/D3DCompiler_43.dll', 'bytes':4,
                                   'sha256':hashlib.sha256(b'comp').hexdigest()}}


class NugetTests(unittest.TestCase):
    def test_package_extracts_only_pinned_members_and_rejects_unsafe_names(self):
        fake=fixture_pins()
        entries={fake['d3dx9_43.dll']['member']:b'd3dx', fake['d3dcompiler_43.dll']['member']:b'comp',
                 'LICENSE.txt':b'license','NOTICE.md':b'notice','.signature.p7s':b'sig'}
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);archive=root/'p.nupkg'
            def write_archive():
                with zipfile.ZipFile(archive,'w') as z:
                    for name,data in entries.items():z.writestr(name,data)
            def identity():
                raw=archive.read_bytes()
                return {'FILES':fake, 'PACKAGE_BYTES':len(raw), 'PACKAGE_SHA256':hashlib.sha256(raw).hexdigest(),
                        'LICENSE_BYTES':7, 'LICENSE_SHA256':hashlib.sha256(b'license').hexdigest(),
                        'NOTICE_BYTES':6, 'NOTICE_SHA256':hashlib.sha256(b'notice').hexdigest()}
            write_archive()
            with patch.multiple(pins,**identity()),patch.object(prepare,'NUGET_ENTRIES',len(entries)), \
                 patch.object(prepare,'NUGET_UNPACKED_BYTES',sum(map(len,entries.values()))),patch.object(acquire,'_pe_x86'):
                result=prepare.inspect_package(archive,root/'selected',lambda:None)
                self.assertEqual(set(result),{'d3dx9_43.dll','d3dcompiler_43.dll','LICENSE.txt','NOTICE.md'})
            entries['../escape']=b'x';write_archive()
            with patch.multiple(pins,**identity()),patch.object(prepare,'NUGET_ENTRIES',len(entries)), \
                 patch.object(prepare,'NUGET_UNPACKED_BYTES',sum(map(len,entries.values()))),patch.object(acquire,'_pe_x86'):
                with self.assertRaisesRegex(RuntimeError,'nuget_unsafe_path'):
                    prepare.inspect_package(archive,root/'bad',lambda:None)
            self.assertFalse((root/'bad').exists())

    def test_holds_precede_runtime_and_file_operations(self):
        with patch.object(prepare, 'PREPARE_NUGET_ENABLED', False), \
             patch.object(prepare, 'NUGET_LICENSE_ACCEPTED', True), \
             patch('activation.require_runtime', side_effect=AssertionError('unexpected binding')):
            with self.assertRaisesRegex(RuntimeError, 'nuget_prepare_held'):
                prepare.prepare('unused')
        with patch.object(runtime, 'APPLOCAL_STAGE_ENABLED', False), \
             patch.object(runtime, 'NUGET_LICENSE_ACCEPTED', True), \
             patch.object(runtime, 'binding', side_effect=AssertionError('unexpected binding')):
            with self.assertRaisesRegex(RuntimeError, 'nuget_stage_held'):
                runtime.stage('unused')

    def test_disabled_license_independently_blocks_both(self):
        with patch.object(prepare, 'PREPARE_NUGET_ENABLED', True), \
             patch.object(prepare, 'NUGET_LICENSE_ACCEPTED', False):
            with self.assertRaisesRegex(RuntimeError, 'nuget_prepare_held'): prepare.prepare('unused')
        with patch.object(runtime, 'APPLOCAL_STAGE_ENABLED', True), \
             patch.object(runtime, 'NUGET_LICENSE_ACCEPTED', False):
            with self.assertRaisesRegex(RuntimeError, 'nuget_stage_held'): runtime.stage('unused')

    def test_static_module_path_identity_and_absence(self):
        fake=fixture_pins()
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);dll=root/'d3dx9_43.dll'
            with patch.object(pins, 'FILES', fake), patch.object(acquire, '_plain_ancestors'), \
                 patch.object(acquire, '_read', return_value=b'd3dx'), patch.object(acquire, '_pe_x86'):
                result=modules.validate_paths([str(dll)],root)
                self.assertFalse(result['compiler_loaded'])
                with self.assertRaisesRegex(RuntimeError, 'nuget_module_wrong_path'):
                    modules.validate_paths([str(root/'other'/'d3dx9_43.dll')],root)
                with self.assertRaisesRegex(RuntimeError, 'duplicate_nuget_module'):
                    modules.validate_paths([str(dll),str(dll)],root)
                with self.assertRaisesRegex(RuntimeError, 'nuget_d3dx_module_not_loaded'):
                    modules.validate_paths([],root)

    def test_owned_module_probe_filters_paths_and_rechecks_identity(self):
        class Call:
            def __init__(self, fn): self.fn=fn
            def __call__(self,*args): return self.fn(*args)
        def enumerate_modules(handle, array, size, needed, selector):
            self.assertEqual(selector,1)
            array[0]=1;array[1]=2
            c.cast(needed,c.POINTER(w.DWORD))[0]=2*c.sizeof(w.HMODULE)
            return 1
        def module_name(handle, module, buffer, size):
            paths={1:'C:/fixture/d3dx9_43.dll',2:'C:/fixture/unrelated.dll'}
            buffer.value=paths[module]
            return len(buffer.value)
        class PS: pass
        ps=PS();ps.EnumProcessModulesEx=Call(enumerate_modules);ps.GetModuleFileNameExW=Call(module_name)
        class Adapter:
            def __init__(self):self.ps=ps;self.calls=0
            def exited(self,process):return False
            def identity(self,process):self.calls+=1;return {'pid':7,'creation_filetime':9}
        class Process: process=123
        adapter=Adapter()
        with patch.object(modules.os,'name','nt'), \
             patch.object(modules,'validate_paths',return_value={'modules':{},'compiler_loaded':False}) as validate:
            result=modules.inspect(adapter,Process(),Path('unused'))
        self.assertEqual(result['pid'],7)
        self.assertEqual(adapter.calls,2)
        self.assertEqual(validate.call_args.args[0],['C:/fixture/d3dx9_43.dll'])

    def test_stage_rolls_back_owned_files_on_postcheck_failure(self):
        fake=fixture_pins();context={'GITHUB_SHA':'a'*40}
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);src=root/'source';src.mkdir();dest=root/'byond'/'bin';dest.mkdir(parents=True)
            (src/'d3dx9_43.dll').write_bytes(b'd3dx');(src/'d3dcompiler_43.dll').write_bytes(b'comp')
            with patch.object(pins,'FILES',fake), patch.object(runtime,'APPLOCAL_STAGE_ENABLED',True), \
                 patch.object(runtime,'NUGET_LICENSE_ACCEPTED',True), patch.object(runtime,'binding',return_value=context), \
                 patch.object(runtime,'verify_source',return_value=src), \
                 patch.object(acquire,'verify_files',side_effect=[{},RuntimeError('postcheck_failed')]):
                with self.assertRaisesRegex(RuntimeError,'postcheck_failed'):runtime.stage(root)
            self.assertFalse((dest/'d3dx9_43.dll').exists())
            self.assertFalse((dest/'d3dcompiler_43.dll').exists())
            receipt=json.loads((root/'nuget-runtime-receipt.json').read_text())
            self.assertEqual(receipt['status'],'FAILED')
            self.assertTrue(receipt['owned_partial_files_removed'])

    def test_stage_retains_receipt_when_source_verification_fails(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp)
            with patch.object(runtime,'APPLOCAL_STAGE_ENABLED',True), \
                 patch.object(runtime,'NUGET_LICENSE_ACCEPTED',True), \
                 patch.object(runtime,'binding',return_value={'GITHUB_SHA':'a'*40}), \
                 patch.object(runtime,'verify_source',side_effect=RuntimeError('nuget_source_identity')):
                with self.assertRaisesRegex(RuntimeError,'nuget_source_identity'):runtime.stage(root)
            receipt=json.loads((root/'nuget-runtime-receipt.json').read_text())
            self.assertEqual(receipt['error'],'nuget_source_identity')
            self.assertEqual(receipt['status'],'FAILED')
            self.assertTrue(receipt['owned_partial_files_removed'])

    def test_successful_stage_writes_only_exact_pair_and_receipt(self):
        fake=fixture_pins();context={'GITHUB_SHA':'a'*40}
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);src=root/'source';src.mkdir();dest=root/'byond'/'bin';dest.mkdir(parents=True)
            (src/'d3dx9_43.dll').write_bytes(b'd3dx');(src/'d3dcompiler_43.dll').write_bytes(b'comp')
            with patch.object(pins,'FILES',fake),patch.object(runtime,'APPLOCAL_STAGE_ENABLED',True), \
                 patch.object(runtime,'NUGET_LICENSE_ACCEPTED',True),patch.object(runtime,'binding',return_value=context), \
                 patch.object(runtime,'verify_source',return_value=src),patch.object(acquire,'verify_files'):
                receipt=runtime.stage(root)
            self.assertEqual(receipt['status'],'PASSED')
            self.assertFalse(receipt['runtime_verified'])
            self.assertEqual({p.name for p in dest.iterdir()},set(fake))
            self.assertEqual((dest/'d3dx9_43.dll').read_bytes(),b'd3dx')
            self.assertTrue((root/'nuget-runtime-receipt.json').exists())

    def test_acquire_rejects_tampered_or_incomplete_nuget_pair(self):
        fake=fixture_pins()
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);dest=root/'byond'/'bin';dest.mkdir(parents=True)
            d=dest/'d3dx9_43.dll';c=dest/'d3dcompiler_43.dll'
            d.write_bytes(b'd3dx');c.write_bytes(b'comp')
            with patch.object(acquire,'NUGET_FILES',fake), \
                 patch.object(acquire,'_vendor',return_value={'files':[],'binaries':{}}),patch.object(acquire,'_pe_x86'):
                acquire.verify_files(root)
                extra=dest/'unreviewed.dll';extra.write_bytes(b'x')
                with self.assertRaisesRegex(acquire.PreflightError,'unexpected_bin_entry'):
                    acquire.verify_files(root)
                extra.unlink()
                c.write_bytes(b'bad!')
                with self.assertRaisesRegex(acquire.PreflightError,'app_local_nuget_changed'):
                    acquire.verify_files(root)
                d.unlink()
                with self.assertRaisesRegex(acquire.PreflightError,'app_local_pair_incomplete'):
                    acquire.verify_files(root)

    def test_stale_runtime_receipt_rejected(self):
        fake=fixture_pins();context={'GITHUB_SHA':'a'*40}
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);receipt={'status':'PASSED','binding':{'GITHUB_SHA':'b'*40},
                'package_sha256':pins.PACKAGE_SHA256,'license_sha256':pins.LICENSE_SHA256,
                'license_accepted_by_user':True,'files':{n:p['sha256'] for n,p in fake.items()}}
            (root/'nuget-runtime-receipt.json').write_text(json.dumps(receipt))
            with patch.object(pins,'FILES',fake),patch.object(runtime,'binding',return_value=context), \
                 patch.object(runtime,'APPLOCAL_STAGE_ENABLED',True),patch.object(runtime,'NUGET_LICENSE_ACCEPTED',True), \
                 patch.object(runtime,'verify_source'),patch.object(acquire,'verify_files'):
                with self.assertRaisesRegex(RuntimeError,'nuget_runtime_receipt_mismatch'):
                    runtime.verify_receipt(root)

    def test_source_requires_same_run_valid_signatures_and_exact_bytes(self):
        fake=fixture_pins()
        context={'GITHUB_SHA':'a'*40,'GITHUB_RUN_ID':'123','GITHUB_JOB':'bakery',
                 'GITHUB_RUN_ATTEMPT':'1','GITHUB_REF':'refs/heads/fixture'}
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);pkg=root/'official-nuget';selected=pkg/'selected';selected.mkdir(parents=True)
            (pkg/'Microsoft.DXSDK.D3DX.9.29.952.8.nupkg').write_bytes(b'pkg')
            (selected/'LICENSE.txt').write_bytes(b'license');(selected/'NOTICE.md').write_bytes(b'notice')
            (selected/'d3dx9_43.dll').write_bytes(b'd3dx');(selected/'d3dcompiler_43.dll').write_bytes(b'comp')
            package_sha=hashlib.sha256(b'pkg').hexdigest()
            prep={'status':'PASSED','binding':{'controller':'a'*40,'run_id':'123','job':'bakery','run_attempt':1},
                  'nuget_download':{'sha256':package_sha}}
            (root/'nuget-preparation-receipt.json').write_text(json.dumps(prep))
            sig={'status':'PASSED','binding':context,'files':{name:{'bytes':pin['bytes'],'sha256':pin['sha256'],
                  'signature':'Valid','signer_thumbprint':pins.SIGNER_THUMBPRINT} for name,pin in fake.items()}}
            (root/'nuget-signature-receipt.json').write_text(json.dumps(sig))
            overrides={'FILES':fake,'PACKAGE_BYTES':3,'PACKAGE_SHA256':package_sha,
                       'LICENSE_SHA256':hashlib.sha256(b'license').hexdigest(),
                       'NOTICE_SHA256':hashlib.sha256(b'notice').hexdigest()}
            with patch.multiple(pins,**overrides),patch.object(acquire,'_pe_x86'), \
                 patch('activation.require_runtime', return_value=prep['binding']):
                self.assertEqual(runtime.verify_source(root,context),selected)
                sig['files']['d3dx9_43.dll']['signer_thumbprint']='bad'
                (root/'nuget-signature-receipt.json').write_text(json.dumps(sig))
                with self.assertRaisesRegex(RuntimeError,'nuget_signature_identity'):
                    runtime.verify_source(root,context)


if __name__=='__main__':unittest.main()

"""Held staging and same-run verification of two signed app-local DLLs."""
import json
import os
from pathlib import Path
import re

import acquire
import nuget_pins as pins
from directx_official_setup import binding, require

APPLOCAL_STAGE_ENABLED = True
NUGET_LICENSE_ACCEPTED = True


def verify_source(root, context):
    root = Path(root).absolute()
    acquire._plain_ancestors(root)
    directory = root/'official-nuget'/'selected'
    acquire._plain_ancestors(directory)
    package = acquire._read(root/'official-nuget'/'Microsoft.DXSDK.D3DX.9.29.952.8.nupkg', pins.PACKAGE_BYTES)
    require(len(package) == pins.PACKAGE_BYTES and acquire._sha(package) == pins.PACKAGE_SHA256,
            'nuget_archive_identity')
    for name, digest in (('LICENSE.txt', pins.LICENSE_SHA256), ('NOTICE.md', pins.NOTICE_SHA256)):
        raw = acquire._read(directory/name, 16384)
        require(acquire._sha(raw) == digest, 'nuget_notice_identity')
    preparation = json.loads(acquire._read(root/'nuget-preparation-receipt.json', 16384))
    prep_binding = preparation.get('binding', {})
    from activation import require_runtime
    admission = require_runtime()
    require(preparation.get('status') == 'PASSED' and
            prep_binding == admission and
            prep_binding.get('controller') == context['GITHUB_SHA'] and
            prep_binding.get('run_id') == context['GITHUB_RUN_ID'] and
            prep_binding.get('job') == context['GITHUB_JOB'] and
            prep_binding.get('run_attempt') == 1 and
            preparation.get('nuget_download', {}).get('sha256') == pins.PACKAGE_SHA256,
            'nuget_preparation_receipt')
    sig = json.loads(acquire._read(root/'nuget-signature-receipt.json', 16384))
    require(sig.get('status') == 'PASSED' and sig.get('binding') == context and
            set(sig.get('files', {})) == set(pins.FILES), 'nuget_signature_receipt')
    for name, pin in pins.FILES.items():
        row = sig['files'][name]
        require(row.get('signature') == 'Valid' and row.get('signer_thumbprint') == pins.SIGNER_THUMBPRINT and
                row.get('bytes') == pin['bytes'] and row.get('sha256') == pin['sha256'],
                'nuget_signature_identity')
        raw = acquire._read(directory/name, pin['bytes'])
        require(len(raw) == pin['bytes'] and acquire._sha(raw) == pin['sha256'], 'nuget_source_identity')
        acquire._pe_x86(raw)
    return directory


def verify_receipt(root):
    require(APPLOCAL_STAGE_ENABLED is True and NUGET_LICENSE_ACCEPTED is True, 'nuget_runtime_held')
    context = binding()
    root = Path(root).absolute()
    verify_source(root, context)
    row = json.loads(acquire._read(root/'nuget-runtime-receipt.json', 16384))
    expected = {name: pin['sha256'] for name, pin in pins.FILES.items()}
    require(row.get('status') == 'PASSED' and row.get('binding') == context and
            row.get('package_sha256') == pins.PACKAGE_SHA256 and row.get('files') == expected and
            row.get('license_sha256') == pins.LICENSE_SHA256 and
            row.get('license_accepted_by_user') is True, 'nuget_runtime_receipt_mismatch')
    acquire.verify_files(root)
    return row


def stage(root):
    require(APPLOCAL_STAGE_ENABLED is True and NUGET_LICENSE_ACCEPTED is True, 'nuget_stage_held')
    context = binding()
    root = Path(root).absolute()
    acquire._plain_ancestors(root)
    output = root/'nuget-runtime-receipt.json'
    require(not output.exists() and not output.is_symlink(), 'nuget_receipt_not_fresh')
    result = {'schema':1, 'status':'FAILED', 'binding':context, 'package_sha256':pins.PACKAGE_SHA256,
              'license_sha256':pins.LICENSE_SHA256,
              'files':{}, 'license_accepted_by_user':True, 'runtime_verified':False}
    created = []
    try:
        src = verify_source(root, context)
        acquire.verify_files(root)
        dest = root/'byond'/'bin'
        acquire._plain_ancestors(dest)
        targets = {name: dest/name for name in pins.FILES}
        require(all(not p.exists() and not p.is_symlink() for p in targets.values()), 'nuget_target_not_fresh')
        for name, pin in pins.FILES.items():
            data = acquire._read(src/name, pin['bytes'])
            require(len(data) == pin['bytes'] and acquire._sha(data) == pin['sha256'], 'nuget_source_changed')
            with targets[name].open('xb') as stream:
                created.append(targets[name])
                stream.write(data)
                stream.flush()
                os.fsync(stream.fileno())
            result['files'][name] = pin['sha256']
        acquire.verify_files(root)
        result['status'] = 'PASSED'
    except Exception as error:
        code=str(error)
        result['error']=code if re.fullmatch('[a-z_]{1,80}',code) else type(error).__name__
        removed=True
        for path in reversed(created):
            try:
                acquire._plain(path)
                path.unlink()
            except Exception:
                removed=False
        result['owned_partial_files_removed']=removed
        raise
    finally:
        data=(json.dumps(result,sort_keys=True)+'\n').encode()
        require(len(data)<=16384,'nuget_receipt_oversize')
        with output.open('xb') as stream:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
    return result


if __name__ == '__main__':
    import argparse
    parser=argparse.ArgumentParser();parser.add_argument('--root',type=Path,required=True);args=parser.parse_args()
    print(json.dumps(stage(args.root),sort_keys=True))

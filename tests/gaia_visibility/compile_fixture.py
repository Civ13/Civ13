"""Compile one exact Gaia packet, never run the generated game or any server."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import prepare


def compile_packet(head, output, byond_bin, *, execute=subprocess.run):
    output = Path(output).absolute()
    if output.exists():
        raise FileExistsError(output)
    output.mkdir(parents=True)
    evidence = output / 'evidence'
    evidence.mkdir()
    receipt = {'head': head, 'status': 'failed', 'executed_game': False, 'compiled': False}
    try:
        packet = output / 'packet'
        manifest = prepare.prepare(packet, head)
        manifest_bytes = (packet / 'gaia-visibility-manifest.json').read_bytes()
        (evidence / 'manifest.json').write_bytes(manifest_bytes)
        version = manifest['toolchain']
        compiler = Path(byond_bin).absolute() / 'DreamMaker'
        if not compiler.is_file():
            raise FileNotFoundError(compiler)
        command = [str(compiler), '-max_errors', '0', 'gaia_visibility.dme']
        receipt.update(command=command, manifest_sha256=hashlib.sha256(manifest_bytes).hexdigest(), version=version)
        with (evidence / 'compiler.log').open('wb') as log:
            result = execute(command, cwd=packet, stdout=log, stderr=subprocess.STDOUT, timeout=300, check=False)
        text = (evidence / 'compiler.log').read_text(errors='replace')
        banners = re.findall(r'^DM compiler version ([^\r\n]+)$', text, re.M)
        binary = packet / 'gaia_visibility.dmb'
        success = result.returncode == 0 and banners == [version] and '- 0 errors, 0 warnings' in text and binary.is_file()
        receipt.update(returncode=result.returncode, status='passed' if success else 'failed', compiled=success)
        if binary.is_file():
            receipt['dmb_sha256'] = hashlib.sha256(binary.read_bytes()).hexdigest()
        return receipt
    except Exception as exc:
        receipt['error'] = str(exc)
        raise
    finally:
        (evidence / 'compile.json').write_text(json.dumps(receipt, indent=2) + '\n')


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--head', required=True)
    p.add_argument('--output', required=True, type=Path)
    p.add_argument('--byond-bin', required=True, type=Path)
    args = p.parse_args()
    result = compile_packet(args.head, args.output, args.byond_bin)
    # Mirror bounded diagnostics into CI logs; the complete log remains an artifact.
    log = args.output / "evidence/compiler.log"
    if log.is_file():
        print(log.read_text(errors="replace")[-32000:])
    print(json.dumps(result, sort_keys=True))
    raise SystemExit(0 if result['status'] == 'passed' else 1)

"""Generate Civ13 API docs with a pinned DM parser; no third-party Python packages."""
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import urllib.request
from html.parser import HTMLParser
from urllib.parse import urlsplit, unquote

ROOT = Path(__file__).resolve().parents[1]
RELEASE = 'suite-1.10'
HASHES = {'Windows': 'c00e103690644e8f10c6c06827242a9a1e33df86c7aaf717ffb7176ddd9a623b',
          'Linux': '925dc2f398ad88918446d12da7bc46e1abb7a76a4df5c1c308696943dcececf5'}

class Page(HTMLParser):
    def __init__(self, text):
        super().__init__()
        self.ids, self.links, self.base = set(), [], None
        self.feed(text)
    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if 'id' in attrs:
            self.ids.add(attrs['id'])
        if tag == 'base':
            self.base = attrs.get('href')
            return
        for key in ('href', 'src'):
            if key in attrs:
                self.links.append(attrs[key])

def main():
    os.chdir(ROOT)
    system = platform.system()
    if system not in HASHES:
        raise SystemExit('Supported release binaries: Windows x64 and Linux x64')
    cache = ROOT / '.cache' / 'api-docs'
    cache.mkdir(parents=True, exist_ok=True)
    binary = cache / ('dmdoc.exe' if system == 'Windows' else 'dmdoc')
    if not binary.exists():
        urllib.request.urlretrieve(f'https://github.com/SpaceManiac/SpacemanDMM/releases/download/{RELEASE}/{binary.name}', binary)
    if hashlib.sha256(binary.read_bytes()).hexdigest() != HASHES[system]:
        raise SystemExit('dmdoc checksum mismatch; remove cached binary and investigate')
    binary.chmod(0o755)
    output = ROOT / 'dmdoc'
    if output.exists():
        shutil.rmtree(output)
    run = subprocess.run([str(binary), '-e', 'civ13.dme', '--index', 'docs/api/index.md'], capture_output=True, text=True)
    (cache / 'generation.log').write_text(run.stdout + run.stderr, encoding='utf-8')
    print(run.stdout)
    print(run.stderr)
    expected = (ROOT / 'docs/api/baseline-diagnostics.txt').read_text().splitlines()
    actual = run.stderr.splitlines()
    if run.returncode or actual != expected:
        raise SystemExit('Generator failed or diagnostics changed; inspect .cache/api-docs/generation.log')
    pages = {p: Page(p.read_text(encoding='utf-8')) for p in output.rglob('*.html')}
    errors = []
    for path, page in pages.items():
        base = (path.parent / page.base).resolve() if page.base else path.parent
        for link in page.links:
            url = urlsplit(link)
            if url.scheme or url.netloc:
                continue
            target = (base / unquote(url.path)).resolve() if url.path else (base / 'index.html' if page.base else path)
            if not target.is_relative_to(output) or not target.is_file():
                errors.append(f'{path.relative_to(output)}: missing {link}')
            elif url.fragment and target in pages and unquote(url.fragment) not in pages[target].ids:
                errors.append(f'{path.relative_to(output)}: missing anchor {link}')
    for name, fragments in {'datum/callback.html': ['proc/Invoke', 'proc/InvokeAsync'],
                            'datum/callback/dynamic.html': ['proc/Invoke']}.items():
        page = pages.get(output / name)
        if not page or not set(fragments).issubset(page.ids):
            errors.append(f'Missing representative API: {name}')
    if errors:
        raise SystemExit('\n'.join(errors[:30]))
    head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip()
    (output / 'build.json').write_text(json.dumps({'head_sha': head, 'release': RELEASE, 'binary_sha256': HASHES[system], 'html_pages': len(pages)}, indent=2))
    print(f'Validated {len(pages)} HTML pages, assets, anchors and callback APIs at {head}')

if __name__ == '__main__':
    main()

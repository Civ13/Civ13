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
    entries = []
    for path in sorted(output.rglob('*.html')):
        text = path.read_text(encoding='utf-8')
        page = Page(text)
        relative = path.relative_to(output).as_posix()
        label = relative.removesuffix('.html')
        entries.append({'label': label, 'url': relative})
        for anchor in sorted(page.ids):
            if anchor.startswith(('proc/', 'var/', 'define/')):
                entries.append({'label': label + '/' + anchor, 'url': relative + '#' + anchor})
        text = text.replace('</head>', '<meta name="viewport" content="width=device-width, initial-scale=1"><link rel="stylesheet" href="search.css"><script defer src="search.js"></script></head>')
        text = text.replace('</header>', ' - <a href="index.html#search">Search</a></header>')
        path.write_text(text, encoding='utf-8')
    for query in ('callback/proc/Invoke', 'datum/var', 'code/datums/callback'):
        if not any(query.lower() in entry['label'].lower() for entry in entries):
            raise SystemExit('Missing search coverage: ' + query)
    (output / 'search-index.json').write_text(json.dumps(entries), encoding='utf-8')
    for asset in ('search.js', 'search.css'):
        shutil.copyfile(ROOT / 'docs/api' / asset, output / asset)
    index = output / 'index.html'
    text = index.read_text(encoding='utf-8')
    search = '<section id="search" aria-label="API search"><h2>Search source documentation</h2><label for="api-search">Types, procs, vars and documented files</label><input id="api-search" type="search" placeholder="Try callback, Invoke or cooldowns" autocomplete="off"><p id="search-status" role="status">Loading search index...</p><ul id="search-results"></ul><noscript>Enable JavaScript for search, or browse the module and type trees below.</noscript></section>'
    index.write_text(text.replace('<main>', '<main>' + search), encoding='utf-8')
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

"""Run the pinned SpacemanDMM dreamchecker and ratchet its diagnostics.

CM-SS13 runs dreamchecker as a blocking CI linter. Civ13 starts from a recorded
baseline so the job reports new diagnostics without failing on the backlog:
each diagnostic message (numbers stripped) has a count in
tools/lint/dreamchecker_baseline.json, and a run fails only when a message's
count rises above its baseline or a new message appears. Lowered counts are
reported so --write can record the improvement.

    python3 scripts/dreamchecker_lint.py download --output .ci/lint/dreamchecker
    python3 scripts/dreamchecker_lint.py run --binary .ci/lint/dreamchecker --output .ci/lint
    python3 scripts/dreamchecker_lint.py check --receipt .ci/lint/dreamchecker.json
    python3 scripts/dreamchecker_lint.py check --receipt .ci/lint/dreamchecker.json --write

The binary pin (URL, sha256, bytes per platform) is tools/lint/dreamchecker.json.
No step here starts BYOND; dreamchecker parses the sources on its own.
"""
import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
import time
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PIN = ROOT / 'tools/lint/dreamchecker.json'
BASELINE = ROOT / 'tools/lint/dreamchecker_baseline.json'
ANSI = re.compile(r'\x1b\[[0-9;]*[A-Za-z]')
LOCATION = re.compile(r'^(?P<path>.+?), line (?P<line>\d+), column (?P<column>\d+):\s*$')
DIAGNOSTIC = re.compile(r'^(?P<severity>error|warning|hint|info|note): (?P<message>.*)$')
SUMMARY = re.compile(r'^Found (\d+) diagnostics?')
NUMBERS = re.compile(r'\d+')
SEVERITIES = ('error', 'warning', 'hint', 'info', 'note')


def load_pin(path=PIN):
    return json.loads(path.read_text(encoding='utf-8'))


def platform_key():
    return 'windows' if os.name == 'nt' else 'linux'


def sha256_of(path):
    digest = hashlib.sha256()
    with open(path, 'rb') as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b''):
            digest.update(chunk)
    return digest.hexdigest()


def verify(path, binding):
    size = Path(path).stat().st_size
    if size != binding['bytes']:
        raise ValueError(f'dreamchecker size {size} does not match pinned {binding["bytes"]}')
    digest = sha256_of(path)
    if digest != binding['sha256']:
        raise ValueError(f'dreamchecker sha256 {digest} does not match pinned {binding["sha256"]}')
    return digest


def download(output, platform=None, pin=None, opener=urllib.request.urlopen):
    pin = pin or load_pin()
    binding = pin[platform or platform_key()]
    output = Path(output)
    output.parent.mkdir(parents=True, exist_ok=True)
    if output.is_file():
        try:
            verify(output, binding)
            return output
        except ValueError:
            output.unlink()
    with opener(binding['url'], timeout=60) as response, open(output, 'wb') as handle:
        for chunk in iter(lambda: response.read(1 << 20), b''):
            handle.write(chunk)
    verify(output, binding)
    if os.name != 'nt':
        output.chmod(0o755)
    return output


def normalise_message(message):
    """Strip numbers and quoted names so one baseline row covers one rule."""
    return NUMBERS.sub('N', message).strip()


def parse(text):
    """Parse dreamchecker output into diagnostics and the reported total."""
    diagnostics = []
    location = None
    total = None
    for raw in text.splitlines():
        line = ANSI.sub('', raw).rstrip()
        found = LOCATION.match(line)
        if found:
            location = dict(path=found['path'].replace('\\', '/'), line=int(found['line']),
                            column=int(found['column']))
            continue
        found = DIAGNOSTIC.match(line)
        if found and location:
            diagnostics.append(dict(location, severity=found['severity'], message=found['message'],
                                    category=normalise_message(found['message'])))
            continue
        found = SUMMARY.match(line)
        if found:
            total = int(found.group(1))
    return diagnostics, total


def summarise(diagnostics):
    by_severity = {severity: 0 for severity in SEVERITIES}
    by_category = {}
    by_file = {}
    for row in diagnostics:
        by_severity[row['severity']] = by_severity.get(row['severity'], 0) + 1
        key = f"{row['severity']}: {row['category']}"
        by_category[key] = by_category.get(key, 0) + 1
        by_file[row['path']] = by_file.get(row['path'], 0) + 1
    return dict(total=len(diagnostics), by_severity=by_severity,
                by_category=dict(sorted(by_category.items(), key=lambda item: (-item[1], item[0]))),
                by_file=dict(sorted(by_file.items(), key=lambda item: (-item[1], item[0]))))


def run(binary, output, environment='civ13.dme', cwd=ROOT, runner=subprocess.run):
    output = Path(output)
    output.mkdir(parents=True, exist_ok=True)
    started = time.monotonic()
    result = runner([str(binary), '-e', environment], cwd=str(cwd), capture_output=True, text=True,
                    encoding='utf-8', errors='replace', timeout=900)
    elapsed = round(time.monotonic() - started, 2)
    text = result.stdout + ('\n' + result.stderr if result.stderr else '')
    (output / 'dreamchecker.log').write_text(ANSI.sub('', text), encoding='utf-8')
    diagnostics, total = parse(text)
    receipt = dict(schema=1, kind='dreamchecker', release=load_pin()['release'],
                   environment=environment, exit_code=result.returncode, seconds=elapsed,
                   reported_total=total, parsed_total=len(diagnostics),
                   summary=summarise(diagnostics), diagnostics=diagnostics)
    if total is not None and total != len(diagnostics):
        receipt['parse_warning'] = f'dreamchecker reported {total} diagnostics but {len(diagnostics)} were parsed'
    (output / 'dreamchecker.json').write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf-8')
    return receipt


def load_baseline(path=BASELINE):
    if not Path(path).is_file():
        return None
    return json.loads(Path(path).read_text(encoding='utf-8'))


def compare(summary, baseline):
    """Return (regressions, improvements) as lists of (category, allowed, now)."""
    allowed_rows = baseline['by_category'] if baseline else {}
    regressions = []
    improvements = []
    for category, count in summary['by_category'].items():
        allowed = allowed_rows.get(category, 0)
        if count > allowed:
            regressions.append((category, allowed, count))
        elif count < allowed:
            improvements.append((category, allowed, count))
    for category, allowed in allowed_rows.items():
        if category not in summary['by_category']:
            improvements.append((category, allowed, 0))
    return regressions, improvements


def write_baseline(receipt, path=BASELINE, head=None):
    payload = dict(schema=1, release=receipt['release'], environment=receipt['environment'],
                   head=head, total=receipt['summary']['total'],
                   by_severity=receipt['summary']['by_severity'],
                   by_category=receipt['summary']['by_category'],
                   note='Counts per dreamchecker message with numbers replaced by N. A count may only fall; '
                        'regenerate with python3 scripts/dreamchecker_lint.py check --receipt <receipt> --write.')
    Path(path).write_text(json.dumps(payload, indent=2) + '\n', encoding='utf-8')
    return payload


def check(receipt, baseline_path=BASELINE, write=False, head=None, out=print):
    summary = receipt['summary']
    baseline = load_baseline(baseline_path)
    out(f"dreamchecker {receipt['release']}: {summary['total']} diagnostics "
        + ', '.join(f'{k}={v}' for k, v in summary['by_severity'].items() if v))
    if receipt.get('parse_warning'):
        out('WARNING: ' + receipt['parse_warning'])
    regressions, improvements = compare(summary, baseline)
    if write:
        write_baseline(receipt, baseline_path, head)
        out(f'Wrote {baseline_path}')
        return 0
    if baseline is None:
        out('No baseline recorded; reporting only. Commit one with --write from a trusted run.')
        for category, count in list(summary['by_category'].items())[:40]:
            out(f'  {count:5d}  {category}')
        return 0
    for category, allowed, now in regressions:
        out(f'REGRESSION {category}: {now} (baseline {allowed})')
        for row in receipt['diagnostics']:
            if f"{row['severity']}: {row['category']}" == category:
                out(f"    {row['path']}:{row['line']}:{row['column']}: {row['message']}")
    for category, allowed, now in improvements:
        out(f'improved {category}: {now} (baseline {allowed})')
    if improvements:
        out(f'{len(improvements)} baseline row(s) can be lowered: rerun check with --write to record it')
    if regressions:
        out(f'{len(regressions)} dreamchecker regression(s) against the baseline')
        return 1
    out('No new dreamchecker diagnostics against the baseline')
    return 0


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    sub = parser.add_subparsers(dest='mode', required=True)
    fetch = sub.add_parser('download', help='download and verify the pinned binary')
    fetch.add_argument('--output', required=True)
    fetch.add_argument('--platform', choices=('linux', 'windows'))
    execute = sub.add_parser('run', help='run dreamchecker and write a receipt')
    execute.add_argument('--binary', required=True)
    execute.add_argument('--output', required=True)
    execute.add_argument('--environment', default='civ13.dme')
    verdict = sub.add_parser('check', help='compare a receipt with the baseline')
    verdict.add_argument('--receipt', required=True)
    verdict.add_argument('--baseline', default=str(BASELINE))
    verdict.add_argument('--write', action='store_true')
    verdict.add_argument('--head', default=os.environ.get('GITHUB_SHA'))
    parse_log = sub.add_parser('parse', help='turn a saved dreamchecker log into a receipt')
    parse_log.add_argument('--log', required=True)
    parse_log.add_argument('--output', required=True)
    args = parser.parse_args(argv)
    if args.mode == 'download':
        path = download(args.output, args.platform)
        print(f'dreamchecker verified at {path}')
        return 0
    if args.mode == 'run':
        receipt = run(args.binary, args.output, args.environment)
        print(f"dreamchecker exit {receipt['exit_code']} in {receipt['seconds']} s, "
              f"{receipt['summary']['total']} diagnostics")
        return 0
    if args.mode == 'parse':
        text = Path(args.log).read_text(encoding='utf-8', errors='replace')
        diagnostics, total = parse(text)
        receipt = dict(schema=1, kind='dreamchecker', release=load_pin()['release'], environment='civ13.dme',
                       exit_code=None, seconds=None, reported_total=total, parsed_total=len(diagnostics),
                       summary=summarise(diagnostics), diagnostics=diagnostics)
        Path(args.output).parent.mkdir(parents=True, exist_ok=True)
        Path(args.output).write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf-8')
        print(f'{len(diagnostics)} diagnostics parsed (reported {total})')
        return 0
    receipt = json.loads(Path(args.receipt).read_text(encoding='utf-8'))
    return check(receipt, Path(args.baseline), args.write, args.head)


if __name__ == '__main__':
    sys.exit(main())

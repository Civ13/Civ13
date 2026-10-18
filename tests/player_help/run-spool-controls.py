"""Prove native spool regression detects each old defect; offline temporary copies only."""
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
source = (ROOT / 'scripts/player_help_bridge.py').read_text(encoding='utf-8')
controls = {
    'old-id-validator': (
        "not valid_request_id(request.get('id'))",
        "not isinstance(request.get('id'), str) or not re.fullmatch(r'[0-9-]{1,100}', request['id'])"),
    'raw-admission-marker': ('marker = read_ready_id(ready)',
                             "marker = ready.read_text(encoding='utf-8')"),
    'raw-completion-marker': ('current = read_ready_id(ready)',
                              "current = ready.read_text(encoding='utf-8')"),
}
for name, (original, mutation) in controls.items():
    if source.count(original) != 1:
        raise SystemExit('Control anchor changed: ' + name)
    with tempfile.TemporaryDirectory(prefix='help-spool-control-') as directory:
        root = Path(directory)
        (root / 'scripts').mkdir()
        (root / 'tests/player_help').mkdir(parents=True)
        (root / 'scripts/player_help_bridge.py').write_text(source.replace(original, mutation), encoding='utf-8')
        test = root / 'tests/player_help/test_spool_protocol.py'
        test.write_bytes((ROOT / 'tests/player_help/test_spool_protocol.py').read_bytes())
        result = subprocess.run([sys.executable, '-B', str(test),
            'SpoolProtocolTests.test_native_scientific_id_crlf_admission_and_completion'],
            cwd=root, capture_output=True, text=True, timeout=15)
        if result.returncode == 0 or 'AssertionError' not in result.stderr:
            raise SystemExit('Control did not detect defect: ' + name + '\n' + result.stderr)
        print('PASS detects ' + name)

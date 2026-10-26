"""Opt-in current Linux fixture identity; no acquisition or process execution."""
import importlib.util
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class CurrentRuntime:
    def __init__(self, bin_dir, archive):
        if sys.platform != 'linux':
            raise ValueError('Current fixture archive identity requires Linux')
        self.bin_dir, self.archive = Path(bin_dir).absolute(), Path(archive).absolute()
        self.verifier = load('fixture_runtime_identity', ROOT/'scripts/byond_runtime.py')
        self.compiler = load('fixture_compile_contract', ROOT/'tests/new_z_budget/z_budget_evidence.py')
        self.identity = json.loads(json.dumps(self.verifier.verify_linux(self.bin_dir, self.archive)))
        self.checks = []

    def before_launch(self, role, output):
        try:
            if self.verifier.verify_linux(self.bin_dir, self.archive) != self.identity:
                raise ValueError('Current fixture runtime identity changed')
        except Exception as error:
            try:
                self.write(output, str(error)[:4096])
            except OSError:
                pass  # Preserve the original identity failure; never launch.
            raise
        self.checks.append(role)
        self.write(output)

    def write(self, output, error=None):
        record = dict(schema=1, runtime=self.identity, verified_before=list(self.checks))
        if error is not None: record['error'] = error
        data = json.dumps(record, indent=2).encode()
        if len(data) > 65536: raise ValueError('Runtime identity receipt bound')
        (Path(output)/'runtime-identity.json').write_bytes(data)

    def validate_compile(self, code, log, artifact):
        if code or len(log.encode()) > self.compiler.MAX_COMPILE_LOG or self.compiler.DIAGNOSTIC.search(log):
            raise RuntimeError('Current compiler exit, output bound or diagnostics invalidated evidence')
        lines = log.splitlines()
        banners = [line for line in lines if re.search('DM compiler version', line, re.I)]
        results = [line for line in lines if re.search(r'\berrors?\b|\bwarnings?\b', line, re.I)]
        summary = re.escape(artifact) + r' - 0 errors, 0 warnings(?: \(\d{1,2}/\d{1,2}/\d{2,4} \d{1,2}:\d{2}(?::\d{2})? (?:am|pm)\))?'
        if (banners != ['DM compiler version '+self.identity['version']] or len(results) != 1
                or not re.fullmatch(summary, results[0]) or lines.index(banners[0]) >= lines.index(results[0])):
            raise RuntimeError('One exact archive-bound compiler banner and clean result required')


def select(bin_dir, archive):
    return CurrentRuntime(bin_dir, archive) if archive is not None else None

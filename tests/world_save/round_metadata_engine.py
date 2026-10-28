"""Explicit round-metadata engine selection; passive current-Linux identity only.

The default preserves the legacy banner-only gate, not archive provenance.
No downloads, extraction, installation, native execution or profile fallback.
"""
import hashlib
import importlib.util
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
LEGACY = '516.1681'
CURRENT = '516.1688'
PINS = {
    'scripts/byond_runtime.py': '43346f4a9f33af6b6d9cbe67f15d4f1843c400fa758d4cccba35002f0c30da4c',
    'scripts/byond_toolchain.py': '2fb8e2dbd3646124e366f17011fcbb7857ee47b913402d9a4c2a90dde0c957cc',
    'tools/byond/version.json': '662acc3d771988e91de44b7be6f648c256aee7b2173e42a64956b8aca3bad95d',
}


def load_runtime():
    # Same reviewed passive helpers as the current fishing-stock runner.
    for relative, expected in PINS.items():
        path = ROOT / relative
        if path.stat().st_size > 1024 * 1024 or hashlib.sha256(path.read_bytes()).hexdigest() != expected:
            raise ValueError('Reviewed engine dependency changed: ' + relative)
    spec = importlib.util.spec_from_file_location('round_metadata_runtime', ROOT / 'scripts/byond_runtime.py')
    runtime = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(runtime)
    return runtime


class EngineProfile:
    def __init__(self, version, archive=None, acquisition=None):
        if version not in (LEGACY, CURRENT):
            raise ValueError('Unsupported round-metadata engine profile')
        self.version = version
        self.current = version == CURRENT
        self.runtime = None
        if not self.current:
            if archive is not None or acquisition is not None:
                raise ValueError('Archive provenance options require explicit 516.1688 selection')
            return
        if sys.platform != 'linux':
            raise ValueError('The explicit 516.1688 profile is Linux only')
        if archive is None or acquisition is None:
            raise ValueError('516.1688 requires --byond-archive and --acquisition-receipt')
        self.archive = Path(archive).absolute()
        self.acquisition = Path(acquisition).absolute()
        self.runtime = load_runtime()
        if self.runtime.pin.load()['version'] != CURRENT:
            raise ValueError('Reviewed engine profile changed')

    def identity(self, binary):
        if not self.current:
            raise ValueError('Historical profile does not establish archive provenance')
        requirement = self.runtime.pin.load()
        if requirement['version'] != self.version:
            raise ValueError('Reviewed engine profile changed')
        acquisition = self.runtime.pin.read_download_receipt(self.acquisition, requirement, 'linux')
        installed = self.runtime.verify_linux(binary, self.archive)
        if installed['version'] != self.version:
            raise ValueError('Installed engine version identity mismatch')
        return {'acquisition': acquisition, 'installed': installed}

    def check_compile(self, log):
        if not self.current:
            raise ValueError('Historical compiler gate belongs to the legacy runner')
        self.runtime.pin.compiler_log(log, self.version)

"""Compile production glide code in temporary storage, including two behavior controls."""
import argparse
from pathlib import Path
import shutil
import subprocess
import tempfile

parser = argparse.ArgumentParser()
parser.add_argument('--engine', type=Path, required=True)
parser.add_argument('--dotnet', type=Path, required=True)
args = parser.parse_args()
base = 'b1a452e7fefa36f8919bff38067c602d0bb4e1a5'
source = 'OpenDreamClient/Rendering/AtomGlideSystem.cs'
baseline = subprocess.check_output(['git', '-C', str(args.engine), 'show', f'{base}:{source}'])
with tempfile.TemporaryDirectory(prefix='civ13-glide-') as temporary:
    root = Path(temporary)
    subprocess.run(['git', 'init', '--quiet'], cwd=root, check=True)
    target = root / source
    target.parent.mkdir(parents=True)
    target.write_bytes(baseline)
    subprocess.run(['git', 'apply', str(Path(__file__).with_name('movement.patch'))], cwd=root, check=True)
    fixed = target.read_bytes()
    timing = target.with_name('GlideTiming.cs')
    fixed_timing = timing.read_bytes()
    command = [str(args.dotnet.resolve()), 'run', '--project', 'tests/glide/GlideProbe.csproj', '-c', 'Release']
    def run(label, expected=None):
        result = subprocess.run(command, cwd=root, capture_output=True, text=True)
        output = result.stdout + result.stderr
        if expected is None:
            if result.returncode or 'PASS 211 production glide assertions' not in output:
                raise RuntimeError(f'{label}: {output}')
        elif result.returncode == 0 or expected not in output:
            raise RuntimeError(f'{label} did not detect the behavior regression: {output}')
        print(f'PASS {label}')
    run('production glide: 211 assertions')
    target.write_bytes(baseline)
    run('historical snapping control', 'consecutive update must never snap')
    target.write_bytes(fixed)
    timing.write_text(fixed_timing.decode().replace('Math.Max(baseline, remaining / interval)', 'baseline'))
    run('fixed slow-animation control', 'automatic speed catches up to held-key cadence')
    timing.write_bytes(fixed_timing)


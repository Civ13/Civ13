"""Compile Civ13 with the exported default chapter as the selected map.

Local evidence for the static export, not a CI job: it needs the pinned BYOND
compiler (`bash scripts/cloud_byond_setup.sh` on Linux) and about a minute.
It writes only temporary files and removes them; the real civ13.dme is not changed.

    python3 tests/liminal_maps/native_compile.py [--dreammaker PATH] [--mode escape]
"""
import argparse
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT))
from tools.liminal_maps.prototype import preset,generate
from tools.liminal_maps.native import export


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--dreammaker',default=shutil.which('DreamMaker') or shutil.which('dm.exe') or 'DreamMaker')
    p.add_argument('--mode',choices=['escape']);a=p.parse_args()
    with tempfile.TemporaryDirectory(dir=ROOT/'data' if (ROOT/'data').is_dir() else None) as tmp:
        folder=Path(tmp)/'export';export(generate(preset())['document'],folder,mode=a.mode)
        dme=ROOT/'civ13.dme';text=dme.read_text(encoding='utf-8')
        start=text.index('// BEGIN_SELECTED_MAP');end=text.index('// END_SELECTED_MAP')
        relative=(folder/'map.dmm').relative_to(ROOT) if (folder/'map.dmm').is_relative_to(ROOT) else folder/'map.dmm'
        check=ROOT/'civ13_liminal_check.dme'
        check.write_text(text[:start]+'// BEGIN_SELECTED_MAP\n#include "'+str(relative).replace('/','\\')+'"\n'+text[end:],encoding='utf-8')
        try:
            run=subprocess.run([a.dreammaker,'-max_errors','20',check.name],cwd=ROOT,capture_output=True,text=True)
        finally:
            for suffix in ['.dme','.dmb','.rsc','.int','.lk','.dyn.rsc']:
                check.with_suffix(suffix).unlink(missing_ok=True)
        print(run.stdout[-2000:]+run.stderr[-2000:])
        ok=run.returncode==0 and '0 errors' in run.stdout
        print('NATIVE_COMPILE', 'PASSED' if ok else 'FAILED');return 0 if ok else 1


if __name__=='__main__':raise SystemExit(main())

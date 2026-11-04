"""Stage the trailer build: a game checkout plus the trailer overlay.

The overlay replaces the map/skin includes in civ13.dme with the authored
village, stubs out shell/network entry points and isolates startup (see
overlay/). The result is a disposable build directory; nothing is written back
into the game checkout.

    python3 tools/village-trailer/stage.py --game <checkout> --out <build-dir>
"""
import argparse
import shutil
from pathlib import Path

HERE = Path(__file__).resolve().parent
# The isolation overlay was reviewed against this game revision.
GAME_REVISION = '58404f5bd16e3fed80f1d9844c5db3edd144942c'
COPY = ['civ13.dme', 'code', 'icons', 'sound', 'UI', 'interface', 'config', 'maps/environment.dm']


def stage(game, out):
    game, out = Path(game).resolve(), Path(out).resolve()
    if out.exists():
        raise SystemExit(f'{out} already exists; stage into a fresh directory')
    out.mkdir(parents=True)
    for name in COPY:
        src = game / name
        if not src.exists():
            continue
        dst = out / name
        dst.parent.mkdir(parents=True, exist_ok=True)
        if src.is_dir():
            shutil.copytree(src, dst)
        else:
            shutil.copy2(src, dst)
    overlay = HERE / 'overlay'
    for src in overlay.rglob('*'):
        if src.is_file():
            dst = out / src.relative_to(overlay)
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src, dst)
    return out


if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('--game', required=True)
    p.add_argument('--out', required=True)
    a = p.parse_args()
    print(stage(a.game, a.out))

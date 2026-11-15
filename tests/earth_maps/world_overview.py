"""One picture of the whole world from the eight land maps.

The two Americas regions and the six draft lands each have their own frame
and scale. This lays their relief overviews on one longitude/latitude sheet
(Antarctica is unrolled from its polar view) and blends the overlaps, for
reviews and for wide shots. It reads nothing but the generators.

    python3 -I -B tests/earth_maps/world_overview.py --dir OUT --scale 10

writes OUT/<land>_relief.png for any land not already there, then
OUT/world.png at `scale` pixels per degree.
"""
import argparse
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import generate  # noqa: E402
import numpy as np  # noqa: E402
from PIL import Image  # noqa: E402

builder = generate.builder
SEA = builder.PREVIEW[builder.T_SEA]
# Lowest first: a later land covers an earlier one where their frames overlap.
ORDER = ['antarctica', 'asia', 'oceania', 'africa', 'greenland', 'europe', 'south', 'north']
FEATHER = 2.0  # degrees over which a frame's edge fades into what lies under it


def frame(name):
    """(west, east, north, south) in degrees east / north."""
    if name in ('north', 'south'):
        spec = generate.continents.MAPS[name]
    else:
        spec = generate.lands.MAPS[name]
    return (-spec['lon'][0], -spec['lon'][1], spec['lat'][0], spec['lat'][1])


def overview(name, folder):
    path = folder / ('%s_relief.png' % name)
    if not path.exists():
        if name in ('north', 'south'):
            turf, _area, objects, _stats, elev = builder.build(name)
        else:
            turf, _area, objects, _stats, elev = generate.build(name)
        generate.relief_preview(path, turf, objects, elev)
    return Image.open(path).convert('RGB')


def lay(canvas, img, west, east, north, south, scale, shift=0.0):
    """Blend one framed overview onto the sheet (plain longitude/latitude)."""
    h, w = canvas.shape[:2]
    pw, ph = int(round((east - west) * scale)), int(round((north - south) * scale))
    patch = np.asarray(img.resize((pw, ph), Image.LANCZOS), dtype=np.float32)
    ramp_x = np.minimum(np.arange(pw) + 0.5, pw - np.arange(pw) - 0.5) / (FEATHER * scale)
    ramp_y = np.minimum(np.arange(ph) + 0.5, ph - np.arange(ph) - 0.5) / (FEATHER * scale)
    alpha = np.clip(np.minimum.outer(ramp_y, ramp_x), 0.0, 1.0)
    x0 = int(round((west + shift + 180.0) * scale))
    y0 = int(round((90.0 - north) * scale))
    xs, ys = max(0, x0), max(0, y0)
    xe, ye = min(w, x0 + pw), min(h, y0 + ph)
    if xs >= xe or ys >= ye:
        return
    a = alpha[ys - y0:ye - y0, xs - x0:xe - x0, None]
    canvas[ys:ye, xs:xe] = canvas[ys:ye, xs:xe] * (1 - a) + patch[ys - y0:ye - y0, xs - x0:xe - x0] * a


def lay_polar(canvas, img, spec, scale):
    """Unroll the polar view: every sheet pixel looks up its place on it."""
    h, w = canvas.shape[:2]
    src = np.asarray(img, dtype=np.float32)
    sh, sw = src.shape[:2]
    reach = abs(spec['lon'][0])      # degrees from the pole to the frame's edge
    top = int((90.0 + 90.0 - (reach + FEATHER)) * scale)
    ys = np.arange(top, h)
    lat = 90.0 - (ys + 0.5) / scale
    lon = np.radians((np.arange(w) + 0.5) / scale - 180.0)
    r = (90.0 + lat)[:, None]
    px = np.clip(((r * np.sin(lon)[None, :] + reach) / (2 * reach) * sw).astype(int), 0, sw - 1)
    py = np.clip(((reach - r * np.cos(lon)[None, :]) / (2 * reach) * sh).astype(int), 0, sh - 1)
    patch = src[py, px]
    alpha = np.clip((reach - 6.0 - r) / FEATHER, 0.0, 1.0)[..., None] * np.ones((1, w, 1), dtype=np.float32)
    canvas[top:h] = canvas[top:h] * (1 - alpha) + patch * alpha


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    parser.add_argument('--dir', required=True, help='folder for the overviews and world.png')
    parser.add_argument('--scale', type=float, default=10.0, help='pixels per degree')
    args = parser.parse_args(argv)
    folder = Path(args.dir)
    folder.mkdir(parents=True, exist_ok=True)
    scale = args.scale
    canvas = np.empty((int(180 * scale), int(360 * scale), 3), dtype=np.float32)
    canvas[:] = SEA
    for name in ORDER:
        img = overview(name, folder)
        if name == 'antarctica':
            lay_polar(canvas, img, generate.lands.MAPS[name], scale)
            continue
        west, east, north, south = frame(name)
        lay(canvas, img, west, east, north, south, scale)
        if east > 180.0:
            lay(canvas, img, west, east, north, south, scale, shift=-360.0)
    # Where each land's frame sits on the sheet, in pixels, for anyone cutting a
    # move from one land's own overview out to the whole world.
    import json
    frames = {'scale': scale, 'size': [canvas.shape[1], canvas.shape[0]], 'lands': {}}
    for name in ORDER:
        if name == 'antarctica':
            frames['lands'][name] = {'polar': True, 'overview': '%s_relief.png' % name}
            continue
        west, east, north, south = frame(name)
        frames['lands'][name] = {'overview': '%s_relief.png' % name, 'degrees': [west, east, north, south],
                                 'box': [round((west + 180) * scale), round((90 - north) * scale),
                                         round((east + 180) * scale), round((90 - south) * scale)]}
    (folder / 'world.json').write_text(json.dumps(frames, indent=1) + '\n', encoding='utf-8')
    out = folder / 'world.png'
    Image.fromarray(np.clip(canvas, 0, 255).astype(np.uint8), 'RGB').save(out)
    print(out)


if __name__ == '__main__':
    main()

"""Generate the lands of the rest of the Earth.

    maps/nomads/nomads_earth_europe.dmm      (a region, with its height files)
    maps/nomads/nomads_earth_africa.dmm      (a region, with its height files)
    maps/earth_drafts/earth_asia.dmm
    maps/earth_drafts/earth_oceania.dmm
    maps/earth_drafts/earth_antarctica.dmm
    maps/earth_drafts/earth_greenland.dmm

They are drawn the way the two Americas regions are: hand-placed outlines,
mountain chains, rivers, lakes and climate centres (europe.py and the other
design files here), turned into terrain by tests/americas_maps/build.py. This
file only feeds those designs to that builder; it changes nothing about the
Americas maps.

Europe and Africa are regions (docs/earth-continents.md): their maps carry
map metadata and this writes their height, current and flood files under
maps/heights as well. The rest are DRAFTS: no map metadata, no region id, in no
region group or .dme, and no height files, so no server loads them. Making one
playable means giving its design 'metadata' and 'heights', generating, and
measuring its memory first (docs/earth-drafts.md).

Run from the repository root (needs numpy and Pillow):

    python3 -I -B tests/earth_maps/generate.py                 # all six
    python3 -I -B tests/earth_maps/generate.py --only asia --preview out.png
"""
import argparse
import hashlib
import importlib.util
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
AMERICAS = ROOT / 'tests' / 'americas_maps'
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(AMERICAS))

import continents  # noqa: E402  (the Americas design data; the builder reads its MAPS)
import lands  # noqa: E402

_spec = importlib.util.spec_from_file_location('americas_build', AMERICAS / 'build.py')
builder = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(builder)

T_FRESH_ICE = '/turf/floor/beach/water/ice'
builder.PREVIEW.setdefault(T_FRESH_ICE, (215, 232, 240))
MANIFEST = HERE / 'drafts.json'


def build(name, width=None, height=None):
    """One draft land: turfs, areas, objects, figures and heights in metres."""
    spec = lands.MAPS[name]
    continents.MAPS[name] = spec
    try:
        turf, area, objects, stats, elev = builder.build(name, width, height)
    finally:
        del continents.MAPS[name]
    objects = {spot: obj for spot, obj in objects.items() if obj}   # a draft has no metadata
    if spec.get('frozen'):
        # The ice cap: no meadow shows through the snow, and what little
        # water gathers on it is frozen over.
        reach = spec['frozen']   # degrees from the centre of the frame
        h, w = turf.shape
        import numpy as np
        yy, xx = np.mgrid[0:h, 0:w].astype('float32')
        north = (spec['lat'][0] + spec['lat'][1]) / 2 - (yy - h / 2) * (spec['lat'][0] - spec['lat'][1]) / h
        east = (xx - w / 2) * (spec['lon'][0] - spec['lon'][1]) / w
        cap = np.hypot(north, east) < reach
        turf[cap & (turf == builder.T_WINTER_GRASS)] = builder.T_WINTER
        for path in (builder.T_RIVER, builder.T_DEEP):
            turf[cap & (turf == path)] = T_FRESH_ICE
        for spot, obj in list(objects.items()):
            if cap[spot] and obj != builder.O_LANDMARK:
                del objects[spot]
    return turf, area, objects, stats, elev


def relief_preview(path, turf, objects, elev):
    """The flat overview, shaded by the relief so the ranges stand up."""
    import numpy as np
    from PIL import Image
    h, w = turf.shape
    rgb = np.zeros((h, w, 3), dtype=np.float32)
    for t, colour in builder.PREVIEW.items():
        rgb[turf == t] = colour
    e = builder.blur(elev.astype(np.float32), 1)
    gx = np.zeros_like(e)
    gy = np.zeros_like(e)
    gx[:, 1:-1] = e[:, 2:] - e[:, :-2]
    gy[1:-1, :] = e[2:, :] - e[:-2, :]
    wet = np.zeros((h, w), dtype=bool)
    for t in builder.PREVIEW:
        if 'water' in t:
            wet |= (turf == t)
    shade = np.clip(1.0 + (-(gx + gy)) / 420.0, 0.62, 1.32)   # light from the north-west
    shade[wet] = 1.0
    out = np.clip(rgb * shade[..., None], 0, 255).astype(np.uint8)
    Image.fromarray(out, 'RGB').save(path)


def digest(path):
    return hashlib.sha256(Path(path).read_bytes().replace(b'\r\n', b'\n')).hexdigest()


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    parser.add_argument('--only', choices=sorted(lands.MAPS))
    parser.add_argument('--out', help='output .dmm (with --only)')
    parser.add_argument('--preview', help='also write a flat colour overview PNG (with --only)')
    parser.add_argument('--relief', help='also write a relief-shaded overview PNG (with --only)')
    parser.add_argument('--no-map', action='store_true', help='previews only')
    args = parser.parse_args(argv)
    for name in ([args.only] if args.only else sorted(lands.MAPS)):
        turf, area, objects, stats, elev = build(name)
        out = Path(args.out) if args.out and args.only else ROOT / lands.MAPS[name]['path']
        if not args.no_map:
            out.parent.mkdir(parents=True, exist_ok=True)
            builder.write_dmm(out, turf, area, objects)
        if args.preview and args.only:
            builder.preview(args.preview, turf, objects)
        if args.relief and args.only:
            relief_preview(args.relief, turf, objects, elev)
        if lands.MAPS[name].get('heights') and not (args.out or args.no_map):
            stats['sidecars'] = builder.write_sidecars(name, turf, elev, lands.MAPS[name]['heights'])
        print(name, out, stats)
    if not (args.out or args.no_map):
        # Every land on disk, so maps built one at a time still list together.
        manifest = {}
        for name, spec in sorted(lands.MAPS.items()):
            if not (ROOT / spec['path']).exists():
                continue
            entry = {'path': spec['path'], 'size': list(spec['size']), 'sha256': digest(ROOT / spec['path'])}
            if spec.get('heights'):
                for kind, suffix in (('heights', '.txt'), ('flow', '.flow.txt'), ('flood', '.flood.txt')):
                    entry[kind] = {'path': spec['heights'] + suffix, 'sha256': digest(ROOT / (spec['heights'] + suffix))}
            manifest[name] = entry
        MANIFEST.write_text(json.dumps(manifest, indent=1, sort_keys=True) + '\n', encoding='utf-8', newline='\n')


if __name__ == '__main__':
    main()

#!/usr/bin/env python3
"""Cuts the vehicle designer's pictures out of the game's own sprite sheets.

The vehicle designer window (code/modules/craft/vehicle_designer.dm) shows
each frame, wheel, track and part of a vehicle sheet as the sprite the built
thing has in the game. Like the ship and submarine designers' pictures
(scripts/build_ship_designer_icons.py, whose DMI reading and tinting this
script uses), they are plain 32x32 PNGs, under icons/vehicle_designer/, sent
to the window with browse_rsc. Each is the south-facing first frame of an
existing state. Nothing is drawn here.

A frame is the whole tile. A wheel, a track or a part stands on a frame, so
it gets a one-pixel pale outline: the steel frame is nearly black, and the
seats and tracks are dark on it without one. A wheel or a track is moved to
the middle of its tile, because the window shows it in a small box.

The turret is the one picture that is not a 32x32 state: the game draws a
built turret from a 256x256 sheet over the tiles around it. Its picture is
that sprite under the turret's own tint, cropped to what is drawn and scaled
down to one tile.

The files are named by what the key is as well as the key (frame_w, mover_W):
keys of different tables differ only by case, and Windows serves the
browser's cache without it.

Run it after changing the tables in code/modules/craft/vehicle_draught.dm or
the sprites they use:

    python3 scripts/build_vehicle_designer_icons.py          # write the PNGs
    python3 scripts/build_vehicle_designer_icons.py --check  # exit 1 if stale
"""
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_ship_designer_icons import REPO, TILE, frame, png_bytes, tint  # noqa: E402

OUT = os.path.join(REPO, 'icons', 'vehicle_designer')
PARTS = 'icons/obj/vehicles/vehicleparts.dmi'
PALE = (236, 224, 196, 255)  # the outline round what stands on a frame
TURRET = (0x58, 0x5A, 0x5C)  # /obj/structure/turret/built turret_color

# file name -> where its picture comes from. 'layers' are (dmi, state, tint)
# as in build_ship_designer_icons.SPRITES; 'fit' scales a bigger sprite's
# drawn part down to one tile; 'centre' moves the drawn part to the middle
# of the tile (the window shows a wheel in a box smaller than a tile).
SPRITES = {
    # ---- vehicle_draught_frames ----
    # /obj/structure/vehicleparts/frame
    'frame_s': {'layers': [(PARTS, 'frame_steel', None)]},
    # /obj/structure/vehicleparts/frame/wood
    'frame_w': {'layers': [(PARTS, 'frame_wood', None)]},
    # /obj/structure/vehicleparts/frame/car/aircraft/section (the deck of
    # /obj/structure/vehicleparts/frame/car/aircraft)
    'frame_a': {'layers': [('icons/obj/vehicles/lightplane.dmi', 'fuselage_center_floor', None)]},
    # ---- vehicle_draught_movers ----
    # /obj/structure/vehicleparts/movement (wheel config "standard_wheel")
    'mover_W': {'layers': [(PARTS, 'wheel_t_dark', None)], 'centre': True, 'outline': True},
    # /obj/structure/vehicleparts/movement/tracks
    'mover_K': {'layers': [(PARTS, 'tracks_end', None)], 'centre': True, 'outline': True},
    # ---- vehicle_draught_parts ----
    # /obj/structure/engine/internal/gasoline, the first engine of the list
    'part_E': {'layers': [('icons/obj/engines32.dmi', 'gasoline_static', None)], 'outline': True},
    # /obj/item/weapon/reagent_containers/glass/barrel/fueltank/small
    'part_Y': {'layers': [(PARTS, 'fueltank_small', None)], 'outline': True},
    # .../fueltank/smalltank
    'part_M': {'layers': [(PARTS, 'fueltank_small_tank', None)], 'outline': True},
    # .../fueltank
    'part_T': {'layers': [(PARTS, 'fueltank_large', None)], 'outline': True},
    # .../fueltank/tank
    'part_X': {'layers': [(PARTS, 'fueltank_large_tank', None)], 'outline': True},
    # /obj/structure/bed/chair/drivers
    'part_D': {'layers': [(PARTS, 'driver_car', None)], 'outline': True},
    # /obj/structure/bed/chair/gunner
    'part_G': {'layers': [('icons/obj/bed_chair.dmi', 'officechair_white', None)], 'outline': True},
    # /obj/structure/bed/chair/loader (the same chair as the gunner's)
    'part_L': {'layers': [('icons/obj/bed_chair.dmi', 'officechair_white', None)], 'outline': True},
    # /obj/structure/bed/chair/commander
    'part_C': {'layers': [(PARTS, 'commanders_seat', None)], 'outline': True},
    # /obj/structure/turret/built: turret_icon "tank_turret", unbroken
    'part_U': {'layers': [('icons/obj/vehicles/vehicles256x256.dmi', 'tank_turret0', TURRET)], 'fit': True, 'outline': True},
    # /obj/structure/cargo_hold
    'part_H': {'layers': [('icons/obj/closet.dmi', 'securecargo', None)], 'outline': True},
}


def outline(img):
    """Marks every clear pixel that touches a solid one along an edge."""
    out = img.copy()
    src, dst = img.load(), out.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            if src[x, y][3] >= 40:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and src[nx, ny][3] >= 128:
                    dst[x, y] = PALE
                    break
    return out


def fit(img):
    """The drawn part of a big sprite, scaled to stand inside one tile."""
    img = img.crop(img.getbbox())
    scale = (TILE - 2) / max(img.size)
    size = (max(1, round(img.width * scale)), max(1, round(img.height * scale)))
    small = img.resize(size, Image.BOX)
    # Hard edges, like the rest of the game's sprites.
    alpha = small.getchannel('A').point(lambda a: 255 if a >= 128 else 0)
    small.putalpha(alpha)
    out = Image.new('RGBA', (TILE, TILE), (0, 0, 0, 0))
    out.alpha_composite(small, ((TILE - size[0]) // 2, (TILE - size[1]) // 2))
    return out


def centre(img):
    box = img.getbbox()
    out = Image.new('RGBA', img.size, (0, 0, 0, 0))
    out.alpha_composite(img.crop(box), ((img.width - (box[2] - box[0])) // 2, (img.height - (box[3] - box[1])) // 2))
    return out


def build(spec):
    out = None
    for path, state, colour in spec['layers']:
        img, _turns = frame(path, state, 2)
        if colour:
            img = tint(img, colour)
        out = img if out is None else Image.alpha_composite(out, img)
    if spec.get('fit'):
        out = fit(out)
    if spec.get('centre'):
        out = centre(out)
    if out.size != (TILE, TILE):
        raise SystemExit('a picture must be one %dx%d tile: give a bigger sprite "fit"' % (TILE, TILE))
    return outline(out) if spec.get('outline') else out


def main():
    check = '--check' in sys.argv[1:]
    wanted = {'%s.png' % name: png_bytes(build(spec)) for name, spec in SPRITES.items()}
    lowered = [name.lower() for name in wanted]
    if len(set(lowered)) != len(lowered):
        raise SystemExit('two pictures differ only by case')
    stale = []
    os.makedirs(OUT, exist_ok=True)
    for fname, data in sorted(wanted.items()):
        path = os.path.join(OUT, fname)
        if not os.path.exists(path) or open(path, 'rb').read() != data:
            stale.append(fname)
            if not check:
                open(path, 'wb').write(data)
    extra = sorted(f for f in os.listdir(OUT) if f.endswith('.png') and f not in wanted)
    if check:
        if stale or extra:
            print('stale: %s; not made by this script: %s' % (stale, extra))
            return 1
        print('icons/vehicle_designer: %d pictures up to date' % len(wanted))
        return 0
    print('icons/vehicle_designer: wrote %d of %d pictures' % (len(stale), len(wanted)))
    if extra:
        print('not made by this script: %s' % extra)
    return 0


if __name__ == '__main__':
    sys.exit(main())

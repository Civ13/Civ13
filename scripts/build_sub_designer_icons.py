#!/usr/bin/env python3
"""Cuts the submarine designer's fitting pictures out of the game's own
sprite sheets.

The submarine designer window (code/modules/naval/sub_designer.dm) shows each
fitting of a submarine sheet as the sprite the built thing has in the game.
Like the ship designer's pictures (scripts/build_ship_designer_icons.py, whose
cutting, tinting and outlining this script uses), they are plain PNGs, under
icons/sub_designer/, sent to the window with browse_rsc. Each is the first
frame of an existing state with a one-pixel ink outline, so it reads on the
grey of a hull section and on the green of a hatch alike. Nothing is drawn
here.

Run it after changing sub_draught_fittings (code/modules/naval/sub_draught.dm)
or the sprites they use (after scripts/draw_submarine_hull.py, which draws
the battery and air banks):

    python3 scripts/build_sub_designer_icons.py          # write the PNGs
    python3 scripts/build_sub_designer_icons.py --check  # exit 1 if stale
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_ship_designer_icons import REPO, WOOD, build, png_bytes  # noqa: E402

OUT = os.path.join(REPO, 'icons', 'sub_designer')

# fitting key (sub_draught_fittings) -> what the built thing looks like, as
# build_ship_designer_icons.SPRITES describes a picture.
SPRITES = {
    # /obj/structure/vehicleparts/shipwheel
    'fit_W': {'layers': [('icons/obj/vehicles/vehicleparts_boats.dmi', 'ship_wheel', None)], 'outline': True},
    # /obj/structure/vehicleparts/sub_station
    'fit_S': {'layers': [('icons/obj/machines/submarine.dmi', 'ballast', None)], 'outline': True},
    # /obj/structure/vehicleparts/sub_fitting/battery
    'fit_E': {'layers': [('icons/obj/vehicles/submarine_hull.dmi', 'battery_bank', None)], 'outline': True},
    # /obj/structure/vehicleparts/sub_fitting/air
    'fit_A': {'layers': [('icons/obj/vehicles/submarine_hull.dmi', 'air_bank', None)], 'outline': True},
    # /obj/structure/closet
    'fit_L': {'layers': [('icons/obj/closet.dmi', 'closed', None)], 'outline': True},
    # /obj/structure/bed/wood (wood tint on the bed overlay)
    'fit_B': {'layers': [('icons/obj/bed_chair.dmi', 'bed', WOOD)], 'outline': True},
    # /obj/structure/torpedo_tube
    'fit_T': {'layers': [('icons/obj/naval_gear.dmi', 'torpedo_tube', None)], 'outline': True},
}


def main():
    check = '--check' in sys.argv[1:]
    wanted = {'%s.png' % name: png_bytes(build(spec)) for name, spec in SPRITES.items()}
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
        print('icons/sub_designer: %d pictures up to date' % len(wanted))
        return 0
    print('icons/sub_designer: wrote %d of %d pictures' % (len(stale), len(wanted)))
    if extra:
        print('not made by this script: %s' % extra)
    return 0


if __name__ == '__main__':
    sys.exit(main())

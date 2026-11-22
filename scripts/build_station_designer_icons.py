#!/usr/bin/env python3
"""Cuts the station designer's pictures out of the game's own sprite sheets.

The station designer window (code/modules/space/station_designer.dm) shows
each slot of a space station plan as the things the built module has in the
game. Like the airship designer's pictures (scripts/build_air_designer_icons.py,
whose shape this script keeps), they are plain 32x32 PNGs, under
icons/station_designer/, sent to the window with browse_rsc. Each is the
first frame of an existing state, or existing states laid over one another
the way the game lays them. Nothing is drawn here.

A slot is built up in the window from three kinds of picture:

  hull, floor   the module's shell and its deck: the window lays the floor
                inside a rim of hull, as habitat_unfold() rings a module's
                floor with its shell.
  hatch         the hatch two docked modules share, shown on the wall
                between them.
  mod_<key>     what tells the module apart, standing on the floor: the
                furniture habitat_furnish() gives it, with a pale outline.

The greenhouse is its hydroponics tray with a ripe crop over it, raised six
pixels as the tray's own update_icon() raises it. The keel airlock is an
open hatch with the keel's truss seen through it, so it is not mistaken for
a plain airlock.

keel_<what> are the things on the keel outside the keel airlock: its truss,
a solar wing at each end of the boom and the reboost thruster at its aft
end. The thruster's sprite is 96x96, so it is cropped to what is drawn and
scaled down to one tile.

The files are named by what the key is as well as the key (mod_C, keel_wing),
as the other designers' are: Windows serves the browser's cache without case.

Run it after changing station_plan_pieces() in
code/modules/space/station_plan.dm or the sprites the modules use:

    python3 scripts/build_station_designer_icons.py          # write the PNGs
    python3 scripts/build_station_designer_icons.py --check  # exit 1 if stale
"""
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_ship_designer_icons import REPO, TILE, frame, png_bytes  # noqa: E402
from build_vehicle_designer_icons import fit, outline  # noqa: E402

OUT = os.path.join(REPO, 'icons', 'station_designer')
STRUCTURES = 'icons/obj/structures.dmi'
DOORS = 'icons/obj/doors/material_doors.dmi'

# file name -> where its picture comes from: 'layers' is a list of
# (dmi, state, facing, pixels raised), the first at the bottom; 'fit' scales
# a bigger sprite's drawn part down to one tile; 'outline' puts the pale line
# round what stands on the floor or hangs on the keel.
SPRITES = {
    # ---- the module itself (habitat_modules.dm) ----
    # /turf/wall/habitat_shell
    'hull': {'layers': [('icons/turf/wall_masks.dmi', 'sub0', 2, 0)]},
    # /turf/floor/habitat
    'floor': {'layers': [('icons/obj/machines/submarine.dmi', 'steel_grid', 2, 0)]},
    # /obj/structure/simple_door/habitat_hatch
    'hatch': {'layers': [(DOORS, 'blast', 2, 0)]},
    # ---- station_plan_pieces() ----
    # C: /obj/structure/orbit_console
    'mod_C': {'layers': [('icons/obj/computers.dmi', 'solar_screen', 2, 0)], 'outline': True},
    # Q: /obj/structure/bed/lander_bunk
    'mod_Q': {'layers': [('icons/obj/bed_chair.dmi', 'bunk_bed', 2, 0)], 'outline': True},
    # G: /obj/structure/hydroponics_tray with a crop ready to harvest
    'mod_G': {'layers': [(STRUCTURES, 'kevlar_trough_empty', 2, 0), ('icons/farming/plants.dmi', 'parsley-harvest', 2, 6)], 'outline': True},
    # W: /obj/structure/table
    'mod_W': {'layers': [(STRUCTURES, 'table', 2, 0)], 'outline': True},
    # S: /obj/structure/closet/crate
    'mod_S': {'layers': [('icons/obj/storage.dmi', 'crate', 2, 0)], 'outline': True},
    # N: /obj/structure/deck_hatch
    'mod_N': {'layers': [('icons/obj/stairs.dmi', 'ladderdown', 2, 0)], 'outline': True},
    # A: /obj/structure/simple_door/habitat_hatch, the outer hatch shut
    'mod_A': {'layers': [(DOORS, 'blast', 2, 0)], 'outline': True},
    # K: /obj/structure/orbit_truss seen through the outer hatch, open
    'mod_K': {'layers': [(STRUCTURES, 'grille', 2, 0), (DOORS, 'blastopen', 2, 0)], 'outline': True},
    # ---- the keel (orbit_found_station_plan) ----
    # /obj/structure/orbit_truss
    'keel_truss': {'layers': [(STRUCTURES, 'grille', 2, 0)], 'outline': True},
    # /obj/structure/civ_generator/solar/wing
    'keel_wing': {'layers': [('icons/obj/renewable_power.dmi', 'solar_panel', 2, 0)], 'outline': True},
    # /obj/structure/orbit_thruster
    'keel_thruster': {'layers': [('icons/obj/decals_wider.dmi', 'rocket', 2, 0)], 'fit': True, 'outline': True},
}


def build(spec):
    out = None
    for path, state, facing, raised in spec['layers']:
        img, _turns = frame(path, state, facing)
        if raised:
            up = Image.new('RGBA', img.size, (0, 0, 0, 0))
            up.alpha_composite(img.crop((0, raised, img.width, img.height)), (0, 0))
            img = up
        out = img if out is None else Image.alpha_composite(out, img)
    if spec.get('fit'):
        out = fit(out)
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
        print('icons/station_designer: %d pictures up to date' % len(wanted))
        return 0
    print('icons/station_designer: wrote %d of %d pictures' % (len(stale), len(wanted)))
    if extra:
        print('not made by this script: %s' % extra)
    return 0


if __name__ == '__main__':
    sys.exit(main())

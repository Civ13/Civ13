#!/usr/bin/env python3
"""Cuts the airship designer's pictures out of the game's own sprite sheets.

The airship designer window (code/modules/naval/air_designer.dm) shows each
tile of deck, gas cell and part of an airship sheet as the sprite the built
thing has in the game. Like the vehicle designer's pictures
(scripts/build_vehicle_designer_icons.py, whose outline and fitting this
script uses), they are plain 32x32 PNGs, under icons/air_designer/, sent to
the window with browse_rsc. Each is the first frame of an existing state.
Nothing is drawn here.

A deck is the whole tile. A part stands on the deck, so it gets a one-pixel
pale outline. The helm is shown facing north, the way the yard sets it up:
the bow is at the top of the sheet.

A gas cell is the one picture that is not a 32x32 state: the game hangs a
64x64 envelope over the tile. Its picture is that sprite cropped to what is
drawn and scaled down to one tile; the window shows it in a small box in the
tile's corner, so the deck and the part under it stay in view.

The files are named by what the key is as well as the key (deck_p, cell_c,
part_W), as the vehicle designer's are: Windows serves the browser's cache
without case.

Run it after changing the tables in code/modules/naval/air_draught.dm or the
sprites they use:

    python3 scripts/build_air_designer_icons.py          # write the PNGs
    python3 scripts/build_air_designer_icons.py --check  # exit 1 if stale
"""
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_ship_designer_icons import REPO, TILE, frame, png_bytes  # noqa: E402
from build_vehicle_designer_icons import fit, outline  # noqa: E402

OUT = os.path.join(REPO, 'icons', 'air_designer')
HULL = 'icons/obj/vehicles/airship_hull.dmi'
CELL = 'icons/obj/vehicles/airship_gas_cell.dmi'
PARTS = 'icons/obj/vehicles/vehicleparts.dmi'

# file name -> where its picture comes from: 'from' is (dmi, state, facing);
# 'fit' scales a bigger sprite's drawn part down to one tile; 'outline' puts
# the pale line round what stands on or hangs over the deck.
SPRITES = {
    # ---- air_draught_decks() ----
    # /obj/covers/airship_deck (the icon of /obj/covers)
    'deck_p': {'from': ('icons/turf/floors.dmi', 'wood_ship', 2)},
    # /obj/covers/airship_deck/aluminium
    'deck_a': {'from': (HULL, 'airship_deck_aluminium', 2)},
    # /obj/covers/airship_deck/steel
    'deck_s': {'from': (HULL, 'airship_deck_steel', 2)},
    # ---- air_draught_cells() ----
    # /obj/structure/airship_gas_cell
    'cell_c': {'from': (CELL, 'gas_cell', 2), 'fit': True, 'outline': True},
    # /obj/structure/airship_gas_cell/rubber
    'cell_r': {'from': (CELL, 'gas_cell_rubber', 2), 'fit': True, 'outline': True},
    # /obj/structure/airship_gas_cell/skin
    'cell_k': {'from': (CELL, 'gas_cell_skin', 2), 'fit': True, 'outline': True},
    # ---- air_draught_parts() ----
    # /obj/structure/airship_helm, facing the bow
    'part_W': {'from': (HULL, 'helm', 1), 'outline': True},
    # /obj/structure/engine/internal/gasoline, the first engine of the list
    'part_E': {'from': ('icons/obj/engines32.dmi', 'gasoline_static', 2), 'outline': True},
    # /obj/item/weapon/reagent_containers/glass/barrel/fueltank/small
    'part_Y': {'from': (PARTS, 'fueltank_small', 2), 'outline': True},
    # .../fueltank/smalltank
    'part_M': {'from': (PARTS, 'fueltank_small_tank', 2), 'outline': True},
    # .../fueltank
    'part_T': {'from': (PARTS, 'fueltank_large', 2), 'outline': True},
    # .../fueltank/tank
    'part_X': {'from': (PARTS, 'fueltank_large_tank', 2), 'outline': True},
    # /obj/structure/airship_bomb_hatch
    'part_B': {'from': (HULL, 'bomb_hatch', 2), 'outline': True},
}


def build(spec):
    path, state, facing = spec['from']
    out, _turns = frame(path, state, facing)
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
        print('icons/air_designer: %d pictures up to date' % len(wanted))
        return 0
    print('icons/air_designer: wrote %d of %d pictures' % (len(stale), len(wanted)))
    if extra:
        print('not made by this script: %s' % extra)
    return 0


if __name__ == '__main__':
    sys.exit(main())

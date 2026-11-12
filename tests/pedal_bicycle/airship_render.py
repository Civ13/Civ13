"""Draw the pedal airship landed and ridden in each direction, from the game's sprites.

    python3 tests/pedal_bicycle/airship_render.py out.png
"""
import importlib.util
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('motorcycle_render', ROOT / 'tests/motorcycle_riding/render.py')
shared = importlib.util.module_from_spec(spec)
spec.loader.exec_module(shared)

SCALE = 5
PARTS = ('groin_m', 'torso_m', 'l_leg_m', 'r_leg_m', 'l_foot_m', 'r_foot_m',
         'l_arm_m', 'r_arm_m', 'l_hand_m', 'r_hand_m', 'head_m')


def main():
    ship = shared.Dmi(ROOT / 'icons/obj/vehicles/pedal_airship.dmi')
    body = shared.Dmi(ROOT / 'icons/mob/human_races/r_human.dmi')
    grass = shared.Dmi(ROOT / 'icons/turf/floors.dmi').get('grass0')
    dirs = (('south', 2), ('north', 1), ('east', 4), ('west', 8))
    sheet = Image.new('RGBA', (64 * 4, 64 * 2))
    for col, (_, d) in enumerate(dirs):
        for row in range(2):
            for tx in range(2):
                for ty in range(2):
                    sheet.alpha_composite(grass, (col * 64 + tx * 32, row * 64 + ty * 32))
            sheet.alpha_composite(ship.get('airship', d), (col * 64, row * 64))
        # The rider stands on the middle of the sheet's bottom edge.
        for part in PARTS:
            sheet.alpha_composite(shared.tint(body.get(part, d), (224, 172, 132)), (col * 64 + 16, 64 + 32))
        sheet.alpha_composite(ship.get('airship_overlay', d), (col * 64, 64))
    big = sheet.resize((sheet.width * SCALE, sheet.height * SCALE), Image.NEAREST)
    out = Image.new('RGBA', (big.width, big.height + 24), (24, 24, 28, 255))
    out.alpha_composite(big, (0, 24))
    draw = ImageDraw.Draw(out)
    for col, (name, _) in enumerate(dirs):
        draw.text((col * 64 * SCALE + 8, 6), 'facing ' + name + ' (landed, then ridden)', fill=(240, 240, 240))
    out.save(sys.argv[1])


if __name__ == '__main__':
    main()

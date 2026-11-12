"""Draw the bicycle parked and ridden in each direction, from the game's sprites.

    python3 tests/pedal_bicycle/render.py out.png
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tests/motorcycle_riding'))
sys.path.insert(1, str(ROOT / 'tests/pedal_bicycle'))
from render import Dmi, tint  # noqa: E402
from sprites import RIDER_LIFT  # noqa: E402

SCALE = 6
PARTS = ('groin_m', 'torso_m', 'l_leg_m', 'r_leg_m', 'l_foot_m', 'r_foot_m',
         'l_arm_m', 'r_arm_m', 'l_hand_m', 'r_hand_m', 'head_m')


def main():
    bike = Dmi(ROOT / 'icons/obj/vehicles/bicycle.dmi')
    body = Dmi(ROOT / 'icons/mob/human_races/r_human.dmi')
    road = Dmi(ROOT / 'icons/turf/floors.dmi').get('road_1')
    dirs = (('south', 2), ('north', 1), ('east', 4), ('west', 8))
    sheet = Image.new('RGBA', (32 * 4, 32 * 2))
    for col, (_, d) in enumerate(dirs):
        for row in range(2):
            sheet.alpha_composite(road, (col * 32, row * 32))
            sheet.alpha_composite(bike.get('bicycle', d), (col * 32, row * 32))
        for part in PARTS:
            sheet.alpha_composite(tint(body.get(part, d), (224, 172, 132)), (col * 32, 32 - RIDER_LIFT))
        sheet.alpha_composite(bike.get('bicycle_overlay', d), (col * 32, 32))
    big = sheet.resize((sheet.width * SCALE, sheet.height * SCALE), Image.NEAREST)
    out = Image.new('RGBA', (big.width, big.height + 24), (24, 24, 28, 255))
    out.alpha_composite(big, (0, 24))
    draw = ImageDraw.Draw(out)
    for col, (name, _) in enumerate(dirs):
        draw.text((col * 32 * SCALE + 8, 6), 'facing ' + name + ' (parked, then ridden)', fill=(240, 240, 240))
    out.save(sys.argv[1])


if __name__ == '__main__':
    main()

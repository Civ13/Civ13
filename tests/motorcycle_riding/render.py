"""Draw the seated rider from ride.py result.json files as a before/after sheet.

Each panel is the bike's tile and its neighbours at the moment the rider
boarded, drawn from the recorded positions with the game's own sprites
(road, motorcycle, bare human body, the bike's cover overlay). The red outline
marks the tile the bike drives into next when the rider's body reaches into it,
which is what made the bike run into its own rider.

    python3 tests/motorcycle_riding/render.py BEFORE/result.json AFTER/result.json out.png
"""
import json
import re
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
DIRS = {2: 0, 1: 1, 4: 2, 8: 3}  # BYOND dmi direction order: S, N, E, W
STEP = {'east': (1, 0), 'north': (0, 1), 'west': (-1, 0), 'south': (0, -1)}
SCALE = 4
VIEW = 3


class Dmi:
    def __init__(self, path):
        self.image = Image.open(path).convert('RGBA')
        desc = Image.open(path).info['Description']
        self.w = int(re.search(r'width = (\d+)', desc).group(1))
        self.h = int(re.search(r'height = (\d+)', desc).group(1))
        self.states = {}
        index = 0
        for name, dirs, frames in re.findall(r'state = "([^"]*)"\n\tdirs = (\d+)\n\tframes = (\d+)', desc):
            self.states.setdefault(name, (index, int(dirs)))
            index += int(dirs) * int(frames)

    def get(self, state, direction=2):
        start, dirs = self.states[state]
        i = start + (DIRS[direction] if dirs > 1 else 0)
        cols = self.image.width // self.w
        x, y = (i % cols) * self.w, (i // cols) * self.h
        return self.image.crop((x, y, x + self.w, y + self.h))


def tint(img, rgb):
    r, g, b = rgb
    px = img.copy()
    data = [(p[0] * r // 255, p[1] * g // 255, p[2] * b // 255, p[3]) for p in px.get_flattened_data()]
    px.putdata(data)
    return px


def panel(frame, label, vehicles, body, floors):
    size = 32 * VIEW
    canvas = Image.new('RGBA', (size, size))
    road = floors.get('road_1')
    for i in range(VIEW):
        for j in range(VIEW):
            canvas.alpha_composite(road, (i * 32, j * 32))
    ox, oy = frame['bike_x'] - 1, frame['bike_y'] - 1

    def place(img, tx, ty, sx=0, sy=0):
        px = (tx - ox) * 32 + sx
        py = size - ((ty - oy) * 32 + sy) - 32
        canvas.alpha_composite(img, (px, py))

    d = frame['bike_dir']
    place(vehicles.get(frame['bike_state'], d), frame['bike_x'], frame['bike_y'])
    rd = frame['rider_dir']
    skin = (224, 172, 132)
    for part in ('groin_m', 'torso_m', 'l_leg_m', 'r_leg_m', 'l_foot_m', 'r_foot_m',
                 'l_arm_m', 'r_arm_m', 'l_hand_m', 'r_hand_m', 'head_m'):
        place(tint(body.get(part, rd), skin), frame['rider_x'], frame['rider_y'],
              frame['rider_sx'] + frame['rider_px'], frame['rider_sy'] + frame['rider_py'])
    overlay = frame['bike_state'] + '_overlay'
    if overlay in vehicles.states:
        place(vehicles.get(overlay, d), frame['bike_x'], frame['bike_y'])
    big = canvas.resize((size * SCALE, size * SCALE), Image.NEAREST)
    draw = ImageDraw.Draw(big)
    dx, dy = STEP[frame['dir']]
    reaches = (dx > 0 and frame['rider_sx'] > 0) or (dy > 0 and frame['rider_sy'] > 0)
    if reaches:
        tx, ty = 1 + dx, 1 + dy
        x0, y0 = tx * 32 * SCALE, (VIEW - 1 - ty) * 32 * SCALE
        draw.rectangle((x0 + 2, y0 + 2, x0 + 32 * SCALE - 3, y0 + 32 * SCALE - 3), outline=(220, 40, 40), width=6)
    out = Image.new('RGBA', (big.width, big.height + 28), (24, 24, 28, 255))
    out.alpha_composite(big, (0, 28))
    ImageDraw.Draw(out).text((8, 8), label, fill=(240, 240, 240))
    return out


def main():
    before, after, target = (Path(a) for a in sys.argv[1:4])
    vehicles = Dmi(ROOT / 'icons/obj/vehicles/vehicleparts.dmi')
    body = Dmi(ROOT / 'icons/mob/human_races/r_human.dmi')
    floors = Dmi(ROOT / 'icons/turf/floors.dmi')
    rows = []
    for name, path in (('before', before), ('after', after)):
        result = json.loads(path.read_text())
        notes = result['notes']
        row = []
        for direction in ('east', 'north', 'west', 'south'):
            frame = next(f for f in result['frames'] if f['label'] == 'mounted' and f['dir'] == direction)
            n = notes[direction]
            text = f"{name}: ride {direction} - offset {frame['rider_sx']},{frame['rider_sy']}, moved {n['travelled']} tiles, {n['brute']:g} brute"
            row.append(panel(frame, text, vehicles, body, floors))
        rows.append(row)
    w, h = rows[0][0].size
    sheet = Image.new('RGBA', (w * 4 + 12 * 3, h * 2 + 12), (24, 24, 28, 255))
    for r, row in enumerate(rows):
        for c, p in enumerate(row):
            sheet.alpha_composite(p, (c * (w + 12), r * (h + 12)))
    sheet.save(target)


if __name__ == '__main__':
    main()

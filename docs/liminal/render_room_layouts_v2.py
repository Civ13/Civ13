"""Static actual-asset previews of the version-2 furnished room layouts.

Composites existing Civ13 DMI frames over room-layouts-v2.json. It is a review
picture, not a native renderer, DMM export or in-game screenshot. Sockets are
drawn open into short hall stubs so each room reads in context.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import sys
from PIL import Image, ImageDraw, ImageFont, __version__ as pillow_version

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))
import room_layouts_v2 as layouts  # noqa: E402

DIRS = layouts.DIRS
ORDER = {1: [2], 4: [2, 1, 4, 8], 8: [2, 1, 4, 8, 6, 10, 5, 9]}
ASSETS = {
    'wall': ('icons/turf/wall_masks.dmi', 'cement_wall', '/turf/wall/cement'),
    'carpet': ('icons/turf/flooring/carpet.dmi', 'sblucarpet', '/turf/floor/carpet/tealcarpet'),
    'steel_tile': ('icons/turf/floors.dmi', 'floor', '/turf/floor/plating/steel'),
    'white_tile': ('icons/turf/floors.dmi', 'white', '/turf/floor/plating/white'),
    'dark_plating': ('icons/turf/floors.dmi', 'dark', '/turf/floor/plating/dark'),
    'hall_floor': ('icons/turf/floors.dmi', 'floor', '/turf/floor/plating/steel'),
    'desk': ('icons/obj/structures.dmi', 'woodtable', '/obj/structure/table/modern/table'),
    'chair': ('icons/obj/bed_chair.dmi', 'officechair_dark', '/obj/structure/bed/chair/office/dark'),
    'computer': ('icons/obj/computers.dmi', 'ibm', '/obj/structure/telecom/terminal'),
    'paper': ('icons/obj/bureaucracy.dmi', 'paper', '/obj/item/weapon/paper'),
    'cabinet': ('icons/obj/bureaucracy.dmi', 'filingcabinet', '/obj/structure/filingcabinet'),
    'shelf': ('icons/obj/library.dmi', 'book-0', '/obj/structure/bookcase'),
    'plant': ('icons/obj/flora/filled_plantpots.dmi', 'plant-05plastic4', '/obj/structure/plant_pot/clay/light/filled'),
    'noticeboard': ('icons/obj/structures.dmi', 'nboard00', '/obj/structure/noticeboard'),
    'locker': ('icons/obj/closet.dmi', 'closed', '/obj/structure/closet'),
    'rack': ('icons/obj/objects.dmi', 'rack', '/obj/structure/table/rack'),
    'vending_snack': ('icons/obj/vending.dmi', 'snack', '/obj/structure/vending/sales/food/snacks'),
    'vending_coffee': ('icons/obj/vending.dmi', 'coffee', '/obj/structure/vending/sales/drinks/hot'),
    'sink': ('icons/obj/watercloset.dmi', 'sink', '/obj/structure/sink'),
}
digest = lambda b: hashlib.sha256(b).hexdigest()


class Frames:
    """First frame of a DMI state; duplicate names are refused only when used."""
    def __init__(self):
        self.sheets, self.used = {}, {}

    def get(self, path, state, direction=2):
        if path not in self.sheets:
            im = Image.open(ROOT / path)
            meta = im.info['Description']
            w = int(re.search(r'width = (\d+)', meta)[1]); h = int(re.search(r'height = (\d+)', meta)[1])
            states, offset = {}, 0
            for m in re.finditer(r'state = "([^"]*)"(.*?)(?=\nstate =|\Z)', meta, re.S):
                dirs = int(re.search(r'dirs = (\d+)', m[2])[1]); frames = int(re.search(r'frames = (\d+)', m[2])[1])
                states.setdefault(m[1], []).append((offset, dirs, frames)); offset += dirs * frames
            self.sheets[path] = (im.convert('RGBA'), w, h, states)
        im, w, h, states = self.sheets[path]
        assert len(states.get(state, ())) == 1, ('missing or ambiguous state', path, state)
        offset, dirs, frames = states[state][0]
        effective = 2 if dirs == 1 else direction
        assert effective in ORDER[dirs], ('unsupported direction', path, state, direction)
        index = offset + ORDER[dirs].index(effective)
        x = (index % (im.width // w)) * w; y = (index // (im.width // w)) * h
        sprite = im.crop((x, y, x + w, y + h))
        assert sprite.getchannel('A').getbbox(), ('empty frame', path, state)
        self.used[(path, state, effective)] = dict(icon=path, state=state, direction=effective, dirs=dirs, frames=frames,
                                                   rgba_sha256=digest(sprite.tobytes()))
        return sprite


def render_room(name, archetype, furnishing, frames):
    w, h = archetype['width'], archetype['height']
    walls, floor = set(), {}
    for y, row in enumerate(archetype['mask']):
        for x, ch in enumerate(row):
            if ch == '#':
                walls.add((x, y))
    columns = {tuple(o['position']) for o in furnishing['objects'] if o['asset'] == 'column'}
    walls |= columns
    for key, material in furnishing['floor'].items():
        x, y = map(int, key.split(','))
        floor[(x, y)] = material
    # Open each declared socket into a 3-wide, 3-long hall stub.
    for s in archetype['sockets'].values():
        cells = layouts.socket_cells(w, h, s)
        dx, dy = {'N': (0, 1), 'S': (0, -1), 'E': (1, 0), 'W': (-1, 0)}[s['facing']]
        for c in cells:
            walls.discard(c); floor[c] = 'hall_floor'
        side = [(cells[0][0] - abs(dy), cells[0][1] - abs(dx)), (cells[-1][0] + abs(dy), cells[-1][1] + abs(dx))]
        for depth in range(1, 4):
            for c in cells:
                floor[(c[0] + dx * depth, c[1] + dy * depth)] = 'hall_floor'
            for c in side:
                walls.add((c[0] + dx * depth, c[1] + dy * depth))
    xs = [p[0] for p in walls | set(floor)]; ys = [p[1] for p in walls | set(floor)]
    minx, maxx, miny, maxy = min(xs), max(xs), min(ys), max(ys)
    image = Image.new('RGBA', ((maxx - minx + 1) * 32, (maxy - miny + 1) * 32), '#111820')

    def place(x, y, asset, state=None, direction=2):
        icon, default, _ = ASSETS[asset]
        image.alpha_composite(frames.get(icon, state or default, direction), ((x - minx) * 32, (maxy - y) * 32))

    carpet = {p for p, m in floor.items() if m == 'carpet'}
    for (x, y), material in sorted(floor.items()):
        if material != 'carpet':
            place(x, y, material); continue
        place(x, y, 'carpet')
        border = sum(bit for bit, (dx, dy) in DIRS.items() if (x + dx, y + dy) not in carpet)
        for bit in DIRS:
            if border & bit:
                place(x, y, 'carpet', 'sblucarpet_edges', bit)
        for v, hz in ((1, 4), (1, 8), (2, 4), (2, 8)):
            dx, dy = DIRS[hz][0], DIRS[v][1]
            if border & v and border & hz:
                place(x, y, 'carpet', 'sblucarpet_edges', v | hz)
            elif not border & v and not border & hz and (x + dx, y + dy) not in carpet:
                place(x, y, 'carpet', 'sblucarpet_corners', v | hz)
    for (x, y) in sorted(walls):
        junction = sum(bit for bit, (dx, dy) in DIRS.items() if (x + dx, y + dy) in walls)
        place(x, y, 'wall', f'cement_wall{junction}')
    # Draw north rows first so taller sprites overlap correctly.
    for o in sorted(furnishing['objects'], key=lambda o: (-o['position'][1], o['position'][0])):
        if o['asset'] == 'column':
            continue
        place(o['position'][0], o['position'][1], o['asset'], o.get('state'), o['direction'])
    return image


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--output', type=Path, required=True)
    a = p.parse_args()
    assert not a.output.exists(), 'Existing output is preserved'
    catalog, furnishing, problems = layouts.check()
    assert not problems, problems
    a.output.mkdir(parents=True)
    frames = Frames()
    font = lambda size: ImageFont.load_default(size=size)
    tiles, files = [], {}
    for name, archetype in catalog['archetypes'].items():
        room = render_room(name, archetype, furnishing[name], frames)
        big = room.resize((room.width * 2, room.height * 2), Image.Resampling.NEAREST)
        sheet = Image.new('RGB', (max(big.width + 60, 900), big.height + 170), '#17212b')
        d = ImageDraw.Draw(sheet)
        d.text((30, 18), name.replace('_', ' ').capitalize(), font=font(30), fill='#f1efe6')
        d.text((30, 60), furnishing[name]['program'], font=font(17), fill='#c4cdd4')
        sheet.paste(big.convert('RGB'), (30, 100))
        d.text((30, big.height + 120), 'Static actual-asset preview, version 2 proposal. Not native-approved.', font=font(16), fill='#e7d9b6')
        out = a.output / (name + '.png'); sheet.save(out)
        tiles.append((name, room))
    cols = 4
    cell_w = max(r.width for _, r in tiles) + 40; cell_h = max(r.height for _, r in tiles) + 60
    rows = (len(tiles) + cols - 1) // cols
    contact = Image.new('RGB', (cols * cell_w + 40, rows * cell_h + 110), '#17212b')
    d = ImageDraw.Draw(contact)
    d.text((30, 20), 'Liminal room layouts, version 2 proposal', font=font(34), fill='#f1efe6')
    d.text((30, 64), 'Existing Civ13 sprites over the furnished catalog; hall stubs show the open doorways.', font=font(18), fill='#c4cdd4')
    for i, (name, room) in enumerate(tiles):
        x = 30 + (i % cols) * cell_w; y = 110 + (i // cols) * cell_h
        d.text((x, y), name.replace('_', ' '), font=font(20), fill='#e7d9b6')
        contact.paste(room.convert('RGB'), (x, y + 30))
    contact.save(a.output / 'contact-sheet.png')
    files = {f.name: dict(sha256=digest(f.read_bytes()), bytes=f.stat().st_size) for f in sorted(a.output.iterdir())}
    manifest = dict(schema='civ13-liminal-room-previews-v2/1', status='PROPOSAL_FOR_REVIEW_NOT_NATIVE_APPROVED',
                    catalog_version=catalog['version'],
                    layouts_sha256=digest(layouts.LAYOUTS.read_bytes()), catalog_sha256=digest(layouts.CATALOG.read_bytes()),
                    renderer_sha256=digest(Path(__file__).read_bytes()), pillow=pillow_version,
                    assets={k: dict(icon=v[0], state=v[1], type=v[2]) for k, v in ASSETS.items()},
                    dmi_frames=sorted(frames.used.values(), key=lambda r: (r['icon'], r['state'], r['direction'])),
                    files=files, native_execution=False,
                    credit='Existing Civ13 and upstream SS13 asset contributors; retain root LICENSE.')
    (a.output / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(dict(status='PASS', output=str(a.output), rooms=len(tiles))))


if __name__ == '__main__':
    main()

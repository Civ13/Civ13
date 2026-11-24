"""Export production Admin Map page CSS and JS around synthetic game data."""
import json
import math
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
COLS, ROWS, SCALE, CELL = 125, 88, 6, 4
COLORS = dict(o='#28476a', w='#466e92', b='#aa956e', g='#71994f', f='#466c3b')
DATA = {
    'b': [
        [107, 125, 'a', 'Northport', 'Example One', 'example_one', 'fixture-player-one'],
        [360, 250, 's', 'Southport', 'Example Two', 'example_two', 'fixture-player-two'],
        [285, 305, 'g', '', 'Example Ghost', 'example_ghost', 'fixture-ghost'],
    ],
    'c': [2],
    's': [
        [7, 'storm', 0, 358, 254, 40, 36, 80, 1, 0, 9],
        [8, 'heat', 0, 204, 267, 47, 31, 40, 0, -1, 4],
    ],
    'w': [1, 0, 1, 'a light breeze from the west'], 'zone': 'none', 'season': 'SUMMER',
    'cap': 4, 'pc': [[1, 'low', 370, 150, 60, 12.5], [2, 'high', 85, 190, 50, 8]],
    'a': [2, 2, 250, [13, 10, 20, 31], [30, 70, 40, 50], [1015, 992, 1021, 1030],
          [5, 100, 30, 5], [3, 9, 5, 1], [-2, 3, 10, 5], [0, 35, 5, 0]],
    'who': 1, 'edit': 0,
}


def terrain():
    """Deterministic sample with no staff data, server assets or external inputs."""
    tiles = []
    for y in range(ROWS):
        for x in range(COLS):
            xs, ys = x / COLS, y / ROWS
            shores = max(1 - ((xs - .28) / .24)**2 - ((ys - .28) / .25)**2,
                         1 - ((xs - .75) / .22)**2 - ((ys - .7) / .2)**2)
            n = shores + .15 * math.sin(x * .25 + y * .08) + .11 * math.sin(y * .29 - x * .1)
            tiles.append('g' if n > .4 else 'f' if n > .22 else 'b' if n > .02 else 'w' if n > -.17 else 'o')
    return ''.join(tiles)


def raw_string(text):
    return text.split('return @{"', 1)[1].split('"}', 1)[0]


def fixture():
    source = (ROOT / 'code/modules/admin/verbs/admin_map.dm').read_text(encoding='utf-8')
    panel = (ROOT / 'code/modules/admin/player_panel_pages.dm').read_text(encoding='utf-8')
    shared_css = raw_string(panel.split('/proc/admin_panel_css()', 1)[1])
    procedure = source.split('/datum/admin_map_controller/proc/page_html(', 1)[1].split('// JSON safe', 1)[0]
    chunks = []
    for chunk in re.findall(r'^\s*html \+= "(.*)"$', procedure, re.M):
        if chunk.startswith(('var REF', 'T=')) or chunk == '</script></body></html>':
            continue
        for key, value in {'[base[2] * scale]': COLS * SCALE, '[base[3] * scale]': ROWS * SCALE,
                           '[AMAP_REFRESH / 10]': 2}.items():
            chunk = chunk.replace(key, str(value))
        chunks.append(chunk)
    assert chunks[-1].endswith('<script>') and "id='mapframe'" in ''.join(chunks)
    script = raw_string(source.split('/proc/admin_map_script()', 1)[1])
    data = (f'var REF="",Z=1,CELL={CELL},W={COLS},H={ROWS},K={SCALE},PICK=null,'
            f'T={json.dumps(terrain())},COL={json.dumps(COLORS)},LV=["Demo region"],D={json.dumps(DATA)};')
    return ("<html><head><meta charset='utf-8'><title>Admin map</title>" + shared_css + '<style>'
            + ''.join(chunks) + data + script + '</script></body></html>')


if __name__ == '__main__':
    output = Path(sys.argv[1])
    output.mkdir(parents=True, exist_ok=True)
    (output / 'fixture.html').write_text(fixture(), encoding='utf-8')

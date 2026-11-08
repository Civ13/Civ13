"""Offline checks for the live tactical map (no compiler, world or network).

Checks the wiring a round relies on and runs the map page's client script in
Node with a stub canvas: clicks must land on the tile they show, and the
script must draw positions and markers without throwing. native_probe.py is
the headless DreamDaemon evidence for the server side.
"""
import json
from pathlib import Path
import re
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/modules/1713/tactical_map.dm'


def read(path):
    return (ROOT / path).read_text(encoding='utf-8-sig')


def client_script():
    text = SOURCE.read_text(encoding='utf-8-sig')
    start = text.index('return @{"') + len('return @{"')
    return text[start:text.index('"}', start)]


STUB = r'''
var clicks=[],fills=0,texts=[];
function ctx(){return {fillRect:function(){fills++;},drawImage:function(){},beginPath:function(){},moveTo:function(){},
 lineTo:function(){},stroke:function(){},arc:function(){},fill:function(){},fillText:function(t){texts.push(t);}};}
var canvases={};
var document={createElement:function(){return {getContext:ctx};},
 getElementById:function(id){if(!canvases[id])canvases[id]={width:0,height:0,getContext:ctx,innerHTML:'',
  getBoundingClientRect:function(){return {left:0,top:0};}};return canvases[id];},
 getElementsByTagName:function(){return [];}};
var window={};Object.defineProperty(window,'location',{set:function(v){clicks.push(v);}});
'''


class TacticalMapTests(unittest.TestCase):
    def test_wiring(self):
        dme = read('civ13.dme')
        self.assertIn('#include "code\\modules\\1713\\tactical_map.dm"', dme)
        jobs = read('code/game/jobs/job_controller.dm')
        self.assertRegex(jobs, r'H\.original_job = job\s+H\.original_job_title = H\.original_job\.title\s+H\.make_tactical_map_user\(\)')
        text = SOURCE.read_text(encoding='utf-8-sig')
        self.assertIn('CM-SS13', text)
        self.assertIn('AGPL-3.0', text)
        # Drawing is officers and commanders only; every marker change checks it.
        for proc in ('add_marker', 'erase_marker', 'clear_markers'):
            body = text[text.index(f'/datum/tactical_map_controller/proc/{proc}('):]
            body = body[:body.index('\n/')]
            self.assertIn('tactical_map_can_draw(H)', body, proc)
        # Positions come only from the viewer's own side.
        blips = text[text.index('/proc/blips_for('):]
        self.assertIn('tactical_map_side(H) != side', blips[:blips.index('\n/')])

    def test_script_has_no_interpolation(self):
        script = client_script()
        self.assertNotIn('"}', script)
        self.assertGreater(len(script), 500)

    @unittest.skipUnless(shutil.which('node'), 'node not installed')
    def test_script_draws_and_clicks_map_tiles(self):
        cell, cols, rows, k = 2, 50, 40, 8
        terrain = ''.join('gwfb'[(x + y) % 4] for y in range(rows) for x in range(cols))
        data = {'b': [[11, 21, 'y', ''], [30, 40, 's', '2'], [5, 5, 'd', '']],
                'm': [[20, 20, 'attack', 'Officer'], [60, 30, 'rally', 'Officer']]}
        prelude = ('var REF="[0x21000001]",CELL=%d,W=%d,H=%d,K=%d,DRAW=1,T=%s,COL={"0":"#000","g":"#0f0"},'
                   'KINDS={"attack":["A","#f00"],"rally":["R","#0f0"]},D=%s;') % (cell, cols, rows, k, json.dumps(terrain), json.dumps(data))
        tiles = [(1, 1), (11, 21), (99, 79), (50, 40)]
        probe = ['function tile(tx,ty){var x=(tx-0.5)/CELL*K,y=(H-(ty-0.5)/CELL)*K;cv.onclick({clientX:x,clientY:y});}']
        probe += ['tile(%d,%d);' % t for t in tiles]
        probe += ['tool("erase");tile(20,20);',
                  'upd(JSON.stringify({b:[],m:[]}));upd("not json");',
                  'console.log(JSON.stringify({clicks:clicks,fills:fills,texts:texts,status:canvases.s.innerHTML}));']
        out = subprocess.run(['node', '-e', STUB + prelude + client_script() + '\n'.join(probe)],
                             capture_output=True, text=True, timeout=60)
        self.assertEqual(out.returncode, 0, out.stderr)
        result = json.loads(out.stdout.strip().splitlines()[-1])
        self.assertGreaterEqual(result['fills'], cols * rows)
        self.assertIn('A', result['texts'])
        self.assertIn('2', result['texts'])
        self.assertEqual(result['status'], '0 on this level, 0 markers.')
        for (tx, ty), href in zip(tiles, result['clicks']):
            query = dict(part.split('=') for part in href.split('?', 1)[1].split('&'))
            self.assertEqual(query['tm'], 'mark')
            self.assertEqual(query['k'], 'attack')
            self.assertLessEqual(abs(int(query['x']) - tx), 1, href)
            self.assertLessEqual(abs(int(query['y']) - ty), 1, href)
        self.assertIn('tm=erase&x=20&y=20', result['clicks'][-1])


if __name__ == '__main__':
    unittest.main()

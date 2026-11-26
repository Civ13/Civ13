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
import sys
from types import SimpleNamespace as NS
import unittest
from urllib.parse import parse_qs

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/modules/1713/tactical_map.dm'
sys.path.insert(0, str(ROOT / 'tests/save_movement'))
from source_adapter import extract, project


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
  getBoundingClientRect:function(){return {left:23,top:37,right:23+this.width*0.75,bottom:37+this.height*0.8};}};return canvases[id];},
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

    def test_all_marker_actions_are_scoped_to_the_rendered_page(self):
        text = SOURCE.read_text()
        dispatch = '/datum/tactical_map_controller/proc/dispatch_marker_action'
        raw = extract(text, dispatch)
        # DM switch case dispatch is represented by equivalent Python conditions;
        # all checks and helper invocations otherwise come from the source body.
        raw = re.sub(r'^\tswitch \(params\["tm"\]\)\n((?:\t\t.*\n)*)',
                     lambda m: re.sub(r'^\t\tif \("([^"]+)"\)', r'\tif (params["tm"] == "\1")',
                                      m[1], flags=re.M).replace('\t\t\treturn', '\t\treturn'), raw, flags=re.M)
        actor = object()
        faction = 'faction:One|2'
        state = NS(current=faction, recorded=faction)
        viewers = {actor: faction}
        calls = []
        def sink(action):
            return lambda *args: calls.append((action, *args)) or True
        gateway = project(dispatch + '(H, params)\n' + raw, dispatch, 'H, params',
                          dict(istext=lambda v: isinstance(v, str), viewers=viewers,
                               view_key=lambda _h: state.current, add_marker=sink('mark'),
                               erase_marker=sink('erase'), clear_markers=sink('clear')))
        for action in ('mark', 'erase', 'clear'):
            with self.subTest(action=action):
                args = {'tm': action, 'v': faction, 'x': '5', 'y': '8', 'k': 'rally'}
                for current, recorded in (('faction:One|3', faction), ('faction:Two|2', faction),
                                          (faction, 'faction:One|3'), (None, None)):
                    state.current = current
                    viewers[actor] = recorded
                    self.assertFalse(gateway(actor, args))
                    self.assertFalse(calls)
                state.current = viewers[actor] = faction
                self.assertFalse(gateway(actor, dict(args, v=None)))
                self.assertTrue(gateway(actor, args))
                self.assertEqual(calls.pop()[0], action)
        topic = text[text.index('/datum/tactical_map_controller/Topic('):text.index(dispatch)]
        self.assertIn('dispatch_marker_action(H, href_list)', topic)
        push = extract(text, '/datum/tactical_map_controller/proc/push')
        self.assertIn('view_key(H) == key', push)
        opened = extract(text, '/datum/tactical_map_controller/proc/open')
        self.assertIn('view_key(H) != key', opened.split('terrain_for(T.z)', 1)[1])
        self.assertIn('findlasttext(key, "|")', text)
        self.assertIn('json_encode(url_encode(key))', text)

    def test_same_level_ally_uses_resolved_transport_turf(self):
        text = SOURCE.read_text()
        blips = extract(text, '/datum/tactical_map_controller/proc/blips_for')
        self.assertNotIn('H.z', blips)
        self.assertRegex(blips, r'var/turf/T = get_turf\(H\)\n\t\tif \(!T \|\| T.z != z\)')
        self.assertIn('list(T.x, T.y, kind, label)', blips)
        self.assertIn('H.stat == DEAD', blips)
        self.assertIn('tactical_map_side(H) != side', blips)

    @unittest.skipUnless(shutil.which('node'), 'node not installed')
    def test_script_draws_and_clicks_map_tiles(self):
        cell, cols, rows, k = 2, 50, 40, 8
        terrain = ''.join('gwfb'[(x + y) % 4] for y in range(rows) for x in range(cols))
        data = {'b': [[11, 21, 'y', ''], [30, 40, 's', '2'], [5, 5, 'd', '']],
                'm': [[20, 20, 'attack', 'Officer'], [60, 30, 'rally', 'Officer']]}
        prelude = ('var REF="[0x21000001]",VIEW="faction%%3AOne%%7C2",MAXX=99,MAXY=79,'
                   'CELL=%d,W=%d,H=%d,K=%d,DRAW=1,T=%s,COL={"0":"#000","g":"#0f0"},'
                   'KINDS={"attack":["A","#f00"],"rally":["R","#0f0"]},D=%s;'
                   'var canvas=document.getElementById("m");canvas.width=W*K;canvas.height=H*K;'
                   ) % (cell, cols, rows, k, json.dumps(terrain), json.dumps(data))
        points = [(1, 1, 0.25), (11, 21, 0.25), (11, 21, 0.75),
                  (99, 79, 0.75), (50, 40, 0.25)]
        probe = ['function click(x,y){var r=cv.getBoundingClientRect();'
                 'cv.onclick({clientX:r.left+x*(r.right-r.left)/W,clientY:r.top+y*(r.bottom-r.top)/H});}'
                 'function tile(tx,ty,f){click((tx-1+f)/CELL,H-(ty-1+f)/CELL);}']
        probe += ['tile(%d,%d,%g);' % t for t in points]
        probe += ['tile(100,20,0.5);tile(20,80,0.5);click(-0.1,3);click(3,-0.1);click(W,3);click(3,H);',
                  'tool("erase");tile(20,20,0.25);tile(100,20,0.5);tile(20,80,0.5);',
                  'go("tm=clear");DRAW=0;tile(20,20,0.25);',
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
        queries = [parse_qs(href.split('?', 1)[1]) for href in result['clicks']]
        self.assertEqual(len(queries), len(points) + 2)
        for (tx, ty, _), query in zip(points, queries):
            self.assertEqual((query['tm'], query['k'], query['x'], query['y']),
                             (['mark'], ['attack'], [str(tx)], [str(ty)]), query)
        self.assertEqual((queries[-2]['tm'], queries[-2]['x'], queries[-2]['y']), (['erase'], ['20'], ['20']))
        self.assertEqual(queries[-1]['tm'], ['clear'])
        self.assertTrue(all(q['v'] == ['faction:One|2'] for q in queries))


if __name__ == '__main__':
    unittest.main()

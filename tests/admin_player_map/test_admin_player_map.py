"""Offline checks for the admin player map (no compiler, world or network).

Checks the wiring and staff guards, then runs the page's client script in Node
with a stub canvas and DOM: markers draw, a click picks the nearest marker,
the panel buttons send jump/follow/PP/VV links, the level picker sends the
chosen level, and names are only ever set as text. native_probe.py is the
headless DreamDaemon evidence for the server side.
"""
import json
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/modules/admin/verbs/player_map.dm'


def read(path):
    return (ROOT / path).read_text(encoding='utf-8-sig')


def client_script():
    text = SOURCE.read_text(encoding='utf-8-sig')
    start = text.index('return @{"') + len('return @{"')
    return text[start:text.index('"}', start)]


STUB = r'''
var clicks=[],fills=0,html=0;
function ctx(){return {fillRect:function(){fills++;},drawImage:function(){},beginPath:function(){},moveTo:function(){},
 lineTo:function(){},stroke:function(){},arc:function(){},fill:function(){},fillText:function(){}};}
function node(tag){var n={tag:tag,children:[],style:{},className:'',checked:false,value:'',textContent:'',
 appendChild:function(c){this.children.push(c);return c;},removeChild:function(c){this.children.splice(this.children.indexOf(c),1);},
 getContext:ctx,getBoundingClientRect:function(){return {left:0,top:0};}};
 Object.defineProperty(n,'firstChild',{get:function(){return n.children[0]||null;}});
 Object.defineProperty(n,'innerHTML',{set:function(){html++;}});return n;}
var nodes={};
var document={createElement:function(t){return node(t);},createTextNode:function(t){var n=node('#text');n.textContent=t;return n;},
 getElementById:function(id){if(!nodes[id])nodes[id]=node(id);return nodes[id];}};
var window={};Object.defineProperty(window,'location',{set:function(v){clicks.push(v);}});
function text(n){var s=n.textContent||'';for(var i=0;i<n.children.length;i++)s+=text(n.children[i]);return s;}
'''


class AdminPlayerMapTests(unittest.TestCase):
    def test_wiring_and_guards(self):
        dme = read('civ13.dme')
        self.assertIn('#include "code\\modules\\admin\\verbs\\player_map.dm"', dme)
        verbs = read('code/modules/admin/admin_verbs.dm')
        for name in ('admin_verbs_admin', 'admin_verbs_mod', 'admin_verbs_trialadmin'):
            start = verbs.index(f'var/list/{name} = list(')
            body = verbs[start:verbs.index('\n)', start)]
            self.assertIn('/client/proc/admin_player_map,', body, name)
        start = verbs.index('var/list/admin_verbs_mentor = list(')
        self.assertNotIn('admin_player_map', verbs[start:verbs.index('\n)', start)])
        text = SOURCE.read_text(encoding='utf-8-sig')
        # The verb, the page and every Topic action check staff rights.
        verb = text[text.index('/client/proc/admin_player_map()'):]
        self.assertIn('check_rights(R_ADMIN|R_MOD)', verb[:verb.index('\n/')])
        topic = text[text.index('/datum/admin_player_map_controller/Topic('):]
        topic = topic[:topic.index('\n/')]
        self.assertLess(topic.index('admin_player_map_allowed(C)'), topic.index('switch (href_list["apm"])'))
        opened = text[text.index('/datum/admin_player_map_controller/proc/open('):]
        self.assertIn('admin_player_map_allowed(C)', opened[:opened.index('\n/')])
        # Jumping and following respect the server's admin jump switch.
        for proc in ('jump_to', 'follow'):
            body = text[text.index(f'/datum/admin_player_map_controller/proc/{proc}('):]
            self.assertIn('config.allow_admin_jump', body[:body.index('\n/')], proc)
        # Data embedded in the page cannot close the script block.
        self.assertIn('replacetext(', text[text.index('/proc/admin_player_map_json('):])
        # Reuses the tactical map's terrain instead of sampling its own.
        self.assertIn('tactical_maps.terrain_for(z)', text)

    def test_script_has_no_interpolation_or_html_names(self):
        script = client_script()
        self.assertNotIn('"}', script)
        self.assertNotIn('innerHTML', script)
        self.assertGreater(len(script), 1000)

    @unittest.skipUnless(shutil.which('node'), 'node not installed')
    def test_script_picks_markers_and_sends_actions(self):
        cell, cols, rows, k = 2, 50, 40, 8
        terrain = ''.join('gwfb'[(x + y) % 4] for y in range(rows) for x in range(cols))
        data = {'b': [[11, 21, 'a', 'Red', 'Ann', 'ann', '[0x3000001]'],
                      [60, 40, 's', 'Blue', '<b>Bob</b>', 'bob', '[0x3000002]'],
                      [30, 30, 'x', 'Red', 'Cid', 'cid', '[0x3000003]'],
                      [80, 70, 'g', '', 'ghost', 'gus', '[0x3000004]'],
                      [5, 5, 'n', '', 'Npc', '', '[0x3000005]']],
                'c': [3, 1]}
        prelude = ('var REF="[0x21000001]",Z=1,CELL=%d,W=%d,H=%d,K=%d,T=%s,COL={"0":"#000","g":"#0f0"},'
                   'LV=["Gaia","Gaia caves"],D=%s;') % (cell, cols, rows, k, json.dumps(terrain), json.dumps(data))
        probe = [
            'function tile(tx,ty){var x=(tx-0.5)/CELL*K,y=(H-(ty-0.5)/CELL)*K;cv.onclick({clientX:x+3,clientY:y-2});}',
            'var out={};',
            'out.listAll=nodes.list.children.length;',
            'tile(11,21);out.sel=SEL;out.panel=text(nodes.sel);',
            'var bs=nodes.sel.children.filter(function(c){return c.tag=="button";});',
            'for(var i=0;i<bs.length;i++)bs[i].onclick();',
            'tile(80,70);out.ghostHidden=SEL;',
            'nodes.og.checked=true;draw();tile(80,70);out.ghost=SEL;out.listGhosts=nodes.list.children.length;',
            'nodes.list.children[0].onclick();out.listPick=SEL;',
            'lvl(2);',
            'out.levels=nodes.z.children.map(function(o){return o.textContent;});',
            'upd(JSON.stringify({b:[],c:[0,0]}));upd("not json");out.panelGone=text(nodes.sel);',
            'out.status=nodes.s.textContent;out.legend=text(nodes.legend);',
            'out.clicks=clicks;out.fills=fills;out.html=html;out.bob=JSON.stringify(nodes.list.children.length);',
            'console.log(JSON.stringify(out));',
        ]
        out = subprocess.run(['node', '-e', STUB + prelude + client_script() + '\n'.join(probe)],
                             capture_output=True, text=True, timeout=60)
        self.assertEqual(out.returncode, 0, out.stderr)
        result = json.loads(out.stdout.strip().splitlines()[-1])
        self.assertGreaterEqual(result['fills'], cols * rows)
        self.assertEqual(result['html'], 0)
        self.assertEqual(result['listAll'], 3)  # ghosts and NPCs hidden by default
        self.assertEqual(result['sel'], '[0x3000001]')
        self.assertIn('Ann (ann)', result['panel'])
        self.assertIn('Red, alive at 11, 21', result['panel'])
        self.assertIsNone(result['ghostHidden'])
        self.assertEqual(result['ghost'], '[0x3000004]')
        self.assertEqual(result['listGhosts'], 4)
        self.assertEqual(result['listPick'], '[0x3000002]')  # '<b>Bob</b>' sorts first, as text
        clicks = result['clicks']
        self.assertIn('byond://?src=[0x21000001]&apm=jump&m=%5B0x3000001%5D', clicks)
        self.assertIn('byond://?src=[0x21000001]&apm=follow&m=%5B0x3000001%5D', clicks)
        self.assertIn('byond://?_src_=holder&adminplayeropts=%5B0x3000001%5D', clicks)
        self.assertIn('byond://?_src_=vars&Vars=%5B0x3000001%5D', clicks)
        self.assertEqual(clicks[-1], 'byond://?src=[0x21000001]&apm=z&z=2')
        self.assertEqual(result['levels'], ['1: Gaia (3 players)', '2: Gaia caves (1 player)'])
        self.assertIn('not on this level', result['panelGone'])
        self.assertEqual(result['status'], '0 players on this level, 0 markers shown.')


if __name__ == '__main__':
    unittest.main()

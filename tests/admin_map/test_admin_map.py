"""Offline checks for the admin map (no compiler, world or network).

The admin map is the former Player Map and Weather Map in one window. This
checks the wiring and the three staff guards (open it, see who players are,
change the weather), then runs the page's client script in Node with a stub
canvas and DOM: markers and storms draw, a click picks the nearest marker,
else a storm's core, else a spot; the panel buttons send the jump/follow/view/
PP/VV and weather links; layers hide what they should; a viewer who may not
see names gets no player list or picking; and names are only ever set as
text. native_probe.py is the headless DreamDaemon evidence for the server side.
"""
import json
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/modules/admin/verbs/admin_map.dm'


def read(path):
    return (ROOT / path).read_text(encoding='utf-8-sig')


def body(text, header):
    start = text.index(header)
    end = text.find('\n/', start)
    return text[start:end if end >= 0 else len(text)]


def client_script():
    text = SOURCE.read_text(encoding='utf-8-sig')
    start = text.index('return @{"') + len('return @{"')
    return text[start:text.index('"}', start)]


STUB = r'''
var clicks=[],fills=0,ovals=0,html=0,labels=[];
function ctx(){return {fillRect:function(){fills++;},drawImage:function(){},beginPath:function(){},moveTo:function(){},
 lineTo:function(){},stroke:function(){},arc:function(){},fill:function(){},fillText:function(t){labels.push(String(t));},closePath:function(){},setLineDash:function(){},
 save:function(){},restore:function(){},translate:function(){},scale:function(){ovals++;}};}
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
function press(id){var bs=nodes[id].children.filter(function(c){return c.tag=="button";});for(var i=0;i<bs.length;i++)bs[i].onclick();return bs.length;}
document.getElementById('lp').checked=true;document.getElementById('lw').checked=true;document.getElementById('lg').checked=true;
'''

CELL, COLS, ROWS, K = 2, 50, 40, 8
TERRAIN = ''.join('gwfb'[(x + y) % 4] for y in range(ROWS) for x in range(COLS))
AIR = [2, 2, 50, [12.5, -3, 20, 31], [40, 90, 55, 10], [1013, 990, 1020, 1030], [0, 100, 30, 5]]


def page_data(who=1, edit=1):
    blips = [[11, 21, 'a', 'Red', 'Ann', 'ann', '[0x3000001]'],
             [60, 40, 's', 'Blue', '<b>Bob</b>', 'bob', '[0x3000002]'],
             [30, 30, 'x', 'Red', 'Cid', 'cid', '[0x3000003]'],
             [80, 70, 'g', '', 'ghost', 'gus', '[0x3000004]'],
             [5, 5, 'n', '', 'Npc', '', '[0x3000005]']]
    if not who:
        blips = [[11, 21, 'p', '', '', '', ''], [60, 40, 'p', '', '', '', '']]
    return {'b': blips, 'c': [3, 1],
            's': [[7, 'storm', 0, 62, 42, 12, 8, 80, 1, 0, 9], [8, 'heat', 0, 20, 70, 10, 10, 40, 0, -1, 4]],
            'w': [1, 0, 1, 'a light breeze from the west'], 'zone': 'none', 'season': 'SUMMER', 'cap': 3,
            'a': AIR, 'pc': [[1, 'low', 40, 30, 60, 12.5], [2, 'high', 80, 60, 50, 8]], 'who': who, 'edit': edit}


def run(data, probe, pick='null'):
    prelude = ('var REF="[0x21000001]",Z=1,CELL=%d,W=%d,H=%d,K=%d,PICK=%s,T=%s,COL={"0":"#000","g":"#0f0"},'
               'LV=["Gaia","Gaia caves"],D=%s;') % (CELL, COLS, ROWS, K, pick, json.dumps(TERRAIN), json.dumps(data))
    helper = 'function tile(tx,ty){var x=(tx-0.5)/CELL*K,y=(H-(ty-0.5)/CELL)*K;cv.onclick({clientX:x,clientY:y});}var out={};'
    out = subprocess.run(['node', '-e', STUB + prelude + client_script() + helper + '\n'.join(probe)
                          + 'out.clicks=clicks;out.html=html;console.log(JSON.stringify(out));'],
                         capture_output=True, text=True, timeout=60)
    if out.returncode:
        raise AssertionError(out.stderr)
    return json.loads(out.stdout.strip().splitlines()[-1])


class AdminMapTests(unittest.TestCase):
    def test_wiring_and_guards(self):
        dme = read('civ13.dme')
        self.assertIn('#include "code\\modules\\admin\\verbs\\admin_map.dm"', dme)
        for old in ('player_map.dm', 'weather_map.dm'):
            self.assertNotIn(old, dme)
            self.assertFalse((ROOT / 'code/modules/admin/verbs' / old).exists(), old)
        verbs = read('code/modules/admin/admin_verbs.dm')
        for name in ('admin_verbs_admin', 'admin_verbs_mod', 'admin_verbs_trialadmin'):
            start = verbs.index(f'var/list/{name} = list(')
            self.assertIn('/client/proc/admin_map,', verbs[start:verbs.index('\n)', start)], name)
        start = verbs.index('var/list/admin_verbs_mentor = list(')
        self.assertNotIn('admin_map', verbs[start:verbs.index('\n)', start)])
        for old in ('admin_player_map', 'admin_weather_map'):
            self.assertNotIn(old, verbs)
        text = SOURCE.read_text(encoding='utf-8-sig')
        self.assertIn('C.holder.rights & (R_ADMIN|R_MOD|R_DEBUG)', body(text, '/proc/admin_map_allowed('))
        self.assertIn('C.holder.rights & (R_ADMIN|R_MOD))', body(text, '/proc/admin_map_sees_players('))
        self.assertIn('C.holder.rights & (R_ADMIN|R_DEBUG))', body(text, '/proc/admin_map_changes_weather('))
        self.assertIn('check_rights(R_ADMIN|R_MOD|R_DEBUG)', body(text, '/client/proc/admin_map()'))
        self.assertIn('admin_map_allowed(C)', body(text, '/datum/admin_map_controller/proc/open('))
        # Every Topic action is behind the guard for its kind.
        topic = body(text, '/datum/admin_map_controller/Topic(')
        allowed = topic.index('if (!admin_map_allowed(C))')
        players = topic.index('if (!admin_map_sees_players(C))')
        changes = topic.index('if (!admin_map_changes_weather(C))')
        self.assertLess(allowed, topic.index('open(C, href_list["z"])'))
        for call in ('jump_to(C, M)', 'follow(C, M)', 'admin_start_player_view(M)', 'open(C, T.z, "\\ref[M]")'):
            self.assertLess(players, topic.index(call), call)
            self.assertLess(topic.index(call), changes, call)
        for call in ('send_weather(C,', 'end_weather(C,', 'clear_weather(C)'):
            self.assertLess(changes, topic.index(call), call)
        # Viewers who may not see names get positions only.
        update = body(text, '/datum/admin_map_controller/proc/update_json(')
        self.assertIn('blips_for(z, C, named)', update)
        unnamed = body(text, '/datum/admin_map_controller/proc/blips_for(')
        unnamed = unnamed[unnamed.index('if (!named)'):unnamed.index('return blips')]
        self.assertIn('list(T.x, T.y, "p", "", "", "", "")', unnamed)
        self.assertNotIn('ckey', unnamed)
        self.assertNotIn('\\ref', unnamed)
        # Jumping and following respect the server's admin jump switch.
        for proc in ('jump_to', 'follow'):
            self.assertIn('config.allow_admin_jump', body(text, f'/datum/admin_map_controller/proc/{proc}('), proc)
        # Weather changes are logged.
        for proc in ('send_weather', 'end_weather', 'clear_weather'):
            self.assertIn('log_admin(', body(text, f'/datum/admin_map_controller/proc/{proc}('), proc)
        # Data embedded in the page cannot close the script block.
        self.assertIn('replacetext(', body(text, '/proc/admin_map_json('))
        # Reuses the tactical map's terrain instead of sampling its own.
        self.assertIn('tactical_maps.terrain_for(z)', text)
        # The player panel links to it.
        self.assertIn("am=show;m=\\ref[M]", read('code/modules/admin/player_panel_pages.dm'))

    def test_script_has_no_interpolation_or_html_names(self):
        script = client_script()
        self.assertNotIn('"}', script)
        self.assertNotIn('innerHTML', script)
        self.assertGreater(len(script), 2000)

    @unittest.skipUnless(shutil.which('node'), 'node not installed')
    def test_players_pick_and_act(self):
        result = run(page_data(), [
            'out.listAll=nodes.list.children.length;',
            'tile(11,21);out.sel=SEL;out.panel=text(nodes.sel);press("sel");',
            'tile(80,70);out.ghostHidden=SEL;out.spot=AT;',
            'nodes.og.checked=true;draw();tile(80,70);out.ghost=SEL;out.listGhosts=nodes.list.children.length;',
            'nodes.list.children[0].onclick();out.listPick=SEL;out.bobPanel=text(nodes.sel);',
            'nodes.q.value="ann";nodes.q.onkeyup();out.searched=nodes.list.children.map(text);nodes.q.value="";',
            'nodes.lp.checked=false;draw();out.hiddenList=nodes.list.children.length;out.hiddenPanel=text(nodes.sel);tile(11,21);out.hiddenPick=SEL;nodes.lp.checked=true;',
            'lvl(2);',
            'out.levels=nodes.z.children.map(function(o){return o.textContent;});',
            'out.fills=fills;',
            'pick("[0x3000001]");upd(JSON.stringify({b:[],c:[0,0],s:[],w:[0,0,1,""],zone:"none",season:"none",cap:1,who:1,edit:0}));upd("not json");out.panelGone=text(nodes.sel);',
            'out.status=nodes.s.textContent;out.sky=text(nodes.wl);',
        ])
        self.assertGreaterEqual(result['fills'], COLS * ROWS)
        self.assertEqual(result['html'], 0)
        self.assertEqual(result['listAll'], 3)  # ghosts and NPCs hidden by default
        self.assertEqual(result['sel'], '[0x3000001]')
        self.assertIn('Ann (ann)', result['panel'])
        self.assertIn('Red, alive at 11, 21', result['panel'])
        self.assertIn('Weather here: clear sky', result['panel'])
        self.assertIn('Air here: 12.5 C, 40% humidity, 1013 hPa, 0% cloud', result['panel'])
        self.assertIsNone(result['ghostHidden'])
        self.assertEqual(result['spot'], [80, 70])  # open ground picks a spot instead
        self.assertEqual(result['ghost'], '[0x3000004]')
        self.assertEqual(result['listGhosts'], 4)
        self.assertEqual(result['listPick'], '[0x3000002]')  # '<b>Bob</b>' sorts first, as text
        self.assertIn('Weather here: under #7 storm (80%)', result['bobPanel'])
        self.assertEqual(result['searched'], ['Ann (ann) - alive'])
        self.assertEqual(result['hiddenList'], 0)
        self.assertIn('layer is hidden', result['hiddenPanel'])
        self.assertIsNone(result['hiddenPick'])
        clicks = result['clicks']
        self.assertIn('byond://?src=[0x21000001]&am=jump&m=%5B0x3000001%5D', clicks)
        self.assertIn('byond://?src=[0x21000001]&am=follow&m=%5B0x3000001%5D', clicks)
        self.assertIn('byond://?src=[0x21000001]&am=view&m=%5B0x3000001%5D', clicks)
        self.assertIn('byond://?_src_=holder&adminplayeropts=%5B0x3000001%5D', clicks)
        self.assertIn('byond://?_src_=vars&Vars=%5B0x3000001%5D', clicks)
        self.assertEqual(clicks[-1], 'byond://?src=[0x21000001]&am=z&z=2')
        self.assertEqual(result['levels'], ['1: Gaia (3 players)', '2: Gaia caves (1 player)'])
        self.assertIn('not on this level', result['panelGone'])
        self.assertEqual(result['status'], '0 players on this level, 0 markers shown.')
        self.assertIn('The sky is clear.', result['sky'])

    @unittest.skipUnless(shutil.which('node'), 'node not installed')
    def test_weather_pick_send_and_end(self):
        result = run(page_data(), [
            'out.systems=nodes.wl.children.map(text);out.heading=nodes.wh.textContent;out.ovals=ovals;out.labels=labels.slice();out.skyText=text(nodes.sky);',
            'tile(64,43);out.sys=SYS;out.sysPanel=text(nodes.sel);press("sel");',
            'tile(90,10);out.at=AT;out.sysAfter=SYS;out.spotPanel=text(nodes.sel);out.sent=press("sel");',
            'nodes.wl.children[1].onclick();out.listSys=SYS;out.heatPanel=text(nodes.sel);',
            'press("sky");',
            'var before=ovals;nodes.lw.checked=false;draw();out.drawnHidden=ovals-before;tile(64,43);out.hiddenSys=SYS;out.hiddenAt=AT;nodes.lw.checked=true;',
            'var f0=fills;LAY="t";draw();out.airFills=fills-f0;f0=fills;LAY="";draw();out.plainFills=fills-f0;out.legend=text(nodes.legend);',
        ])
        self.assertEqual(result['heading'], 'Weather systems (2)')
        self.assertEqual(result['systems'], ['#7 storm at 62, 42 - 80%, 9 min', '#8 heat wave at 20, 70 - 40%, 4 min'])
        self.assertGreater(result['ovals'], 0)
        for label in ('#7', 'L', 'H', '-12.5 hPa', '+8 hPa'):
            self.assertIn(label, result['labels'])
        self.assertIn('Pressure centres: 2', result['skyText'])
        self.assertEqual(result['sys'], 7)
        self.assertIn('#7 storm', result['sysPanel'])
        self.assertIn('1 player under it on this level: <b>Bob</b>', result['sysPanel'])
        self.assertEqual(result['at'], [90, 10])
        self.assertIsNone(result['sysAfter'])
        self.assertIn('Weather here: clear sky', result['spotPanel'])
        self.assertIn('Air here: -3 C, 90% humidity, 990 hPa, 100% cloud', result['spotPanel'])
        self.assertEqual(result['sent'], 3)
        self.assertEqual(result['listSys'], 8)
        self.assertIn('Nobody is under it', result['heatPanel'])
        self.assertEqual(result['drawnHidden'], 0)
        self.assertIsNone(result['hiddenSys'])  # a hidden storm cannot be picked
        self.assertEqual(result['hiddenAt'], [64, 43])
        self.assertEqual(result['airFills'] - result['plainFills'], 4)  # one fill per air cell
        clicks = result['clicks']
        self.assertEqual(clicks[0], 'byond://?src=[0x21000001]&am=end&id=7')
        self.assertEqual(clicks[1:4], ['byond://?src=[0x21000001]&am=spawn&k=storm&x=90&y=10',
                                       'byond://?src=[0x21000001]&am=spawn&k=severe&x=90&y=10',
                                       'byond://?src=[0x21000001]&am=spawn&k=heat&x=90&y=10'])
        self.assertEqual(clicks[4], 'byond://?src=[0x21000001]&am=clear')
        self.assertEqual(result['html'], 0)

    @unittest.skipUnless(shutil.which('node'), 'node not installed')
    def test_unnamed_viewer_and_read_only_weather(self):
        result = run(page_data(who=0, edit=0), [
            'out.listHidden=nodes.pc.style.display;out.list=nodes.list.children.length;',
            'tile(11,21);out.sel=SEL;out.at=AT;out.buttons=press("sel");',
            'tile(64,43);out.sys=SYS;out.sysPanel=text(nodes.sel);out.sysButtons=press("sel");out.skyButtons=press("sky");',
            'out.status=nodes.s.textContent;',
        ])
        self.assertEqual(result['listHidden'], 'none')
        self.assertEqual(result['list'], 0)
        self.assertIsNone(result['sel'])  # dots cannot be picked
        self.assertEqual(result['at'], [11, 21])
        self.assertEqual(result['buttons'], 0)  # no weather buttons without the right
        self.assertEqual(result['sys'], 7)
        self.assertIn('1 player under it on this level', result['sysPanel'])
        self.assertNotIn('under it on this level:', result['sysPanel'])  # no names
        self.assertEqual(result['sysButtons'], 0)
        self.assertEqual(result['skyButtons'], 0)
        self.assertEqual(result['status'], '2 players on this level, 2 markers shown.')
        self.assertEqual(result['clicks'], [])

    @unittest.skipUnless(shutil.which('node'), 'node not installed')
    def test_opens_with_a_player_picked(self):
        result = run(page_data(), ['out.sel=SEL;out.panel=text(nodes.sel);'], pick='"[0x3000003]"')
        self.assertEqual(result['sel'], '[0x3000003]')
        self.assertIn('Cid (cid)', result['panel'])
        self.assertIn('Red, dead at 30, 30', result['panel'])


if __name__ == '__main__':
    unittest.main()

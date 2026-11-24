"""Offline checks for the admin player panel (no compiler, world or network).

Checks the wiring, what each rank may see and that player text is escaped,
then runs the list's client script in Node with a stub DOM: the search box and
the state chips hide rows, and a column header sorts them both ways.
native_probe.py is the headless DreamDaemon evidence for the pages themselves.
"""
import json
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/modules/admin/player_panel_pages.dm'


def read(path):
    return (ROOT / path).read_text(encoding='utf-8-sig')


def body(text, header):
    start = text.index(header)
    end = text.find('\n/', start)
    return text[start:end if end >= 0 else len(text)]


def client_script():
    text = body(SOURCE.read_text(encoding='utf-8-sig'), '/proc/admin_player_list_script()')
    start = text.index('return @{"') + len('return @{"')
    return text[start:text.index('"}', start)]


STUB = r'''
function node(attrs,cells){var n={attrs:attrs||{},style:{},className:'',value:'',textContent:'',children:[],
 getAttribute:function(k){return k in this.attrs?this.attrs[k]:null;},
 appendChild:function(c){var i=this.children.indexOf(c);if(i>=0)this.children.splice(i,1);this.children.push(c);return c;},
 focus:function(){}};
 if(cells)for(var i=0;i<cells.length;i++){var c=node(cells[i][1]?{'data-v':cells[i][1]}:{});c.textContent=cells[i][0];n.children.push(c);}
 Object.defineProperty(n,'innerHTML',{set:function(){html++;}});return n;}
var html=0,nodes={q:node(),n:node(),rows:node(),chips:node()};
var document={getElementById:function(id){return nodes[id];}};
'''


class AdminPlayerPanelTests(unittest.TestCase):
    def test_wiring(self):
        self.assertIn('#include "code\\modules\\admin\\player_panel_pages.dm"', read('civ13.dme'))
        verbs = read('code/modules/admin/admin_verbs.dm')
        self.assertIn('/client/proc/player_panel,', verbs)
        self.assertNotIn('player_panel_new,', verbs)  # one list, one verb
        self.assertIn('holder.player_panel_new()', body(verbs, '/client/proc/player_panel()'))
        topic = read('code/modules/admin/topic.dm')
        # Every link goes through the holder's Topic, which checks the caller first.
        self.assertLess(topic.index('usr.client != owner || !check_rights(0)'), topic.index('href_list["player_list"]'))
        self.assertLess(topic.index('usr.client != owner || !check_rights(0)'), topic.index('href_list["adminplayeropts"]'))
        text = SOURCE.read_text(encoding='utf-8-sig')
        self.assertEqual(text.count('/datum/admins/proc/show_player_panel('), 1)
        self.assertNotIn('show_player_panel(', read('code/modules/admin/admin.dm'))

    def test_kick_requires_moderation_rights_and_same_target_after_prompt(self):
        topic = read('code/modules/admin/topic.dm')
        kick = topic.split('else if (href_list["boot2"])', 1)[1].split('else if (href_list["mute"])', 1)[0]
        before, after = kick.split('sanitize(input(usr, "Please enter reason"))', 1)
        for stage in (before, after):
            self.assertIn('check_rights(R_MOD | R_ADMIN)', stage)
            self.assertIn('check_if_greater_rights_than(kick_target)', stage)
            self.assertIn('kick_target.mob != M', stage)
        self.assertIn('var/client/kick_target = M.client', before)
        for condition in ('owner != kick_actor', 'kick_actor.holder != src', 'M.client != kick_target'):
            self.assertLess(after.index(condition), after.index('qdel(kick_target)'))
        panel = body(read('code/modules/admin/player_panel_pages.dm'), '/datum/admins/proc/player_options_html(')
        self.assertRegex(panel, r'if \(rights & \(R_MOD \| R_ADMIN\)\)\n\t\tbody \+= .*boot2=')

    def test_ban_button_opens_the_existing_staff_dialog_for_the_visible_account(self):
        panel = body(SOURCE.read_text(encoding='utf-8-sig'), '/datum/admins/proc/player_options_html(')
        link = panel.index('panel_ban=')
        for term in ('<h2>Moderation</h2>', 'if (has_quickBan_rights())', 'quickBan_panel_account(M)', 'if (ban_account)'):
            self.assertLess(panel.index(term), link)
        self.assertIn('ban_account=[html_encode(ban_account)]', panel)
        topic = read('code/modules/admin/topic.dm')
        action = topic.split('else if (href_list["panel_ban"])', 1)[1].split('else if (href_list["boot2"])', 1)[0]
        self.assertLess(topic.index('usr.client != owner || !check_rights(0)'), topic.index('href_list["panel_ban"]'))
        self.assertIn('locate(href_list["panel_ban"])', action)
        self.assertIn('usr.client.quickBan_from_panel(target, href_list["ban_account"])', action)
        self.assertNotIn('quickBan_ban(', action)
        ban = read('code/modules/admin/verbs/quickBan.dm')
        rights = body(ban, '/datum/admins/proc/has_quickBan_rights()')
        self.assertIn('rights & (R_MOD | R_TRIALADMIN)', rights)
        actor = body(ban, '/client/proc/quickBan_actor_current(')
        self.assertIn('holder == acting_holder && acting_holder.owner == src && acting_holder.has_quickBan_rights()', actor)
        account = body(ban, '/proc/quickBan_panel_account(')
        for term in ('QDELETED(target)', '!target.ckey', 'target.client.mob != target',
                     'target.client.ckey != target.ckey', 'return target.ckey'):
            self.assertIn(term, account)
        start = body(ban, '/client/proc/quickBan_from_panel(')
        self.assertLess(start.index('quickBan_actor_current(acting_holder)'), start.index('quickBan_details('))
        self.assertLess(start.index('account != expected_account'), start.index('quickBan_details('))
        self.assertIn('quickBan_details(list("ckey" = account), acting_holder, selection)', start)
        self.assertNotIn('lastKnown', account + start)
        self.assertNotIn('find_ip(', start)
        manual = body(ban, '/client/proc/quickBan_person(')
        self.assertIn('list("Client", "Manual Input", "Cancel")', manual)
        self.assertIn('quickBan_details(fields, acting_holder, null)', manual)

    def test_ban_confirmation_rechecks_rights_account_body_connection_and_protected_role(self):
        source = read('code/modules/admin/verbs/quickBan.dm')
        gate = body(source, '/client/proc/quickBan_dialog_current(')
        self.assertIn('!quickBan_actor_current(acting_holder)', gate)
        self.assertIn('selection && !quickBan_panel_selection_current(selection)', gate)
        target = body(source, '/proc/quickBan_panel_selection_current(')
        for term in ('return target &&', 'quickBan_panel_account(target) == selection["account"]',
                     '(!!target.client) == selection["connected"]', 'target.client == selection["client"]'):
            self.assertIn(term, target)
        dialog = body(source, '/client/proc/quickBan_details(')
        before, after = dialog.split('"Confirm ban", "Ban", "Cancel") != "Ban"')
        for term in ('in ban_types', 'What job?', 'What faction?', 'How long do you want the ban', 'Provide a reason'):
            self.assertIn(term, before)
        self.assertEqual(before.count('if (quickBan_protected_target(fields))'), 1)
        self.assertNotIn('quickBan_ban(', before)
        self.assertRegex(after, r"return\s+if \(!quickBan_dialog_current\(acting_holder, selection\) \|\| quickBan_protected_target\(fields\)\)\s+return")
        self.assertLess(after.index('quickBan_protected_target(fields)'), after.index('quickBan_ban(fields, src)'))
        protection = body(source, '/client/proc/quickBan_protected_target(')
        self.assertIn('admin_datums[target_account]', protection)
        self.assertIn('trying_to_quickBan_admin(target_account, fields["cID"], fields["ip"])', protection)

    def test_ranks_and_escaping(self):
        text = SOURCE.read_text(encoding='utf-8-sig')
        listing = body(text, '/datum/admins/proc/player_list_html(')
        self.assertIn('var/staff = rights & (R_ADMIN|R_MOD)', listing)
        for staff_only in ('M.lastKnownIP', '_src_=vars', 'notes=show'):
            line = next(row for row in listing.splitlines() if staff_only in row)
            position = listing.index(line)
            guard = max(listing.rfind('if (staff)', 0, position), listing.rfind('(staff &&', 0, position + len(line)))
            self.assertGreater(guard, 0, staff_only)
        self.assertLess(listing.index('if (staff)'), listing.index('shared_records.summary(M.ckey)'))
        panel = body(text, '/datum/admins/proc/player_options_html(')
        self.assertIn('if (karma_key && (rights & R_ADMIN))', panel)
        # Text a player chose never reaches a page unescaped.
        for source in (listing, panel):
            for raw in ('[M.name]', '[M.real_name]', '[M.key]'):
                for row in source.splitlines():
                    if raw in row and 'html_encode(' not in row and '!=' not in row:
                        self.fail(row.strip())

    def test_profile_link_uses_raw_account_key_and_escapes_the_path(self):
        text = SOURCE.read_text(encoding='utf-8-sig')
        panel = body(text, '/datum/admins/proc/player_options_html(')
        self.assertRegex(panel, r"admin_byond_profile_url\(M\.key\)\n\tif \(profile\)\n\t\tbody \+= .*href='\[html_encode\(profile\)\]'")
        self.assertIn("rel='noopener noreferrer'>BYOND Profile</a>", panel)
        self.assertNotIn('admin_byond_profile_url(', body(text, '/datum/admins/proc/player_list_html('))
        helper = body(text, '/proc/admin_byond_profile_url(')
        self.assertIn('!istext(account_key) || !ckey(account_key)', helper)
        self.assertIn('regex(@"^Guest-W?[0-9]+$", "i")', helper)
        self.assertIn('copytext(account_key, 1, 2) == "@"', helper)
        self.assertIn('replacetext(url_encode(account_key), "+", "%20")', helper)
        self.assertIn('https://www.byond.com/members/[path_key]?format=text', helper)
        self.assertNotIn('world.Export', helper + panel)

    def test_staff_form_link_and_action_share_existing_eligibility(self):
        topic = read('code/modules/admin/topic.dm')
        action = topic.split('else if (href_list["grant_staff_form"])', 1)[1].split('else if (href_list["simplemake"])', 1)[0]
        self.assertLess(topic.index('usr.client != owner || !check_rights(0)'), topic.index('href_list["grant_staff_form"]'))
        grant_call = action.index('H.heteromorph_grant(K, null, usr.ckey)')
        for guard in ('!check_rights(R_ADMIN) || !check_rights(R_SPAWN)', '!ishuman(H)',
                      'QDELETED(H)', '!H.client', 'H.client.mob != H', '|| H.heteromorph_id',
                      'heteromorph_kind("dragonoid")'):
            self.assertLess(action.index(guard), grant_call)
        self.assertNotIn('change_mob_type(', action)
        self.assertNotIn('href_list["species"]', action)
        panel = body(SOURCE.read_text(encoding='utf-8-sig'), '/datum/admins/proc/player_options_html(')
        match = panel.index('grant_staff_form=1')
        for guard in ('if (M.client && !isnewplayer(M))', '(rights & R_ADMIN) && (rights & R_SPAWN) && ishuman(M)',
                      '!H.heteromorph_id && !H.heteromorph_grant_problem(heteromorph_kind("dragonoid"))'):
            self.assertLess(panel.index(guard), match)
        forms = read('code/modules/divine/heteromorph.dm')
        grant = body(forms, '/mob/living/human/proc/heteromorph_grant(')
        self.assertLess(grant.index('heteromorph_grant_problem(K)'), grant.index('heteromorph_id = K.id'))
        eligibility = body(forms, '/mob/living/human/proc/heteromorph_grant_problem(')
        for guard in ('stat == DEAD', 'K.staff_only && !heteromorph_staff_run()', 'K.origin != heteromorph_world_origin()'):
            self.assertIn(guard, eligibility)
        self.assertIn('heteromorph_log(', grant)

    def test_script_has_no_interpolation_or_html_writes(self):
        script = client_script()
        self.assertNotIn('innerHTML', script)
        self.assertNotIn('[', script.replace('r[i]', '').replace('c[i]', '').replace('a[i]', '').replace('children[c]', '').replace('children[i]', '').replace('a=[]', ''))
        self.assertGreater(len(script), 500)

    @unittest.skipUnless(shutil.which('node'), 'node not installed')
    def test_script_filters_and_sorts(self):
        people = [('alive', 'ann red farmer', 'Ann', 1), ('dead dc flag', 'bob blue smith', 'Bob', 3),
                  ('ghost', 'cid', 'Cid', 4), ('alive flag', 'dee red hunter', 'Dee', 1)]
        setup = ['var P=%s;' % json.dumps(people),
                 'for(var i=0;i<P.length;i++)nodes.rows.children.push(node({"data-s":P[i][0],"data-q":P[i][1]},[["",String(P[i][3])],[P[i][2]]]));',
                 'var F0=["all","alive","dead","ghost","dc","flag"];for(i=0;i<F0.length;i++)nodes.chips.children.push(node({"data-f":F0[i]}));']
        probe = [
            'function shown(){return nodes.rows.children.filter(function(r){return r.style.display!="none";}).map(function(r){return r.children[1].textContent;});}',
            'var out={};out.start=shown();out.count=nodes.n.textContent;',
            'chip("alive");out.alive=shown();out.on=nodes.chips.children.filter(function(c){return c.className=="chip on";}).length;',
            'chip("flag");out.flag=shown();chip("dc");out.dc=shown();',
            'chip("all");nodes.q.value="RED";nodes.q.onkeyup();out.red=shown();out.redCount=nodes.n.textContent;',
            'chip("flag");out.redFlag=shown();nodes.q.value="";chip("all");',
            'sortBy(1);sortBy(1);out.desc=shown();sortBy(0);out.byState=shown();sortBy(1);out.asc=shown();',
            'out.html=html;console.log(JSON.stringify(out));',
        ]
        out = subprocess.run(['node', '-e', STUB + '\n'.join(setup) + client_script() + '\n'.join(probe)],
                             capture_output=True, text=True, timeout=60)
        self.assertEqual(out.returncode, 0, out.stderr)
        result = json.loads(out.stdout.strip().splitlines()[-1])
        self.assertEqual(result['start'], ['Ann', 'Bob', 'Cid', 'Dee'])
        self.assertEqual(result['count'], '4 shown')
        self.assertEqual(result['alive'], ['Ann', 'Dee'])
        self.assertEqual(result['on'], 1)
        self.assertEqual(result['flag'], ['Bob', 'Dee'])
        self.assertEqual(result['dc'], ['Bob'])
        self.assertEqual(result['red'], ['Ann', 'Dee'])
        self.assertEqual(result['redCount'], '2 shown')
        self.assertEqual(result['redFlag'], ['Dee'])
        self.assertEqual(result['desc'], ['Dee', 'Cid', 'Bob', 'Ann'])
        self.assertEqual(result['byState'][-2:], ['Bob', 'Cid'])
        self.assertEqual(result['asc'], ['Ann', 'Bob', 'Cid', 'Dee'])
        self.assertEqual(result['html'], 0)


if __name__ == '__main__':
    unittest.main()

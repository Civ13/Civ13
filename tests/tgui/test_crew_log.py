"""Crew Log source projections and authorization contracts; no DM execution."""
from pathlib import Path
import re
import unittest

ROOT=Path(__file__).resolve().parents[2]
SOURCE=(ROOT/'code/game/objects/map_metadata/voyage.dm').read_text(errors='replace')
BOOK=SOURCE.split('/obj/structure/voyage/boatswain_book\n',1)[1].split('/datum/topic_state/crew_log\n',1)[0]
ROLE=BOOK.split('\tproc/can_read_crew_log(',1)[1].split('\tui_interact(',1)[0]
OPEN=BOOK.split('\tui_interact(',1)[1].split('\tproc/crew_log_data()',1)[0]
DATA=BOOK.split('\tproc/crew_log_data()',1)[1]
STATE=SOURCE.split('/datum/topic_state/crew_log/can_use_topic',1)[1].split('/obj/structure/voyage/quartermaster_book',1)[0]

def permitted(original_job_title, title='', human=True):
    match=re.search(r'^\t\treturn (.+)$',ROLE,re.M)
    assert match is not None, 'Role return expression missing'
    expression=match.group(1)
    expression=expression.replace('H.original_job_title','original_job_title').replace('H.title','title').replace('||','or')
    return human and eval(expression,{'__builtins__':{},'FALSE':False,'TRUE':True},dict(original_job_title=original_job_title,title=title))

class CrewLogContract(unittest.TestCase):
    def test_exact_original_three_role_alternatives_and_deputy_title_field(self):
        self.assertIn('if (!ishuman(user))',ROLE)
        self.assertTrue(permitted('Pirate Boatswain'))
        self.assertTrue(permitted('Pirate Captain'))
        self.assertTrue(permitted('Carpenter','Deputy Boatswain'))
        for job,title in [('Pirate Quartermaster',''),('Pirate',''),('Deputy Boatswain',''),('Pirate Deputy Boatswain',''),('Doctor','Captain')]:
            self.assertFalse(permitted(job,title),(job,title))
        self.assertFalse(permitted('Pirate Captain',human=False))

    def test_role_client_and_physical_admission_precede_roster_collection(self):
        for marker in ('!can_read_crew_log(user) || !user.client','default_state.can_use_topic(src, user) != STATUS_INTERACTIVE','var/list/data = crew_log_data()'):
            self.assertIn(marker,OPEN)
        self.assertLess(OPEN.index('!can_read_crew_log(user)'),OPEN.index('var/list/data = crew_log_data()'))
        self.assertLess(OPEN.index('default_state.can_use_topic'),OPEN.index('var/list/data = crew_log_data()'))

    def test_projected_roster_retains_non_dead_world_humans_npcs_and_non_pirate_jobs(self):
        self.assertIn('for(var/mob/living/human/HM in world)',DATA)
        condition=re.search(r'if \((HM\.stat .+)\)',DATA).group(1).replace('HM.stat','stat')
        pirate,sailor=re.search(r'if \(t_title == "([^"]+)"\)\n\s+t_title = "([^"]+)"',DATA).groups()
        strip,replacement=re.search(r'replacetext\(HM\.original_job_title,"([^"]*)","([^"]*)"\)',DATA).groups()
        dead=object()
        rows=[
            dict(kind='human',stat=0,name='Masked',real_name='SECRET',job='Pirate',client=None),
            dict(kind='human',stat=1,name='Unconscious captain',job='Pirate Captain',client=True),
            dict(kind='human',stat=dead,name='Dead human',job='Pirate',client=True),
            dict(kind='human',stat=0,name='Non-pirate doctor',job='Doctor',client=True),
            dict(kind='human',stat=0,name='NPC carpenter',job='Pirate Carpenter',client=None),
            dict(kind='observer',stat=0,name='Observer',job='Pirate',client=True),
        ]
        # Model only the source's literal roster/title rules, not native world iteration.
        result=[]
        for row in rows:
            if row['kind']=='human' and eval(condition,{'__builtins__':{}},dict(stat=row['stat'],DEAD=dead)):
                job=sailor if row['job']==pirate else row['job'].replace(strip,replacement)
                result.append((row['name'],job))
        self.assertEqual(result,[('Masked','Sailor'),('Unconscious captain','Captain'),('Non-pirate doctor','Doctor'),('NPC carpenter','Carpenter')])
        self.assertNotIn('.client',DATA)
        self.assertNotRegex(DATA,r'get_area|map\.|civilization|sort\(')

    def test_only_escaped_display_names_and_job_text_are_transmitted(self):
        self.assertIn('"name" = html_encode(HM.name)',DATA)
        self.assertIn('"job" = html_encode("[t_title]")',DATA)
        self.assertNotIn('real_name',DATA)
        self.assertIn('return list("crew" = entries)',DATA)

    def test_window_state_rejects_wrong_body_book_logout_and_role_revocation(self):
        guard=re.search(r'if \((.+)\)\n\t\treturn STATUS_CLOSE',STATE).group(1)
        expression=guard.replace('!book.can_read_crew_log(user)','not role_allowed').replace('!user.client','not connected').replace('!book','not book').replace('!user','not user').replace('||','or')
        def allowed(book,source,user,reader,connected=True,role_allowed=True):
            return not eval(expression,{'__builtins__':{}},dict(book=book,src_object=source,user=user,reader=reader,connected=connected,role_allowed=role_allowed))
        book,owner,other=object(),object(),object()
        self.assertTrue(allowed(book,book,owner,owner))
        self.assertFalse(allowed(None,None,owner,owner))
        self.assertFalse(allowed(book,other,owner,owner))
        self.assertFalse(allowed(book,book,None,None))
        self.assertFalse(allowed(book,book,other,owner))
        self.assertFalse(allowed(book,book,owner,owner,connected=False))
        self.assertFalse(allowed(book,book,owner,owner,role_allowed=False))
        self.assertIn('return STATUS_UPDATE',STATE)
        self.assertNotIn('STATUS_INTERACTIVE',STATE)
        self.assertNotIn('get_dist',STATE)

    def test_no_polling_and_close_side_noninterference(self):
        for marker in ('if (ui)\n\t\t\tui.push_data(null, TRUE)\n\t\t\treturn','ui.use_on_close_logic(FALSE)','ui.open()','new(src, user)'):
            self.assertIn(marker,OPEN)
        self.assertLess(OPEN.index('ui.push_data(null, TRUE)'),OPEN.index('var/list/data = crew_log_data()'))
        self.assertLess(OPEN.index('ui.use_on_close_logic(FALSE)'),OPEN.index('ui.open()'))
        self.assertNotIn('set_auto_update',BOOK)
        self.assertNotIn('spawn(',BOOK)
        self.assertNotIn('set_using_object',BOOK)
        self.assertNotIn('unset_using_object',BOOK)

    def test_both_protocols_refuse_domain_actions_and_checks_follow_dependencies(self):
        transport=(ROOT/'code/modules/nano/tgui.dm').read_text()
        self.assertIn('/datum/nanoui/tgui/Topic',transport)
        self.assertNotIn('crew_log.tmpl',transport.split('/datum/nanoui/tgui/Topic',1)[0])
        legacy=(ROOT/'code/modules/nano/_nanoui.dm').read_text()
        self.assertIn('/datum/nanoui/Topic',legacy)
        legacy=legacy.split('/datum/nanoui/Topic',1)[1]
        for marker in ('status != STATUS_INTERACTIVE','src_object.Topic'):
            self.assertIn(marker,legacy)
        self.assertLess(legacy.index('status != STATUS_INTERACTIVE'),legacy.index('src_object.Topic'))
        template=(ROOT/'UI/templates/crew_log.tmpl').read_text()
        self.assertNotIn('href=',template)
        self.assertNotIn('<input',template)
        workflow=(ROOT/'.github/workflows/tgui.yml').read_text()
        self.assertIn("'code/game/objects/map_metadata/voyage.dm'",workflow)
        self.assertIn("'UI/js/libraries/doT.js'",workflow)

if __name__=='__main__':unittest.main()

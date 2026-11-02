"""Complete helper-body projection; fake file/regex/ckey boundaries, no native engine."""
from pathlib import Path
from types import SimpleNamespace
import importlib.util
import json
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("access_source_adapter", ROOT / "tests/save_movement/source_adapter.py")
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)
adapter.FIELDS += ("approved_list", "approved_list_ready", "whitelist_list", "whitelist_list_ready")
SOURCE = (ROOT / "code/_helpers/access_lists.dm").read_text(encoding='utf-8-sig')
# Lexical DM raw regex literals map to Python raw literals; no statements omitted.
PROJECTED_SOURCE = SOURCE.replace('regex(@"', 'regex(r"')

class DMList(list):
    @property
    def len(self): return len(self)
    def __getitem__(self, index): return super().__getitem__(index - 1)
    def __iadd__(self, item): self.append(item); return self

class Regex:
    def __init__(self, pattern): self.pattern = pattern
    def Find(self, text): return bool(isinstance(text, str) and re.fullmatch(self.pattern, text))

class Harness:
    def __init__(self):
        self.files = {}
        self.state = SimpleNamespace(approved_list=DMList(), whitelist_list=DMList(),
                                     approved_list_ready=False, whitelist_list_ready=False)
        self.env = dict(istext=lambda s:isinstance(s,str), length=len, list=DMList,
            replacetext=lambda s,a,b:s.replace(a,b), findtext=lambda s,t:s.find(t)+1,
            copytext=lambda s,start:s[start-1:], splittext=lambda s,d:DMList(s.split(d)),
            regex=Regex, ckey=lambda s:re.sub('[^a-z0-9]', '', s.lower()), trim=lambda s:s.strip(),
            isnull=lambda x:x is None, fexists=lambda p:p in self.files, file2text=self.read)
        self.parse = adapter.project(PROJECTED_SOURCE, '/proc/parse_verified_access_text', 'access_text', self.env)
        self.env['parse_verified_access_text'] = self.parse
        self.reload = adapter.project(PROJECTED_SOURCE, '/proc/reload_verified_access_list', 'src,access_kind', self.env, method=True)
        self.member = adapter.project(PROJECTED_SOURCE, '/proc/verified_access_member', 'src,access_kind,candidate_key', self.env, method=True)
    def read(self,path):
        value=self.files[path]
        if isinstance(value,Exception): raise value
        return value
    def load(self, kind, text):
        self.files['SQL/'+kind+'.txt']=text
        return self.reload(self.state,kind)

class AccessLists(unittest.TestCase):
    def setUp(self): self.h=Harness()
    def test_producer_vectors_and_explicit_legacy_extensions(self):
        vectors=json.loads((Path(__file__).parent/'producer-vectors.json').read_text(encoding='utf-8-sig'))['vectors']
        self.assertEqual(len(vectors),16)
        extensions={'crlf','trailing_space','embedded_space'}
        for vector in vectors:
            with self.subTest(vector['name']):
                accepted=self.h.parse(vector['bytes']) is not None
                self.assertEqual(accepted,vector['producer_accept'] or vector['name'] in extensions)
    def test_canonical_legacy_key(self):
        self.assertEqual(self.h.parse('  Fake_ Alpha\t= 990000000000000001\t\r\n'),['fakealpha'])
    def test_replacement_revokes_without_stale_append(self):
        self.assertTrue(self.h.load('approved','old=990000000000000001\n'))
        old=self.h.state.approved_list
        self.assertTrue(self.h.load('approved','new=990000000000000002\n'))
        self.assertIsNot(old,self.h.state.approved_list)
        self.assertFalse(self.h.member(self.h.state,'approved','old'))
        self.assertTrue(self.h.member(self.h.state,'approved','new'))
    def test_failure_preserves_known_good_identity_and_readiness(self):
        for kind in ('approved','whitelist'):
            self.assertTrue(self.h.load(kind,'old=990000000000000001\n'))
            previous=getattr(self.h.state,kind+'_list')
            for invalid in ('',None,'new=990000000000000002\nbad\n',OSError('unreadable')):
                with self.subTest(kind=kind,invalid=repr(invalid)):
                    self.assertFalse(self.h.load(kind,invalid))
                    self.assertIs(getattr(self.h.state,kind+'_list'),previous)
                    self.assertTrue(getattr(self.h.state,kind+'_list_ready'))
            del self.h.files['SQL/'+kind+'.txt']
            self.assertFalse(self.h.reload(self.h.state,kind))
            self.assertIs(getattr(self.h.state,kind+'_list'),previous)
    def test_initial_unavailable_and_ready_empty_distinct(self):
        for kind in ('approved','whitelist'):
            self.assertFalse(self.h.reload(self.h.state,kind))
            self.assertFalse(getattr(self.h.state,kind+'_list_ready'))
            self.assertFalse(self.h.member(self.h.state,kind,'old'))
            for invalid in ('',None,'bad\n'):
                self.assertFalse(self.h.load(kind,invalid))
                self.assertFalse(getattr(self.h.state,kind+'_list_ready'))
            self.assertTrue(self.h.load(kind,'old=990000000000000001\n'))
            self.assertTrue(self.h.load(kind,'\n'))
            self.assertTrue(getattr(self.h.state,kind+'_list_ready'))
            self.assertEqual(getattr(self.h.state,kind+'_list'),[])
            self.assertFalse(self.h.member(self.h.state,kind,'old'))
            self.assertFalse(self.h.load(kind,''))
            self.assertTrue(getattr(self.h.state,kind+'_list_ready'))
    def test_duplicate_canonical_keys_and_ids_reject_whole_file(self):
        for text in ('Fake_Alpha=990000000000000001\nfake alpha=990000000000000002\n',
                     'alpha=990000000000000001\nbeta=990000000000000001\n'):
            self.assertIsNone(self.h.parse(text))
    def test_ids_remain_lexical_and_distinct(self):
        self.assertEqual(self.h.parse('alpha=99999999999999999999\nbeta=99999999999999999998\n'),['alpha','beta'])
    def test_bad_keys_controls_and_empty_framing(self):
        for key in ('_','a'*257,'faké','alpha!','alpha\x00'):
            self.assertIsNone(self.h.parse(key+'=990000000000000001\n'))
        self.assertIsNotNone(self.h.parse('a'*256+'=990000000000000001\n'))
        for text in ('\r\n',' \n','\n\n','alpha=990000000000000001\r','alpha=990000000000000001\n\n'):
            self.assertIsNone(self.h.parse(text))
    def test_independent_targets_and_unknown_target(self):
        self.h.load('approved','alpha=990000000000000001\n')
        self.h.load('whitelist','beta=990000000000000002\n')
        self.assertEqual(self.h.state.approved_list,['alpha'])
        self.assertEqual(self.h.state.whitelist_list,['beta'])
        self.assertFalse(self.h.reload(self.h.state,'../approved'))
        self.assertFalse(self.h.member(self.h.state,'bad','alpha'))
    def test_startup_and_admin_use_same_transactional_loader(self):
        setup=(ROOT/'code/setup.dm').read_text(encoding='utf-8-sig')
        admin=adapter.extract((ROOT/'code/modules/admin/admin.dm').read_text(encoding='utf-8-sig'),'/client/proc/reload_admins')
        for source in (setup,admin):
            self.assertIn('reload_verified_access_list("approved")',source)
            self.assertIn('reload_verified_access_list("whitelist")',source)
            self.assertNotIn('approved_list +=',source)
            self.assertNotIn('whitelist_list +=',source)
        self.assertLess(admin.index('check_rights(R_SERVER)'),admin.index('reload_verified_access_list'))
        self.assertIn('load_admins(1)',admin)
    def test_gate_wiring_preserves_config_and_population_exception(self):
        source=(ROOT/'code/game/mob/new_player/new_player.dm').read_text(encoding='utf-8-sig')
        self.assertIn('if (config.useapprovedlist)\n\t\t\tif (!approved_list_ready)',source)
        self.assertIn('if (!verified_access_member("approved", client.ckey))',source)
        self.assertIn('if (actual_job.whitelisted && config.use_job_whitelist && clients.len > 12)',source)
        self.assertIn('if (!verified_access_member("whitelist", client.ckey))',source)
        self.assertNotIn('!isemptylist(approved_list)',source)
        self.assertNotIn('!isemptylist(whitelist_list)',source)
    def test_regex_literals_are_noninterpolating(self):
        # Ordinary DM quoted strings interpret square brackets as expressions.
        self.assertEqual(SOURCE.count('= regex(@"'), 2)
        self.assertNotIn('= regex("', SOURCE)

    def test_include_and_initial_readiness(self):
        self.assertEqual((ROOT/'civ13.dme').read_text(encoding='utf-8-sig').count('#include "code\\_helpers\\access_lists.dm"'),1)
        world=(ROOT/'code/world.dm').read_text(encoding='utf-8-sig')
        self.assertIn('var/global/approved_list_ready = FALSE',world)
        self.assertIn('var/global/whitelist_list_ready = FALSE',world)

if __name__ == '__main__': unittest.main()

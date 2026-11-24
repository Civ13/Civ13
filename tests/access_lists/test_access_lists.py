"""Complete helper-body projection; fake file/regex/ckey boundaries, no native engine."""
from pathlib import Path
from types import SimpleNamespace
from tempfile import TemporaryDirectory
from unittest import mock
import importlib.util
import json
import re
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("access_source_adapter", ROOT / "tests/save_movement/source_adapter.py")
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)
adapter.FIELDS += ("approved_list", "approved_list_ready", "whitelist_list", "whitelist_list_ready", "approved_discord_ids")
SOURCE = (ROOT / "code/_helpers/access_lists.dm").read_text(encoding='utf-8-sig')
# Lexical DM raw regex literals map to Python raw literals; no statements omitted.
PROJECTED_SOURCE = SOURCE.replace('regex(@"', 'regex(r"').replace('\tcatch\n', '\tcatch(projected_read_error)\n')

class DMList(list):
    """DM list: 1-based indexes, plus associated values for text keys."""
    @property
    def len(self): return len(self)
    def __getitem__(self, index):
        if isinstance(index, str): return self.__dict__.setdefault('assoc', {}).get(index)
        return super().__getitem__(index - 1)
    def __setitem__(self, index, value):
        if not isinstance(index, str): return super().__setitem__(index - 1, value)
        if index not in self: self.append(index)
        self.__dict__.setdefault('assoc', {})[index] = value
    def __iadd__(self, item): self.append(item); return self

class Regex:
    def __init__(self, pattern): self.pattern = pattern
    def Find(self, text): return bool(isinstance(text, str) and re.fullmatch(self.pattern, text))

class Harness:
    def __init__(self):
        self.files = {}
        self.state = SimpleNamespace(approved_list=DMList(), whitelist_list=DMList(),
                                     approved_list_ready=False, whitelist_list_ready=False,
                                     approved_discord_ids=DMList())
        self.env = dict(ascii2text=chr, istext=lambda s:isinstance(s,str), length=len, list=DMList,
            replacetext=lambda s,a,b:s.replace(a,b), findtext=lambda s,t:s.find(t)+1,
            copytext=lambda s,start,end=0:s[start-1:(end-1 if end else None)], islist=lambda x:isinstance(x,list), splittext=lambda s,d:DMList(s.split(d)),
            regex=Regex, ckey=lambda s:re.sub('[^a-z0-9]', '', s.lower()), trim=lambda s:s.strip(),
            gateway_access_enabled=lambda:False, reload_gateway_verified_access=lambda:False,
            isnull=lambda x:x is None, fexists=lambda p:p in self.files, file2text=self.read)
        self.parse = adapter.project(PROJECTED_SOURCE, '/proc/parse_verified_access_text', 'access_text', self.env)
        self.env['parse_verified_access_text'] = self.parse
        self.ids = adapter.project(PROJECTED_SOURCE, '/proc/verified_access_discord_ids', 'access_text,staged_keys', self.env)
        self.env['verified_access_discord_ids'] = self.ids
        self.discord_id = adapter.project(PROJECTED_SOURCE, '/proc/verified_discord_id', 'src,candidate_key', self.env, method=True)
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
    def test_engine_safe_string_literals(self):
        # Ordinary DM quoted strings interpret square brackets as expressions.
        self.assertEqual(SOURCE.count('= regex(@"'), 2)
        self.assertNotIn('= regex("', SOURCE)
        self.assertNotIn(r'"\r"', SOURCE)
        self.assertNotIn(r'"\r\n"', SOURCE)
        self.assertIn('ascii2text(13)', SOURCE)

    def test_approved_list_keeps_discord_ids(self):
        self.assertIsNone(self.h.discord_id(self.h.state,'alpha'))
        self.assertTrue(self.h.load('approved','Alpha=990000000000000001\r\nbeta = 990000000000000002\n'))
        self.assertEqual(self.h.discord_id(self.h.state,'alpha'),'990000000000000001')
        self.assertEqual(self.h.discord_id(self.h.state,'beta'),'990000000000000002')
        self.assertIsNone(self.h.discord_id(self.h.state,'gamma'))
        self.assertTrue(self.h.load('whitelist','gamma=990000000000000003\n'))
        self.assertIsNone(self.h.discord_id(self.h.state,'gamma'))
        self.assertTrue(self.h.load('approved','\n'))
        self.assertIsNone(self.h.discord_id(self.h.state,'alpha'))
    def test_discord_ids_need_every_staged_key(self):
        self.assertEqual(self.h.ids('alpha=990000000000000001\n',DMList(['alpha','beta'])),[])
        self.assertEqual(self.h.ids(None,DMList(['alpha'])),[])

    def test_running_world_rereads_changed_files(self):
        watch=adapter.extract(SOURCE,'/proc/watch_verified_access_lists')
        self.assertIn('set waitfor = FALSE',watch)
        self.assertIn('sleep(2 MINUTES)',watch)
        self.assertIn('access_text == loaded_text[access_kind]',watch)
        self.assertLess(watch.index('if (reload_verified_access_list(access_kind))'),watch.index('loaded_text[access_kind] = access_text'))
        reader=adapter.extract(SOURCE,'/proc/verified_access_file_text')
        self.assertIn('"SQL/approved.txt"',reader)
        self.assertIn('"SQL/whitelist.txt"',reader)
        self.assertIn('fexists(access_filename)',reader)
        setup=(ROOT/'code/setup.dm').read_text(encoding='utf-8-sig')
        self.assertLess(setup.index('reload_verified_access_list("whitelist")'),setup.index('watch_verified_access_lists()'))

    def test_include_and_initial_readiness(self):
        self.assertEqual((ROOT/'civ13.dme').read_text(encoding='utf-8-sig').count('#include "code\\_helpers\\access_lists.dm"'),1)
        world=(ROOT/'code/world.dm').read_text(encoding='utf-8-sig')
        self.assertIn('var/global/approved_list_ready = FALSE',world)
        self.assertIn('var/global/whitelist_list_ready = FALSE',world)

class GatewayReader(unittest.TestCase):
    def setUp(self):
        self.h = Harness()
        self.h.state.next_read = 0
        self.h.state.loaded_revision = 0
        self.h.state.loaded_text = None
        self.clock = SimpleNamespace(time=0)
        self.h.env.update(world=self.clock, shard_group=SimpleNamespace(group="sample"),
                          json_decode=lambda wire: self.as_list(json.loads(wire)),
                          isnum=lambda x: isinstance(x, (int, float)),
                          round=round, pack=lambda *args: self.as_list(dict(zip(args[::2], args[1::2]))))
        projected = PROJECTED_SOURCE.replace('return list("revision" = revision, "approved" = staged_approved, "ids" = staged_ids, "whitelist" = staged_whitelist)',
                                            'return pack("revision", revision, "approved", staged_approved, "ids", staged_ids, "whitelist", staged_whitelist)')
        projected = re.sub(r'^\tvar/static/(?:next_read|loaded_revision|loaded_text).*\n', '', projected, flags=re.M)
        projected = projected.replace('5 SECONDS', '50')
        adapter.FIELDS += ("next_read", "loaded_revision", "loaded_text")
        self.h.env['stage_gateway_verified_access'] = adapter.project(projected, '/proc/stage_gateway_verified_access',
                'access_text,group,loaded_revision,loaded_text', self.h.env)
        unavailable = adapter.project(projected, '/proc/gateway_access_unavailable', 'src', self.h.env, method=True)
        projected = projected.replace('gateway_access_unavailable()', 'gateway_access_unavailable(src)')
        self.h.env['gateway_access_unavailable'] = unavailable
        self.refresh = adapter.project(projected, '/proc/reload_gateway_verified_access', 'src,force=False', self.h.env, method=True)
        self.snapshot = '../front-door/SQL/verified-access.json'
        self.left = "alpha=990000000000000001\n"
        self.right = "beta=990000000000000002\n"

    @staticmethod
    def as_list(value):
        if not isinstance(value, dict):
            return value
        result = DMList()
        for key, entry in value.items():
            result[key] = entry
        return result

    def supply(self, revision, **changes):
        wire = json.dumps(dict({"schema": 1, "group": "sample", "revision": revision,
                                "approved": self.left, "whitelist": self.right}, **changes))
        self.h.files[self.snapshot] = wire
        return wire

    def test_wake_requires_valid_authority_pair_before_marking_ready(self):
        self.h.files['SQL/approved.txt'] = self.left
        self.h.files['SQL/whitelist.txt'] = self.right
        self.assertFalse(self.refresh(self.h.state, True))
        self.assertFalse(self.h.state.approved_list_ready or self.h.state.whitelist_list_ready)
        self.supply(1, whitelist='broken')
        self.assertFalse(self.refresh(self.h.state, True))
        self.assertFalse(self.h.state.approved_list or self.h.state.whitelist_list)
        self.supply(1)
        self.assertTrue(self.refresh(self.h.state, True))
        self.assertEqual(self.h.state.approved_discord_ids['alpha'], '990000000000000001')
        self.assertEqual(self.h.state.whitelist_list, ['beta'])

    def test_skipped_notification_recovers_and_lower_or_mutated_revision_fails_closed(self):
        original = self.supply(2)
        self.assertTrue(self.refresh(self.h.state))
        self.supply(1)
        self.clock.time += 50
        self.assertFalse(self.refresh(self.h.state))
        self.assertFalse(self.h.state.approved_list or self.h.state.whitelist_list)
        self.supply(2, approved=self.right)
        self.assertFalse(self.refresh(self.h.state, True))
        self.h.files[self.snapshot] = original
        self.assertTrue(self.refresh(self.h.state, True))
        self.supply(3, approved="\n", whitelist=self.left)
        self.clock.time += 100
        self.assertTrue(self.refresh(self.h.state))
        self.assertTrue(self.h.state.approved_list_ready and self.h.state.whitelist_list_ready)
        self.assertEqual(self.h.state.approved_list, [])
        self.assertEqual(self.h.state.whitelist_list, ['alpha'])

    def test_warm_wake_refreshes_during_existing_poll_window(self):
        self.supply(1)
        self.assertTrue(self.refresh(self.h.state))
        self.supply(2, approved="\n")
        self.assertTrue(self.refresh(self.h.state))
        self.assertEqual(self.h.state.approved_list, ['alpha'])
        self.assertTrue(self.refresh(self.h.state, True))
        self.assertEqual(self.h.state.approved_list, [])
        source = (ROOT / 'code/modules/client/client_procs.dm').read_text(encoding='utf-8-sig')
        connect = source.split('/client/New(TopicData)', 1)[1].split('/client/Del(', 1)[0]
        self.assertLess(connect.index('if(!nomads_lifecycle.admit_client())'),
                        connect.index('if (gateway_access_enabled())'))
        self.assertLess(connect.index('reload_gateway_verified_access(TRUE)'),
                        connect.index('. = ..()'))

    def test_wrong_group_bad_revision_and_read_exception_do_not_grant(self):
        for revision, fields in [(1, {"group": "other"}), (1.5, {}), (0, {}), (8000001, {}),
                                 (1, {"extra": True}), (1, {"whitelist": None})]:
            self.supply(revision, **fields)
            self.assertFalse(self.refresh(self.h.state, True))
        self.h.files[self.snapshot] = OSError('fixture')
        self.assertFalse(self.refresh(self.h.state, True))


class GatewayPublisher(unittest.TestCase):
    def setUp(self):
        spec = importlib.util.spec_from_file_location("gateway_admission", ROOT / "scripts/shard-group/verified_admission.py")
        self.authority = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.authority)
        fixture = TemporaryDirectory()
        self.addCleanup(fixture.cleanup)
        root = Path(fixture.name)
        self.folder = root / "front-door" / "SQL"
        self.folder.mkdir(parents=True)
        self.file = self.folder / "verified-access.json"
        self.group = {"root": str(root), "group": "sample", "gateway_verified_access": True,
                      "relay_port": 1764, "gate": "gate",
                      "regions": [{"id": "gate", "kind": "GATEWAY"}, {"id": "other", "kind": "SURFACE"}]}
        self.first = "alpha=990000000000000001\n"
        self.second = "beta=990000000000000002\n"

    def test_one_atomic_pair_and_noop_does_not_broadcast_revision(self):
        self.assertEqual(self.authority.publish(self.group, self.first, self.second), {"revision": 1, "changed": True})
        prior = self.file.read_bytes()
        self.assertEqual(self.authority.publish(self.group, self.first, self.second), {"revision": 1, "changed": False})
        self.assertEqual(self.file.read_bytes(), prior)
        self.assertEqual(self.authority.publish(self.group, self.second, "\n"), {"revision": 2, "changed": True})
        self.assertEqual(json.loads(self.file.read_bytes()), {"schema": 1, "group": "sample", "revision": 2,
                         "approved": self.second, "whitelist": "\n"})

    def test_invalid_second_half_or_replace_error_keeps_previous_pair(self):
        self.authority.publish(self.group, self.first, self.second)
        prior = self.file.read_bytes()
        for malformed in ("", "bad", self.first + self.first):
            with self.assertRaises(ValueError):
                self.authority.publish(self.group, self.second, malformed)
            self.assertEqual(self.file.read_bytes(), prior)
        with mock.patch.object(self.authority.os, "replace", side_effect=OSError("fixture")):
            with self.assertRaises(OSError):
                self.authority.publish(self.group, self.second, self.first)
        self.assertEqual(self.file.read_bytes(), prior)
        self.assertEqual(list(self.folder.glob(".verified-access-*")), [])

    def test_pipe_accepts_paired_content_only(self):
        with self.assertRaises(ValueError):
            self.authority.publish_input(self.group, b'{"approved":"discard","root":"untrusted"}')
        with self.assertRaises(ValueError):
            self.authority.publish_input(self.group, b'{"approved":"first","approved":"last","whitelist":"\\n"}')
        self.assertFalse(self.file.exists())
        value = json.dumps({"approved": self.first, "whitelist": self.second}).encode()
        self.assertEqual(self.authority.publish_input(self.group, value), {"revision": 1, "changed": True})

    def test_disabled_wrong_gate_and_corrupt_authority_refuse(self):
        for group in (dict(self.group, gateway_verified_access=False), dict(self.group, gate="other")):
            with self.assertRaises(ValueError):
                self.authority.publish(group, self.first, self.second)
            self.assertFalse(self.file.exists())
        self.file.write_text('{"schema": 1}', encoding="utf-8")
        with self.assertRaises(ValueError):
            self.authority.publish(self.group, self.first, self.second)
        self.assertEqual(self.file.read_text(encoding="utf-8"), '{"schema": 1}')

    def test_inbox_commits_only_complete_bound_tdm_and_persistence_proposals(self):
        for name in ("earth", "tdm"):
            root = self.folder.parent.parent / name
            inbox = root / "front-door" / "access-inbox"
            inbox.mkdir(parents=True)
            output = root / "front-door" / "SQL"
            output.mkdir()
            group = dict(self.group, group=name, root=str(root), gateway_verified_access_inbox=True)
            group["persistent"] = name == "earth"
            if not group["persistent"]:
                group["regions"] = [group["regions"][0], {"id": "barracks", "kind": "BARRACKS"},
                                    {"id": "battle", "kind": "BATTLE"}]
            path = inbox / "proposal.json"
            target = output / "verified-access.json"
            self.assertEqual(self.authority.publish(group, inbox=True), {"changed": False, "proposal": "absent"})
            self.assertFalse(target.exists())
            for invalid in ({"group": "other", "approved": self.first, "whitelist": self.second},
                            {"group": name, "approved": self.first},
                            {"group": name, "approved": self.first, "whitelist": "truncated"}):
                path.write_text(json.dumps(invalid), encoding="utf-8")
                with self.assertRaises(ValueError):
                    self.authority.publish(group, inbox=True)
                self.assertFalse(target.exists())
            good = {"group": name, "approved": self.first, "whitelist": self.second}
            path.write_text(json.dumps(good), encoding="utf-8")
            self.assertEqual(self.authority.publish(group, inbox=True), {"revision": 1, "changed": True})
            self.assertEqual(self.authority.publish(group, inbox=True), {"revision": 1, "changed": False})
            with self.assertRaises(ValueError):
                self.authority.publish(group, self.first, self.second)
            reader = GatewayReader("test_wake_requires_valid_authority_pair_before_marking_ready")
            reader.setUp()
            reader.h.env["shard_group"].group = name
            reader.h.files[reader.snapshot] = target.read_text(encoding="utf-8")
            self.assertTrue(reader.refresh(reader.h.state, True))
            self.assertEqual(reader.h.state.approved_list, ["alpha"])
            self.assertEqual(reader.h.state.whitelist_list, ["beta"])
            path.write_text(json.dumps(dict(good, approved="\n", whitelist="\n")), encoding="utf-8")
            self.assertEqual(self.authority.publish(group, inbox=True), {"revision": 2, "changed": True})
            reader.h.files[reader.snapshot] = target.read_text(encoding="utf-8")
            self.assertTrue(reader.refresh(reader.h.state, True))
            self.assertEqual(list(reader.h.state.approved_list), [])
            self.assertEqual(list(reader.h.state.whitelist_list), [])

    def test_inbox_supersession_preserves_authority_until_fresh_pair_commits(self):
        group = dict(self.group, gateway_verified_access_inbox=True)
        inbox = self.folder.parent / "access-inbox"
        inbox.mkdir()
        proposal = inbox / "proposal.json"
        first = dict(group="sample", approved=self.first, whitelist=self.second)
        proposal.write_text(json.dumps(first), encoding="utf-8")
        self.assertEqual(self.authority.publish(group, inbox=True)["revision"], 1)
        before = self.file.read_bytes()
        proposal.write_text(json.dumps(dict(first, approved=self.second)), encoding="utf-8")
        sync = self.authority.os.fsync

        def supersede(fd):
            sync(fd)
            proposal.write_text(json.dumps(dict(first, approved="\n")), encoding="utf-8")

        with mock.patch.object(self.authority.os, "fsync", side_effect=supersede):
            with self.assertRaisesRegex(ValueError, "superseded"):
                self.authority.publish(group, inbox=True)
        self.assertEqual(self.file.read_bytes(), before)
        self.assertEqual(list(self.folder.glob(".verified-access-*")), [])
        self.assertEqual(self.authority.publish(group, inbox=True)["revision"], 2)
        self.assertEqual(json.loads(self.file.read_bytes())["approved"], "\n")

    def test_real_host_cli_accepts_scoped_configs_for_both_game_modes(self):
        base = self.folder.parent.parent
        source = ROOT / "scripts/shard-group"
        repo = base / "fixture-repository"
        repo.mkdir()
        for name, stock, port in (("earth", "group.example.json", 6000), ("tdm", "tdm.example.json", 7000)):
            root = base / name
            inbox = root / "front-door" / "access-inbox"
            inbox.mkdir(parents=True)
            (root / "front-door" / "SQL").mkdir()
            config = json.loads((source / stock).read_text(encoding="utf-8"))
            config.update(group=name, root=str(root), repository=str(repo), live=False, public_host="localhost",
                          gate="gateway", gateway_verified_access=True, gateway_verified_access_inbox=True,
                          relay_port=port+40, relay_control_port=port+41, doorman_port=port+42)
            for offset, region in enumerate(config["regions"]):
                region.update(port=port+offset)
            config["regions"].append(dict(id="gateway", name="Gateway", kind="GATEWAY", port=port+20,
                                          map="maps/special/gateway.dmm"))
            cfg = base / (name + ".json")
            cfg.write_text(json.dumps(config), encoding="utf-8")

            def run(action, expected=0, payload=None):
                result = subprocess.run([sys.executable, str(source / "shard_group.py"), "--config", str(cfg), action],
                                        input=payload, capture_output=True, text=True, timeout=12, check=False)
                self.assertEqual(result.returncode, expected, (name, result.stdout, result.stderr))
                return json.loads(result.stdout)

            self.assertEqual(run("consume-verified-access")["proposal"], "absent")
            path = inbox / "proposal.json"
            pair = dict(approved=self.first, whitelist=self.second)
            wrong = "tdm" if name == "earth" else "earth"
            path.write_text(json.dumps(dict(pair, group=wrong)), encoding="utf-8")
            self.assertFalse(run("consume-verified-access", 1)["ok"])
            self.assertFalse((root / "front-door" / "SQL" / "verified-access.json").exists())
            path.write_text(json.dumps(dict(pair, group=name)), encoding="utf-8")
            self.assertEqual(run("consume-verified-access")["revision"], 1)
            self.assertFalse(run("consume-verified-access")["changed"])
            self.assertFalse(run("publish-verified-access", 1, json.dumps(pair))["ok"])
            self.assertEqual(config, json.loads(cfg.read_text(encoding="utf-8")))

    def test_running_consumer_never_falls_back_when_gateway_enabled(self):
        body = adapter.extract(SOURCE, '/proc/reload_verified_access_list')
        self.assertLess(body.index('if (gateway_access_enabled())'), body.index('access_filename = null'))
        consumer = adapter.extract(SOURCE, '/proc/reload_gateway_verified_access')
        self.assertIn('var/path = "../front-door/SQL/verified-access.json"', consumer)
        stage = adapter.extract(SOURCE, '/proc/stage_gateway_verified_access')
        self.assertIn('bundle["group"] != group', stage)
        self.assertIn('revision < loaded_revision', stage)
        self.assertIn('revision == loaded_revision && access_text != loaded_text', stage)
        self.assertLess(consumer.index('if (!islist(staged))'), consumer.index('approved_list = staged["approved"]'))
        unavailable = adapter.extract(SOURCE, '/proc/gateway_access_unavailable')
        for removal in ('approved_list = list()', 'whitelist_list = list()', 'approved_discord_ids = list()'):
            self.assertIn(removal, unavailable)
        watch = adapter.extract(SOURCE, '/proc/watch_verified_access_lists')
        self.assertIn('reload_gateway_verified_access()', watch)
        self.assertIn('sleep(5 SECONDS)', watch)


if __name__ == '__main__': unittest.main()

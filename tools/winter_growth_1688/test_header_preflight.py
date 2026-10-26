"""Synthetic text headers only. No historical writer bytes or native execution."""
import copy
import hashlib
import json
import os
from pathlib import Path
import tempfile
import unittest
from audit_offline import install
install()
from header_preflight import (LIMITS, validate_header_bytes, validate_saved_headers,
    validate_identity_init_source, validate_generator_source)


def fixture():
    metadata=b'NOMADS_PANGEA\n5000 B.C.\n0\n0\n0\n1\n0\n0\nNomads\n2026-10-26-(00-00-00)\n0\n0\n0\n0\n'
    marker='round-v1:'+('a'*32)
    state=dict(version=1,generation=marker,map='NOMADS_PANGEA',maxx=10,maxy=8,maxz=1,
        game_id='aB1-cD23',state=1,elapsed=0,roundstart_time=0,
        elevation=dict(version=1,maxx=10,maxy=8,maxz=1,default_metres=0,regions=[]),
        metadata=hashlib.md5(metadata).hexdigest())
    return {'round.json':json.dumps(state).encode(),'map.txt':metadata,'save_complete.txt':(marker+'\n').encode()}


def changed(**fields):
    h=fixture(); s=json.loads(h['round.json']); s.update(fields)
    h['round.json']=json.dumps(s).encode(); return h


class Headers(unittest.TestCase):
    def reject(self,h,pattern=None):
        with self.assertRaisesRegex(ValueError,pattern or '.'):
            validate_header_bytes(h)

    def test_valid_current_fixture(self):
        r=validate_header_bytes(fixture())
        self.assertEqual(r['status'],'header-prerequisites-passed')
        self.assertIn('native level validation remains required',r['scope'])
        self.assertEqual(set(r['headers']),set(LIMITS))
        for phase in (3,4): validate_header_bytes(changed(state=phase,elapsed=123,roundstart_time=42))

    def test_identity_regression_and_bounds(self):
        for v in (None,'',0,True,[],{},'a'*129): self.reject(changed(game_id=v),'identity')
        validate_header_bytes(changed(game_id='a'*128))

    def test_version_map_dimensions_phase(self):
        for k,v in [('version',2),('version',True),('map','OTHER'),('maxx',11),('maxy',True),('maxz',2),('state',2),('state',True),('state','1')]:
            with self.subTest(k=k,v=v): self.reject(changed(**{k:v}))

    def test_clock_controls(self):
        for k in ('elapsed','roundstart_time'):
            for v in (-1,1e16,True,None,'0',float('inf'),float('nan')):
                self.reject(changed(**{k:v}))
        self.reject(changed(elapsed=1),'pregame')
        validate_header_bytes(changed(state=3,elapsed=1e15,roundstart_time=.5))

    def test_schema_duplicates_json_bounds(self):
        h=fixture(); s=json.loads(h['round.json']); s.pop('game_id'); h['round.json']=json.dumps(s).encode();self.reject(h)
        self.reject(changed(extra=0))
        for payload in (b'[]',b'{}',b'{',b'{"a":1,"a":2}',b'{"a":{"x":1,"x":2}}',b'['*2000+b']'*2000):
            h=fixture();h['round.json']=payload;self.reject(h)
        for name,limit in LIMITS.items():
            for payload in (b'',b'x'*(limit+1),b'\xff',b'\x00',b'\r'):
                h=fixture();h[name]=payload;self.reject(h)
        h=fixture();del h['round.json'];self.reject(h)
        h=fixture();h['1.sav']=b'never parsed';self.reject(h)

    def test_generation_and_hash_relations(self):
        for m in ('','done','round-v2:'+'a'*32,'round-v1:xyz','round-v1:'+'b'*32):
            h=fixture();h['save_complete.txt']=m.encode();self.reject(h)
        self.reject(changed(generation='round-v1:'+'b'*32))
        self.reject(changed(metadata='0'*32))
        h=fixture();h['map.txt']=h['map.txt'].replace(b'Nomads',b'nomads');self.reject(h,'MD5')

    def test_metadata_flags_and_current_shape(self):
        for lines in (['NOMADS_PANGEA']*9,['NOMADS_PANGEA']*15):
            h=fixture();h['map.txt']='\n'.join(lines).encode();self.reject(h)
        for value in ('2','true','', '01'):
            h=fixture();m=h['map.txt'].decode().splitlines();m[10]=value;h['map.txt']='\n'.join(m).encode();self.reject(h,'flags')

    def test_elevation_controls(self):
        base=json.loads(fixture()['round.json'])['elevation']
        for e in (None,[],{},dict(base,version=2),dict(base,maxx=9),dict(base,default_metres=1),dict(base,default_metres=True),dict(base,regions=[{}]),dict(base,extra=1)):
            self.reject(changed(elevation=e),'elevation')

    def write_headers(self,root):
        (root/'map_saves').mkdir()
        for n,b in fixture().items(): (root/'map_saves'/n).write_bytes(b)

    def test_fixed_directory_and_external_hashes(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d);self.write_headers(root)
            result=validate_saved_headers(root)
            expected=dict(result['header_files'], **{'map_saves/1.sav':{'bytes':99,'sha256':'b'*64},'winter-growth-writer.json':{}})
            self.assertEqual(validate_saved_headers(root,expected_files=expected),result)
            # No native level file exists: explicitly demonstrates header-only scope.
            self.assertFalse((root/'map_saves/1.sav').exists())
            for field,value in [('bytes',1),('sha256','0'*64)]:
                wrong=copy.deepcopy(expected);wrong['map_saves/round.json'][field]=value
                with self.assertRaisesRegex(ValueError,'external header'):validate_saved_headers(root,expected_files=wrong)
            with self.assertRaises(ValueError):validate_saved_headers(root,expected_files={})

    def test_missing_nonregular_symlinks_and_oversize(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d);self.write_headers(root);p=root/'map_saves/round.json';p.unlink()
            with self.assertRaises(OSError):validate_saved_headers(root)
            p.mkdir()
            with self.assertRaises(ValueError):validate_saved_headers(root)
            p.rmdir();p.symlink_to(root/'map_saves/map.txt')
            with self.assertRaises(OSError):validate_saved_headers(root)
            p.unlink();p.write_bytes(b'x'*(LIMITS['round.json']+1))
            with self.assertRaises(ValueError):validate_saved_headers(root)
        with tempfile.TemporaryDirectory() as d:
            root=Path(d);(root/'other').mkdir();(root/'map_saves').symlink_to(root/'other')
            with self.assertRaises(OSError):validate_saved_headers(root)

    def test_identity_init_source_controls(self):
        good='/proc/winter_setup()\n\tgenerate_gameid()\n\twinter_check(game_id, "id")\n/proc/writer()\n\tmap_storage.Save_World()\n'
        self.assertTrue(validate_identity_init_source(good))
        for bad in (good.replace('\tgenerate_gameid()','\t// generate_gameid()'), good.replace('\tgenerate_gameid()','\tif (FALSE)\n\t\tgenerate_gameid()'),good.replace('\tgenerate_gameid()','\tmap_storage.Save_World()\n\tgenerate_gameid()'),good.replace('\tgenerate_gameid()','\tgame_id = "fabricated"'),good.replace('\tgenerate_gameid()','\tgenerate_gameid()\n\tglobal.game_id = null')):
            with self.assertRaises(ValueError):validate_identity_init_source(bad)
        late=good.replace('\tgenerate_gameid()\n','').replace('\tmap_storage.Save_World()','\tmap_storage.Save_World()\n\tgenerate_gameid()')
        with self.assertRaises(ValueError): validate_identity_init_source(late)
        actual=Path(__file__).with_name('probe.dm').read_text()
        validate_identity_init_source(actual)

    def test_writer_reader_preflight_and_retention_wiring(self):
        root=Path(__file__).parent
        probe=(root/'probe.dm').read_text()
        writer=probe.split('/proc/winter_food_writer()',1)[1].split('\n/proc/',1)[0]
        self.assertLess(writer.index('map_storage.Save_World()'),writer.index('map_storage.validate_world_save()'))
        backend=(root/'backend_proposal.py').read_text()
        self.assertEqual(backend.count("validate_saved_headers(work, expected_files=restart_receipt['restart_files'])"),2)
        self.assertLess(backend.index('copy_restart(output'),backend.index("dump(work / 'header-preflight.json'"))
        collector=(root/'collect_evidence.py').read_text()
        for name in ('header-preflight.json','map_saves/round.json','map_saves/map.txt','map_saves/save_complete.txt'):
            self.assertIn(repr(name),collector)

    @unittest.skipUnless(os.environ.get('WINTER_TEST_SOURCE'), 'optional pinned production source audit')
    def test_actual_ordinary_generator_source(self):
        source=(Path(os.environ['WINTER_TEST_SOURCE'])/'code/world.dm').read_text()
        validate_generator_source(source)
        for old,new in [('world.timeofday','rand(1,9)'),('TRUE to 4','TRUE to 400'),('game_id = ""','game_id = ""\n\tworld.Export("https://example.invalid")')]:
            with self.assertRaises(ValueError):validate_generator_source(source.replace(old,new))


if __name__=='__main__': unittest.main()

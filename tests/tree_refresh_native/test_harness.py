"""Offline harness contracts and omission controls. Never launch native code."""
from copy import deepcopy
from datetime import datetime,timezone
import importlib.util,json,sys,tempfile,unittest
from pathlib import Path
from types import SimpleNamespace as N
from unittest.mock import patch
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
sys.path.insert(0,str(HERE))
import protocol as P
import prepare as Q
import supervisor as S
import runner as R
import acquire as A

def witness():
    rows=[]
    for case in P.CASES:
        for kind in P.CLASSES:
            for iteration in range(1,26):
                def state(index,after=False):
                    moved=kind=='viewer_move' and case['mode']=='fallback' and index==1 and after
                    return dict(client=index,view='15x15',pan=[0,0],client_engine=[516,1688],scene_active=int(case['mode']=='root'),fallback_reason=None if case['mode']=='root' else 'native foreground or mixed-layer appearance',discovered=case['roots'],identities=[dict(root='root'+str(index),image='image'+str(index)+('new' if moved else ''),published_frame='frame' if case['mode']=='root' else None,native_icon_present=1,in_client_images=1,override=1,plane=1,mouse_opacity=1)])
                before=[state(i) for i in range(1,case['viewers']+1)];after=[state(i,True) for i in range(1,case['viewers']+1)]
                phases=[]
                if kind=='viewer_move':
                    entered=deepcopy(before);front=entered[0]['identities'][0];front.update(published_frame=None,native_icon_present=0)
                    if case['mode']=='fallback':front['image']=None
                    phases=[dict(phase='entered',clients=entered),dict(phase='postmove',clients=deepcopy(entered))]
                timer=dict(name='event',start_tick=1,end_tick=1,start_usage=1,end_usage=2,tick_lag=.5)
                row=dict(case=case['id'],**{'class':kind},iteration=iteration,viewers=case['viewers'],roots=case['roots'],mode=case['mode'],native_returns=[dict(result=2,sx=2,sy=0)] if kind=='viewer_move' else [],scene_valid=1,safe=1,other_sync_captures=0,before=before,after=after,phases=phases,timings=[dict(timer,name='reconcile',client=1)],event_timer=timer,allowance_ms=12.5,scheduled=dict(timings=[dict(timer,name='reconcile',client=i) for i in range(1,case['viewers']+1)],counters={}))
                if kind=='viewer_move' and iteration==1:row['capture_failed']=deepcopy(phases[0]['clients'])
                if kind=='queued_light':row['pending_committed']=deepcopy(before)
                rows.append(row)
    return dict(head='a'*40,binding='run',engine=[516,1688],world=dict(map=[64,64,1],view='15x15',fps=20,tick_lag=.5,icon_size=32,seed=13013),error=None,cleanup=1,events=800,pixels_verified=0),rows

class Protocol(unittest.TestCase):
    def test_complete_native_schema_and_limits(self):
        receipt,rows=witness();s=P.validate(receipt,rows,'a'*40,'run')
        self.assertTrue(s['native_dispatch_validated']);self.assertFalse(s['pixels_verified']);self.assertEqual(len(rows),800)
        self.assertEqual(sum(r['iteration']>5 for r in rows),640)
        self.assertEqual(P.LIMITS['rss_bytes'],1920*1024**2)
    def test_native_omission_and_unsafe_identity_controls(self):
        for mutation in ('entered','root_stale','fallback_retained','unrelated','capture_failed','pending','budget_fallback','density','extra_event'):
            with self.subTest(mutation=mutation):
                receipt,rows=witness();root=next(r for r in rows if r['class']=='viewer_move' and r['mode']=='root' and r['iteration']==1)
                fallback=next(r for r in rows if r['class']=='viewer_move' and r['mode']=='fallback')
                if mutation=='entered':root['phases']=root['phases'][1:]
                if mutation=='root_stale':root['phases'][0]['clients'][0]['identities'][0]['published_frame']='stale'
                if mutation=='fallback_retained':fallback['phases'][0]['clients'][0]['identities'][0]['image']='retained'
                if mutation=='unrelated':next(r for r in rows if r['class']=='opaque_move' and r['viewers']==2)['other_sync_captures']=1
                if mutation=='capture_failed':root['capture_failed'][0]['identities'][0]['native_icon_present']=1
                if mutation=='pending':next(r for r in rows if r['class']=='queued_light')['pending_committed'][0]['identities'][0]['image']=None
                if mutation=='budget_fallback':fallback['before'][0]['fallback_reason']='scene atom audit budget exceeded'
                if mutation=='density':root['before'][0]['discovered']=63
                if mutation=='extra_event':rows.append(rows[0])
                with self.assertRaises(ValueError):P.validate(receipt,rows,'a'*40,'run')
    def test_invalid_native_receipts_never_pass(self):
        for field,value in [('head','b'*40),('binding','other'),('engine',[516,1681]),('cleanup',0),('pixels_verified',1),('error','native failure')]:
            receipt,rows=witness();receipt[field]=value
            with self.subTest(field=field),self.assertRaises(ValueError):P.validate(receipt,rows,'a'*40,'run')
    def test_unresolved_timers_are_never_zero_or_accepted(self):
        for tick,end in [(2,3),(1,0)]:
            row=dict(start_tick=1,end_tick=tick,start_usage=1,end_usage=end,tick_lag=.5)
            self.assertIsNone(P.same_tick_ms(row))
        self.assertEqual(P.same_tick_ms(dict(start_tick=1,end_tick=1,start_usage=10,end_usage=20,tick_lag=.5)),5)
        receipt,rows=witness();rows[0]['timings'][0]['end_tick']=2
        summary=P.validate(receipt,rows,'a'*40,'run');self.assertFalse(summary['cost_accepted']);self.assertEqual(len(summary['unresolved']),1)
        receipt,rows=witness();rows[5]['event_timer']['end_tick']=2
        self.assertFalse(P.validate(receipt,rows,'a'*40,'run')['cost_accepted'])
    def test_review_hash_deadline_and_host_binding(self):
        env=dict(RUNNER_ENVIRONMENT='github-hosted',RUNNER_OS='Windows',GITHUB_REPOSITORY='Civ13/Civ13',GITHUB_EVENT_NAME='workflow_dispatch',GITHUB_RUN_ATTEMPT='1',GITHUB_SHA='a'*40,GITHUB_WORKFLOW_SHA='a'*40)
        now=datetime(2026,11,2,6,tzinfo=timezone.utc);raw=b'manifest';until='2026-11-02T13:23:00Z'
        self.assertGreater(P.admit('a'*40,raw,P.digest(raw),until,env,now),now.timestamp())
        for key,value in [('RUNNER_ENVIRONMENT','self-hosted'),('GITHUB_RUN_ATTEMPT','2'),('GITHUB_SHA','b'*40),('RUNNER_OS','Linux')]:
            with self.subTest(key=key),self.assertRaises(ValueError):P.admit('a'*40,raw,P.digest(raw),until,dict(env,**{key:value}),now)
        with self.assertRaises(ValueError):P.admit('a'*40,raw,P.digest(raw),'2026-11-03T13:23:00Z',env,now)
        with self.assertRaises(ValueError):P.admit('a'*40,raw,'0'*64,until,env,now)
        with self.assertRaises(ValueError):P.admit('a'*40,raw,P.digest(raw),'2026-11-02T06:00:01Z',env,now)

class Preparation(unittest.TestCase):
    def test_current_source_anchors_are_exact_and_instrumented_only(self):
        for rel in set(Q.SPANS)|{'code/datums/observation/moved.dm','code/modules/visibility/root_light_snapshot.dm'}:
            text=(ROOT/rel).read_text();adapted=Q.adapt(rel,text)
            self.assertIn('tree_native_',adapted)
            for header,name in Q.SPANS.get(rel,[]):
                self.assertEqual(adapted.count('tree_native_begin("'+name+'", src)'),1)
                self.assertIn(header,adapted)
        text=(ROOT/'code/modules/client/client_procs.dm').read_text()
        for header in ('/client/New(TopicData)','/client/Topic(href, href_list, hsrc)','/client/Del()'):Q.proc(text,header)
        Q.proc((ROOT/'tests/human_subtile/probe.dm').read_text(),'/proc/human_subtile_fixture_initialize()')
    def test_source_selector_drift_fails_closed(self):
        with self.assertRaises(ValueError):Q.adapt('code/datums/observation/moved.dm','/atom/Entered()\n\treturn\n')
        with self.assertRaises(ValueError):Q.instrument('/proc/f()\n\treturn\n/proc/f()\n\treturn\n','/proc/f()','span')
    def test_prepared_input_tampering_fails_before_launch(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d);(root/'stage').mkdir();(root/'stage/input.dm').write_bytes(b'good');m=dict(input_files={'input.dm':dict(bytes=4,sha256=P.digest(b'good'))})
            self.assertEqual(R.inputs(root,m),root/'stage');(root/'stage/input.dm').write_bytes(b'evil')
            with self.assertRaises(ValueError):R.inputs(root,m)
            (root/'stage/input.dm').write_bytes(b'good');(root/'stage/extra.dm').write_bytes(b'unreviewed')
            with self.assertRaises(ValueError):R.inputs(root,m)
    def test_wrong_pinned_download_never_reaches_extraction_or_installation(self):
        import io
        with tempfile.TemporaryDirectory() as d,patch.dict(A.os.environ,{'RUNNER_ENVIRONMENT':'github-hosted','RUNNER_OS':'Windows'}):
            pin=dict(version='516.1688',url='https://www.byond.com/download/build/516/516.1688_byond.exe',bytes=3,sha256='0'*64)
            with patch.object(A.urllib.request,'urlopen',return_value=io.BytesIO(b'bad')),patch.object(A.subprocess,'run') as extraction:
                with self.assertRaises(ValueError):A.acquire(Path(d)/'new',pin)
                extraction.assert_not_called()

    def test_no_model_or_frozen_fixture_in_native_entry(self):
        text=(HERE/'probe.dm').read_text();self.assertIn('H.SelfMove(',text);self.assertIn('begin_change()',text);self.assertIn('C.reconcile_geometric_los()',text)
        self.assertNotIn('IdentityTrace',text);self.assertNotIn('test_production.py',(HERE/'prepare.py').read_text())
        self.assertIn('new /obj/tree_native_fallback(C.mob.loc)',text)
        self.assertNotIn('root_tree_presentation/fixture.dm',(HERE/'prepare.py').read_text())

class Containment(unittest.TestCase):
    def test_only_exact_loopback_endpoint_is_admitted(self):
        listen=dict(protocol='tcp',address='127.0.0.1',port=59479,remote_address='0.0.0.0',remote_port=0,state='listen')
        self.assertTrue(S.socket_ok(listen,59479,True));self.assertFalse(S.socket_ok(listen,59479,False))
        client=dict(protocol='tcp',address='127.0.0.1',port=40000,remote_address='127.0.0.1',remote_port=59479,state='5')
        self.assertTrue(S.socket_ok(client,59479,False))
        for bad in (dict(client,address='0.0.0.0'),dict(client,remote_address='1.1.1.1'),dict(client,remote_port=59478),dict(client,protocol='udp')):
            self.assertFalse(S.socket_ok(bad,59479,False))
    def test_derived_launcher_changes_only_reviewed_binary_guard(self):
        import ast
        text=(ROOT/'tests/human_subtile/native_1688/windows.py').read_text()
        tree=ast.parse(text);method=next(n for c in tree.body if isinstance(c,ast.ClassDef) and c.name=='Adapter' for n in c.body if isinstance(n,ast.FunctionDef) and n.name=='launch')
        original=''.join(text.splitlines(True)[method.lineno-1:method.end_lineno])
        derived=S.derive_launch(original);compile(derived,'<offline derived source>','exec')
        self.assertIn('AssignProcessToJobObject',derived);self.assertIn('ResumeThread',derived)
        self.assertIn('APPDATA=str(envroot)',derived);self.assertNotIn('from guard_config',derived)
        with self.assertRaises(ValueError):S.derive_launch('def launch():\n    return None\n')

    def test_unexpected_cumulative_child_is_rejected_without_launch(self):
        adapter=N(accounting=lambda:N(total=1,terminated=0,active=1));fake=N(a=adapter,windows=N(),owned=N(query_members=lambda a:dict(pids=[])))
        with patch.object(S,'facade',return_value=fake):
            owned=S.OwnedRun(Path('.'),{})
            with self.assertRaises(ValueError):owned.poll()
    def test_expired_or_unreviewed_execution_emits_failure_before_native(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d);prep=root/'prep';prep.mkdir();(prep/'tree-native-manifest.json').write_text(json.dumps(dict(head='a'*40)))
            with patch.object(R,'OwnedRun') as native,self.assertRaises(ValueError):R.execute(prep,root,'0'*64,'2026-11-02T13:23:00Z',root/'out',1)
            native.assert_not_called();receipt=json.loads((root/'out/execution-receipt.json').read_text());self.assertEqual(receipt['status'],'failed');self.assertFalse(receipt['native_executed'])

if __name__=='__main__':unittest.main()

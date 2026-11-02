"""Fake-daemon cleanup tests only. No Docker or process is launched."""
from pathlib import Path
import importlib.util
import json
import unittest
from unittest import mock
ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('sleep_watchdog',ROOT/'owned_container_watchdog.py')
w=importlib.util.module_from_spec(spec);spec.loader.exec_module(w)
TOKEN='b'*32; IMAGE='sha256:'+'a'*64; CID='c'*64

def state(started=True,confirmed=True):
    return {'token':TOKEN,'image':IMAGE,'create_started':started,'create_confirmed':confirmed,'container_id':CID if confirmed else None,'start_started':False,'start_confirmed':False}
class FakeDocker:
    def __init__(self, label=TOKEN, ids=None, fail=None, status='running'):
        self.ids=[CID] if ids is None else ids[:];self.label=label;self.fail=fail;self.status=status;self.calls=[]
    def __call__(self,args):
        self.calls.append(args)
        if args[0]==self.fail:raise RuntimeError('synthetic failure')
        if args[0]=='ps':return '\n'.join(self.ids)
        if args[0]=='inspect':return json.dumps([{'Id':CID,'Name':'/civ13-sleep-'+TOKEN,'Image':IMAGE,'Config':{'Labels':{w.LABEL:self.label}},'State':{'Status':self.status}}])
        if args[0]=='kill':return CID
        if args[0]=='wait':return '137'
        if args[0]=='rm':self.ids=[];return CID
        raise AssertionError(args)
class Tests(unittest.TestCase):
    def test_confirmed_container_stopped_removed_and_censused(self):
        d=FakeDocker();result=w.cleanup_owned(d,state(),TOKEN,IMAGE)
        self.assertEqual(result['status'],'docker_cleanup_verified')
        self.assertEqual([x[0] for x in d.calls],['ps','inspect','kill','wait','rm','ps'])
    def test_wrong_identity_or_ambiguous_census_never_mutates(self):
        for d in (FakeDocker(label='wrong'),FakeDocker(ids=[CID,'d'*64]),FakeDocker(ids=['d'*64])):
            with self.subTest(ids=d.ids),self.assertRaises(ValueError):w.cleanup_owned(d,state(),TOKEN,IMAGE)
            self.assertFalse(any(x[0] in ('kill','rm') for x in d.calls))
    def test_unconfirmed_create_never_claims_verified(self):
        d=FakeDocker();result=w.cleanup_owned(d,state(confirmed=False),TOKEN,IMAGE)
        self.assertEqual(result['status'],'cleanup_unverified_create_outcome')
        self.assertEqual(d.ids,[])
    def test_unconfirmed_create_with_empty_census_stays_unknown(self):
        d=FakeDocker(ids=[]);result=w.cleanup_owned(d,state(confirmed=False),TOKEN,IMAGE)
        self.assertEqual(result['status'],'cleanup_unverified_create_outcome')
        self.assertFalse(any(x[0] in ('kill','rm') for x in d.calls))
    def test_created_container_is_removed_without_kill(self):
        d=FakeDocker(status='created');result=w.cleanup_owned(d,state(),TOKEN,IMAGE)
        self.assertEqual(result['status'],'docker_cleanup_verified')
        self.assertEqual([x[0] for x in d.calls],['ps','inspect','rm','ps'])
    def test_missing_confirmed_container_is_not_verified_cleanup(self):
        result=w.cleanup_owned(FakeDocker(ids=[]),state(),TOKEN,IMAGE)
        self.assertEqual(result['status'],'cleanup_unverified_missing_owned_container')
    def test_container_before_create_never_mutates(self):
        d=FakeDocker()
        with self.assertRaises(ValueError):w.cleanup_owned(d,state(started=False,confirmed=False),TOKEN,IMAGE)
        self.assertFalse(any(x[0] in ('kill','rm') for x in d.calls))
    def test_denied_kill_is_not_retried(self):
        d=FakeDocker(fail='kill')
        with self.assertRaises(RuntimeError):w.cleanup_owned(d,state(),TOKEN,IMAGE)
        self.assertEqual([x[0] for x in d.calls].count('kill'),1)
        self.assertFalse(any(x[0]=='rm' for x in d.calls))
    def test_deadline_uses_exact_pidfd_and_escalates_once(self):
        class Poll:
            def __init__(self,answers):self.answers=iter(answers)
            def poll(self,timeout):return next(self.answers)
        sent=[]
        with mock.patch.object(w.signal,'SIGKILL',9,create=True):
            self.assertEqual(w.stop_deadline_owner(lambda fd,sig:sent.append((fd,sig)),17,Poll([[],[],[1]])),'kill_exited')
        self.assertEqual(sent,[(17,w.signal.SIGTERM),(17,9)])
        sent=[]
        self.assertEqual(w.stop_deadline_owner(lambda fd,sig:sent.append((fd,sig)),17,Poll([[],[1]])),'term_exited')
        self.assertEqual(sent,[(17,w.signal.SIGTERM)])
    def test_unconfirmed_start_remains_unknown_after_cleanup(self):
        s=state();s['start_started']=True
        d=FakeDocker();result=w.cleanup_owned(d,s,TOKEN,IMAGE)
        self.assertEqual(result['status'],'cleanup_unverified_start_outcome')
        self.assertEqual(d.ids,[])
    def test_parent_reuse_or_exit_after_open_refuses_before_ready(self):
        class Poll:
            def __init__(self,ready):self.ready=ready
            def register(self,fd,event):pass
            def poll(self,timeout):return self.ready
        for parents,ready in ((iter([123,456]),[]),(iter([123,123]),[1])):
            closed=[]
            with mock.patch.object(w.select,'POLLIN',1,create=True),self.assertRaises(ValueError):
                w.open_verified_parent(123,lambda pid,flags:17,lambda:next(parents),lambda:Poll(ready),closed.append)
            self.assertEqual(closed,[17])
    def test_parent_ready_is_rechecked_before_publication(self):
        source=(ROOT/'owned_container_watchdog.py').read_text(encoding='utf-8')
        self.assertLess(source.index("require(os.getppid()==parent_pid and not poll.poll(0),'watch owner changed before readiness')"),source.index("os.replace(ready_tmp,evidence/'watchdog-ready.json')"))
    def test_invalid_start_transition_is_rejected(self):
        s=state(started=False,confirmed=False);s['start_started']=True
        with self.assertRaises(ValueError):w.exact_state(json.dumps(s),TOKEN,IMAGE)
        s=state();s['start_confirmed']=True
        with self.assertRaises(ValueError):w.exact_state(json.dumps(s),TOKEN,IMAGE)
    def test_deadline_stops_owner_before_state_or_census(self):
        events=[]
        class Poll:
            def __init__(self):self.n=0
            def poll(self,timeout):self.n+=1;events.append('poll');return [] if self.n==1 else [1]
        def send(fd,sig):events.append('signal')
        def load():events.append('state');return state()
        def cleanup(value):events.append('cleanup');return {'status':'docker_cleanup_verified'}
        result=w.reconcile_trigger('deadline',17,Poll(),send,load,cleanup)
        self.assertEqual(result['owner_deadline_signal'],'term_exited')
        self.assertLess(events.index('signal'),events.index('state'))
        self.assertLess(events.index('state'),events.index('cleanup'))
    def test_unknown_trigger_refuses_without_state_or_cleanup(self):
        events=[]
        with self.assertRaises(ValueError):w.reconcile_trigger('other',17,None,None,lambda:events.append('state'),lambda s:events.append('cleanup'))
        self.assertEqual(events,[])
    def test_unstopped_owner_does_not_read_state_or_clean(self):
        events=[]
        class Poll:
            def poll(self,timeout):return []
        def send(fd,sig):events.append('signal');raise OSError('denied')
        result=w.reconcile_trigger('deadline',17,Poll(),send,lambda:events.append('state'),lambda s:events.append('cleanup'))
        self.assertEqual(result['status'],'unknown')
        self.assertEqual(events,['signal'])
    def test_duplicate_state_and_unconfirmed_id_rejected(self):
        bad=b'{"token":"x","token":"y"}'
        with self.assertRaises(ValueError):w.exact_state(bad,TOKEN,IMAGE)
        s=state(confirmed=False);s['container_id']=CID
        with self.assertRaises(ValueError):w.exact_state(json.dumps(s),TOKEN,IMAGE)
if __name__=='__main__':unittest.main()

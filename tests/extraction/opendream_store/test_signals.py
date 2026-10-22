"""Execute real PosixEffects.signal policy with every kernel effect injected."""
import copy
import unittest
from types import SimpleNamespace
from unittest.mock import patch
import backend as b
import run as r
import v2_signal_control as old


class SignalEffects(b.PosixEffects):
    def __init__(self):
        self.rows=[{'pid':100,'birth':'10','sid':100,'pgid':100,'state':'S'},
                   {'pid':101,'birth':'11','sid':100,'pgid':101,'state':'S'},
                   {'pid':102,'birth':'12','sid':100,'pgid':100,'state':'S'}]
        self.events=[]; self.changed={}; self.fail_open=set(); self.fail_send=set()
        self.gone=set(); self.closed=[]
    def members(self,owned): return copy.deepcopy(self.rows)
    def _pidfd_open(self,pid):
        self.events.append(('open',pid))
        if pid in self.gone: raise ProcessLookupError('already exited')
        if pid in self.fail_open: raise PermissionError('open denied')
        return pid+1000
    def _stat(self,pid):
        self.events.append(('identity',pid))
        row=copy.deepcopy(next(row for row in self.rows if row['pid']==pid))
        row.update(self.changed.get(pid,{}))
        return row
    def _pidfd_signal(self,fd,sig):
        self.events.append(('send',fd-1000,sig))
        if fd-1000 in self.fail_send: raise PermissionError('send denied')
    def _pidfd_close(self,fd):
        self.events.append(('close',fd-1000)); self.closed.append(fd-1000)


class SignalTests(unittest.TestCase):
    def owner(self): return b.Owned('owned',process=object(),pid=100,birth='10')
    def test_same_session_separate_pgid_is_targeted(self):
        fx=SignalEffects(); fx.signal(self.owner(),'SIGKILL')
        sends=[event[1] for event in fx.events if event[0]=='send']
        self.assertEqual(sends,[100,101,102])
        for pid in sends:
            self.assertLess(fx.events.index(('identity',pid)),fx.events.index(('send',pid,'SIGKILL')))
        self.assertEqual(fx.closed,[100,101,102])

    def test_v2_group_only_control_fails_exact_owned_coverage_oracle(self):
        # Frozen V2's exact effect: one killpg(owner.pid). Model the kernel group
        # selection in memory; never call the OS. PGID101 remains in SID100.
        def coverage(rows,targeted):
            r.need({row['pid'] for row in rows}==set(targeted), 'same-session member not targeted')
        fx=SignalEffects(); owner=self.owner()
        v2_targeted=[]
        def killpg(group,sig):
            v2_targeted.extend(row['pid'] for row in fx.rows if row['pgid']==group)
        with patch.object(old,'os',SimpleNamespace(killpg=killpg)), patch.object(old,'signal',SimpleNamespace(SIGKILL='SIGKILL')):
            old.signal_control(fx,owner,'SIGKILL')
        self.assertEqual(v2_targeted,[100,102])
        with self.assertRaisesRegex(r.Rejected,'same-session member not targeted'):
            coverage(fx.rows,v2_targeted)
        fx.signal(owner,'SIGKILL')
        coverage(fx.rows,[event[1] for event in fx.events if event[0]=='send'])

    def test_changed_birth_or_session_never_signaled_others_attempted(self):
        for changed in ({'birth':'99'},{'sid':999},{'pid':999}):
            with self.subTest(changed=changed):
                fx=SignalEffects(); fx.changed[101]=changed
                with self.assertRaisesRegex(r.Rejected,'identity drift'): fx.signal(self.owner(),'SIGKILL')
                self.assertNotIn(('send',101,'SIGKILL'),fx.events)
                self.assertIn(('send',102,'SIGKILL'),fx.events)
                self.assertEqual(fx.closed,[100,101,102])

    def test_pgid_change_with_same_identity_does_not_escape(self):
        fx=SignalEffects(); fx.changed[101]={'pgid':1010}
        fx.signal(self.owner(),'SIGKILL')
        self.assertIn(('send',101,'SIGKILL'),fx.events)

    def test_failed_open_or_send_still_attempts_other_processes(self):
        for failed in ('fail_open','fail_send'):
            with self.subTest(failed=failed):
                fx=SignalEffects(); getattr(fx,failed).add(101)
                with self.assertRaisesRegex(r.Rejected,'denied'): fx.signal(self.owner(),'SIGKILL')
                self.assertIn(('send',102,'SIGKILL'),fx.events)
                self.assertEqual(fx.closed,[100,102] if failed=='fail_open' else [100,101,102])

    def test_exited_member_is_not_retargeted(self):
        fx=SignalEffects(); fx.gone.add(101)
        fx.signal(self.owner(),'SIGKILL')
        self.assertNotIn(('send',101,'SIGKILL'),fx.events)
        self.assertIn(('send',102,'SIGKILL'),fx.events)

    def test_unresolved_partial_owner_fails_before_pidfd(self):
        fx=SignalEffects(); owner=self.owner(); owner.birth=None
        with self.assertRaisesRegex(r.Rejected,'unresolved'): fx.signal(owner,'SIGKILL')
        self.assertEqual(fx.events,[])


if __name__=='__main__': unittest.main()

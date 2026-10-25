"""Only fake owned-child geometry; no windows, content, or pixels read."""
import unittest
from unittest.mock import Mock
import capture

class ChildGeometryTests(unittest.TestCase):
    def backend(self, count=2):
        n=object.__new__(capture._WindowsScreen);n.user=object();calls=[]
        n._owner=Mock(return_value=(123,124))
        def api(lib,name,*args,**kw):
            calls.append(name)
            if name=='GetWindow':
                hwnd,which=args
                return (100 if count else 0) if which==5 else (hwnd+1 if hwnd<99+count else 0)
            if name=='GetAncestor':return 567
            if name=='GetClientRect':
                rect=capture.c.cast(args[1],capture.c.POINTER(capture._RECT)).contents
                rect.left=0;rect.top=0;rect.right=480;rect.bottom=480 if args[0]==100 else 19
            if name=='ClientToScreen':
                point=capture.c.cast(args[1],capture.c.POINTER(capture._POINT)).contents
                point.x+=80;point.y+=80+(480 if args[0]==101 else 0)
            return 1
        n._call=api
        return n,calls

    def test_exact_bounded_numeric_relative_geometry(self):
        n,calls=self.backend();rows=n.owned_child_geometry(567,123,124)
        self.assertEqual(len(rows),2)
        self.assertEqual(rows[0]['parent_client_rect'],[0,0,480,480])
        self.assertEqual(rows[1]['parent_client_rect'],[0,480,480,499])
        self.assertEqual(set(rows[0]),{'hwnd','pid','thread_id','visible','client_rect','parent_client_rect'})
        self.assertFalse(set(calls)&{'GetWindowTextW','GetClassNameW','EnumWindows','BitBlt','GetDC','SetWindowPos'})

    def test_no_children_is_valid(self):
        n,_=self.backend(0);self.assertEqual(n.owned_child_geometry(567,123,124),[])

    def test_limit_eight_is_fail_closed(self):
        n,_=self.backend(9)
        with self.assertRaises(capture.CaptureError):n.owned_child_geometry(567,123,124)
        n,_=self.backend(8);self.assertEqual(len(n.owned_child_geometry(567,123,124)),8)

    def test_foreign_owner_and_changed_owner_fail_closed(self):
        for owners in ([(999,124)],[(123,124),(999,124)]):
            n,_=self.backend();n._owner=Mock(side_effect=owners)
            with self.assertRaises(capture.CaptureError):n.owned_child_geometry(567,123,124)

    def test_repeated_child_rejected(self):
        n,_=self.backend();old=n._call
        n._call=lambda lib,name,*args,**kw:100 if name=='GetWindow' else old(lib,name,*args,**kw)
        with self.assertRaises(capture.CaptureError):n.owned_child_geometry(567,123,124)

    def test_indirect_child_rejected(self):
        n,_=self.backend();old=n._call
        n._call=lambda lib,name,*args,**kw:888 if name=='GetAncestor' else old(lib,name,*args,**kw)
        with self.assertRaises(capture.CaptureError):n.owned_child_geometry(567,123,124)

    def test_no_hypothesis_fix_or_admission_relaxation(self):
        from pathlib import Path
        root=Path(__file__).parent
        skin=(root/'changed-source/filming/cloud.dmf').read_text()
        self.assertEqual(skin.count('size = 480x480'),2)
        self.assertIn('statusbar = false',skin)
        s=(root/'capture.py').read_text()
        self.assertIn("error.evidence['child_geometry_status'] = 'unavailable'",s)
        self.assertIn('            raise error',s)
        self.assertIn('(client.left, client.top, client.right, client.bottom) != (0, 0, *size)',s)

if __name__=='__main__':unittest.main()

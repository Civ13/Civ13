"""Offline scaffold contracts, not native login or rendering acceptance."""
from pathlib import Path
import inspect,re,tempfile,unittest
from unittest.mock import patch
import integration

HERE=Path(__file__).resolve().parent

class Scaffold(unittest.TestCase):
    def test_native_special_lists_are_mutated_and_checked(self):
        source=(HERE/'changed-source/filming/scene.dm').read_text()
        self.assertNotRegex(source,r'(?m)^\s*verbs\s*=')
        self.assertNotIn('verbs.Cut()',source)
        self.assertEqual(source.count('for (var/fixture_verb in verbs.Copy())\n\t\tverbs -= fixture_verb'),2)
        for phrase in ['client verbs empty before native New','client verbs empty after native New','observer verbs empty before capture','observer verbs empty after Login']:
            self.assertEqual(source.count(phrase),1)
        client=source.split('/client/New()\n',1)[1].split('/client/Del()',1)[0]
        self.assertLess(client.index('client verbs empty before native New'),client.index('\n\t..()'))
        self.assertLess(client.index('\n\t..()'),client.index('client verbs empty after native New'))
        self.assertLess(client.index('observer verbs empty before capture'),client.index('intro_cadence_write("admission")'))
    def test_scripted_capture_procs_survive_empty_verb_list(self):
        source=(HERE/'changed-source/filming/scene.dm').read_text()
        for name in ['Abort_carriage','Prepare_carriage','Run_carriage']:
            self.assertIn('/mob/intro_observer/proc/'+name+'()',source)
            self.assertNotIn('/mob/intro_observer/verb/'+name,source)
        self.assertIn('O.Prepare_carriage()\n\t\tO.Run_carriage()',source)
        self.assertIn('intro_capture_requests()',source)
    def test_guest_and_viewport_admission_retained(self):
        source=(HERE/'changed-source/filming/scene.dm').read_text()
        for token in ['copytext(key, 1, 7) != "Guest-"','address != "127.0.0.1"','byond_version != 516','byond_build != 1688','eye = locate(8, 8, 1)','perspective = EYE_PERSPECTIVE','maxx == 15 && maxy == 15 && maxz == 1']:
            self.assertIn(token,source)
        skin=(HERE/'changed-source/filming/carriage.dmf').read_text()
        for token in ['statusbar = false','can-resize = false','title = "Civ13 carriage take"','pos = 0,0']:
            self.assertIn(token,skin)
        self.assertEqual(skin.count('size = 480x480'),2)
    def test_exact_binary_handshake_callbacks_and_exclusive_creation(self):
        class Finished(Exception):pass
        with tempfile.TemporaryDirectory() as root:
            source=Path(root)
            (source/'intro-cadence-end.json').write_bytes(b'{}')
            def burst(*args,**kwargs):
                read_configuration=args[5]
                first=kwargs['on_first_sample']
                first()
                self.assertEqual((source/'intro-first-sample.txt').read_bytes(),b'first_owned_sample\n')
                with self.assertRaises(FileExistsError):first()
                read_configuration();read_configuration()
                self.assertEqual((source/'intro-end-request.txt').read_bytes(),b'end\n')
                raise Finished()
            with patch.object(integration,'record_burst',burst),patch.object(integration,'config_at',return_value=({},0)):
                with self.assertRaises(Finished):integration.record_scene(None,None,source,source,'fixed',lambda:None,0,{})
        code=inspect.getsource(integration.record_scene)
        self.assertEqual(code.count(".open('xb')"),2)
        self.assertNotIn(".open('x')",code)

if __name__=='__main__':unittest.main()

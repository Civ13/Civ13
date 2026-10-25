"""Source-order/negative controls only, not a native DM execution proof."""
import unittest
from test_scene import SCENE


def verify(source):
    new = source.split('/client/New()\n', 1)[1].split('\n/client/Del()', 1)[0]
    tokens = ('filming_observer_client = src',
              'for (var/fixture_verb in verbs.Copy())\n\t\tverbs -= fixture_verb',
              'filming_check(!verbs.len, "client verbs empty before native New")',
              '\n\t..()',
              'filming_check(!verbs.len, "client verbs empty after native New")',
              'filming_check(istype(mob, /mob/filming_observer) && !mob.verbs.len, "observer verbs empty before capture")',
              '"cloud-client.txt"', 'spawn(20)')
    positions = [new.index(t) for t in tokens]
    if positions != sorted(positions) or 'verbs.Cut(' in source:
        raise ValueError('unsafe fixture verb admission order')
    login = source.split('/mob/filming_observer/Login()\n', 1)[1].split('\n/mob/filming_observer/Move()', 1)[0]
    if login.index('verbs = list()') > login.index('filming_check(!verbs.len, "observer verbs empty after Login")'):
        raise ValueError('observer check precedes removal')


class FixtureVerbContracts(unittest.TestCase):
    def test_snapshot_removal_and_zero_gates_before_acceptance(self):
        verify(SCENE)

    def test_old_cut_rejected(self):
        with self.assertRaises(ValueError):
            verify(SCENE.replace('for (var/fixture_verb in verbs.Copy())\n\t\tverbs -= fixture_verb', 'verbs.Cut()'))

    def test_live_list_iteration_rejected(self):
        with self.assertRaises(ValueError):
            verify(SCENE.replace('verbs.Copy()', 'verbs'))

    def test_each_zero_assertion_required(self):
        for line in SCENE.splitlines():
            if 'filming_check(' in line and 'verbs empty' in line:
                with self.subTest(line=line), self.assertRaises(ValueError):
                    verify(SCENE.replace(line, ''))

    def test_post_new_assertion_cannot_move_after_acceptance(self):
        gate = '\tfilming_check(!verbs.len, "client verbs empty after native New")\n'
        with self.assertRaises(ValueError):
            verify(SCENE.replace(gate, '').replace('\tspawn(20)', gate+'\tspawn(20)'))

    def test_failure_still_throws_and_world_error_stops(self):
        self.assertIn('if (!ok)\n\t\tthrow EXCEPTION("Filming check failed: [label]")', SCENE)
        self.assertIn('/world/Error(exception/E)\n\tfilming_stop(', SCENE)
        stop = SCENE.split('/proc/filming_stop(reason)')[1].split('// Keep the Little Creek')[0]
        self.assertIn('world.OpenPort("none")', stop)
        self.assertIn('del(world)', stop)

if __name__ == '__main__':
    unittest.main()

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
              'mob = tan_worker',
              'filming_check(mob == tan_worker && tan_worker.client == src && tan_worker.key == key && !mob.verbs.len && !verbs.len, "same real guest bound to exact zero-verb worker")',
              '"cloud-client.txt"', 'spawn(20)')
    positions = [new.index(t) for t in tokens]
    if positions != sorted(positions) or 'verbs.Cut(' in source:
        raise ValueError('unsafe fixture verb admission order')
    login = source.split('/mob/filming_observer/Login()\n', 1)[1].split('\n/mob/filming_observer/Move()', 1)[0]
    if login.index('for (var/fixture_verb in verbs.Copy())\n\t\tverbs -= fixture_verb') > login.index('filming_check(!verbs.len, "observer verbs empty after Login")'):
        raise ValueError('observer check precedes removal')

    worker = source.split('/mob/living/human/filming_worker/Login()\n', 1)[1].split('/mob/living/human/filming_worker/Logout()', 1)[0]
    required = ('native guest worker Login identity', 'for (var/fixture_verb in verbs.Copy())\n\t\tverbs -= fixture_verb', 'filming_check(!verbs.len, "worker verbs empty after Login")')
    if any(t not in worker for t in required):
        raise ValueError('worker identity or zero verbs missing')


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


class ObserverVerbContracts(unittest.TestCase):
    def test_observer_uses_proven_snapshot_subtraction(self):
        login = SCENE.split('/mob/filming_observer/Login()\n', 1)[1].split('\n/mob/filming_observer/Move()', 1)[0]
        self.assertIn('for (var/fixture_verb in verbs.Copy())\n\t\tverbs -= fixture_verb', login)
        self.assertIn('filming_check(!verbs.len, "observer verbs empty after Login")', login)

    def test_old_observer_assignment_rejected(self):
        login = SCENE.split('/mob/filming_observer/Login()\n', 1)[1]
        mutation = login.replace('for (var/fixture_verb in verbs.Copy())\n\t\tverbs -= fixture_verb', 'verbs = list()', 1)
        with self.assertRaises(ValueError):
            verify(SCENE.split('/mob/filming_observer/Login()\n', 1)[0]+'/mob/filming_observer/Login()\n'+mutation)

    def test_fixture_has_no_special_list_assignments_or_cut(self):
        import re
        special = r'(?:verbs|contents|overlays|underlays|vis_contents|vis_locs|screen|images|filters|vars)'
        self.assertIsNone(re.search(r'\b'+special+r'\s*=(?!=)', SCENE))
        self.assertIsNone(re.search(r'\b'+special+r'\s*\.\s*(?:Cut|Insert|Swap)\s*\(', SCENE))

if __name__ == '__main__':
    unittest.main()

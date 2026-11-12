"""Execute the monitor's complete pipe-row proc with fake engine boundaries.

Only DM list syntax is adapted. Spatial lookup, types, deletion and turfs are
injected; this is source control-flow evidence, not native DM acceptance.
The existing meter_probe.dm supplies the production-object regression.
"""
import importlib.util
import math
import re
from pathlib import Path
from types import SimpleNamespace as NS
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('monitor_projection', ROOT / 'tests/save_movement/source_adapter.py')
vm = importlib.util.module_from_spec(spec)
spec.loader.exec_module(vm)
SOURCE = (ROOT / 'code/modules/1713/factory_monitor.dm').read_text()
PROC = '/obj/structure/factory_monitor/proc/pipe_network_rows'
PIPE = '/obj/structure/fluid_pipe'
PUMP = '/obj/structure/fluid_pump'


class DMList(list):
    @property
    def len(self):
        return len(self)

    def __iadd__(self, value):
        self.append(value)
        return self


def dm_list(*values):
    return DMList(values)


class Turf:
    def __init__(self, x=3, y=3, z=1):
        self.x, self.y, self.z = x, y, z


class Pipe:
    def __init__(self, net, x=2, y=2, z=1, open=True):
        self.network = net
        self.x, self.y, self.z = x, y, z
        self.loc = Turf(x, y, z)
        self.open = open
        self.deleted = False

    def fluid_open(self):
        return self.open


class Pump:
    def __init__(self, on=False, powered=False):
        self.loc = Turf()
        self.anchored = True
        self.on, self.powered = on, powered
        self.deleted = False


class Network:
    def __init__(self, pumps=()):
        self.pipes = DMList()
        self.members = DMList(pumps)
        self.deleted = False
        self.idle_steps = 0
        self.last_moved = 0


def run(pipes, networks, dirty=False, here=True, source=SOURCE):
    # Mechanical adaptation of DM's append-by-growing-index and list constructor.
    source = source.replace('rows[++rows.len] = list(P.x, P.y, N.pipes.len, running, pumps, state, moved)',
                            'rows.append(list(P.x, P.y, N.pipes.len, running, pumps, state, moved))')
    def nearby(distance, origin):
        return [p for p in pipes if p.z == origin.z
                and max(abs(p.x - origin.x), abs(p.y - origin.y)) <= distance]
    env = {'get_turf': lambda _: Turf() if here else None,
           'fluid_networks_dirty': dirty, 'fluid_networks': networks,
           'FACTORY_MONITOR_RANGE': int(re.search(r'^#define FACTORY_MONITOR_RANGE (\d+)$', source, re.M)[1]), 'range': nearby,
           'QDELETED': lambda obj: obj is None or obj.deleted,
           'isturf': lambda obj: isinstance(obj, Turf),
           'typed_iter': lambda items, path: [i for i in items if isinstance(i, {PIPE: Pipe, PUMP: Pump}[path])],
           'list': dm_list, 'round': lambda n, step: math.floor(n / step + 1e-9) * step}
    return vm.project(source, PROC, 'src', env)(NS())


class PipeMonitorTests(unittest.TestCase):
    def setUp(self):
        self.net = Network([Pump(True, True), Pump(True, False), Pump(False, True)])
        self.pipes = [Pipe(self.net, x) for x in range(2, 7)]
        self.net.pipes = DMList(self.pipes)
        self.networks = [self.net]

    def rows(self, **kwargs):
        return run(self.pipes, self.networks, **kwargs)

    def test_each_network_once_with_whole_network_counts(self):
        self.net.pipes.append(Pipe(self.net, 18))
        rows = self.rows()
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0][2:], [6, 1, 3, 'idle', 0])

    def test_running_and_idle_flow_are_last_step_not_rate(self):
        self.net.last_moved = 20
        self.assertEqual(self.rows()[0][5:], ['running', 20])
        self.net.idle_steps = 1
        self.assertEqual(self.rows()[0][5:], ['idle', 0])

    def test_independent_networks_and_unrelated_members(self):
        other = Network([NS()])
        p = Pipe(other, 8)
        other.pipes.append(p)
        self.pipes.append(p)
        self.networks.append(other)
        rows = self.rows()
        self.assertEqual(len(rows), 2)
        self.assertEqual(rows[1][2:], [1, 0, 0, 'idle', 0])

    def test_spatial_boundary_and_other_levels(self):
        for x, y, z, expected in [(10, 10, 1, 1), (11, 3, 1, 0), (3, 11, 1, 0), (3, 3, 2, 0)]:
            p = Pipe(self.net, x, y, z)
            self.net.pipes = DMList([p])
            self.assertEqual(len(run([p], self.networks)), expected)

    def test_dirty_or_unlocated_monitor_has_no_stale_rows(self):
        self.assertFalse(self.rows(dirty=True))
        self.assertFalse(self.rows(here=False))

    def test_removed_closed_deleted_and_contained_pipes_are_excluded(self):
        for field, value in [('open', False), ('deleted', True), ('loc', NS()), ('network', None)]:
            with self.subTest(field=field):
                p = Pipe(self.net)
                self.net.pipes = DMList([p])
                setattr(p, field, value)
                self.assertFalse(run([p], self.networks))
        self.net.pipes = DMList()
        self.assertFalse(self.rows())

    def test_unpublished_or_deleted_network_is_excluded(self):
        self.assertFalse(run(self.pipes, []))
        self.net.deleted = True
        self.assertFalse(self.rows())

    def test_deleted_unanchored_contained_pumps_not_counted(self):
        for field, value in [('deleted', True), ('anchored', False), ('loc', NS())]:
            bad = Pump(True, True)
            setattr(bad, field, value)
            self.net.members.append(bad)
        self.assertEqual(self.rows()[0][3:5], [1, 3])

    def test_observation_leaves_all_network_and_pump_state_unchanged(self):
        def snapshot():
            return (tuple(self.net.pipes), tuple(self.net.members), self.net.deleted,
                    self.net.idle_steps, self.net.last_moved,
                    tuple(tuple(p.__dict__.items()) for p in self.net.members))
        before = snapshot()
        for _ in range(3):
            self.rows()
        self.assertEqual(before, snapshot())
        body = vm.extract(SOURCE, PROC)
        for forbidden in ['network_step(', 'fluid_rebuild_networks(', 'pump_step(', 'draw_cable_power(', 'fluid_mark_dirty(']:
            self.assertNotIn(forbidden, body)

    def test_network_table_does_not_depend_on_item_rows(self):
        body = vm.extract(SOURCE, '/obj/structure/factory_monitor/proc/report_html')
        self.assertEqual(body.count('return out.Join()'), 1)
        self.assertIn('\n\tout += pipe_network_html()', body)
        self.assertLess(body.index('pipe_network_html()'), body.index('return out.Join()'))
        table = vm.extract(SOURCE, '/obj/structure/factory_monitor/proc/pipe_network_html')
        self.assertIn('html_encode(row[6])', table)
        self.assertIn('Units last step', table)
        self.assertIn('including pipes beyond', table)
        self.assertIn('fluid_networks_dirty', table)

    def test_missing_deduplication_negative_control(self):
        changed = SOURCE.replace(' || (N in seen)', '')
        self.assertNotEqual(changed, SOURCE)
        self.assertEqual(len(self.rows(source=changed)), 5)

    def test_missing_dirty_gate_negative_control(self):
        changed = SOURCE.replace('!here || fluid_networks_dirty', '!here')
        self.assertTrue(self.rows(source=changed, dirty=True))

    def test_missing_idle_gate_negative_control(self):
        changed = SOURCE.replace('!N.idle_steps && N.last_moved > 0', 'N.last_moved > 0')
        self.net.idle_steps = 2
        self.net.last_moved = 20
        self.assertEqual(self.rows(source=changed)[0][5:], ['running', 20])


if __name__ == '__main__':
    unittest.main()

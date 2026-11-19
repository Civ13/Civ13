"""Offline source-projected station selection; does not execute BYOND."""
from dataclasses import dataclass
from importlib.util import module_from_spec, spec_from_file_location
from pathlib import Path
from types import SimpleNamespace
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/modules/space/satellites.dm'
DECLARATION = '/proc/satellite_station_near'
spec = spec_from_file_location('source_adapter', ROOT / 'tests/save_movement/source_adapter.py')
adapter = module_from_spec(spec)
spec.loader.exec_module(adapter)


@dataclass(eq=False)
class Station:
    name: str
    distance: int
    z: int = 1
    loc: str = 'turf'
    deleted: bool = False
    comms: bool = False


def select(source, stations, *, distance_limit=7, has_turf=True):
    turf = SimpleNamespace(z=1) if has_turf else None
    calls = []
    def get_dist(station, target):
        assert target is turf
        calls.append(station.name)
        return station.distance
    env = dict(get_turf=lambda a: turf, satellite_stations=stations,
               typed_iter=lambda items, typ: (s for s in items if isinstance(s, Station)),
               QDELETED=lambda s: s.deleted, isturf=lambda loc: loc == 'turf',
               get_dist=get_dist)
    proc = adapter.project(source, DECLARATION, 'A, range', env)
    return proc(object(), distance_limit), calls


class SatelliteStationSelection(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = SOURCE.read_text(encoding='utf-8-sig')

    def test_empty_invalid_and_out_of_range(self):
        stations = [Station('deleted', 0, deleted=True), Station('container', 0, loc='box'),
                    Station('other-z', 0, z=2), Station('outside', 8)]
        self.assertEqual(select(self.source, stations), (None, ['outside']))
        self.assertEqual(select(self.source, stations, has_turf=False), (None, []))
        self.assertEqual(select(self.source, []), (None, []))

    def test_nearest_first_on_ties_and_inclusive_limit(self):
        far = Station('far', 7, comms=True)
        near = Station('near', 2)
        tied = Station('tied', 2, comms=True)
        best, calls = select(self.source, [far, near, tied])
        self.assertIs(best, near)  # Do not skip a closer station without comms.
        self.assertEqual(calls, ['far', 'near', 'tied'])
        self.assertIs(select(self.source, [far])[0], far)
        self.assertIsNone(select(self.source, [far], distance_limit=6)[0])
        self.assertIs(select(self.source, [near, tied])[0], near)
        self.assertIs(select(self.source, [tied, near])[0], tied)

    def test_threshold_and_tie_mutations_are_detected(self):
        a, b = Station('a', 7), Station('b', 7)
        for old, new in (('distance > range', 'distance >= range'),
                         ('distance < best_distance', 'distance <= best_distance')):
            with self.subTest(mutation=old):
                self.assertEqual(self.source.count(old), 1)
                mutated = self.source.replace(old, new, 1)
                self.assertIsNot(select(self.source, [a, b])[0], select(mutated, [a, b])[0])


if __name__ == '__main__':
    unittest.main()

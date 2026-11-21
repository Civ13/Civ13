"""Compare the production fallout scan with its frozen pre-change body offline.

Engine type checks, world iteration, random draws and effects are injected; this
is source control-flow evidence, not native DM behavior or performance evidence.
"""
import importlib.util
from pathlib import Path
from types import SimpleNamespace
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('source_adapter', ROOT / 'tests/save_movement/source_adapter.py')
vm = importlib.util.module_from_spec(spec)
spec.loader.exec_module(vm)
SOURCE = (ROOT / 'code/modules/1713/radiation.dm').read_text(encoding='utf-8')
BEFORE = (ROOT / 'tests/fallout_area_lookup/phase26_before.dm.txt').read_text(encoding='utf-8')


def phase26(source):
    start = source.index('\tif(phase == 26)\n')
    end = source.index('\t\tif (world.time <= last && duration > 0)', start)
    return source[start:end]


def projected(scan, atoms, events, lookups, outcomes):
    prefix = '\tif(phase == 26)\n'
    assert scan.startswith(prefix)
    body = scan[len(prefix):]
    body = '\n'.join(line[1:] for line in body.splitlines()) + '\n'
    assert body.count('for(var/atom/T)') == 1
    body = body.replace('for(var/atom/T)', 'for(var/atom/T in atom_world)')
    body = body.replace('var/mob/living/human/H', 'var/H')
    body = body.replace('var/obj/structure/window/W', 'var/W')
    for source_type, fake in [('/obj/structure/window', 'WINDOW'), ('/mob/living', 'LIVING'), ('/obj', 'OBJ')]:
        body = body.replace(source_type, fake)
    source = '/proc/phase26()\n' + body
    def get_area(atom):
        lookups.append(atom.name)
        return SimpleNamespace(location=atom.area)
    def prob(chance):
        value = next(outcomes)
        events.append(('prob', chance, value))
        return value
    env = {'atom_world': atoms, 'typed_iter': lambda values, kind: values,
           'get_area': get_area, 'prob': prob,
           'LIVING': 'living', 'OBJ': 'obj', 'WINDOW': 'window',
           'istype': lambda atom, kind: kind in atom.types,
           'ismob': lambda atom: 'mob' in atom.types,
           'ishuman': lambda atom: 'human' in atom.types,
           'flick': lambda effect, target: events.append(('flick', effect, target)),
           'event_z': 1, 'severity': 300}
    vm.project(source, '/proc/phase26', '', env)()


class Hud(dict):
    def Find(self, name):
        return name in self


class Atom:
    def __init__(self, name, types, z, events, *, area=0, dense=False, flash=False):
        self.name, self.types, self.z, self.events = name, set(types), z, events
        self.area, self.density = area, dense
        self.HUDtech = Hud({'flash': name + '-hud'} if flash else {})
    def rad_act(self, dose): self.events.append(('radiation', self.name, dose))
    def Weaken(self, time): self.events.append(('weaken', self.name, time))
    def shatter(self): self.events.append(('shatter', self.name))
    def ex_act(self, severity): self.events.append(('explosion', self.name, severity))


def run(scan):
    events, lookups = [], []
    atoms = [
        Atom('turf', {'turf'}, 1, events),
        Atom('remote-mob', {'mob', 'living'}, 2, events),
        Atom('indoor-human', {'mob', 'living', 'human'}, 1, events, area=0, flash=True),
        Atom('outdoor-human', {'mob', 'living', 'human'}, 1, events, area=1),
        Atom('animal', {'mob', 'living'}, 1, events, area=1),
        Atom('remote-window', {'obj', 'window'}, 2, events, dense=True),
        Atom('window', {'obj', 'window'}, 1, events, dense=True),
        Atom('remote-object', {'obj'}, 2, events, dense=True),
        Atom('loose-object', {'obj'}, 1, events),
        Atom('dense-object', {'obj'}, 1, events, dense=True),
        Atom('dense-object-2', {'obj'}, 1, events, dense=True),
    ]
    projected(scan, atoms, events, lookups, iter([True, False, True, False]))
    return events, lookups


class FalloutScanTests(unittest.TestCase):
    def test_effects_and_random_draws_match_original(self):
        before, old_lookups = run(BEFORE)
        after, new_lookups = run(phase26(SOURCE))
        self.assertEqual(after, before)
        self.assertEqual(len(old_lookups), 11)
        self.assertEqual(new_lookups, ['indoor-human', 'outdoor-human', 'animal'])
        self.assertIn(('radiation', 'indoor-human', 3), after)
        self.assertIn(('radiation', 'outdoor-human', 10), after)
        self.assertIn(('shatter', 'window'), after)
        self.assertIn(('explosion', 'dense-object', 1.0), after)

    def test_rng_order_negative_control_is_detected(self):
        scan = phase26(SOURCE)
        anchor = 'if (prob(20) && T.density && T.z == event_z)'
        self.assertEqual(scan.count(anchor), 1)
        altered = scan.replace(anchor, 'if (T.density && T.z == event_z && prob(20))')
        self.assertNotEqual(run(altered)[0], run(BEFORE)[0])


if __name__ == '__main__':
    unittest.main()

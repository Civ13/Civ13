"""A chemical cloud doses atoms already inside it when created (issue #6728).

The production initial_splash body runs through the shared source adapter.
view(), the cloud's reagent holder and type checks are test boundaries.
"""
from pathlib import Path
import re
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tests/save_movement'))
from source_adapter import extract, project

CHEM = (ROOT / 'code/game/objects/effects/chem/chemsmoke.dm').read_text(encoding='utf-8')
EFFECTS = (ROOT / 'code/game/objects/effects/effect_system.dm').read_text(encoding='utf-8')
DECL = '/obj/effect/effect/smoke/chem/proc/initial_splash'
SMOKE = '/obj/effect/effect/smoke/chem'
CONTAINER = '/obj/item/weapon/reagent_containers'


def projected_source():
    body = extract(CHEM, DECL)
    body = re.sub(r'istype\((\w+), (/[\w/]+)\)', r'istype(\1, "\2")', body)
    body = body.replace('"\\ref[AM]"', 'ref(AM)')
    body = re.sub(r'(?<![\w.])(reagents|splash_amount)\b', r'src.\1', body)
    return DECL + '(splashed_keys = null)\n' + body


class DMList(dict):
    # A DM list is a true reference even while empty.
    def __bool__(self):
        return True

    def __missing__(self, key):
        return None  # an absent associative key reads as null


class Atom:
    def __init__(self, *types):
        self.types = types


class Reagents:
    def __init__(self, volume=500):
        self.total_volume, self.doses = volume, []

    def splash(self, target, amount, copy=False):
        self.doses.append((target, amount, copy))


class Cloud:
    def __init__(self, turfs, volume=500):
        self.turfs, self.reagents, self.splash_amount = turfs, Reagents(volume), 10


def run(cloud, keys=None):
    env = {'istype': lambda atom, path: path in atom.types, 'ref': lambda atom: id(atom),
           'view': lambda dist, centre: centre.turfs,
           'typed_iter': lambda items, path: list(items)}
    project(projected_source(), DECL, 'src, splashed_keys = None', env)(cloud, keys)


class InitialSplash(unittest.TestCase):
    def test_stationary_human_in_new_cloud_is_dosed(self):
        human = Atom()
        cloud = Cloud([[human]])
        run(cloud)
        self.assertEqual(cloud.reagents.doses, [(human, 10, True)])

    def test_smoke_and_containers_stay_excluded(self):
        cloud = Cloud([[Atom(SMOKE), Atom(CONTAINER)]])
        run(cloud)
        self.assertEqual(cloud.reagents.doses, [])

    def test_wave_of_particles_doses_each_atom_once(self):
        human, other = Atom(), Atom()
        keys = DMList()
        clouds = [Cloud([[human], [other]]) for _ in range(10)]
        for cloud in clouds:
            run(cloud, keys)
        doses = [d[0] for c in clouds for d in c.reagents.doses]
        self.assertEqual(sorted(map(id, doses)), sorted([id(human), id(other)]))

    def test_empty_cloud_doses_nothing(self):
        cloud = Cloud([[Atom()]], volume=0)
        run(cloud)
        self.assertEqual(cloud.reagents.doses, [])

    def test_generic_wave_shares_keys_and_splashes_on_creation(self):
        start = extract(EFFECTS, '/datum/effect/effect/system/smoke_spread/start')
        shared = start.index('var/list/splashed_keys = list()')
        loop = start.index('for (i=0, i<number, i++)')
        created = start.index('PoolOrNew(smoke_type, location)')
        splash = start.index('initial_splash(splashed_keys)')
        self.assertLess(shared, loop)
        self.assertLess(created, splash)
        self.assertLess(splash, start.index('step(smoke,src_direction)'))


if __name__ == '__main__':
    unittest.main()

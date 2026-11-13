"""Source contracts for the shared fragment ring.

Fragment grenades (modern, WW2, cold war), mines and bomb payloads each
copied the same fragment loop. original_modern_prime.dm.txt freezes one
grenade copy; fragment_burst and /obj/item/weapon/grenade/frag_detonate in
grenade.dm now hold the only loop.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
GRENADE = ROOT / 'code/game/objects/items/weapons/grenades/grenade.dm'
MINES = ROOT / 'code/game/objects/items/weapons/mines.dm'
LIGHT = {'modern': 3, 'ww2': 3, 'coldwar': 4}


def proc_body(source, header):
    match = re.search(r'(?m)^' + re.escape(header) + r'.*\n((?:\t.*\n|[ \t]*\n)*)', source + '\n')
    return match.group(1) if match else None


def normalise(body):
    out = []
    for line in body.splitlines():
        line = re.sub(r'//.*', '', line).strip()
        if line:
            out.append(line)
    return out


def errors(grenade, mines):
    found = []
    for name, light in LIGHT.items():
        body = proc_body(grenade, f'/obj/item/weapon/grenade/{name}/prime()')
        if body is None or normalise(body) != ['set waitfor = 0', '..()', f'frag_detonate({light})']:
            found.append(f'{name} prime must call frag_detonate({light})')
    burst = proc_body(grenade, '/proc/fragment_burst(')
    if burst is None:
        return found + ['fragment_burst missing']
    for line in ('var/obj/item/projectile/bullet/pellet/fragment/P = new fragment_type(T)', 'P.damage = fragment_damage',
                 'P.pellets = fragments_per_projectile', 'P.range_step = damage_step', 'P.launch_fragment(TT)',
                 'var/fragments_per_projectile = round(num_fragments/target_turfs.len)', 'P.attack_mob(L, 0, 0)'):
        if line not in burst:
            found.append(f'fragment_burst lost: {line}')
    detonate = proc_body(grenade, '/obj/item/weapon/grenade/proc/frag_detonate(')
    if detonate is None or 'fragment_burst(T, fragment_type, num_fragments, fragment_damage, damage_step, spread_range, name, TRUE)' not in detonate:
        found.append('frag_detonate must fire one ring that hits mobs on the source turf')
    for source, label in ((grenade, 'grenade.dm'), (mines, 'mines.dm')):
        copies = source.count('round(num_fragments/target_turfs.len)')
        if copies != (1 if label == 'grenade.dm' else 0):
            found.append(f'{label} has {copies} copies of the fragment loop')
    if 'fragment_burst(T, fragment_type, num_fragments, fragment_damage, damage_step, spread_range, name)' not in mines:
        found.append('mines must use fragment_burst')
    if 'fragment_burst(T, fragment_type, num_fragments, fragment_damage, damage_step, spread_range, name)' not in proc_body(grenade, '/obj/structure/payload/proc/explode()'):
        found.append('payloads must use fragment_burst')
    return found


class FragmentBurstTest(unittest.TestCase):
    def setUp(self):
        self.grenade = GRENADE.read_text(encoding='utf-8')
        self.mines = MINES.read_text(encoding='utf-8')

    def test_shared_ring(self):
        self.assertEqual(errors(self.grenade, self.mines), [])

    def test_shared_detonation_matches_frozen_grenade(self):
        original = normalise((HERE / 'original_modern_prime.dm.txt').read_text(encoding='utf-8'))
        detonate = normalise(proc_body(self.grenade, '/obj/item/weapon/grenade/proc/frag_detonate('))
        burst = normalise(proc_body(self.grenade, '/proc/fragment_burst('))
        # Blast, held check and delayed delete are unchanged.
        for line in ('var/turf/T = get_turf(src)', 'if(!T) return', 'if(explosion_size)', 'damage_hull(T)',
                     'if (!ismob(loc))', 'spawn (5)', 'qdel(src)'):
            self.assertIn(line, original)
            self.assertIn(line, detonate)
        self.assertIn('explosion(T,1,1,3,1,sound=explosion_sound)', original)
        self.assertIn('explosion(T,1,1,light_range,1,sound=explosion_sound)', detonate)
        # The ring sets the same projectile fields in the same order.
        fields = [l for l in original if l.startswith('P.')]
        self.assertEqual([l.replace('shot_from = name', 'shot_from = shot_from') for l in fields],
                         [l for l in burst if l.startswith('P.')])

    def test_detects_reintroduced_copy(self):
        original = (HERE / 'original_modern_prime.dm.txt').read_text(encoding='utf-8')
        changed = self.grenade.replace(proc_body(self.grenade, '/obj/item/weapon/grenade/ww2/prime()'), original.split('\n', 1)[1], 1)
        self.assertTrue(errors(changed, self.mines))

    def test_detects_wrong_blast(self):
        changed = self.grenade.replace('frag_detonate(4)', 'frag_detonate(3)', 1)
        self.assertTrue(errors(changed, self.mines))


if __name__ == '__main__':
    unittest.main()

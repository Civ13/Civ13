"""Audited source projection with simulated wait/engine effects, not native evidence."""
from pathlib import Path
from types import SimpleNamespace
import unittest

ROOT = Path(__file__).resolve().parents[2]
CAVES = ROOT / 'code/game/objects/structures/animalspawner'

def body(source, declaration):
    text = source.split(declaration, 1)[1].split('\n', 1)[1]
    return text.split('\n/obj/', 1)[0]

def project(source):
    mapping = {
        'if(!istype(W, /obj/item/weapon/material/pickaxe) || !can_dismantle())': 'if not W or not can_dismantle(src):',
        'return ..()': 'return parent(src)',
        'if(dismantling)': 'if src.dismantling:',
        'return': 'return',
        'dismantling = TRUE': 'src.dismantling = True',
        'var/completed = do_after(user, 65, src)': 'completed = wait(src, 65)',
        'if(QDELETED(src))': 'if src.deleted:',
        'if(!completed || !can_dismantle())': 'if not completed or not can_dismantle(src):',
        'dismantling = FALSE': 'src.dismantling = False',
        'to_chat(user, "<span class=\'notice\'>You break apart \\the [src].</span>")': 'src.messages += 1',
        'for(var/i = 1, i <= 10, i++)': 'for i in range(1, 11):',
        'new /obj/item/stack/material/stone(loc)': 'src.stones += 1',
        'qdel(src)': 'src.deleted = True',
    }
    predicate = body(source, '/obj/structure/animalspawner/proc/can_dismantle()').strip()
    expected = 'return !QDELETED(src) && empty && !total_population && !males && !females && !cubs'
    if predicate != expected:
        raise AssertionError('unreviewed eligibility predicate')
    lines = ['def attack(src, W=True):']
    for line in body(source, '/obj/structure/animalspawner/attackby(').splitlines():
        if not line.strip() or line.strip().startswith('//'):
            continue
        if line.strip() not in mapping:
            raise AssertionError('unreviewed operation: ' + line)
        lines.append('    ' * (len(line) - len(line.lstrip('\t'))) + mapping[line.strip()])
    env = {'can_dismantle': lambda c: not c.deleted and c.empty and not any((c.total_population, c.males, c.females, c.cubs)),
           'parent': lambda c: setattr(c, 'parents', c.parents + 1)}
    exec('\n'.join(lines), env)
    return env

def cave():
    return SimpleNamespace(deleted=False, empty=True, total_population=0, males=0, females=0, cubs=0,
                           dismantling=False, stones=0, messages=0, parents=0)

class Dismantling(unittest.TestCase):
    def setUp(self):
        self.source = (CAVES / 'animal_spawner.dm').read_text()
        self.env = project(self.source)
        self.waits = []
        self.env['wait'] = lambda c, ticks: self.waits.append(ticks) or True

    def test_empty_cave_yields_ten_once(self):
        c = cave(); self.env['attack'](c); self.env['attack'](c)
        self.assertEqual((c.stones, c.messages, self.waits), (10, 1, [65]))
        self.assertTrue(c.deleted)

    def test_wrong_tool_and_population_never_wait(self):
        for field in ('empty', 'total_population', 'males', 'females', 'cubs'):
            c = cave(); setattr(c, field, False if field == 'empty' else 1)
            self.env['attack'](c)
            self.assertEqual((c.stones, c.parents), (0, 1))
        c = cave(); self.env['attack'](c, False)
        self.assertEqual(c.parents, 1); self.assertEqual(self.waits, [])

    def test_interruption_releases_owner_for_retry(self):
        c = cave(); self.env['wait'] = lambda c, ticks: False
        self.env['attack'](c); self.assertFalse(c.dismantling)
        self.assertEqual(c.stones, 0)
        self.env['wait'] = lambda c, ticks: True
        self.env['attack'](c); self.assertEqual(c.stones, 10)

    def test_population_or_deletion_during_wait_awards_nothing(self):
        for field in ('deleted', 'empty', 'total_population', 'males', 'females', 'cubs'):
            c = cave()
            def wait(c, ticks):
                setattr(c, field, False if field == 'empty' else 1)
                return True
            self.env['wait'] = wait; self.env['attack'](c)
            self.assertEqual(c.stones, 0, field)

    def test_second_miner_cannot_enter_wait(self):
        c = cave()
        def wait(c, ticks):
            self.waits.append(ticks)
            self.env['attack'](c)
            return True
        self.env['wait'] = wait; self.env['attack'](c)
        self.assertEqual((self.waits, c.stones), ([65], 10))

    def test_species_only_aggression_then_one_parent(self):
        for species in ('bearcave', 'wolfcave'):
            code = body((CAVES / (species + '.dm')).read_text(), '/obj/structure/animalspawner/' + species + '/attackby(')
            code = code.replace('src.', '').strip()
            self.assertEqual(code, 'if(!aggroed)\n\t\taggro()\n\treturn ..()')

    def test_runtime_owner_excluded_and_wolf_chains_parent(self):
        self.assertIn('var/tmp/dismantling = FALSE', self.source)
        self.assertIn('return key == "dismantling" || ..()', self.source)
        self.assertIn('return key == "ticking" || ..()', (CAVES/'wolfcave.dm').read_text())

    def test_negative_control_without_recheck_awards_invalid_population(self):
        # Remove the actual production post-wait block to demonstrate coverage sensitivity.
        mutant = self.source.replace('\tif(!completed || !can_dismantle())\n\t\tdismantling = FALSE\n\t\treturn\n', '')
        env = project(mutant); c = cave()
        env['wait'] = lambda c, ticks: setattr(c, 'cubs', 1) or True
        env['attack'](c)
        self.assertEqual(c.stones, 10)

if __name__ == '__main__': unittest.main()

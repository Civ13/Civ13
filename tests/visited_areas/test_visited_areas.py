"""Visit tracking and the wildlife a save leaves out: source wiring.

The native probe is developer evidence, outside the offline suite (about 20 s):
python3 tests/visited_areas/run.py
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


def read(relative):
    return (ROOT / relative).read_text(encoding='utf-8')


class VisitedAreasSources(unittest.TestCase):
    def test_module_is_compiled(self):
        self.assertIn('#include "code\\modules\\persistence\\visited_areas.dm"', read('civ13.dme'))

    def test_record_rides_with_the_round_state(self):
        saving = read('code/modules/persistence/saving.dm')
        self.assertIn('if(visited) round_state["visited"] = visited', saving)
        self.assertIn('visited_loaded(transfer_round_state)', read('code/modules/persistence/loading.dm'))
        functions = read('code/modules/persistence/functions.dm')
        self.assertIn('if(has_visited && !valid_visited_record(state["visited"]', functions)

    def test_save_leaves_skipped_wildlife_out_everywhere_it_decides(self):
        saving = read('code/modules/persistence/saving.dm')
        build = saving[saving.index('/map_storage/proc/BuildVarDirectory('):]
        self.assertIn('if(ismob(A) && save_skips_wildlife(A))\n\t\treturn 0', build[:build.index('saving_world_movables[A]')])
        self.assertIn('(ismob(target) && save_skips_wildlife(target))', saving)
        plain = saving[saving.index('/map_storage/proc/plain_cell_fields('):]
        self.assertIn('(ismob(M) && save_skips_wildlife(M))', plain[:plain.index('\n/')])

    def test_only_repopulated_wild_animals_are_left_out(self):
        visited = read('code/modules/persistence/visited_areas.dm')
        skip = visited[visited.index('/map_storage/save_skips_wildlife('):]
        for needle in ('ecology_wild_animal(animal)', 'visited_chunk(animal.x, animal.y, animal.z)', 'wildlife_repopulated(animal.type)', 'isturf(A.loc)', '!persistence_visited_since'):
            self.assertIn(needle, skip)


if __name__ == '__main__':
    unittest.main()

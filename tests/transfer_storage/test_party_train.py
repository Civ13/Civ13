"""Source contracts for the party train station project. Never launches BYOND."""
import os
import re
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def read(path):
    with open(os.path.join(ROOT, path), encoding='utf-8-sig') as f:
        return f.read().replace('\r\n', '\n')


def proc(source, name):
    start = source.index('\n' + name + '(') + 1
    end = re.search(r'\n(?=[^\s#])', source[start + 1:])
    return source[start:start + 1 + end.start()] if end else source[start:]


TRAIN = read('code/modules/persistence/party_train.dm')
OFFICE = '/obj/structure/region_gate/railway_station'


class PartyTrainTests(unittest.TestCase):
    def test_built_from_the_crafting_menu_and_included_after_the_gate(self):
        recipes = read('config/crafting/material_recipes_global.txt')
        self.assertRegex(recipes, r'(?m)^RECIPE: /material/wood/,railway works office,' + re.escape(OFFICE) + ',')
        dme = read('civ13.dme')
        self.assertLess(dme.index('region_travel.dm"'), dme.index('party_train.dm"'))

    def test_a_station_needs_straight_track(self):
        start = proc(TRAIN, OFFICE + '/proc/start')
        self.assertLess(start.index('station_problem()'), start.index('party = new_party'))
        self.assertIn('party_train_run_through(T) >= PARTY_TRAIN_TRACK_MIN', proc(TRAIN, OFFICE + '/proc/station_problem'))

    def test_one_project_per_party_rechecked_after_the_prompt(self):
        start = proc(TRAIN, OFFICE + '/proc/start')
        prompt = start.index('alert(')
        self.assertLess(start.index('party_train_office_of(new_party, src)'), prompt)
        self.assertGreater(start.index('party_train_office_of(new_party, src)', prompt), prompt)

    def test_closed_until_every_material_is_delivered(self):
        closed = proc(TRAIN, OFFICE + '/closed_reason')
        self.assertLess(closed.index('if(!completed)'), closed.index('return ..()'))
        give = proc(TRAIN, OFFICE + '/attackby')
        # Only what is still missing is taken, and completion follows the last delivery.
        self.assertIn('min(missing, S.amount)', give)
        self.assertLess(give.index('S.use(amount)'), give.index('complete(user)'))
        self.assertIn('if(!length(remaining()))', give)

    def test_only_the_party_boards_and_only_to_the_rail_yard(self):
        refusal = proc(TRAIN, OFFICE + '/travel_refusal')
        self.assertIn('party_train_party_of(H) != party', refusal)
        self.assertIn('peer["kind"] == "RAILYARD"', proc(TRAIN, OFFICE + '/proc/rail_yard'))
        self.assertIn(OFFICE + '/accepts_arrivals()\n\treturn FALSE', TRAIN)

    def test_progress_is_saved(self):
        saved = re.search(r'map_storage_saved_vars = "([^"]+)"', TRAIN).group(1).split(';')
        for var in ('party', 'delivered', 'completed', 'completed_at'):
            self.assertIn(var, saved)

    def test_rail_yard_is_a_region_kind(self):
        self.assertIn("'RAILYARD'", read('scripts/shard-group/shard_group.py'))
        self.assertIn('"RAILYARD"', read('code/modules/persistence/shard_group.dm'))


if __name__ == '__main__':
    unittest.main()

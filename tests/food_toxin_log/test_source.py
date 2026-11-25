"""Offline wiring checks for food toxins and contamination provenance."""
from pathlib import Path
import importlib.util
import re
from types import SimpleNamespace as State
import unittest

ROOT = Path(__file__).resolve().parents[2]


def read(path):
    return (ROOT / path).read_text(encoding="utf-8")


class FoodToxinLogWiring(unittest.TestCase):
    def test_every_swallow_is_checked_after_the_transfer(self):
        ingest = read("code/game/mob/living/carbon/taste.dm").split("/mob/living/human/proc/ingest(", 1)[1]
        transfer = ingest.index("from.trans_to_holder(target,amount,multiplier,copy)")
        hook = ingest.index("log_food_toxin(src, from.my_atom, toxins, food_toxin_cause(from.my_atom)")
        self.assertLess(transfer, hook)
        self.assertIn("var/list/toxins = food_toxin_amounts(temp)", ingest)

    def test_raw_bite_roll_keeps_its_odds_and_logs_only_hits(self):
        consume = read("code/modules/reagents/reagent_containers/food/snacks.dm").split("/proc/On_Consume(", 1)[1].split("\n/", 1)[0]
        self.assertIn("var/raw_poison = pick(0,0,1)", consume)
        roll = consume.split("var/raw_poison = pick(0,0,1)", 1)[1]
        self.assertLess(roll.index("if (raw_poison)"), roll.index('H.reagents.add_reagent("food_poisoning", raw_poison)'))
        self.assertIn('log_food_toxin(H, src, list("food_poisoning" = raw_poison)', roll)

    def test_contamination_sites_record_their_cause(self):
        for path, note in (
            ("code/modules/reagents/reagent_containers/food.dm", 'note_food_toxin("rotted while decaying")'),
            ("code/game/objects/structures/watercloset.dm", 'RG.note_food_toxin("puddle water (1 in 10 fill roll)")'),
            ("code/game/mob/living/simple_animal/simple_ai.dm", 'meat.note_food_toxin("zombie meat")'),
            ("code/game/objects/structures/watercloset.dm", 'RG.note_food_toxin(dirty ? "unboiled water from a dirty [name]'),
            ("code/modules/1713/factory_pipes.dm", 'note_food_toxin("unboiled [W.name] water drawn by [name] at ([x],[y],[z])")'),
            ("code/modules/1713/factory_pipes.dm", "fluid_carry_toxin_origin(S, R, D)"),
        ):
            with self.subTest(path=path):
                self.assertIn(note, read(path))

    def test_transfers_carry_the_origin_only_with_a_toxin(self):
        holder = read("code/modules/reagents/Chemistry-Holder.dm").split("/datum/reagents/proc/trans_to_holder(", 1)[1].split("\n/", 1)[0]
        self.assertIn("if (istype(current, /datum/reagent/toxin))", holder)
        self.assertIn("if (carried_toxin && isobj(my_atom) && isobj(target.my_atom) && my_atom != target.my_atom)", holder)
        self.assertIn("food_toxin_cause(my_atom, TRUE)", holder)

    def test_agents_can_read_the_food_log(self):
        actions = read("code/modules/agent_control/agent_actions.dm").split("/datum/agent_control/proc/act_logs(", 1)[1].split("\n/", 1)[0]
        self.assertIn('req["kind"] == "food"', actions)
        self.assertIn("food_toxin_log", actions)
        catalog = read("tools/agent-control/catalog.py")
        self.assertIn('"kind": {"type": "string", "enum": ["admin", "food"]}', catalog)


class CarcassRadiationWiring(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        spec = importlib.util.spec_from_file_location(
            'carcass_source_adapter', ROOT / 'tests/save_movement/source_adapter.py')
        cls.adapter = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.adapter)

    def assign_radiation(self, source, out, **environment):
        effects = re.findall(r'^\t+' + out + r'\.radiation = [^\n]+', source, re.M)
        self.assertTrue(effects, f'No radiation is copied onto {out}')
        for effect in effects:
            output = State(radiation=0)
            env = {**environment, out: output}
            # Run the real transfer expression, without constructing world objects.
            assign = self.adapter.project('/proc/radiation()\n\t' + effect.strip(), '/proc/radiation', '', env)
            assign()
            yield output.radiation

    def test_chicken_receives_half_at_harvest_then_every_part_gets_the_same_dose(self):
        harvest = self.adapter.extract(read('code/modules/1713/animal_harvest.dm'),
                                       '/mob/living/simple_animal/proc/harvest_products')
        chicken = harvest.split('else if (chicken)', 1)[1].split('\n\telse\n', 1)[0]
        self.assertIn('for (var/i = 1, i <= portions, i++)', chicken)
        cutter = self.adapter.extract(read('code/modules/1713/complex_production.dm'),
                                      '/obj/item/weapon/chicken_carcass/attackby')
        parts = re.findall(r'/snacks/chicken/(\w+)', cutter.split('var/obj/item', 1)[0])
        self.assertEqual(parts, ['breast', 'wing', 'drumstick'])
        self.assertIn('part.radiation = radiation', cutter)
        self.assertLess(cutter.index('if (do_after(user, 75, src))'), cutter.index('part.radiation = radiation'))
        self.assertLess(cutter.index('part.radiation = radiation'), cutter.index('qdel(src)'))
        for living_dose, expected in ((80, 40), (0, 0)):
            carcass_dose, = self.assign_radiation(chicken, 'carcass', radiation=living_dose)
            part_dose, = self.assign_radiation(cutter, 'part', radiation=carcass_dose)
            self.assertEqual([part_dose] * len(parts), [expected] * 3)

    def test_predator_outputs_take_prey_dose_for_all_existing_meats(self):
        feed = self.adapter.extract(read('code/game/mob/living/simple_animal/simple_ai.dm'),
                                    '/mob/living/simple_animal/proc/check_food')
        rip = feed.split('if (predatory_carnivore)', 1)[1].split('\n\tif (scavenger)', 1)[0]
        self.assertIn('meat.name = "rotten zombie meat"', rip)
        self.assertIn('meat.name = "[ML.name] meat"', rip)
        self.assertIn('snacks/rawcrab/meat', rip)
        self.assertEqual(rip.count('for (var/i=0, i<=namt, i++)'), 3)
        self.assertIn('bone = new(get_turf(src), amt-2, FALSE)', rip)
        self.assertIn('bone.name = "[ML.name] bone"', rip)
        for prey, predator, expected in ((80, 0, 40), (0, 80, 0)):
            env = dict(ML=State(radiation=prey), radiation=predator)
            self.assertEqual(list(self.assign_radiation(rip, 'meat', **env)), [expected] * 3)
            self.assertEqual(list(self.assign_radiation(rip, 'bone', **env)), [expected])


if __name__ == "__main__":
    unittest.main()

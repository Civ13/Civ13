"""Offline wiring checks: every route that puts a toxin into a human is logged."""
from pathlib import Path
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


if __name__ == "__main__":
    unittest.main()

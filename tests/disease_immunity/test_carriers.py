"""Source checks for illness carried in blood and meat, bed rest, intestinal
worms and the handbook's treatment line.

A sick person's blood and raw flesh carried nothing, beds did not help an
illness, there were no parasites, and the doctor's handbook named an illness
without saying how to treat it.
"""
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
HUMAN = "code/game/mob/living/carbon/human/"


def read(path):
    return (ROOT / path).read_text(encoding="utf-8")


def proc(text, header):
    body = text.split(header, 1)[1]
    end = re.search(r"\n(?=[/#])", body)
    return body[: end.start()] if end else body


class Carriers(unittest.TestCase):
    def setUp(self):
        self.severe = read(HUMAN + "severe_disease.dm")

    def test_blood_carries_germs_but_not_flu(self):
        carried = proc(self.severe, "/mob/living/human/proc/carried_germ(")
        self.assertIn('if ("cholera", "typhus", "plague")', carried)
        self.assertIn('return meat ? null : "malaria"', carried)
        self.assertIn('return meat ? "worm_eggs" : null', carried)
        self.assertNotIn('"flu"', carried)
        blood = read("code/modules/organs/blood.dm")
        self.assertIn("container.reagents.add_reagent(germ, amount * 0.1)", blood)

    def test_butchered_sick_body_meat_carries_germs(self):
        defense = read(HUMAN + "human_defense.dm")
        self.assertIn("var/germ = carried_germ(TRUE)", defense)
        self.assertIn("meat.reagents.add_reagent(germ, 2)", defense)
        cutlet = proc(read("code/modules/reagents/reagent_containers/food/snacks/meat.dm"),
                      "/obj/item/weapon/reagent_containers/food/snacks/proc/prepare_meat_cutlet(")
        self.assertIn("cutlet.reagents.add_reagent(germ, amount / 2)", cutlet)

    def test_cooking_kills_every_germ(self):
        kill = proc(self.severe, "/datum/reagents/proc/kill_germs()")
        self.assertIn("for (var/germ in germ_reagent_disease)", kill)
        for germ in ("cholera", "typhus", "plague", "worm_eggs", "malaria"):
            self.assertIn(f'"{germ}" = ', self.severe)
        for path, count in (("oven.dm", 3), ("pot.dm", 2), ("cooked_meals.dm", 1)):
            text = read("code/game/objects/structures/kitchen/" + path)
            self.assertEqual(text.count("reagents.kill_germs()"), count, path)
            self.assertNotIn('del_reagent("cholera")', text)

    def test_malaria_in_blood_only_and_worm_eggs_in_gut_only(self):
        toxins = read("code/modules/reagents/Chemistry-Reagents/Chemistry-Reagents-Toxins.dm")
        swallowed = re.search(r"var/global/list/swallowed_germs = list\(([^)]*)\)", self.severe).group(1)
        self.assertEqual(sorted(re.findall(r'"(\w+)"', swallowed)), ["cholera", "plague", "typhus", "worm_eggs"])
        for kind in ("malaria", "worm_eggs"):
            body = proc(toxins, f"/datum/reagent/toxin/{kind}/affect_ingest(")
            self.assertEqual(body.strip().splitlines()[-1].strip(), "return")
        self.assertIn('H.catch_disease("malaria")', proc(toxins, "/datum/reagent/toxin/malaria/affect_blood("))
        self.assertEqual(proc(toxins, "/datum/reagent/toxin/worm_eggs/affect_blood(").strip().splitlines()[-1].strip(), "return")

    def test_dirty_water_also_brings_worms(self):
        swallow = proc(self.severe, "/mob/living/human/proc/swallow_germs(")
        self.assertIn('swallowed.get_reagent_amount("cholera")', swallow)
        self.assertIn("DIRTY_WATER_WORMS", swallow)
        drink = proc(self.severe, "/mob/living/human/proc/catch_dirty_water_illness(")
        self.assertIn('catch_disease("worms")', drink)
        self.assertIn('find_trait("Strong Immune System")', drink)
        for path, count in (("code/game/turfs/floor_attackby.dm", 1), ("code/modules/1713/trench.dm", 2),
                            ("code/game/objects/structures/watercloset.dm", 1)):
            text = read(path)
            self.assertEqual(text.count("H.catch_dirty_water_illness("), count, path)
            self.assertNotIn('H.disease_type ="cholera"', text)


class BedRest(unittest.TestCase):
    def test_bed_doubles_resistance_but_chairs_do_not(self):
        severe = read(HUMAN + "severe_disease.dm")
        bed = proc(severe, "/mob/living/human/proc/resting_in_bed()")
        self.assertLess(bed.index("/obj/structure/bed/chair"), bed.index("istype(buckled, /obj/structure/bed)"))
        immunity = read(HUMAN + "immunity.dm")
        self.assertIn("if (resting_in_bed())\n\t\tgain *= 2", immunity)
        flu = read(HUMAN + "human_disease.dm")
        self.assertIn("flu_step = resting_in_bed() ? 1 : 0.5", flu)
        # The fever onset must still fire when the step skips 25 exactly.
        self.assertIn("disease_progression >= 25 && disease_progression - flu_step < 25", flu)


class Worms(unittest.TestCase):
    def setUp(self):
        self.src = read(HUMAN + "intestinal_worms.dm")

    def define(self, name):
        return float(re.search(rf"#define {name} ([\d.]+)", self.src).group(1))

    def test_worms_run_before_other_illness_and_are_included(self):
        disease = read(HUMAN + "human_disease.dm")
        self.assertLess(disease.index("handle_severe_disease()"), disease.index("handle_worms()"))
        self.assertLess(disease.index("handle_worms()"), disease.index("acquire_nearby_disease()"))
        self.assertIn('#include "code\\game\\mob\\living\\carbon\\human\\intestinal_worms.dm"', read("civ13.dme"))

    def test_worms_build_no_resistance_and_do_not_spread(self):
        immunity = read(HUMAN + "immunity.dm")
        builds = proc(immunity, "/mob/living/human/proc/builds_disease_immunity(")
        self.assertNotIn("worms", builds)
        contagious = re.search(r"contagious_diseases = list\(([^)]*)\)", read(HUMAN + "severe_disease.dm")).group(1)
        self.assertNotIn("worms", contagious)

    def test_course_and_natural_clearing_times(self):
        course = self.define("WORMS_COURSE")
        # Chewed healing herbs give 0.3 a tick: under four minutes of remedy.
        self.assertLessEqual(course / 0.3, 240)
        clear = self.define("WORMS_CLEAR")
        self.assertEqual(clear / 60, 90)  # minutes untreated, half that in bed
        self.assertIn("disease_progression += resting_in_bed() ? 2 : 1", self.src)
        pain = self.define("WORMS_PAIN")
        self.assertLess(pain, 30)  # below the severe illness ache

    def test_cures_penicillin_does_not(self):
        severe = read(HUMAN + "severe_disease.dm")
        treat = proc(severe, "/mob/living/human/proc/receive_disease_treatment(")
        self.assertIn('disease_type == "worms"', treat)
        medicine = read("code/modules/reagents/Chemistry-Reagents/Chemistry-Reagents-Medicine.dm")
        penicillin = proc(medicine, "/datum/reagent/penicillin/affect_blood(")
        self.assertNotIn("worms", penicillin)
        drinks = read("code/modules/reagents/Chemistry-Reagents/Chemistry-Reagents-Food-Drinks.dm")
        absinthe = proc(drinks, "/datum/reagent/ethanol/absinthe/affect_ingest(")
        self.assertIn('M.disease_type == "worms"', absinthe)
        self.assertIn("M.receive_disease_treatment(1)", absinthe)

    def test_wild_meat_sometimes_has_worms(self):
        harvest = proc(read("code/modules/1713/animal_harvest.dm"), "/mob/living/simple_animal/proc/harvest_food(")
        self.assertIn('F.reagents.add_reagent("worm_eggs", 1)', harvest)
        self.assertIn("prob(10)", harvest)


class Handbook(unittest.TestCase):
    def test_handbook_names_the_cure_and_drops_wrong_claims(self):
        book = read("code/modules/1713/doctor_handbook.dm")
        self.assertIn("var/cure = disease_cure_text(H.disease_type)", book)
        cures = proc(book, "/proc/disease_cure_text(")
        for kind in ("flu", "plague", "malaria", "worms", "zombie"):
            self.assertIn(f'"{kind}"', cures)
        self.assertIn("penicillin does nothing", cures)
        self.assertNotIn("will not clear on its own", book)
        self.assertNotIn("fatal without treatment", book)
        self.assertIn('"worms" = "Intestinal worms"', book)


if __name__ == "__main__":
    unittest.main()

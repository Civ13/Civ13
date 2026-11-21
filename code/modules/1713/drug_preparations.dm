// Traditional drug preparations, usable in any era (drug_classes.dm has the
// classes, tolerance and dangers these reagents feed):
// - Opium poppy: lance a ripe poppy with a knife on help intent, wait, then
//   pick the dried latex off by hand as an opium ball. Each plant takes three
//   lancings and can still be harvested afterwards. Dried poppy heads grind in
//   a mortar into poppy straw, which steeps in water into weak poppy tea.
// - Coca: chew leaves (click yourself with them) for a mild lift; holding
//   wood ash in the other hand frees more of it. Ground coca steeps into tea.
// - Tobacco: chew dried leaves for nicotine.
// - Cannabis: dried tops smoke in a pipe or roll as joints; fresh tops rub
//   into hashish (crafting); dried tops grind in a mortar for bhang.
// - Khat: a new shrub of dry savanna and semiarid land. Its fresh shoots are
//   chewed and wilt (food decay) within about an hour of picking.

#define POPPY_LANCINGS 3
#define POPPY_LATEX_WAIT 3000 // 5 minutes for the latex to dry on the pod

// --- Reagents ----------------------------------------------------------------

/datum/reagent/coca_leaf
	name = "Coca"
	id = "coca_leaf"
	description = "Juice of chewed or ground coca leaves. A mild stimulant."
	taste_description = "green bitterness"
	reagent_state = LIQUID
	color = "#5c7a2e"
	metabolism = REM * 0.2
	overdose = 40

/datum/reagent/coca_leaf/affect_blood(var/mob/living/human/M, var/alien, var/removed)
	M.drug_dose("stimulant", 0.02, 0.05)
	M.drug_stamina("stimulant", removed * 4)
	M.drug_mood("stimulant", removed * 6, "chewing coca")
	M.add_chemical_effect(CE_PULSE, 1)
	// Takes the edge off hunger and the cold.
	if (M.nutrition < 150)
		M.nutrition += removed

/datum/reagent/coca_leaf/affect_ingest(var/mob/living/human/M, var/alien, var/removed)
	affect_blood(M, alien, removed)

/datum/reagent/coca_leaf/tea
	name = "Coca tea"
	id = "coca_tea"
	description = "Coca leaves steeped in water."
	taste_description = "grassy bitterness"
	color = "#8a9a4a"

/datum/reagent/khat
	name = "Khat"
	id = "khat"
	description = "Juice of fresh khat shoots. A stimulant that kills the appetite."
	taste_description = "astringent leaves"
	reagent_state = LIQUID
	color = "#4f7a2a"
	metabolism = REM * 0.2
	overdose = 30

/datum/reagent/khat/affect_blood(var/mob/living/human/M, var/alien, var/removed)
	M.drug_dose("stimulant", 0.03, 0.06)
	M.drug_stamina("stimulant", removed * 5)
	M.drug_mood("stimulant", removed * 10, "chewing khat")
	M.add_chemical_effect(CE_PULSE, 1)
	// No appetite and poor sleep while it lasts.
	if (M.sleeping && prob(10))
		M.sleeping = max(0, M.sleeping - 5)

/datum/reagent/khat/affect_ingest(var/mob/living/human/M, var/alien, var/removed)
	affect_blood(M, alien, removed)

/datum/reagent/khat/overdose(var/mob/living/human/M, var/alien)
	..()
	M.make_jittery(5)
	M.add_chemical_effect(CE_PULSE, 2)

/datum/reagent/poppy_straw
	name = "Poppy straw"
	id = "poppy_straw"
	description = "Ground dried poppy heads. Steep it in water for poppy tea."
	taste_description = "dusty bitterness"
	reagent_state = SOLID
	color = "#8a7a5a"

/datum/reagent/poppy_tea
	name = "Poppy tea"
	id = "poppy_tea"
	description = "Dried poppy heads steeped in water. A weak, unreliable opiate."
	taste_description = "harsh bitterness"
	reagent_state = LIQUID
	color = "#6b5a3a"
	metabolism = REM * 0.15
	overdose = 25

/datum/reagent/poppy_tea/affect_blood(var/mob/living/human/M, var/alien, var/removed)
	M.drug_painkiller("opioid", 40)
	M.drug_dose("opioid", 0.05, 0.12)
	M.drug_mood("opioid", removed * 12, "poppy tea")
	if (prob(8))
		M.drowsyness = max(M.drowsyness, 3)

/datum/reagent/poppy_tea/affect_ingest(var/mob/living/human/M, var/alien, var/removed)
	affect_blood(M, alien, removed)

/datum/reagent/poppy_tea/overdose(var/mob/living/human/M, var/alien)
	..()
	M.sleeping = max(M.sleeping, 40)
	M.adjustOxyLoss(1)
	if (M.losebreath < 3 && prob(25))
		M.losebreath++

/datum/chemical_reaction/poppy_tea
	name = "Poppy tea"
	id = "poppy_tea"
	result = "poppy_tea"
	required_reagents = list("poppy_straw" = 1, "water" = 2)
	result_amount = 3

/datum/chemical_reaction/coca_tea
	name = "Coca tea"
	id = "coca_tea"
	result = "coca_tea"
	required_reagents = list("coca_leaf" = 1, "water" = 2)
	result_amount = 3

// --- Chewing -------------------------------------------------------------------

// Click yourself with the leaves to chew a wad of them.
/obj/item/stack/proc/chew_wad(mob/living/human/user, reagent_id, amount, verb_text)
	if (!istype(user) || !user.ingested)
		return FALSE
	if (user.is_muzzled())
		to_chat(user, SPAN_WARNING("Something covers your mouth."))
		return TRUE
	if (!use(1))
		return TRUE
	user.ingested.add_reagent(reagent_id, amount)
	user.visible_message("<span class='notice'>[user] tucks a wad of [verb_text] into [user.gender == FEMALE ? "her" : "their"] cheek.</span>", SPAN_NOTICE("You tuck a wad of [verb_text] into your cheek and chew."))
	playsound(user, 'sound/items/eatfood.ogg', 30, TRUE)
	return TRUE

/obj/item/stack/material/coca/attack(mob/living/M, mob/living/user)
	if (M == user && ishuman(user))
		var/mob/living/human/H = user
		var/ash = istype(H.get_inactive_hand(), /obj/item/wood_ash)
		if (chew_wad(H, "coca_leaf", ash ? 5 : 3, ash ? "coca leaves with ash" : "coca leaves"))
			return TRUE
	return ..()

/obj/item/stack/material/tobacco/attack(mob/living/M, mob/living/user)
	if (M == user && ishuman(user))
		if (chew_wad(user, "nicotine", 4, "chewing tobacco"))
			return TRUE
	return ..()

// --- Khat ----------------------------------------------------------------------

/obj/item/stack/farming/seeds/khat
	name = "khat seeds"
	desc = "Seeds of the khat shrub of dry highland savanna."
	plant = "khat"
	color = "#6b8e23"
	biomes = list("semiarid", "savanna")

/obj/structure/farming/plant/khat
	name = "khat shrub"
	desc = "An evergreen shrub with glossy leaves and reddish young shoots, chewed fresh as a stimulant."
	icon_state = "khat-grow1"
	plant = "khat"
	biomes = list("semiarid", "savanna")
	max_water = 50

/obj/item/weapon/reagent_containers/food/snacks/grown/khat
	name = "khat shoots"
	desc = "A bundle of fresh khat shoots. Chew them while fresh: they wilt within the hour."
	icon = 'icons/obj/drugs.dmi'
	icon_state = "khat"
	nutriment_desc = list("bitter leaves" = 1)
	filling_color = "#4f7a2a"
	bitesize = 2
	satisfaction = 0
	decay = 60*600

/obj/item/weapon/reagent_containers/food/snacks/grown/khat/New()
	..()
	reagents.add_reagent("khat", 6)

// --- Cannabis ------------------------------------------------------------------

/obj/item/weapon/reagent_containers/pill/hashish
	name = "lump of hashish"
	desc = "Cannabis resin rubbed from fresh tops and pressed into a lump. Smoke it in a pipe or eat it."
	icon = 'icons/obj/drugs.dmi'
	icon_state = "hashish"
	value = 8
	is_contraband = TRUE

/obj/item/weapon/reagent_containers/pill/hashish/New()
	..()
	reagents.add_reagent("thc", 10)

// --- Opium poppy lancing -----------------------------------------------------

/obj/structure/farming/plant/poppy
	var/lancings = 0
	var/latex_due = 0 // world.time the latex on the cut pods has dried

/obj/structure/farming/plant/poppy/persistence_runtime_var(key)
	return key == "latex_due" || ..()

/obj/structure/farming/plant/poppy/attackby(obj/item/weapon/W, mob/user)
	if (is_tool(W, TOOL_KNIFE) && user.a_intent == I_HELP && readyHarvest())
		if (latex_due)
			to_chat(user, SPAN_NOTICE("The cuts on these pods are still weeping latex."))
			return TRUE
		if (lancings >= POPPY_LANCINGS)
			to_chat(user, SPAN_NOTICE("These pods are bled dry. Harvest the poppy instead."))
			return TRUE
		to_chat(user, SPAN_NOTICE("You start scoring the green pods with shallow cuts."))
		if (!do_after(user, 40, src) || QDELETED(src) || latex_due || !readyHarvest())
			return TRUE
		lancings++
		latex_due = world.time + POPPY_LATEX_WAIT
		desc = "An opium poppy. Milky latex weeps from cuts in its pods."
		to_chat(user, SPAN_NOTICE("White latex beads from the cuts. Come back when it has dried brown, and pick it off by hand."))
		return TRUE
	return ..()

/obj/structure/farming/plant/poppy/attack_hand(mob/living/user)
	if (!latex_due)
		return ..()
	if (world.time < latex_due)
		to_chat(user, SPAN_NOTICE("The latex is still wet and white."))
		return TRUE
	latex_due = 0
	desc = initial(desc)
	var/count = plant_nutrition >= 80 ? 2 : 1
	for (var/i in 1 to count)
		new /obj/item/weapon/reagent_containers/pill/opium(get_turf(src))
	to_chat(user, SPAN_NOTICE("You scrape the dried latex off the pods and roll it into [count == 1 ? "a ball" : "two balls"] of raw opium."))
	return TRUE

#undef POPPY_LANCINGS
#undef POPPY_LATEX_WAIT

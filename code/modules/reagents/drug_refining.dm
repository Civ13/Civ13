// Apothecary and refined drugs (drug_classes.dm has the classes these feed):
// - Laudanum: opium dissolved in spirits or wine. A measured liquid opiate
//   for doctors; it carries alcohol, so a second drink adds up fast.
// - The laboratory distiller refines, for an operator who knows the node:
//   opium into morphine and ground coca into cocaine (Pharmacology), and
//   morphine into heroin (Modern Medicine). How pure the result comes out
//   depends on the operator's medical skill; the rest is plant residue.
// - Packaging: fold a blank paper around a pinch from a container (click the
//   container with the paper) to make a paper twist. A twist does not show
//   what is in it or how strong it is. Taste a pinch, or test it at a
//   chemistry bench, to find out. A seller can cut a twist with any filler.
// - Cigarettes: roll dried tobacco in a blank paper (click the tobacco with
//   the paper).

#define DRUG_TWIST_VOLUME 10

// --- Reagents ----------------------------------------------------------------

/datum/reagent/laudanum
	name = "Laudanum"
	id = "laudanum"
	description = "Opium dissolved in spirits. A measured liquid painkiller."
	taste_description = "bitter spirits"
	reagent_state = LIQUID
	color = "#7a3b1e"
	metabolism = REM * 0.12
	overdose = 20

/datum/reagent/laudanum/affect_blood(var/mob/living/human/M, var/alien, var/removed)
	M.drug_painkiller("opioid", 80)
	M.drug_dose("opioid", 0.06, 0.15)
	M.drug_mood("opioid", removed * 20, "laudanum")
	if (prob(8))
		M.drowsyness = max(M.drowsyness, 3)

/datum/reagent/laudanum/affect_ingest(var/mob/living/human/M, var/alien, var/removed)
	affect_blood(M, alien, removed)

/datum/reagent/laudanum/overdose(var/mob/living/human/M, var/alien)
	..()
	M.sleeping = max(M.sleeping, 60)
	M.adjustOxyLoss(1.5)
	if (M.losebreath < 4 && prob(30))
		M.losebreath++

/datum/reagent/heroin
	name = "Heroin"
	id = "heroin"
	description = "A refined opiate, far stronger than morphine. The strongest high and the fastest habit."
	taste_description = "harsh bitterness"
	reagent_state = SOLID
	color = "#e8dcc8"
	metabolism = REM * 0.12
	overdose = 5

/datum/reagent/heroin/affect_blood(var/mob/living/human/M, var/alien, var/removed)
	M.drug_painkiller("opioid", 250)
	M.drug_dose("opioid", 0.3, 0.5)
	M.drug_mood("opioid", removed * 50, "heroin")
	M.add_chemical_effect(CE_PULSE, -1)
	M.drowsyness = max(M.drowsyness, 5)
	if (prob(10))
		M.sleeping = max(M.sleeping, 5)

/datum/reagent/heroin/affect_ingest(var/mob/living/human/M, var/alien, var/removed)
	affect_blood(M, alien, removed)

// Breathing slows until it stops.
/datum/reagent/heroin/overdose(var/mob/living/human/M, var/alien)
	..()
	M.sleeping = max(M.sleeping, 120)
	M.adjustOxyLoss(3)
	if (M.losebreath < 8 && prob(50))
		M.losebreath++

// What is left of the plant after refining. Harmless filler.
/datum/reagent/drug_residue
	name = "Plant residue"
	id = "drug_residue"
	description = "Bitter plant matter left over from refining. It does nothing."
	taste_description = "bitter grit"
	reagent_state = SOLID
	color = "#9a8a6a"

/datum/chemical_reaction/laudanum
	name = "Laudanum"
	id = "laudanum"
	result = "laudanum"
	required_reagents = list("opium" = 1, "ethanol" = 2)
	inhibitors = list("acetone" = 1) // opium, ethanol and acetone make tramadol
	result_amount = 3

/datum/chemical_reaction/laudanum/wine
	id = "laudanum_wine"
	required_reagents = list("opium" = 1, "wine" = 2)

// --- Refining in the laboratory distiller ------------------------------------

// input reagent id -> list(product id, research node, input per unit of product)
/proc/drug_refining_table()
	return list(
		"opium" = list("morphine", "pharmacology", 2),
		"coca_leaf" = list("cocaine", "pharmacology", 2),
		"morphine" = list("heroin", "modern_medicine", 1.5),
	)

// 0.5 at the distiller's minimum medical skill, 1 for a skilled doctor.
/proc/drug_refining_purity(mob/living/human/H)
	if (!istype(H))
		return 0.5
	var/coeff = H.getStatCoeff("medical")
	if (!isnum(coeff))
		return 0.5
	return clamp(0.5 + (coeff - GET_MIN_STAT_COEFF(STAT_MEDIUM_HIGH)), 0.5, 1)

// Called by the distiller when a run finishes. Returns TRUE when it handled
// the run (refined, or refused and kept the input), FALSE for ordinary
// distilling.
/obj/structure/lab_distillery/proc/drug_refine(largest, mob/living/human/H)
	var/list/table = drug_refining_table()
	var/list/entry = table[largest]
	if (!islist(entry))
		return FALSE
	if (!H || !research_node_known(H, entry[2]))
		visible_message(SPAN_NOTICE("\The [src] bubbles, but nothing useful collects."))
		if (H)
			to_chat(H, SPAN_WARNING("You don't know how to draw anything useful from this."))
		return TRUE
	var/input = min(reagents.get_reagent_amount(largest), collector.reagents.get_free_space() * entry[3])
	if (input <= 0)
		visible_message(SPAN_NOTICE("\The [src] has no room left in its collector."))
		return TRUE
	var/made = input / entry[3]
	var/purity = drug_refining_purity(H)
	reagents.remove_reagent(largest, input)
	collector.reagents.add_reagent(entry[1], made * purity)
	if (purity < 1)
		collector.reagents.add_reagent("drug_residue", made * (1 - purity))
	visible_message(SPAN_NOTICE("\The [src] finishes refining."))
	return TRUE

// --- Paper twists ------------------------------------------------------------

/obj/item/weapon/reagent_containers/pill/paper_twist
	name = "paper twist"
	desc = "A twist of paper folded around a pinch of something. There is no telling how strong it is without tasting it."
	icon = 'icons/obj/bureaucracy.dmi'
	icon_state = "scrap"
	volume = DRUG_TWIST_VOLUME
	value = 1

/obj/item/weapon/reagent_containers/pill/paper_twist/attack(mob/M as mob, mob/user as mob, def_zone)
	if (!reagents || reagents.total_volume <= 0)
		to_chat(user, SPAN_NOTICE("\The [src] is empty."))
		return TRUE
	return ..()

// A pinch on the tongue tells strong from cut.
/obj/item/weapon/reagent_containers/pill/paper_twist/verb/taste_pinch()
	set name = "Taste a Pinch"
	set category = null
	set src in usr
	var/mob/living/human/H = usr
	if (!istype(H) || H.stat || H.restrained())
		return
	to_chat(H, drug_strength_text(reagents))
	if (H.ingested && reagents.total_volume > 0)
		reagents.trans_to_holder(H.ingested, min(0.5, reagents.total_volume))

// How much of a holder is a drug of any class.
/proc/drug_strength_text(datum/reagents/holder)
	if (!holder || holder.total_volume <= 0)
		return SPAN_NOTICE("There is nothing left to taste.")
	var/drug = 0
	for (var/datum/reagent/R in holder.reagent_list)
		if (drug_reagent_class(R))
			drug += R.volume
	var/share = drug / holder.total_volume
	if (share >= 0.85)
		return SPAN_WARNING("It numbs your tongue at once. This is strong and clean.")
	if (share >= 0.5)
		return SPAN_NOTICE("It is fairly strong, with some grit in it.")
	if (share >= 0.2)
		return SPAN_NOTICE("It is weak, mostly filler.")
	if (share > 0)
		return SPAN_NOTICE("There is barely anything in it but filler.")
	return SPAN_NOTICE("It tastes of nothing but filler.")

// Glass containers call this when a paper is used on them (glass.dm).
/proc/paper_twist_fold(obj/item/weapon/reagent_containers/glass/G, obj/item/weapon/paper/P, mob/living/user)
	if (!istype(G) || !istype(P) || !istype(user) || !recipe_blank_paper(P))
		return FALSE
	if (!G.is_open_container() || !G.reagents || G.reagents.total_volume <= 0)
		to_chat(user, SPAN_NOTICE("There is nothing in \the [G] to fold into the paper."))
		return TRUE
	var/obj/item/weapon/reagent_containers/pill/paper_twist/T = new(get_turf(user))
	var/moved = G.reagents.trans_to_holder(T.reagents, DRUG_TWIST_VOLUME)
	user.drop_from_inventory(P)
	qdel(P)
	user.put_in_hands(T)
	to_chat(user, SPAN_NOTICE("You tip [round(moved, 0.1)] units into the paper and twist it shut."))
	return TRUE

// --- Cigarettes ----------------------------------------------------------------

/obj/item/stack/material/tobacco/attackby(obj/item/W, mob/user)
	if (!istype(W, /obj/item/weapon/paper))
		return ..()
	if (!recipe_blank_paper(W))
		to_chat(user, SPAN_NOTICE("You need a blank sheet to roll cigarettes."))
		return TRUE
	if (amount < 2)
		to_chat(user, SPAN_NOTICE("You need at least two leaves of tobacco to roll cigarettes."))
		return TRUE
	to_chat(user, SPAN_NOTICE("You cut the paper into strips and roll the tobacco."))
	if (!do_after(user, 30, src) || QDELETED(W) || W.loc != user || !use(2))
		return TRUE
	user.drop_from_inventory(W)
	qdel(W)
	for (var/i in 1 to 2)
		new /obj/item/clothing/mask/smokable/cigarette(get_turf(user))
	to_chat(user, SPAN_NOTICE("You roll two cigarettes."))
	return TRUE

#undef DRUG_TWIST_VOLUME

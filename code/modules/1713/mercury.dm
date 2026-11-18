// Mercury (quicksilver) from cinnabar, and the slow poisoning it causes
// (docs/mercury.md).
//
// Cinnabar comes out of mined rock from the Classical age. Roasted openly on
// a fire it gives a little mercury and a lot of vapour; a retort with a
// condenser gives three times as much and keeps the vapour in while its seal
// holds. Heating mercury anywhere near people builds a slow "mercury burden"
// in them that drains over hours of play. Vapour is an event at the end of a
// step, not a gas: nothing lingers and nothing ticks while nobody is exposed.

// Cinnabar in mined rock, per mining action (silver is about 2% to 2.5%).
#define CINNABAR_CHANCE 1
#define CINNABAR_RICH_CHANCE 2
// Mercury units from one cinnabar.
#define MERCURY_ROAST_UNITS 2
// Mercury retort: code/__defines/ore_processing.dm
// Retort load, seal wear per firing and the seal below which it leaks.
#define RETORT_SEAL_WEAR 10
#define RETORT_SEAL_LEAKS 30
// Burden stages.
#define MERCURY_LOW 20
#define MERCURY_MODERATE 40
#define MERCURY_HIGH 70
#define MERCURY_SEVERE 100
// Burden left after one second: 10% of the burden drains per hour of play.
#define MERCURY_DECAY_TICK 0.99997073
// Burden added per exposure.
#define MERCURY_ROAST_VAPOUR 1.5 // per ore roasted openly, under a roof
#define MERCURY_LEAK_VAPOUR 3 // per firing of a leaking retort
#define MERCURY_SWALLOWED 0.2 // per unit of liquid mercury swallowed
#define MERCURY_VAPOUR_RANGE 2

// Lands on old mercury belts (Almaden, Idrija, Huancavelica, Guizhou).
/obj/map_metadata/var/cinnabar_rich = FALSE

/mob/living/human/var/mercury_burden = 0
/mob/living/human/var/mercury_stage = 0
/mob/living/human/var/mercury_cause = null
/mob/living/human/var/mercury_told = FALSE

//////////////////////////////////////////////////////////////////////////////
// Cinnabar

// An independent roll like flint, gems and obsidian, so the ore table is
// unchanged. Every land from the Classical age; mercury belts twice as often.
/turf/proc/mining_cinnabar(mob/living/human/H)
	if (!map || map.ordinal_age < 1)
		return 0
	if (!prob(map.cinnabar_rich ? CINNABAR_RICH_CHANCE : CINNABAR_CHANCE))
		return 0
	var/obj/item/stack/ore/mercury/C = new /obj/item/stack/ore/mercury(src)
	C.amount = 4
	if (istype(get_area(src), /area/caribbean/void/caves/special))
		C.amount *= 2
	C.update_icon()
	if (H)
		to_chat(H, SPAN_GREEN_BOLD("You found some <font color=#a8322a><b>cinnabar</b></font>!"))
	return C.amount

/obj/item/stack/ore/mercury/attackby(obj/item/W, mob/living/human/H)
	if (istype(W, /obj/item/weapon/reagent_containers/glass/extraction_kit))
		to_chat(H, SPAN_NOTICE("Quicksilver can't be leached out of cinnabar. Roast it over a fire with an open vessel in your other hand, or charge it into a mercury retort."))
		return
	return ..()

// Cinnabar used on a lit fire, furnace or brazier: open roasting.
/obj/item/stack/ore/mercury/resolve_attackby(atom/A, mob/user, icon_x, icon_y)
	if (istype(A, /obj/structure) && isflamesource(A) && ishuman(user))
		roast_cinnabar(A, user)
		return TRUE
	return ..()

/obj/item/stack/ore/mercury/proc/roast_cinnabar(obj/structure/fire, mob/living/human/H)
	if (!crafting_node_allowed_or_warn(H, "bronze_working"))
		return FALSE
	var/obj/item/weapon/reagent_containers/V = H.get_inactive_hand()
	if (!istype(V) || !V.is_open_container() || !V.reagents)
		to_chat(H, SPAN_WARNING("Hold an open vessel in your other hand to catch the quicksilver that sweats out of the ore."))
		return FALSE
	if (V.reagents.get_free_space() < MERCURY_ROAST_UNITS)
		to_chat(H, SPAN_WARNING("\The [V] is too full."))
		return FALSE
	H.visible_message(SPAN_NOTICE("[H] roasts a lump of cinnabar over \the [fire], holding \the [V] under the fumes."), SPAN_NOTICE("You roast a lump of cinnabar over \the [fire]. The fumes are bitter."))
	if (!do_after(H, 60, fire) || QDELETED(src) || amount < 1 || V.loc != H || !isflamesource(fire))
		return FALSE
	if (V.reagents.get_free_space() < MERCURY_ROAST_UNITS)
		return FALSE
	use(1)
	V.reagents.add_reagent("mercury", MERCURY_ROAST_UNITS)
	to_chat(H, SPAN_NOTICE("Bright beads of quicksilver gather in \the [V]."))
	mercury_vapour(fire, MERCURY_ROAST_VAPOUR, "the fumes of roasting cinnabar")
	pollution_emit(fire, 1, 1)
	return TRUE

//////////////////////////////////////////////////////////////////////////////
// The mercury flask

/obj/item/weapon/reagent_containers/glass/mercury_flask
	name = "mercury flask"
	desc = "A squat wrought-iron flask with a screw stopper, the way quicksilver has always been shipped: iron is the one common metal mercury does not eat."
	icon = 'icons/obj/mercury.dmi'
	icon_state = "flask"
	item_state = "atoxinbottle"
	w_class = ITEM_SIZE_SMALL
	volume = 60
	amount_per_transfer_from_this = 5
	possible_transfer_amounts = list(1, 2, 5, 10, 20, 30, 60)
	flags = OPENCONTAINER
	flammable = FALSE

/obj/item/weapon/reagent_containers/glass/mercury_flask/on_reagent_change()
	update_icon()

/obj/item/weapon/reagent_containers/glass/mercury_flask/update_icon()
	icon_state = reagents && reagents.total_volume > 0 ? "flask_full" : "flask"

//////////////////////////////////////////////////////////////////////////////
// The mercury retort

/obj/structure/workshop_machine/mercury_retort
	name = "mercury retort"
	desc = "An iron pot over a small firebox, sealed with clay, with a condenser pipe running down into a cooled receiver. Charge it with cinnabar, then feed the firebox charcoal, coal or wood: the quicksilver distils off and condenses instead of poisoning the room. Draw it off with a flask or any open vessel. Each firing cracks the clay seal a little; patch it with clay before it leaks."
	icon = 'icons/obj/mercury.dmi'
	icon_state = "retort"
	var/cinnabar = 0
	var/seal = 100

/obj/structure/workshop_machine/mercury_retort/New()
	..()
	if (!reagents)
		create_reagents(60)
	update_icon()

/obj/structure/workshop_machine/mercury_retort/update_icon()
	if (busy)
		icon_state = "retort_fired"
	else if (seal < RETORT_SEAL_LEAKS)
		icon_state = "retort_cracked"
	else
		icon_state = "retort"

/obj/structure/workshop_machine/mercury_retort/examine(mob/user, distance)
	..(user, distance)
	if (distance > 2)
		return
	to_chat(user, SPAN_NOTICE("It holds [retort_contents()] and [reagents ? round(reagents.total_volume) : 0] units of quicksilver."))
	if (seal < RETORT_SEAL_LEAKS)
		to_chat(user, SPAN_WARNING("Its clay seal is cracked through: it will leak fumes. Patch it with clay."))
	else if (seal < 60)
		to_chat(user, SPAN_NOTICE("Its clay seal is getting worn."))

// What is charged in the pot, for examine; amalgam.dm adds amalgam.
/obj/structure/workshop_machine/mercury_retort/proc/retort_contents()
	return "[cinnabar] cinnabar"

// Lumps charged in the pot; each adds to the firing time.
/obj/structure/workshop_machine/mercury_retort/proc/retort_charge()
	return cinnabar

// Empties the pot after a firing: the quicksilver it gives (before any leak),
// and any metal it leaves (amalgam.dm).
/obj/structure/workshop_machine/mercury_retort/proc/retort_empty(mob/living/human/H)
	. = cinnabar * MERCURY_RETORT_UNITS
	cinnabar = 0

/obj/structure/workshop_machine/mercury_retort/proc/retort_fuel(obj/item/I)
	return istype(I, /obj/item/stack/ore/charcoal) || istype(I, /obj/item/stack/ore/coal) || istype(I, /obj/item/stack/material/wood)

/obj/structure/workshop_machine/mercury_retort/attackby(obj/item/I, mob/living/human/H)
	if (!istype(H))
		return
	if (handle_machine_tool(I, H))
		return
	if (busy)
		to_chat(H, SPAN_WARNING("\The [src] is firing."))
		return
	if (istype(I, /obj/item/stack/ore/mercury))
		load_cinnabar(I, H)
		return
	if (istype(I, /obj/item/stack/material/clay))
		patch_seal(I, H)
		return
	if (retort_fuel(I))
		fire_retort(I, H)
		return
	if (istype(I, /obj/item/weapon/reagent_containers) && I.is_open_container())
		var/obj/item/weapon/reagent_containers/C = I
		if (!reagents || reagents.total_volume <= 0)
			to_chat(H, SPAN_NOTICE("The receiver is empty."))
			return
		var/moved = reagents.trans_to_obj(C, C.amount_per_transfer_from_this)
		if (moved > 0)
			to_chat(H, SPAN_NOTICE("You draw [moved] units of quicksilver into \the [C]."))
		else
			to_chat(H, SPAN_WARNING("\The [C] is full."))
		return
	return ..()

/obj/structure/workshop_machine/mercury_retort/proc/load_cinnabar(obj/item/stack/ore/mercury/S, mob/living/human/H)
	var/room = min(RETORT_CAPACITY - retort_charge(), round((reagents.get_free_space()) / MERCURY_RETORT_UNITS) - cinnabar)
	if (room <= 0)
		to_chat(H, SPAN_WARNING("\The [src] is full, or its receiver is: draw off the quicksilver first."))
		return
	var/moved = min(room, S.amount)
	S.use(moved)
	cinnabar += moved
	to_chat(H, SPAN_NOTICE("You charge \the [src] with [moved] cinnabar ([cinnabar]/[RETORT_CAPACITY])."))

/obj/structure/workshop_machine/mercury_retort/proc/patch_seal(obj/item/stack/material/clay/S, mob/living/human/H)
	if (seal >= 100)
		to_chat(H, SPAN_NOTICE("The seal is sound."))
		return
	if (!do_after(H, 30, src) || QDELETED(S) || S.amount < 1)
		return
	S.use(1)
	seal = 100
	update_icon()
	to_chat(H, SPAN_NOTICE("You pack fresh clay around the lid and the pipe joint."))

/obj/structure/workshop_machine/mercury_retort/proc/fire_retort(obj/item/stack/S, mob/living/human/H)
	if (!anchored)
		to_chat(H, SPAN_WARNING("Fasten \the [src] down with a wrench first."))
		return
	if (retort_charge() <= 0)
		to_chat(H, SPAN_WARNING("Charge \the [src] with cinnabar or amalgam first."))
		return
	if (!crafting_node_allowed_or_warn(H, "amalgamation"))
		return
	busy = TRUE
	update_icon()
	H.visible_message(SPAN_NOTICE("[H] fires \the [src]."), SPAN_NOTICE("You feed the firebox and fire \the [src]."))
	var/done = do_after(H, 40 + 10 * retort_charge(), src) && worker_ready(H, S)
	busy = FALSE
	if (!done || retort_charge() <= 0)
		update_icon()
		return
	S.use(1)
	var/ores = retort_charge()
	var/leaking = seal < RETORT_SEAL_LEAKS
	var/units = retort_empty(H)
	if (leaking)
		units = round(units * 0.7)
		mercury_vapour(src, MERCURY_LEAK_VAPOUR, "fumes leaking from a cracked retort")
		pollution_emit(src, ores, 1)
		visible_message(SPAN_WARNING("Grey fumes curl out of the cracked seal of \the [src]."))
	reagents.add_reagent("mercury", units)
	seal = max(0, seal - RETORT_SEAL_WEAR)
	update_icon()
	to_chat(H, SPAN_NOTICE("The retort ticks as it cools: [units] units of quicksilver have run down into the receiver."))

//////////////////////////////////////////////////////////////////////////////
// Vapour

/obj/effect/mercury_vapour
	name = "fumes"
	icon = 'icons/obj/mercury.dmi'
	icon_state = "vapour"
	mouse_opacity = 0
	anchored = TRUE
	density = FALSE
	opacity = FALSE
	should_save = FALSE
	layer = 4.1

/obj/effect/mercury_vapour/New(loc)
	..()
	animate(src, alpha = 0, time = 30)
	QDEL_IN(src, 30)

// Share of vapour that gets past a person's mask.
/mob/living/human/proc/mercury_mask_factor()
	if (istype(wear_mask, /obj/item/clothing/mask/gas))
		return 0.1
	if (istype(wear_mask, /obj/item/clothing/mask))
		return 0.75
	return 1

// One release of vapour at source: everyone within MERCURY_VAPOUR_RANGE breathes
// per_person burden, halved under the open sky.
/proc/mercury_vapour(atom/source, per_person, cause)
	var/turf/T = get_turf(source)
	if (!T || per_person <= 0)
		return 0
	new /obj/effect/mercury_vapour(T)
	var/amount = signal_fire_open_sky(T) ? per_person * 0.5 : per_person
	. = 0
	for (var/mob/living/human/H in range(MERCURY_VAPOUR_RANGE, T))
		if (H.stat == DEAD)
			continue
		H.add_mercury_burden(amount * H.mercury_mask_factor(), cause)
		.++

//////////////////////////////////////////////////////////////////////////////
// The burden

/mob/living/human/proc/add_mercury_burden(amount, cause)
	if (amount <= 0 || (status_flags & GODMODE))
		return
	mercury_burden += amount
	if (cause)
		mercury_cause = cause

/mob/living/human/proc/mercury_stage_for(burden)
	if (burden >= MERCURY_SEVERE)
		return 4
	if (burden >= MERCURY_HIGH)
		return 3
	if (burden >= MERCURY_MODERATE)
		return 2
	if (burden >= MERCURY_LOW)
		return 1
	return 0

/mob/living/human/Life()
	. = ..()
	if (mercury_burden > 0)
		handle_mercury_burden()

/mob/living/human/proc/handle_mercury_burden()
	if (stat == DEAD)
		return
	mercury_burden *= MERCURY_DECAY_TICK
	if (mercury_burden < 0.05)
		mercury_burden = 0
	var/stage = mercury_stage_for(mercury_burden)
	if (stage != mercury_stage)
		mercury_stage_changed(mercury_stage, stage)
		mercury_stage = stage
	switch (stage)
		if (1)
			if (prob(0.3))
				to_chat(src, SPAN_WARNING(pick("There is a metallic taste in your mouth.", "A dull headache sits behind your eyes.")))
		if (2)
			if (prob(0.5))
				to_chat(src, SPAN_WARNING(pick("Your hands tremble.", "Your fingers won't keep still.", "Everything and everyone grates on you.")))
				make_jittery(20)
		if (3)
			var/obj/item/organ/kidneys/K = internal_organs_by_name["kidneys"]
			if (istype(K))
				K.damage = min(K.max_damage, K.damage + 0.01)
			if (prob(0.5))
				to_chat(src, SPAN_WARNING(pick("Your gums bleed.", "A tooth feels loose.", "You lose the thread of what you were thinking.", "Your hands shake badly.")))
				make_jittery(40)
		if (4)
			adjustBrainLoss(0.2)
			if (prob(0.5))
				to_chat(src, SPAN_DANGER(pick("Your whole body shakes.", "You can't remember where you are.", "Your mouth is full of blood.")))
				make_jittery(60)
			if (prob(0.2))
				Weaken(3)

/mob/living/human/proc/mercury_stage_changed(old_stage, stage)
	if (stage > old_stage)
		if (!mercury_told && stage >= 1)
			mercury_told = TRUE
			to_chat(src, SPAN_DANGER("Quicksilver is poisoning you[mercury_cause ? ", from [mercury_cause]" : ""]. Keep away from its fumes: it drains out slowly, over hours."))
		switch (stage)
			if (2)
				to_chat(src, SPAN_DANGER("A tremor has come into your hands. Fine work and aiming come harder."))
			if (3)
				to_chat(src, SPAN_DANGER("Your gums are sore and your memory is slipping. The poison is deep in you now."))
			if (4)
				to_chat(src, SPAN_DANGER("The quicksilver is in your brain. Get away from it, or it will kill you."))
	else if (stage == 0)
		to_chat(src, SPAN_NOTICE("The metallic taste has finally gone."))

// Tremor and memory: fine work, aiming and study come harder.
/mob/living/human/getStatCoeff(statname)
	. = ..()
	if (!. || mercury_stage < 2)
		return
	switch (statname)
		if ("dexterity", "crafting", "medical", "rifle", "pistol", "bows", "swords")
			. *= mercury_stage >= 3 ? 0.7 : 0.85
		if ("philosophy")
			if (mercury_stage >= 3)
				. *= 0.8

// Liquid mercury is poorly absorbed from the gut, but not harmless.
/datum/reagent/mercury/affect_ingest(mob/living/human/M, alien, removed)
	if (istype(M))
		M.add_mercury_burden(removed * MERCURY_SWALLOWED, "swallowed quicksilver")
	..()

//////////////////////////////////////////////////////////////////////////////
// Diagnosis

/obj/item/weapon/doctor_handbook/diagnose_poisons(mob/living/human/H)
	. = ..()
	if (H.mercury_stage >= 1)
		var/static/list/words = list("mild", "moderate", "heavy", "deadly")
		. += "Mercury poisoning, [words[H.mercury_stage]] (burden [round(H.mercury_burden)]). Treatment: keep away from quicksilver and its fumes; it drains slowly over hours, and a dose of dimercaprol draws much of it out."

// Admin Check Illnesses lists mercury poisoning when nothing else is wrong.
/mob/living/human/illness_summary()
	. = ..()
	if (. || mercury_stage < 1)
		return
	var/static/list/words = list("mild", "moderate", "heavy", "deadly")
	return list(
		"type" = "mercury",
		"severe" = mercury_stage >= 3 ? TRUE : FALSE,
		"stage" = words[mercury_stage],
		"progression" = round(mercury_burden),
		"course" = 0,
		"treated" = FALSE,
		"resistance" = 0)

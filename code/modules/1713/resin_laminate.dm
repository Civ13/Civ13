// Phenolic resin and resin laminate (Val, 2026-11-21; plan "Resin materials
// plan", PR 6).
//
// The bakelizer (modern_items.dm) gains settings: besides plastic sheets it can
// cook its petroleum into a liquid resin, BAKELIZER_LIQUID_UNITS per 5
// petroleum. Choose with the bakelizer's Change Setting verb; use an empty
// container on the bakelizer to draw off what it made. Later PRs add settings
// through bakelizer_settings().
//
// The hot press bonds cloth with resin into resin laminate, the hard board of
// the Dayfield shields, insulators and gun furniture:
//   - pour phenolic resin (or plain pine resin) into the press from a container,
//   - use LAMINATE_CLOTH sheets of plain cloth or silk on the press.
// Each pressing takes LAMINATE_RESIN units: phenolic resin gives 2 sheets from
// cloth and 3 from silk, the best grade; plain resin gives half (at least 1).
//
// Sprites by Fable (icons/obj/resin_works.dmi, icons/obj/fabrics.dmi). Nothing
// here sleeps outside the do_after wait; the bakelizer keeps its own timer.

#define BAKELIZER_LIQUID_UNITS 10
#define BAKELIZER_NYLON_SKEINS 2
#define LAMINATE_CLOTH 4
#define LAMINATE_RESIN 10
#define LAMINATE_PRESS_TIME 80

/datum/reagent/phenolic_resin
	name = "Phenolic resin"
	id = "phenolic_resin"
	description = "A thick amber resin cooked from petroleum. Pressed hot into cloth, it sets as hard as horn and never softens again."
	taste_description = "tar and carbolic"
	reagent_state = LIQUID
	color = "#A0521E"

/material/resin_laminate
	name = "resin_laminate"
	display_name = "resin laminate"
	use_name = "resin laminate"
	icon_colour = "#7A3E1C"
	hardness = 45
	weight = 8
	sheet_singular_name = "sheet"
	sheet_plural_name = "sheets"
	stack_type = /obj/item/stack/material/resin_laminate
	integrity = 120
	resilience = 0.6
	density = 14
	firmness = 60
	toughness = 55
	wear = 70
	heat_limit = 180
	corrosion = 0
	spring = 25
	shaping = SHAPE_MOULDED

/obj/item/stack/material/resin_laminate
	name = "resin laminate"
	desc = "Hard brown boards of cloth pressed in resin. Light, stiff and tough; it does not rot or rust, and it does not carry a current."
	icon = 'icons/obj/fabrics.dmi'
	icon_state = "resin_laminate"
	default_type = "resin_laminate"
	apply_colour = FALSE
	value = 8
	w_class = ITEM_SIZE_NORMAL

/obj/item/stack/material/resin_laminate/New()
	update_icon()
	return ..()

/obj/item/stack/material/resin_laminate/update_icon()
	icon_state = "resin_laminate[pile_suffix(amount, list(13, 26, 39))]"

// The bakelizer.

// Settings make solid products or store a liquid reagent for later draw-off.
// Built per call: proc-static and global lists add to the world's global
// initialiser, which is at the compiler's size limit.
/proc/bakelizer_settings()
	return list("plastic" = "plastic sheets", "polymer_pellets" = "thermoplastic pellets", "phenolic_resin" = "phenolic resin", "nylon_thread" = "nylon thread", "epoxy" = "epoxy", "photopolymer" = "photopolymer resin")

// The earliest ordinal age (research_faction.dm) a setting can be chosen in.
/proc/bakelizer_setting_age(id)
	switch (id)
		if ("nylon_thread", "polymer_pellets")
			return 6 // WW2
		if ("epoxy")
			return 7 // Cold War (fiberglass.dm)
		if ("photopolymer")
			return 9 // Digital Age (resin_printer.dm)
	return 0

// Settings that make solid goods, drawn out with the Remove verb, not poured.
/proc/bakelizer_solid_setting(id)
	return id == "plastic" || id == "polymer_pellets" || id == "nylon_thread" || id == "photopolymer"

/obj/structure/bakelizer/var/setting = "plastic"
/obj/structure/bakelizer/var/polymer_pellets = 0
/obj/structure/bakelizer/var/list/stock = null // reagent id = units ready to draw off
/obj/structure/bakelizer/var/nylon_thread = 0 // skeins of nylon thread made (nylon.dm)

// One refining step's product (modern_items.dm calls this per 5 petroleum).
/obj/structure/bakelizer/proc/bakelizer_make()
	if (!(setting in bakelizer_settings()))
		setting = "plastic"
	if (setting == "plastic")
		plastic += 1
		return
	if (setting == "polymer_pellets")
		polymer_pellets += 1
		return
	if (setting == "nylon_thread")
		nylon_thread += BAKELIZER_NYLON_SKEINS
		return
	if (setting == "photopolymer")
		photopolymer += BAKELIZER_NYLON_SKEINS // resin_printer.dm: bottles
		return
	if (!stock)
		stock = list()
	stock[setting] = (stock[setting] || 0) + BAKELIZER_LIQUID_UNITS

/obj/structure/bakelizer/proc/bakelizer_desc()
	var/list/parts = list("[plastic] plastic sheets")
	if (polymer_pellets)
		parts += "[polymer_pellets] measures of thermoplastic pellets"
	if (nylon_thread)
		parts += "[nylon_thread] skeins of nylon thread"
	if (photopolymer)
		parts += "[photopolymer] bottles of photopolymer resin"
	for (var/id in stock)
		parts += "[stock[id]] units of [bakelizer_settings()[id] || id]"
	desc = "A machine used to transform petroleum into plastics and resins. It is set to make [bakelizer_settings()[setting]]. Has [volume] petroleum, [english_list(parts)] inside."

// Draw the bakelizer's liquid products into an empty-handed container.
/obj/structure/bakelizer/proc/bakelizer_fill(obj/item/weapon/reagent_containers/C, mob/user)
	if (!stock || !stock.len)
		return FALSE
	if (!C.is_open_container() || !C.reagents)
		to_chat(user, SPAN_WARNING("Open \the [C] first."))
		return TRUE
	var/drawn = 0
	for (var/id in stock.Copy())
		var/units = min(stock[id], C.reagents.get_free_space())
		if (units <= 0)
			continue
		C.reagents.add_reagent(id, units)
		stock[id] -= units
		drawn += units
		if (stock[id] <= 0)
			stock -= id
	if (!drawn)
		to_chat(user, SPAN_WARNING("\The [C] is full."))
		return TRUE
	bakelizer_desc()
	to_chat(user, SPAN_NOTICE("You draw [drawn] units off \the [src] into \the [C]."))
	return TRUE

/obj/structure/bakelizer/proc/bakelizer_setting_allowed(id, mob/living/human/H)
	return (!map || map.ordinal_age >= bakelizer_setting_age(id)) && (id != "polymer_pellets" || crafting_node_allowed(H, "industrial_plastics"))

/obj/structure/bakelizer/verb/change_setting()
	set category = null
	set name = "Change Setting"
	set src in range(1)
	var/mob/living/human/H = usr
	if (!istype(H) || H.incapacitated() || H.restrained() || !H.Adjacent(src) || persistence_admission_blocked())
		return
	var/datum/admission = persistence_admission_identity
	var/was_active = active
	var/run_at_prompt = refine_epoch
	var/list/settings = bakelizer_settings()
	var/list/choices = list()
	for (var/id in settings)
		if (!bakelizer_setting_allowed(id, H))
			continue
		choices[settings[id]] = id
	var/choice = WWinput(H, "What should \the [src] make? Turn it off before changing products.", "Bakelizer", settings[setting], choices)
	if (!choice || !(choice in choices) || QDELETED(src) || QDELETED(H) || H.incapacitated() || H.restrained() || !H.Adjacent(src) || persistence_admission_changed(admission))
		return
	if (was_active || active || run_at_prompt != refine_epoch)
		to_chat(H, SPAN_WARNING("Turn the bakelizer off before changing its product."))
		return
	var/id = choices[choice]
	if (!bakelizer_setting_allowed(id, H))
		return
	setting = id
	bakelizer_desc()
	to_chat(usr, SPAN_NOTICE("You set \the [src] to make [choice]."))

// Eject at most one legal stack; remaining stock can be collected again.
/obj/structure/bakelizer/proc/bakelizer_eject_pellets(mob/user)
	var/turf/site = get_turf(src)
	var/obj/item/stack/pellet_type = /obj/item/stack/polymer_pellets
	if (!site || polymer_pellets < 1 || persistence_admission_blocked())
		return FALSE
	var/amount = min(initial(pellet_type.max_amount), polymer_pellets)
	polymer_pellets -= amount
	new /obj/item/stack/polymer_pellets(site, amount)
	bakelizer_desc()
	if (user)
		to_chat(user, SPAN_NOTICE("You collect [amount] [amount == 1 ? "measure" : "measures"] of thermoplastic pellets."))
	return TRUE

// Hand out the nylon thread (the Remove verb, modern_items.dm). TRUE if any.
/obj/structure/bakelizer/proc/bakelizer_eject_nylon(mob/user)
	if (nylon_thread <= 0)
		nylon_thread = 0
		return FALSE
	new /obj/item/stack/nylon_thread(get_turf(src), nylon_thread)
	nylon_thread = 0
	bakelizer_desc()
	if (user)
		to_chat(user, SPAN_NOTICE("You take the nylon thread out of \the [src]."))
	return TRUE

// The hot press.

/obj/structure/hot_press
	name = "hot press"
	desc = "A heavy screw press with heated platens. Pour in phenolic or pine resin, then lay four sheets of cloth or silk in it to press resin laminate, or four piles of sawdust to press particle board."
	icon = 'icons/obj/resin_works.dmi'
	icon_state = "hot_press"
	anchored = TRUE
	density = TRUE
	flammable = FALSE
	not_movable = FALSE
	not_disassemblable = FALSE

/obj/structure/hot_press/New()
	..()
	create_reagents(60)

// The wait, as a proc so a test fixture can stand in for do_after.
/obj/structure/hot_press/proc/press_wait(mob/living/human/H)
	return do_after(H, LAMINATE_PRESS_TIME, src)

// The resin a pressing would use: phenolic first, then plain resin.
/obj/structure/hot_press/proc/press_resin()
	if (reagents.get_reagent_amount("phenolic_resin") >= LAMINATE_RESIN)
		return "phenolic_resin"
	if (reagents.get_reagent_amount("resin") >= LAMINATE_RESIN)
		return "resin"
	return null

// Sheets of laminate one pressing of this cloth gives with this resin.
/proc/laminate_yield(obj/item/stack/material/S, resin_id)
	var/sheets = 0
	if (istype(S, /obj/item/stack/material/silk))
		sheets = 3
	else if (treatable_cloth(S)) // treated_cloth.dm: plain cloth only
		sheets = 2
	if (!sheets || !resin_id)
		return 0
	if (resin_id != "phenolic_resin")
		sheets = max(1, round(sheets / 2))
	return sheets

/obj/structure/hot_press/attackby(obj/item/W, mob/user)
	if (!ishuman(user) || user.a_intent == I_HARM)
		return ..()
	var/mob/living/human/H = user
	if (istype(W, /obj/item/weapon/reagent_containers) && W.reagents && (W.reagents.has_reagent("phenolic_resin") || W.reagents.has_reagent("resin")))
		var/poured = 0
		for (var/id in list("phenolic_resin", "resin"))
			var/units = min(W.reagents.get_reagent_amount(id), reagents.get_free_space())
			if (units > 0)
				W.reagents.remove_reagent(id, units)
				reagents.add_reagent(id, units)
				poured += units
		if (poured)
			to_chat(H, SPAN_NOTICE("You pour [poured] units of resin into \the [src]."))
		else
			to_chat(H, SPAN_WARNING("\The [src] is full of resin."))
		return TRUE
	if (istype(W, /obj/item/stack/sawdust)) // particle_board.dm
		press_particle_board(W, H)
		return TRUE
	if (istype(W, /obj/item/stack/material))
		var/obj/item/stack/material/S = W
		if (!laminate_yield(S, "phenolic_resin"))
			return ..()
		press_laminate(S, H)
		return TRUE
	return ..()

/obj/structure/hot_press/proc/press_laminate(obj/item/stack/material/S, mob/living/human/H)
	var/resin_id = press_resin()
	if (!resin_id)
		to_chat(H, SPAN_WARNING("\The [src] needs [LAMINATE_RESIN] units of phenolic or pine resin first."))
		return FALSE
	if (S.amount < LAMINATE_CLOTH)
		to_chat(H, SPAN_WARNING("You need [LAMINATE_CLOTH] sheets of \the [S] for one pressing."))
		return FALSE
	H.visible_message(SPAN_NOTICE("[H] lays resined [S.name] between the platens of \the [src] and screws it down."), SPAN_NOTICE("You lay the resined [S.name] between the platens and screw \the [src] down."))
	icon_state = "hot_press_on"
	var/done = press_wait(H)
	icon_state = initial(icon_state)
	if (!done || persistence_save_in_progress || QDELETED(src) || QDELETED(S) || S.amount < LAMINATE_CLOTH || press_resin() != resin_id)
		return FALSE
	var/sheets = laminate_yield(S, resin_id)
	if (!sheets || !S.use(LAMINATE_CLOTH))
		return FALSE
	reagents.remove_reagent(resin_id, LAMINATE_RESIN)
	var/obj/item/stack/material/resin_laminate/L = new(get_turf(src), sheets)
	H.put_in_hands(L)
	to_chat(H, SPAN_NOTICE("You unscrew \the [src]: [sheets] sheet\s of resin laminate, hard as horn."))
	return TRUE

/obj/structure/hot_press/examine(mob/user, distance = -1)
	. = ..()
	var/phenolic = reagents.get_reagent_amount("phenolic_resin")
	var/resin = reagents.get_reagent_amount("resin")
	if (phenolic || resin)
		to_chat(user, SPAN_NOTICE("It holds [phenolic] units of phenolic resin and [resin] units of pine resin."))

#undef BAKELIZER_LIQUID_UNITS
#undef BAKELIZER_NYLON_SKEINS
#undef LAMINATE_CLOTH
#undef LAMINATE_RESIN
#undef LAMINATE_PRESS_TIME

// Aluminium: bauxite to alumina to aluminium (docs/aluminium.md).
// ------------------------------------------------------------
// Bauxite is mined from the Industrial age, richer under jungle and savanna.
// An alumina digester (the Bayer process, 1888) dissolves crushed bauxite in
// hot lye or sodium hydroxide and leaves alumina powder and red mud. A
// reduction pot (the Hall-Heroult process, 1886) splits alumina with a heavy
// electric current through carbon anodes, which burn away, and gives
// aluminium ingots. Both machines run on cable power; the pot draws a whole
// engine's worth, so a working power plant is the real gate. Both are
// unlocked by Aluminium Refining.
//
// Aluminium is light (a third of the weight of steel for the same volume):
// vehicle hulls made of it drive faster (vehicle_load.dm).
// ============================================================

#define DIGESTER_STEPS 5          // powered object-process steps (2 s each) per batch
#define DIGESTER_BAUXITE 2        // bauxite per alumina
#define DIGESTER_CAUSTIC 1        // units of lye or sodium hydroxide per alumina
#define DIGESTER_MAX_BAUXITE 100
#define DIGESTER_RED_MUD_EVERY 10 // alumina made per puddle of red mud
#define REDUCTION_STEPS 5
#define REDUCTION_CARBON_EVERY 2  // ingots per carbon anode burnt
#define REDUCTION_MAX_LOAD 100

// ---- Materials and stacks ----

/material/aluminium
	name = "aluminium"
	display_name = "aluminium"
	icon_colour = "#d6dde3"
	hardness = 35
	weight = 8
	door_icon_base = "metal"
	sheet_singular_name = "ingot"
	sheet_plural_name = "ingots"
	stack_type = /obj/item/stack/material/aluminium
	integrity = 120
	resilience = 0.8

/obj/item/stack/material/aluminium
	name = "aluminium"
	desc = "Bright, light ingots of aluminium, about a third of the weight of steel."
	icon = 'icons/obj/aluminium.dmi'
	icon_state = "sheet-aluminium"
	default_type = "aluminium"
	value = 4
	max_amount = 2000
	flags = CONDUCT

/obj/item/stack/material/aluminium/New()
	update_icon()
	return ..()

/obj/item/stack/material/aluminium/update_icon()
	icon_state = "sheet-aluminium[pile_suffix(amount, list(13, 26, 39))]"

/obj/item/stack/ore/bauxite
	name = "bauxite"
	desc = "Aluminium ore: red-brown earthy lumps. An alumina digester turns it into alumina."
	icon = 'icons/obj/aluminium.dmi'
	icon_state = "ore_bauxite"
	value = 1

/obj/item/stack/ore/bauxite/attackby(obj/W, mob/living/human/H)
	if (istype(W, /obj/item/weapon/reagent_containers/glass/extraction_kit))
		var/obj/item/weapon/reagent_containers/glass/extraction_kit/ET = W
		if (ET.reagents.total_volume > 0)
			to_chat(H, SPAN_NOTICE("Empty \the [ET] first."))
			return
		if (istype(H))
			visible_message(SPAN_NOTICE("[H] starts to purify \the [src] with \the [W.name]..."), SPAN_NOTICE("You start to purify \the [src] with \the [W.name]."))
			playsound(src, 'sound/effects/pickaxe.ogg', 100, 1)
			// One ore per use: the kit holds 5 units, so the rest of the stack stays.
			if (kit_wait(H, 110 / H.getStatCoeff("dexterity")) && ET.reagents.total_volume <= 0 && !QDELETED(src) && use(1))
				ET.reagents.add_reagent("aluminum", 5)
				ET.update_icon()
				if (!QDELETED(src))
					update_icon()
		return
	return ..()

/obj/item/stack/ore/alumina
	name = "alumina"
	desc = "Fine white aluminium oxide powder. A reduction pot turns it into aluminium; fired in a kiln it makes hard ceramic."
	icon = 'icons/obj/aluminium.dmi'
	icon_state = "alumina"
	value = 2

/obj/effect/decal/cleanable/red_mud
	name = "red mud"
	desc = "Caustic red sludge left over from refining bauxite."
	icon = 'icons/obj/aluminium.dmi'
	icon_state = "red_mud"

// Bauxite found in one mined wall, or 0: the Industrial age on, twice as
// often under jungle and savanna, where bauxite forms in real life.
/proc/mining_bauxite_chance(area/above)
	if (!map || map.ordinal_age < 4)
		return 0
	if (above && (above.climate == "jungle" || above.climate == "savanna"))
		return 12
	return 6

// Puts amount of stack_type on T, topping up a stack already there.
/proc/aluminium_works_output(turf/T, stack_type, amount = 1)
	if (!T || amount <= 0)
		return null
	for (var/obj/item/stack/S in T)
		if (S.type == stack_type && S.amount + amount <= S.max_amount)
			S.amount += amount
			S.update_icon()
			return S
	var/obj/item/stack/S = new stack_type(T)
	S.amount = amount
	S.update_icon()
	return S

// ---- The machines ----

/obj/structure/aluminium_works
	name = "aluminium works"
	icon = 'icons/obj/aluminium.dmi'
	anchored = TRUE
	density = TRUE
	flammable = FALSE
	not_movable = FALSE
	not_disassemblable = FALSE
	var/tmp/progress = 0
	var/base_state = "digester"

/obj/structure/aluminium_works/Destroy()
	processing_objects -= src
	works_release_power()
	return ..()

/obj/structure/aluminium_works/persistence_runtime_var(key)
	if (key == "powered" || key == "progress")
		return TRUE
	return ..()

// A batch in progress starts over after a load.
/obj/structure/aluminium_works/after_load()
	. = ..()
	powered = FALSE
	progress = 0
	if (can_work())
		processing_objects |= src
	update_icon()

/obj/structure/aluminium_works/update_icon()
	icon_state = powered ? "[base_state]_on" : base_state

/obj/structure/aluminium_works/proc/works_release_power()
	if (powersource)
		powersource.update_power(-powerneeded, 1, src)
	powered = FALSE

// TRUE while the machine holds enough for another batch.
/obj/structure/aluminium_works/proc/can_work()
	return FALSE

// Makes one batch; the inputs were checked by can_work().
/obj/structure/aluminium_works/proc/finish_batch()
	return

/obj/structure/aluminium_works/proc/wake()
	if (can_work())
		processing_objects |= src

/obj/structure/aluminium_works/process()
	if (!anchored || !isturf(loc) || !can_work())
		processing_objects -= src
		works_release_power()
		progress = 0
		update_icon()
		return PROCESS_KILL
	var/was_powered = powered
	powered = draw_cable_power() ? TRUE : FALSE
	if (powered != was_powered)
		update_icon()
	if (!powered || ++progress < process_steps())
		return
	progress = 0
	finish_batch()

/obj/structure/aluminium_works/proc/process_steps()
	return DIGESTER_STEPS

/obj/structure/aluminium_works/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/stack/cable_coil))
		connect_cable(user, W)
		return
	return ..()

// -- Alumina digester --

/obj/structure/aluminium_works/digester
	name = "alumina digester"
	desc = "A heated steel pressure vessel. Fill it with lye or sodium hydroxide, load bauxite and give it cable power: it makes alumina powder."
	icon_state = "digester"
	base_state = "digester"
	flags = NOREACT
	powerneeded = 10
	var/bauxite = 0
	var/alumina_made = 0

/obj/structure/aluminium_works/digester/New()
	..()
	create_reagents(100)

/obj/structure/aluminium_works/digester/proc/caustic()
	return reagents.get_reagent_amount("sodium_hydroxide") + reagents.get_reagent_amount("lye")

/obj/structure/aluminium_works/digester/can_work()
	return bauxite >= DIGESTER_BAUXITE && caustic() >= DIGESTER_CAUSTIC

/obj/structure/aluminium_works/digester/finish_batch()
	bauxite -= DIGESTER_BAUXITE
	var/need = DIGESTER_CAUSTIC
	for (var/id in list("sodium_hydroxide", "lye"))
		var/take = min(need, reagents.get_reagent_amount(id))
		if (take > 0)
			reagents.remove_reagent(id, take)
			need -= take
	var/turf/T = get_turf(src)
	aluminium_works_output(T, /obj/item/stack/ore/alumina)
	alumina_made++
	if (alumina_made % DIGESTER_RED_MUD_EVERY == 0 && !(locate(/obj/effect/decal/cleanable/red_mud) in T))
		new /obj/effect/decal/cleanable/red_mud(T)

// Loads up to the digester's room from S; returns how many went in.
/obj/structure/aluminium_works/digester/proc/load_bauxite(obj/item/stack/ore/bauxite/S)
	var/amount = min(S.amount, DIGESTER_MAX_BAUXITE - bauxite)
	if (amount <= 0 || !S.use(amount))
		return 0
	bauxite += amount
	wake()
	return amount

/obj/structure/aluminium_works/digester/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/stack/ore/bauxite))
		var/loaded = load_bauxite(W)
		if (loaded)
			to_chat(user, SPAN_NOTICE("You load [loaded] bauxite into \the [src]."))
		else
			to_chat(user, SPAN_WARNING("\The [src] is full of bauxite."))
		return
	if (istype(W, /obj/item/weapon/reagent_containers/glass))
		var/obj/item/weapon/reagent_containers/glass/B = W
		var/poured = 0
		for (var/id in list("sodium_hydroxide", "lye"))
			var/amount = min(B.amount_per_transfer_from_this - poured, B.reagents.get_reagent_amount(id), reagents.get_free_space())
			if (amount > 0)
				B.reagents.remove_reagent(id, amount)
				reagents.add_reagent(id, amount)
				poured += amount
		if (poured <= 0)
			to_chat(user, SPAN_WARNING("\The [src] takes only lye or sodium hydroxide, and has room for [round(reagents.get_free_space())] units."))
			return
		to_chat(user, SPAN_NOTICE("You pour [poured] units of caustic into \the [src]."))
		wake()
		return
	return ..()

/obj/structure/aluminium_works/digester/examine(mob/user, distance)
	..(user, distance)
	to_chat(user, SPAN_NOTICE("It holds [bauxite] bauxite and [round(caustic())] units of caustic, enough for [min(round(bauxite / DIGESTER_BAUXITE), round(caustic() / DIGESTER_CAUSTIC))] alumina."))
	if (can_work() && !powered)
		to_chat(user, SPAN_WARNING("It is waiting for power."))

// -- Reduction pot --

/obj/structure/aluminium_works/reduction_pot
	name = "reduction pot"
	desc = "An electrolytic cell lined with carbon. Load alumina and coal or charcoal for the anodes, then give it heavy cable power: it makes aluminium."
	icon_state = "reduction_pot"
	base_state = "reduction_pot"
	powerneeded = 40
	var/alumina = 0
	var/carbon = 0
	var/anode_wear = 0 // ingots made since the last anode burnt away

/obj/structure/aluminium_works/reduction_pot/process_steps()
	return REDUCTION_STEPS

/obj/structure/aluminium_works/reduction_pot/can_work()
	return alumina >= 1 && (carbon >= 1 || anode_wear > 0)

/obj/structure/aluminium_works/reduction_pot/finish_batch()
	alumina--
	if (anode_wear <= 0)
		carbon--
	anode_wear = (anode_wear + 1) % REDUCTION_CARBON_EVERY
	aluminium_works_output(get_turf(src), /obj/item/stack/material/aluminium)

/obj/structure/aluminium_works/reduction_pot/proc/is_carbon(obj/item/W)
	return istype(W, /obj/item/stack/ore/coal) || istype(W, /obj/item/stack/ore/charcoal)

/obj/structure/aluminium_works/reduction_pot/proc/load(obj/item/stack/S)
	var/carbon_load = is_carbon(S)
	if (!carbon_load && !istype(S, /obj/item/stack/ore/alumina))
		return 0
	var/amount = min(S.amount, REDUCTION_MAX_LOAD - (carbon_load ? carbon : alumina))
	if (amount <= 0 || !S.use(amount))
		return 0
	if (carbon_load)
		carbon += amount
	else
		alumina += amount
	wake()
	return amount

/obj/structure/aluminium_works/reduction_pot/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/stack/ore/alumina) || is_carbon(W))
		var/what = is_carbon(W) ? "carbon" : "alumina"
		var/loaded = load(W)
		if (loaded)
			to_chat(user, SPAN_NOTICE("You load [loaded] [what] into \the [src]."))
		else
			to_chat(user, SPAN_WARNING("\The [src] is full of [what]."))
		return
	return ..()

/obj/structure/aluminium_works/reduction_pot/examine(mob/user, distance)
	..(user, distance)
	to_chat(user, SPAN_NOTICE("It holds [alumina] alumina and [carbon] coal or charcoal for its anodes."))
	if (can_work() && !powered)
		to_chat(user, SPAN_WARNING("It is waiting for power: it needs [powerneeded] from the cable."))

// Factory arms load both machines.
/obj/structure/aluminium_works/digester/factory_accepts(obj/item/I, from_dir = 0)
	return istype(I, /obj/item/stack/ore/bauxite) && bauxite < DIGESTER_MAX_BAUXITE ? 1 : 0

/obj/structure/aluminium_works/digester/factory_insert(obj/item/I, from_dir = 0)
	return factory_accepts(I, from_dir) > 0 && load_bauxite(I) ? 1 : 0

/obj/structure/aluminium_works/reduction_pot/factory_accepts(obj/item/I, from_dir = 0)
	if (is_carbon(I))
		return carbon < REDUCTION_MAX_LOAD ? 1 : 0
	return istype(I, /obj/item/stack/ore/alumina) && alumina < REDUCTION_MAX_LOAD ? 1 : 0

/obj/structure/aluminium_works/reduction_pot/factory_insert(obj/item/I, from_dir = 0)
	return factory_accepts(I, from_dir) > 0 && load(I) ? 1 : 0

#undef DIGESTER_STEPS
#undef DIGESTER_BAUXITE
#undef DIGESTER_CAUSTIC
#undef DIGESTER_MAX_BAUXITE
#undef DIGESTER_RED_MUD_EVERY
#undef REDUCTION_STEPS
#undef REDUCTION_CARBON_EVERY
#undef REDUCTION_MAX_LOAD

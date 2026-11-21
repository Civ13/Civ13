// Crucible steel, wootz (docs/steelmaking.md): wrought iron and charcoal
// sealed in a small fired clay crucible and held in a kiln under a bellows
// blast until the iron melts and takes up carbon. Each crucible gives one
// cake of fine steel, if it does not crack.

#define CRUCIBLE_IRON 2 // wrought iron bars one crucible takes
#define CRUCIBLE_CHARCOAL 1 // charcoal packed with them
#define CRUCIBLE_FIRINGS 3 // blown kiln firings to melt a charge
#define CRUCIBLE_CRACK_CHANCE 25 // percent, for an ordinary smith
#define CRUCIBLE_KILN_FUEL 2 // extra kiln fuel each crucible takes per firing
#define CRUCIBLE_KILN_LIMIT 4 // crucibles one kiln holds

/obj/item/weapon/clay/crucible
	name = "unfired crucible"
	desc = "A small, thick-walled clay cup. Fire it before use."
	icon = 'icons/obj/steelmaking.dmi'
	icon_state = "steel_crucible_unfired"
	result = /obj/item/weapon/steel_crucible

/obj/item/weapon/steel_crucible
	name = "crucible"
	desc = "A small fired clay crucible for making steel. Pack it with 2 wrought iron bars and 1 charcoal, seal it with an empty hand, then fire it in a kiln under a bellows blast three times."
	icon = 'icons/obj/steelmaking.dmi'
	icon_state = "steel_crucible"
	w_class = ITEM_SIZE_SMALL
	var/iron = 0
	var/charcoal = 0
	var/sealed = FALSE
	var/heat = 0 // blown kiln firings it has been through
	var/packer_skill = 1 // Crafting coefficient of whoever sealed it

/obj/item/weapon/steel_crucible/examine(mob/user, distance)
	..(user, distance)
	if (sealed)
		to_chat(user, SPAN_NOTICE("It is sealed. It has been through [heat] of [CRUCIBLE_FIRINGS] blown kiln firings."))
	else
		to_chat(user, SPAN_NOTICE("It holds [iron] of [CRUCIBLE_IRON] iron bars and [charcoal] of [CRUCIBLE_CHARCOAL] charcoal."))

/obj/item/weapon/steel_crucible/attackby(obj/item/I, mob/user)
	if (sealed)
		to_chat(user, SPAN_WARNING("\The [src] is sealed."))
		return
	if (istype(I, /obj/item/stack/material/iron) && iron < CRUCIBLE_IRON)
		var/obj/item/stack/S = I
		var/moved = min(S.amount, CRUCIBLE_IRON - iron)
		iron += moved
		S.use(moved)
		to_chat(user, SPAN_NOTICE("You pack [moved] iron bar\s into \the [src]."))
		return
	if (istype(I, /obj/item/stack/ore/charcoal) && charcoal < CRUCIBLE_CHARCOAL)
		var/obj/item/stack/S = I
		var/moved = min(S.amount, CRUCIBLE_CHARCOAL - charcoal)
		charcoal += moved
		S.use(moved)
		to_chat(user, SPAN_NOTICE("You pack [moved] charcoal into \the [src]."))
		return
	return ..()

/obj/item/weapon/steel_crucible/attack_self(mob/living/human/user)
	if (!istype(user))
		return
	if (sealed)
		to_chat(user, SPAN_WARNING("\The [src] is already sealed."))
		return
	if (iron < CRUCIBLE_IRON || charcoal < CRUCIBLE_CHARCOAL)
		if (iron || charcoal)
			to_chat(user, SPAN_NOTICE("You tip the charge back out of \the [src]."))
			if (iron)
				spawn_stack(/obj/item/stack/material/iron, get_turf(user), iron)
			if (charcoal)
				spawn_stack(/obj/item/stack/ore/charcoal, get_turf(user), charcoal)
			iron = 0
			charcoal = 0
		else
			to_chat(user, SPAN_WARNING("Pack [CRUCIBLE_IRON] wrought iron bars and [CRUCIBLE_CHARCOAL] charcoal into \the [src] first."))
		return
	if (!do_after(user, 30, src))
		return
	sealed = TRUE
	icon_state = "steel_crucible_sealed"
	packer_skill = user.getStatCoeff("crafting")
	name = "sealed crucible"
	to_chat(user, SPAN_NOTICE("You seal the lid of \the [src] with clay."))

// Percent chance a fully fired crucible cracks: skill brings it down.
/obj/item/weapon/steel_crucible/proc/crack_chance()
	return clamp(round(CRUCIBLE_CRACK_CHANCE - (packer_skill - 1) * 40), 5, 40)

// One kiln firing. Only a blown firing gets a crucible hot enough.
/obj/item/weapon/steel_crucible/proc/kiln_fired(blown, turf/T)
	if (!sealed)
		return
	if (!blown)
		T.visible_message(SPAN_NOTICE("\The [src] glows, but the kiln never got hot enough to melt its charge. Pump the bellows."))
		return
	heat++
	if (heat < CRUCIBLE_FIRINGS)
		T.visible_message(SPAN_NOTICE("The charge in \the [src] is softening ([heat] of [CRUCIBLE_FIRINGS] firings)."))
		return
	if (prob(crack_chance()))
		T.visible_message(SPAN_WARNING("\The [src] cracks in the heat. The melt runs out into the ashes and is lost."))
		new /obj/item/weapon/clay(T)
		qdel(src)
		return
	T.visible_message(SPAN_NOTICE("\The [src] is broken open on a cake of fine steel."))
	spawn_stack(/obj/item/stack/material/steel/fine, T, 1)
	qdel(src)

/obj/structure/furnace/kiln/proc/crucibles()
	. = list()
	for (var/obj/item/weapon/steel_crucible/C in contents)
		. += C

// refining.dm's kiln attackby offers a sealed crucible here first.
/obj/structure/furnace/kiln/proc/accept_crucible(obj/item/I, mob/living/human/H)
	if (!istype(I, /obj/item/weapon/steel_crucible))
		return FALSE
	var/obj/item/weapon/steel_crucible/C = I
	if (!C.sealed)
		to_chat(H, SPAN_WARNING("Seal \the [C] first (use it in hand)."))
		return TRUE
	if (length(crucibles()) >= CRUCIBLE_KILN_LIMIT)
		to_chat(H, SPAN_WARNING("\The [src] holds no more crucibles."))
		return TRUE
	H.remove_from_mob(C)
	C.forceMove(src)
	visible_message(SPAN_NOTICE("[H] sets \the [C] in \the [src]."))
	return TRUE

// Each crucible in a kiln burns more fuel per firing.
/obj/structure/furnace/kiln/proc/crucible_fuel()
	return length(crucibles()) * CRUCIBLE_KILN_FUEL

// After every kiln firing: crucibles take their heat and come out.
/obj/structure/furnace/kiln/proc/fire_crucibles()
	var/turf/T = get_turf(src)
	for (var/obj/item/weapon/steel_crucible/C in crucibles())
		C.kiln_fired(blown_firing, T)
		if (!QDELETED(C))
			C.forceMove(T)

#undef CRUCIBLE_IRON
#undef CRUCIBLE_CHARCOAL
#undef CRUCIBLE_FIRINGS
#undef CRUCIBLE_CRACK_CHANCE
#undef CRUCIBLE_KILN_FUEL
#undef CRUCIBLE_KILN_LIMIT

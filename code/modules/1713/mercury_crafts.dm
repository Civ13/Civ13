// Crafts that use quicksilver (docs/mercury_crafts.md): fire gilding, the
// silvered wall mirror, the mercury barometer and thermometer, carroted felt
// for hats, and dimercaprol against mercury poisoning. Every one of them puts
// some quicksilver into the people doing the work.

#define GILDING_VAPOUR 6 // per item fire-gilt under a roof, halved outdoors
#define GILDING_TIME 80
#define MIRROR_TIN 1
#define MIRROR_MERCURY 5
#define MIRROR_VAPOUR 1
#define BAROMETER_MERCURY 5
#define THERMOMETER_MERCURY 2
#define CARROT_MERCURY 2
#define CARROT_FELT 2 // felt from one pelt
#define CARROT_VAPOUR 0.5
#define FELT_PER_HAT 2
#define DIMERCAPROL_PER_UNIT 6 // burden drawn out per unit metabolised (30 a 5u dose)

// Take amount units of quicksilver out of an open container held as W.
/proc/take_mercury(obj/item/W, amount)
	var/obj/item/weapon/reagent_containers/C = W
	if (!istype(C) || !C.is_open_container() || !C.reagents || C.reagents.get_reagent_amount("mercury") < amount)
		return FALSE
	C.reagents.remove_reagent("mercury", amount)
	return TRUE

/proc/holds_mercury(obj/item/W)
	var/obj/item/weapon/reagent_containers/C = W
	return istype(C) && C.reagents && C.reagents.get_reagent_amount("mercury") > 0

//////////////////////////////////////////////////////////////////////////////
// Fire gilding: rub gold amalgam on a copper, bronze or silver piece, then
// hold it over a fire until the quicksilver smokes off and leaves the gold.

var/global/list/fire_gilding_bases = list("copper", "bronze", "brass", "silver", "gold")

// Why I cannot be fire-gilt, or null when it can.
/proc/fire_gilding_refusal(obj/item/I)
	var/why = plating_refusal(I)
	if (why)
		return why
	if (istype(I, /obj/item/weapon/material))
		var/obj/item/weapon/material/M = I
		if (!M.material || !(M.material.name in fire_gilding_bases))
			return "Gold amalgam only takes on copper, bronze, brass or silver."
	return null

/obj/item/proc/fire_gild()
	var/list/data = plating_metals["gold"]
	if (plating || !data)
		return FALSE
	plating = "gold"
	name = "gilded [name]"
	color = data[3]
	value += data[4]
	return TRUE

/obj/item/stack/ore/amalgam/proc/gilds()
	return sponge_type == /obj/item/stack/ore/gold/sponge

// Gold amalgam used on a lit fire, brazier or furnace with the piece to gild
// in the other hand.
/obj/item/stack/ore/amalgam/resolve_attackby(atom/A, mob/user, icon_x, icon_y)
	if (gilds() && istype(A, /obj/structure) && !istype(A, /obj/structure/workshop_machine) && isflamesource(A) && ishuman(user))
		fire_gild_at(A, user)
		return TRUE
	return ..()

/obj/item/stack/ore/amalgam/proc/fire_gild_at(obj/structure/fire, mob/living/human/H)
	if (!crafting_node_allowed_or_warn(H, "bronze_working"))
		return FALSE
	var/obj/item/I = H.get_inactive_hand()
	if (!istype(I))
		to_chat(H, SPAN_WARNING("Hold the copper, bronze or silver piece you want to gild in your other hand."))
		return FALSE
	var/why = fire_gilding_refusal(I)
	if (why)
		to_chat(H, SPAN_WARNING(why))
		return FALSE
	H.visible_message(SPAN_NOTICE("[H] rubs gold amalgam over \the [I] and holds it over \the [fire]."), SPAN_NOTICE("You rub gold amalgam over \the [I] and hold it over \the [fire] while the quicksilver smokes off."))
	if (!do_after(H, GILDING_TIME, fire) || QDELETED(src) || amount < 1 || I.loc != H || !isflamesource(fire) || fire_gilding_refusal(I))
		return FALSE
	use(1)
	I.fire_gild()
	H.update_inv_l_hand()
	H.update_inv_r_hand()
	to_chat(H, SPAN_NOTICE("The grey coat turns to bright gold: \the [I] is gilded."))
	mercury_vapour(fire, GILDING_VAPOUR, "the fumes of fire gilding")
	return TRUE

//////////////////////////////////////////////////////////////////////////////
// The wall mirror: glass backed with tin foil, the foil wetted with quicksilver.

/obj/structure/mirror/unsilvered
	name = "unsilvered mirror"
	desc = "A pane of glass in a frame, waiting for its backing. Lay a sheet of tin foil on it, then pour quicksilver over the foil: it soaks in and turns the back to a bright mirror."
	icon = 'icons/obj/mercury_crafts.dmi'
	icon_state = "mirror_unsilvered"
	item_type = /obj/item/mirror/unsilvered
	var/tinned = FALSE

/obj/item/mirror/unsilvered
	name = "unsilvered mirror"
	desc = "A framed pane of glass with no backing yet. Fasten it to a wall with a hammer, then back it with tin and quicksilver."
	icon = 'icons/obj/mercury_crafts.dmi'
	icon_state = "mirror_unsilvered"
	structure_type = /obj/structure/mirror/unsilvered

/obj/structure/mirror/unsilvered/examine(mob/user, distance)
	..(user, distance)
	if (!shattered)
		to_chat(user, tinned ? "Tin foil is laid on the back. It needs [MIRROR_MERCURY] units of quicksilver." : "It needs a sheet of tin, then [MIRROR_MERCURY] units of quicksilver.")

/obj/structure/mirror/unsilvered/attack_hand(mob/user)
	if (!shattered)
		to_chat(user, SPAN_NOTICE("The bare glass shows only a faint ghost of your face."))

/obj/structure/mirror/unsilvered/attackby(obj/item/I, mob/living/human/user)
	if (shattered || !istype(user))
		return ..()
	if (istype(I, /obj/item/stack/material/tin))
		if (tinned)
			to_chat(user, SPAN_NOTICE("The tin foil is already on."))
			return
		var/obj/item/stack/material/tin/T = I
		if (!T.use(MIRROR_TIN))
			return
		tinned = TRUE
		to_chat(user, SPAN_NOTICE("You beat the tin out thin and lay it smooth on the back of \the [src]."))
		return
	if (holds_mercury(I))
		if (!tinned)
			to_chat(user, SPAN_WARNING("Lay a sheet of tin on the back first."))
			return
		if (!take_mercury(I, MIRROR_MERCURY))
			to_chat(user, SPAN_WARNING("It takes [MIRROR_MERCURY] units of quicksilver to silver a mirror."))
			return
		silver(user)
		return
	return ..()

/obj/structure/mirror/unsilvered/proc/silver(mob/living/human/H)
	var/obj/structure/mirror/M = new(loc)
	M.pixel_x = pixel_x
	M.pixel_y = pixel_y
	M.dir = dir
	if (H)
		to_chat(H, SPAN_NOTICE("The quicksilver runs over the foil and eats into it. The glass turns bright: \the [M] is silvered."))
	mercury_vapour(M, MIRROR_VAPOUR, "silvering a mirror")
	qdel(src)
	return M

//////////////////////////////////////////////////////////////////////////////
// The mercury barometer: a sealed glass tube of quicksilver.

/obj/item/weapon/barometer
	var/filled = TRUE

/obj/item/weapon/barometer/empty
	name = "empty barometer"
	desc = "A brass case with an empty glass tube. Pour in quicksilver to make it read the weight of the air."
	filled = FALSE

/obj/item/weapon/barometer/attack_self(mob/user)
	if (!filled)
		to_chat(user, SPAN_NOTICE("The tube of \the [src] is empty. It needs [BAROMETER_MERCURY] units of quicksilver."))
		return
	return ..()

/obj/item/weapon/barometer/attackby(obj/item/I, mob/user)
	if (!filled && holds_mercury(I))
		if (!take_mercury(I, BAROMETER_MERCURY))
			to_chat(user, SPAN_WARNING("It takes [BAROMETER_MERCURY] units of quicksilver to fill the tube."))
			return
		filled = TRUE
		name = "barometer"
		desc = initial(desc)
		to_chat(user, SPAN_NOTICE("You fill the tube of \the [src] with quicksilver and seal it."))
		return
	return ..()

//////////////////////////////////////////////////////////////////////////////
// The mercury thermometer.

/obj/item/weapon/thermometer
	name = "thermometer"
	desc = "A slim glass tube of quicksilver on a scale. The column climbs as the air warms. Use it in your hand to read it."
	icon = 'icons/obj/mercury_crafts.dmi'
	icon_state = "thermometer"
	slot_flags = SLOT_BELT | SLOT_POCKET
	w_class = ITEM_SIZE_TINY
	force = WEAPON_FORCE_HARMLESS
	throwforce = WEAPON_FORCE_HARMLESS
	flammable = FALSE
	var/filled = TRUE

/obj/item/weapon/thermometer/empty
	name = "empty thermometer"
	desc = "A slim glass tube on a scale, with nothing in it yet. Pour in quicksilver to make it read the warmth of the air."
	icon_state = "thermometer_empty"
	filled = FALSE

/proc/thermometer_reading(atom/A)
	var/t = round(get_temp(A))
	var/feel
	if (t <= -15)
		feel = "bitter frost"
	else if (t <= 0)
		feel = "freezing"
	else if (t <= 10)
		feel = "cold"
	else if (t <= 20)
		feel = "mild"
	else if (t <= 30)
		feel = "warm"
	else
		feel = "hot"
	return "The quicksilver stands at [t] degrees: [feel]."

/obj/item/weapon/thermometer/attack_self(mob/user)
	if (!filled)
		to_chat(user, SPAN_NOTICE("The tube of \the [src] is empty. It needs [THERMOMETER_MERCURY] units of quicksilver."))
		return
	to_chat(user, SPAN_NOTICE(thermometer_feels_reading(user)))

/obj/item/weapon/thermometer/attackby(obj/item/I, mob/user)
	if (!filled && holds_mercury(I))
		if (!take_mercury(I, THERMOMETER_MERCURY))
			to_chat(user, SPAN_WARNING("It takes [THERMOMETER_MERCURY] units of quicksilver to fill the tube."))
			return
		filled = TRUE
		name = "thermometer"
		desc = initial(desc)
		icon_state = "thermometer"
		to_chat(user, SPAN_NOTICE("You fill \the [src] with quicksilver and seal the tube."))
		return
	return ..()

//////////////////////////////////////////////////////////////////////////////
// Carroted felt: fur brushed with quicksilver mats into felt for hats.

/obj/item/stack/carroted_felt
	name = "carroted felt"
	singular_name = "sheet"
	desc = "Dense fur felt, its fibres roughened with quicksilver so they mat tight. Use it in your hand to block a felt hat from two sheets."
	icon = 'icons/obj/mercury_crafts.dmi'
	icon_state = "carroted_felt"
	max_amount = 10
	w_class = ITEM_SIZE_SMALL

var/global/list/felt_hat_types = list(
	"felt tricorne" = /obj/item/clothing/head/tricorne_black/felt,
	"felt bicorne" = /obj/item/clothing/head/bicorne_british_soldier/felt,
	"felt top hat" = /obj/item/clothing/head/top_hat/felt)

/obj/item/stack/carroted_felt/attack_self(mob/living/human/H)
	if (!istype(H))
		return
	if (amount < FELT_PER_HAT)
		to_chat(H, SPAN_WARNING("A hat takes [FELT_PER_HAT] sheets of felt."))
		return
	var/choice = WWinput(H, "Which hat do you block?", "Felt hat", "Cancel", WWinput_list_or_null(felt_hat_types))
	if (!choice || choice == "Cancel" || !felt_hat_types[choice])
		return
	to_chat(H, SPAN_NOTICE("You steam and block the felt into a [choice]."))
	if (!do_after(H, 40, src) || QDELETED(src) || amount < FELT_PER_HAT || loc != H)
		return
	var/hat_type = felt_hat_types[choice]
	use(FELT_PER_HAT)
	var/obj/item/clothing/head/hat = new hat_type(get_turf(H))
	H.put_in_hands(hat)
	to_chat(H, SPAN_NOTICE("You finish \a [hat]."))

// A pelt brushed with quicksilver from an open vessel.
/obj/item/stack/material/pelt/attackby(obj/item/W, mob/user)
	if (!holds_mercury(W) || !ishuman(user))
		return ..()
	var/mob/living/human/H = user
	if (!crafting_node_allowed_or_warn(H, "haberdashery"))
		return
	if (W.reagents.get_reagent_amount("mercury") < CARROT_MERCURY)
		to_chat(H, SPAN_WARNING("Carroting a pelt takes [CARROT_MERCURY] units of quicksilver."))
		return
	H.visible_message(SPAN_NOTICE("[H] brushes quicksilver into \the [src]."), SPAN_NOTICE("You brush quicksilver into the fur of \the [src] and work it into felt."))
	if (!do_after(H, 50, src) || QDELETED(src) || amount < 1)
		return
	if (!take_mercury(W, CARROT_MERCURY))
		return
	use(1)
	var/obj/item/stack/carroted_felt/F = new(get_turf(H), CARROT_FELT)
	H.put_in_hands(F)
	to_chat(H, SPAN_NOTICE("The fur mats down into [CARROT_FELT] sheets of carroted felt."))
	mercury_vapour(H, CARROT_VAPOUR, "carroting felt")

/obj/item/clothing/head/tricorne_black/felt
	name = "felt tricorne"
	desc = "A tricorne blocked from beaver felt. Felt sheds the rain far better than cloth."
	icon = 'icons/obj/mercury_crafts.dmi'
	icon_state = "felt_tricorne"
	item_state_slots = list(slot_head_str = "felt_tricorne")
	item_icons = list(
		slot_head_str = 'icons/mob/mercury_crafts.dmi',
		slot_l_hand_str = 'icons/mob/items/lefthand_hats.dmi',
		slot_r_hand_str = 'icons/mob/items/righthand_hats.dmi',
		)
	rain_resist = 30

/obj/item/clothing/head/bicorne_british_soldier/felt
	name = "felt bicorne"
	desc = "A bicorne blocked from beaver felt. Felt sheds the rain far better than cloth."
	icon = 'icons/obj/mercury_crafts.dmi'
	icon_state = "felt_bicorne"
	item_state_slots = list(slot_head_str = "felt_bicorne")
	item_icons = list(
		slot_head_str = 'icons/mob/mercury_crafts.dmi',
		slot_l_hand_str = 'icons/mob/items/lefthand_hats.dmi',
		slot_r_hand_str = 'icons/mob/items/righthand_hats.dmi',
		)
	rain_resist = 30

/obj/item/clothing/head/top_hat/felt
	name = "felt top hat"
	desc = "A tall top hat blocked from beaver felt. Felt sheds the rain far better than cloth."
	icon = 'icons/obj/mercury_crafts.dmi'
	icon_state = "felt_top_hat"
	item_state_slots = list(slot_head_str = "felt_top_hat")
	item_icons = list(
		slot_head_str = 'icons/mob/mercury_crafts.dmi',
		slot_l_hand_str = 'icons/mob/items/lefthand_hats.dmi',
		slot_r_hand_str = 'icons/mob/items/righthand_hats.dmi',
		)
	rain_resist = 30

//////////////////////////////////////////////////////////////////////////////
// Dimercaprol: binds quicksilver in the blood so the body can pass it.

/datum/reagent/dimercaprol
	name = "dimercaprol"
	id = "dimercaprol"
	description = "An oily chelating drug that binds quicksilver in the blood so the body can pass it. A 5 unit dose draws out much of a mercury burden."
	taste_description = "rotten eggs"
	reagent_state = LIQUID
	color = "#D8D0A0"
	metabolism = REM * 0.5
	overdose = REAGENTS_OVERDOSE
	scannable = TRUE

/datum/reagent/dimercaprol/affect_blood(mob/living/human/M, alien, removed)
	if (istype(M) && M.mercury_burden > 0)
		M.mercury_burden = max(0, M.mercury_burden - DIMERCAPROL_PER_UNIT * removed)

/datum/chemical_reaction/dimercaprol
	name = "Dimercaprol"
	id = "dimercaprol"
	result = "dimercaprol"
	required_reagents = list("glycerol" = 1, "bromine" = 1, "sodium_sulfide" = 1)
	result_amount = 2

// Modern Medicine age: before it nobody knows how to make it.
/datum/chemical_reaction/dimercaprol/can_happen(datum/reagents/holder)
	if (!map || map.ordinal_age < 7)
		return FALSE
	return ..()

#undef GILDING_VAPOUR
#undef GILDING_TIME
#undef MIRROR_TIN
#undef MIRROR_MERCURY
#undef MIRROR_VAPOUR
#undef BAROMETER_MERCURY
#undef THERMOMETER_MERCURY
#undef CARROT_MERCURY
#undef CARROT_FELT
#undef CARROT_VAPOUR
#undef FELT_PER_HAT
#undef DIMERCAPROL_PER_UNIT

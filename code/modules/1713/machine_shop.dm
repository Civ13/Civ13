// Machine shop: three machines that take work off the smith at an anvil.
//
// Like the trip hammer (mechanical_power.dm) each is fastened next to an
// anvil and asked by the anvil's forge_time() when a job starts. The steam
// hammer is a hammer that needs no prime mover: it burns fuel, one blow's
// worth a job. The drill press and the hydraulic press are fitting machines:
// each shortens one class of anvil work, on top of whatever hammer is there.
// Nothing ticks; a machine is only looked at when a job starts.

#define STEAM_HAMMER_FACTOR 0.35
#define STEAM_HAMMER_FUEL_LIMIT 60
#define FITTING_FACTOR 0.6

// Forging jobs one unit of each fuel pays for.
var/global/list/steam_hammer_fuel_rates = list(
	"coal" = 4, "charcoal" = 3, "wood" = 1, "plank" = 1, "bamboo" = 1)

// Anvil recipe categories a drill press bores and drills.
var/global/list/drill_press_categories = list("guns", "machine guns", "flintlock parts", "parts")
// Words that mark an anvil category as pressed plate.
var/global/list/hydraulic_press_words = list("helmet", "armor", "shield", "headwear", "brodie", "adrian")

//////////////////////////////////////////////////////////////////////////////
// Steam hammer

/obj/structure/workshop_machine/trip_hammer/steam
	name = "steam hammer"
	desc = "An iron frame with a steam cylinder that throws a heavy ram down on the work. Fasten it next to an anvil and load coal, charcoal or wood: while it has fuel, forging at that anvil takes about a third of the time. It needs no prime mover."
	icon = 'icons/obj/machine_shop.dmi'
	icon_state = "steam_hammer"
	working_text = "It has steam up. Forging at an anvil next to it takes about a third of the time."
	idle_text = "Its firebox is cold. Load coal, charcoal or wood."
	var/fuel = 0 // forging jobs it can still strike for

/obj/structure/workshop_machine/trip_hammer/steam/striking(preview = FALSE)
	return anchored && isturf(loc) && fuel >= 1

/obj/structure/workshop_machine/trip_hammer/steam/forge_factor(category, preview = FALSE)
	return striking() ? STEAM_HAMMER_FACTOR : 1

/obj/structure/workshop_machine/trip_hammer/steam/forge_used()
	fuel = max(0, fuel - 1)
	..()

/obj/structure/workshop_machine/trip_hammer/steam/examine(mob/user, distance)
	..(user, distance)
	to_chat(user, SPAN_NOTICE("Its firebox holds fuel for [round(fuel)] of [STEAM_HAMMER_FUEL_LIMIT] forging jobs."))

/obj/structure/workshop_machine/trip_hammer/steam/attackby(obj/item/I, mob/living/human/H)
	if (!istype(H))
		return
	var/obj/item/stack/S = I
	var/each = istype(S) ? solid_fuel_unit_value(S, steam_hammer_fuel_rates) : 0
	if (!each)
		return ..()
	var/moved = min(S.amount, round((STEAM_HAMMER_FUEL_LIMIT - fuel) / each))
	if (moved <= 0)
		to_chat(H, SPAN_WARNING("\The [src]'s firebox is full."))
		return
	fuel += moved * each
	S.use(moved)
	visible_message(SPAN_NOTICE("[H] stokes \the [src]."))

//////////////////////////////////////////////////////////////////////////////
// Fitting machines

/obj/structure/workshop_machine/fitting
	name = "fitting machine"
	icon = 'icons/obj/machine_shop.dmi'
	forge_role = "fitting"
	var/work = "work" // what it takes off the smith, for messages

// TRUE when the fastened machine can work right now.
/obj/structure/workshop_machine/fitting/proc/ready(preview = FALSE)
	return anchored && isturf(loc)

/obj/structure/workshop_machine/fitting/proc/helps(category)
	return FALSE

/obj/structure/workshop_machine/fitting/forge_factor(category, preview = FALSE)
	return (category && ready(preview) && helps(category)) ? FITTING_FACTOR : 1

/obj/structure/workshop_machine/fitting/proc/idle_reason()
	return null

/obj/structure/workshop_machine/fitting/examine(mob/user, distance)
	..(user, distance)
	if (!anchored)
		to_chat(user, SPAN_WARNING("It is not fastened down."))
	else if (ready())
		to_chat(user, SPAN_NOTICE("It is ready. [capitalize(work)] forged at an anvil next to it takes two fifths less time."))
	else
		to_chat(user, SPAN_WARNING(idle_reason()))

/obj/structure/workshop_machine/fitting/attack_hand(mob/living/human/H)
	if (istype(H))
		examine(H, 1)

/obj/structure/workshop_machine/fitting/attackby(obj/item/I, mob/living/human/H)
	if (!istype(H))
		return
	if (handle_machine_tool(I, H))
		return
	return ..()

/obj/structure/workshop_machine/fitting/drill_press
	name = "drill press"
	desc = "An iron pillar drill with a belt-driven spindle. Fasten it next to an anvil and next to a turning treadwheel, horse gin, mill wheel or windmill: guns, gun parts and machine parts forged at that anvil are bored and drilled on it, and take two fifths less time."
	icon_state = "drill_press"
	work = "guns, gun parts and machine parts"

/obj/structure/workshop_machine/fitting/drill_press/ready(preview = FALSE)
	return ..() && mechanical_drive_factor(src, !preview) < 1

/obj/structure/workshop_machine/fitting/drill_press/helps(category)
	return category in drill_press_categories

/obj/structure/workshop_machine/fitting/drill_press/idle_reason()
	return "Nothing is turning its spindle. It needs a turning prime mover next to it."

/obj/structure/workshop_machine/fitting/hydraulic_press
	name = "hydraulic press"
	desc = "A heavy iron press with a hand pump and a water cylinder. Fasten it next to an anvil: helmets, armour and shields forged at that anvil are pressed to shape on it, and take two fifths less time. It is pumped by hand and needs no prime mover."
	icon_state = "hydraulic_press"
	work = "helmets, armour and shields"

/obj/structure/workshop_machine/fitting/hydraulic_press/helps(category)
	for (var/word in hydraulic_press_words)
		if (findtext(category, word))
			return TRUE
	return FALSE

#undef STEAM_HAMMER_FACTOR
#undef STEAM_HAMMER_FUEL_LIMIT
#undef FITTING_FACTOR

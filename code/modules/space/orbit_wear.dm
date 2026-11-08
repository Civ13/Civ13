// ============================================================
// Station wear (orbital stations, stage C)
// ------------------------------------------------------------
// Two parts of a station wear out in orbit and need spares from the ground.
// Wear only applies on an orbit world; ground and Moon or Mars habitats keep
// their old behaviour.
//
// - CO2 scrubbers use up their sorbent bed as they work: one percent for
//   every ORBIT_SORBENT_PER_PERCENT kPa-tiles of CO2 removed (a little under
//   three hours of steady scrubbing for a full bed). An empty bed stops the
//   scrubber until a sorbent cartridge refills it.
// - Solar wings and arrays lose efficiency in sunlight as the cells degrade,
//   ORBIT_PANEL_WEAR_PER_HOUR percent an hour, down to half their output.
//   Two glass sheets replace the worst cells (25 points).
//
// Both are plain numbers on the parts themselves. Panel wear counts on the
// space hazard clock, so nothing wears while the world is empty.
// ============================================================

#define ORBIT_SORBENT_PER_PERCENT 10
#define ORBIT_PANEL_WEAR_PER_HOUR 3
#define ORBIT_PANEL_WEAR_MAX 50
#define ORBIT_PANEL_REPAIR 25

// ---------------------------------------------------------------- sorbent

/obj/structure/life_support/scrubber/var/sorbent = 100

/proc/orbit_sorbent_ready(obj/structure/life_support/scrubber/S)
	return !orbit_world() || S.sorbent > 0

/proc/orbit_sorbent_use(obj/structure/life_support/scrubber/S, amount)
	if (!orbit_world() || !isnum(amount) || amount <= 0)
		return
	var/before = S.sorbent
	S.sorbent = max(0, S.sorbent - amount / ORBIT_SORBENT_PER_PERCENT)
	if (before > 0 && S.sorbent <= 0)
		S.visible_message(SPAN_WARNING("\The [S]'s sorbent bed is spent. It needs a fresh cartridge."))

/obj/structure/life_support/scrubber/examine(mob/user)
	..()
	if (orbit_world())
		to_chat(user, SPAN_NOTICE("Sorbent bed: [round(sorbent)]%."))

/obj/structure/life_support/scrubber/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/sorbent_cartridge))
		if (sorbent >= 100)
			to_chat(user, SPAN_NOTICE("The sorbent bed is fresh."))
			return
		sorbent = 100
		to_chat(user, SPAN_NOTICE("You swap in a fresh sorbent cartridge."))
		qdel(W)
		return
	return ..()

/obj/item/sorbent_cartridge
	name = "sorbent cartridge"
	desc = "A packed canister of lithium hydroxide and amine beads. Swap it into a CO2 scrubber when its bed is spent."
	icon = 'icons/obj/modern_structures.dmi'
	icon_state = "airfilter_canister"
	w_class = ITEM_SIZE_SMALL

// ---------------------------------------------------------------- panels

/obj/structure/civ_generator/solar/wing/var/wear = 0

/obj/structure/civ_generator/solar/wing/rated_output()
	. = ..()
	if (orbit_world() && wear > 0)
		. = round(. * (100 - clamp(wear, 0, ORBIT_PANEL_WEAR_MAX)) / 100, 1)

/obj/structure/civ_generator/solar/wing/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/stack/material/glass))
		var/obj/item/stack/material/glass/G = W
		if (wear <= 0)
			to_chat(user, SPAN_NOTICE("The cells are like new."))
			return
		if (!G.use(2))
			to_chat(user, SPAN_WARNING("You need two sheets of glass."))
			return
		wear = max(0, wear - ORBIT_PANEL_REPAIR)
		to_chat(user, SPAN_NOTICE("You replace the worst cells ([round(wear)]% wear)."))
		return
	return ..()

// Panel wear for one hazard step: wings in sunlight age.
/proc/orbit_wear_step(seconds)
	if (!orbit_world() || !isnum(seconds) || seconds <= 0)
		return FALSE
	var/obj/structure/orbit_registry/R = orbit_get_registry()
	if (!R || !R.sunlit)
		return FALSE
	for (var/obj/structure/civ_generator/solar/wing/W in civ_generators)
		if (!QDELETED(W) && W.enabled)
			W.wear = min(ORBIT_PANEL_WEAR_MAX, W.wear + ORBIT_PANEL_WEAR_PER_HOUR * seconds / 3600)
	return TRUE

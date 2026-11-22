// ============================================================
// Small boat upkeep (docs/small-boat-upkeep.md)
// ------------------------------------------------------------
// Wear comes only from tiles travelled with someone at the paddle, so a boat
// left alone never changes. Salt water wears twice as fast as fresh.
//
// - Lashings (rafts and outriggers) work loose. Slack, they slow her; loose,
//   she ships water as a damaged boat does. One rope makes them tight. She
//   never comes apart. A new raft is bound with bark and vines and starts
//   part worn; rope makes a proper job of it.
// - Dugout hulls (canoes and outriggers) soak. A heavy hull is slower and a
//   waterlogged one much slower. Hauled out she dries by the minute; animal
//   fat or tarred oakum rubbed in ashore dries her at once and halves the
//   soaking for the next stretch of travel.
// - An outrigger's sail left set in a strong wind may tear. A torn sail
//   drives nothing until two pieces of cloth mend it.
//
// Hooks: do_move and small_craft_attackby/small_craft_text in
// small_craft_leaks.dm, Move in boat_hauling.dm, step_delay in dugout_canoe.dm.
// ============================================================

#define BOAT_UPKEEP_TIME 50
#define BOAT_SAIL_CLOTH 2

/obj/structure/vehicle/raft
	var/lash_wear = BOAT_RAFT_NEW_WEAR
	var/soak = 0
	var/dressing = 0                 // Tiles of dressing left on the hull.
	var/tmp/ashore_since = null      // world.time she came out of the water; not saved, so a load restarts her drying.

/obj/structure/vehicle/raft/dugout
	lash_wear = 0

/obj/structure/vehicle/raft/proc/has_lashings()
	return TRUE

/obj/structure/vehicle/raft/dugout/has_lashings()
	return FALSE

/obj/structure/vehicle/raft/dugout/outrigger/has_lashings()
	return TRUE

/obj/structure/vehicle/raft/proc/soaks()
	return FALSE

/obj/structure/vehicle/raft/dugout/soaks()
	return TRUE

// ---- Wear ----

// One tile travelled with someone at the paddle.
/obj/structure/vehicle/raft/proc/boat_wear()
	var/turf/floor/beach/water/W = loc
	var/rate = BOAT_WEAR_FRESH * ((istype(W) && W.salty) ? 2 : 1)
	if (has_lashings() && lash_wear < 100)
		var/was = lash_wear
		lash_wear = min(100, lash_wear + rate)
		if (was < BOAT_LASH_SLACK && lash_wear >= BOAT_LASH_SLACK)
			small_craft_message(SPAN_WARNING("The lashings of \the [src] are working slack and she is slower for it. A rope will make them tight."))
		else if (was < BOAT_LASH_LOOSE && lash_wear >= BOAT_LASH_LOOSE)
			small_craft_message(SPAN_DANGER("The lashings of \the [src] are loose and she is taking water. Re-lash her with a rope."))
	if (soaks() && soak < 100)
		var/was = soak
		soak = min(100, soak + (dressing > 0 ? rate / 2 : rate))
		if (dressing > 0)
			dressing--
			if (!dressing)
				small_craft_message(SPAN_NOTICE("The dressing has worn off the hull of \the [src]."))
		if (was < BOAT_SOAK_HEAVY && soak >= BOAT_SOAK_HEAVY)
			small_craft_message(SPAN_WARNING("The hull of \the [src] is soaking up water and getting heavy. Haul her out to dry."))
		else if (was < BOAT_SOAK_LOGGED && soak >= BOAT_SOAK_LOGGED)
			small_craft_message(SPAN_DANGER("\The [src] is waterlogged and wallows. Haul her out to dry, or dress the hull with fat."))
	sail_weather()

/obj/structure/vehicle/raft/proc/sail_weather()
	return

// Tenths of a second her wear adds to every tile.
/obj/structure/vehicle/raft/proc/wear_delay()
	. = 0
	if (has_lashings() && lash_wear >= BOAT_LASH_SLACK)
		. += 2
	if (soaks())
		if (soak >= BOAT_SOAK_LOGGED)
			. += 3
		else if (soak >= BOAT_SOAK_HEAVY)
			. += 1

// Tenths of a second her next tile takes, heading m_dir.
/obj/structure/vehicle/raft/proc/step_delay(m_dir)
	return initial(vehicle_m_delay) + wear_delay()

/obj/structure/vehicle/raft/processmove(m_dir = null)
	vehicle_m_delay = step_delay(m_dir)
	return ..()

/obj/structure/vehicle/raft/leak_chance()
	. = ..()
	if (has_lashings() && lash_wear >= BOAT_LASH_LOOSE)
		. = max(., 30)

// ---- Drying ----

/obj/structure/vehicle/proc/came_ashore()
	return

/obj/structure/vehicle/proc/took_water()
	return

/obj/structure/vehicle/raft/came_ashore()
	ashore_since = world.time

/obj/structure/vehicle/raft/took_water()
	dry_out()
	ashore_since = null

// Takes the time she has lain ashore off her soak.
/obj/structure/vehicle/raft/proc/dry_out()
	if (isnull(ashore_since))
		if (!afloat())
			ashore_since = world.time
		return
	var/minutes = (world.time - ashore_since) / 600
	if (soaks() && soak > 0)
		soak = max(0, soak - BOAT_DRY_PER_MINUTE * minutes * dry_factor())
	ashore_since = world.time

// ---- Work ----

// TRUE when the click was upkeep and is done with.
/obj/structure/vehicle/raft/proc/upkeep_work(obj/item/W, mob/living/human/H)
	if (istype(W, /obj/item/stack/material/rope) && has_lashings())
		if (lash_wear < 10)
			to_chat(H, SPAN_NOTICE("The lashings of \the [src] are tight."))
			return TRUE
		if (upkeep_refused(H, "re-lash"))
			return TRUE
		var/obj/item/stack/S = W
		H.visible_message(SPAN_NOTICE("[H] starts re-lashing \the [src]."), SPAN_NOTICE("You start hauling the lashings of \the [src] tight with fresh rope."))
		if (do_after(H, BOAT_UPKEEP_TIME, src) && !QDELETED(S) && !upkeep_refusal() && S.use(1))
			lash_wear = 0
			to_chat(H, SPAN_NOTICE("The lashings of \the [src] are tight again."))
		return TRUE
	if (soaks() && (istype(W, /obj/item/weapon/reagent_containers/food/snacks/animalfat) || istype(W, /obj/item/stack/tarred_oakum)))
		if (afloat())
			to_chat(H, SPAN_WARNING("Haul \the [src] out of the water to dress her hull."))
			return TRUE
		if (upkeep_refused(H, "dress the hull of"))
			return TRUE
		H.visible_message(SPAN_NOTICE("[H] starts working \the [W] into the hull of \the [src]."), SPAN_NOTICE("You start working \the [W] into the wood of the hull."))
		if (do_after(H, BOAT_UPKEEP_TIME, src) && !QDELETED(W) && !afloat() && !upkeep_refusal())
			if (istype(W, /obj/item/stack))
				var/obj/item/stack/S = W
				if (!S.use(1))
					return TRUE
			else
				H.drop_from_inventory(W)
				qdel(W)
			soak = 0
			dressing = BOAT_DRESSING_TILES
			to_chat(H, SPAN_NOTICE("The hull of \the [src] is dry and dressed. She will soak half as fast for a good while."))
		return TRUE
	return FALSE

/obj/structure/vehicle/raft/proc/upkeep_refusal()
	if (istype(loc, /turf/floor/beach/water/deep))
		return "she has to be ashore or in the shallows"
	if (length(ontop) || length(ontop_o))
		return "she has to be empty"
	return null

/obj/structure/vehicle/raft/proc/upkeep_refused(mob/user, what)
	var/why = upkeep_refusal()
	if (why)
		to_chat(user, SPAN_WARNING("You cannot [what] \the [src]: [why]."))
		return TRUE
	return FALSE

// ---- The outrigger's sail ----

/obj/structure/vehicle/raft/dugout/outrigger/sail_weather()
	if (!mast || !sail_set || sail_torn)
		return
	var/wind = weather_wind_at(src)
	if (wind >= 3 && prob(wind >= 4 ? 6 : 2))
		sail_torn = TRUE
		update_icon()
		small_craft_message(SPAN_DANGER("The sail of \the [src] tears in the wind! It drives nothing until [BOAT_SAIL_CLOTH] pieces of cloth mend it. Furl the sail when it blows this hard."))

/obj/structure/vehicle/raft/dugout/outrigger/upkeep_work(obj/item/W, mob/living/human/H)
	if (mast && sail_torn && (istype(W, /obj/item/stack/material/cloth) || istype(W, /obj/item/stack/material/woolcloth)))
		var/obj/item/stack/S = W
		if (S.amount < BOAT_SAIL_CLOTH)
			to_chat(H, SPAN_WARNING("Mending the sail takes [BOAT_SAIL_CLOTH] pieces of cloth."))
			return TRUE
		if (upkeep_refused(H, "mend the sail of"))
			return TRUE
		H.visible_message(SPAN_NOTICE("[H] starts mending the sail of \the [src]."), SPAN_NOTICE("You start stitching cloth over the tears."))
		if (do_after(H, BOAT_UPKEEP_TIME, src) && sail_torn && !QDELETED(S) && !upkeep_refusal() && S.use(BOAT_SAIL_CLOTH))
			sail_torn = FALSE
			update_icon()
			to_chat(H, SPAN_NOTICE("The sail of \the [src] is whole again."))
		return TRUE
	return ..()

// ---- What a look tells ----

/obj/structure/vehicle/raft/proc/upkeep_text()
	. = ""
	if (has_lashings())
		if (lash_wear >= BOAT_LASH_LOOSE)
			. += " Her lashings are loose and let water in: re-lash her with a rope."
		else if (lash_wear >= BOAT_LASH_SLACK)
			. += " Her lashings are slack and slow her: a rope makes them tight."
		else if (lash_wear >= 25)
			. += " Her lashings have some give in them."
	if (soaks())
		dry_out()
		if (soak >= BOAT_SOAK_LOGGED)
			. += " Her hull is waterlogged."
		else if (soak >= BOAT_SOAK_HEAVY)
			. += " Her hull is heavy with water."
		else if (soak >= 20)
			. += " Her hull is damp."
		if (soak >= 20)
			. += afloat() ? " Hauled out, she dries." : " She is drying; animal fat or tarred oakum rubbed in would finish it."
		if (dressing > 0)
			. += " Her hull is dressed against the water."
	return trim(.)

/obj/structure/vehicle/raft/dugout/outrigger/upkeep_text()
	. = ..()
	if (mast && sail_torn)
		. = trim("[.] Her sail is torn: [BOAT_SAIL_CLOTH] pieces of cloth mend it.")

#undef BOAT_UPKEEP_TIME
#undef BOAT_SAIL_CLOTH

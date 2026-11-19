// Free diving: down to the seabed on one breath (docs/river-flow.md, "Free diving").
//
// A swimmer in the open sea over the sea layer (sea_layer.dm) may Dive to the
// seabed straight below, holding the breath their swimming skill gives them
// (swimming.dm: 10 seconds at 100, 60 at 250). Down there they move at their
// swimming speed, may pick up what has sunk to the seabed, and Surface again
// before the breath runs out. Anyone can reach the shelf near the coast; open
// water needs a swimming skill of 200. The deep and the abyss stay for sealed
// suits. When the breath runs out the diver kicks for the surface and arrives
// half drowned, or drowns where they are if a hull is overhead; anyone who
// passes out down there drowns. Breath refills at the surface three seconds a
// second, so a long dive needs a rest between. A dive mask and a scuba set
// breathe for the diver instead (scuba.dm).

#define FREE_DIVE_DESCENT (2 SECONDS)
#define FREE_DIVE_ASCENT_SHELF (3 SECONDS)
#define FREE_DIVE_ASCENT_OPEN (6 SECONDS)
#define FREE_DIVE_OPEN_SKILL 200
#define FREE_DIVE_WARN_AT 5 // seconds of breath left
#define FREE_DIVE_SPENT_OXYLOSS 20 // a breathless kick to the surface
#define FREE_DIVE_OPEN_TRAIN 1.5 // open-water dives teach more

// The deepest zone this diver may reach on a breath.
/mob/living/human/proc/free_dive_zone_limit()
	if (scuba_ready())
		return SEA_ZONE_OPEN // breathing from a scuba set (scuba.dm)
	return swimming_skill() >= FREE_DIVE_OPEN_SKILL ? SEA_ZONE_OPEN : SEA_ZONE_SHELF

// A free diver only goes as deep as their skill; suits are limited by wear.
/mob/proc/seabed_zone_allowed(turf/T)
	return TRUE

/mob/living/human/seabed_zone_allowed(turf/T)
	if (!free_diving || seabed_diving_rating())
		return TRUE
	return sea_zone_of(T) <= free_dive_zone_limit()

// Breathing down here is the held breath (handle_drowning), not the open air.
/mob/living/human/outside_exposure_step(turf/T)
	if (free_diving && sea_layer_cell(T) && !T.iscovered() && !pressure_suit_sealed())
		return FALSE
	return ..()

// The seabed cell straight under a surface swimmer at T, or null.
/proc/free_dive_target(turf/T)
	if (!T || !sea_layer_open_surface(T) || T.iscovered())
		return null
	var/below = multiz_level_below(T.z)
	if (!below)
		return null
	var/turf/B = locate(T.x, T.y, below)
	if (!sea_layer_cell(B) || B.iscovered())
		return null
	return B

// Dives from the surface. Returns TRUE once on the seabed.
/mob/living/human/proc/free_dive()
	var/turf/T = get_turf(src)
	if (stat || restrained() || buckled)
		return FALSE
	if (free_diving)
		to_chat(src, SPAN_WARNING("You are already under the water."))
		return FALSE
	if (!can_swim_deep() || !sea_layer_open_surface(T) || T.iscovered())
		to_chat(src, SPAN_WARNING("You can only dive from the open sea, swimming."))
		return FALSE
	var/turf/B = free_dive_target(T)
	if (!B)
		to_chat(src, SPAN_WARNING("The water here is too shallow to dive, or something lies below."))
		return FALSE
	if (!seabed_diving_rating() && sea_zone_of(B) > free_dive_zone_limit())
		to_chat(src, SPAN_WARNING("The seabed here is too far down for you to reach on one breath. [sea_zone_of(B) == SEA_ZONE_OPEN ? "Open water needs a strong swimmer." : "Only a sealed suit goes this deep."]"))
		return FALSE
	if (swim_under || swim_tiredness >= 80)
		to_chat(src, SPAN_WARNING("You are too tired to dive. Rest first."))
		return FALSE
	if (!scuba_ready() && swim_breath >= 0 && swim_breath < swim_breath_max() / 2)
		to_chat(src, SPAN_WARNING("You are still catching your breath."))
		return FALSE
	visible_message(SPAN_NOTICE("[src] takes a deep breath and dives."))
	if (!do_after(src, FREE_DIVE_DESCENT, src))
		return FALSE
	if (free_diving || free_dive_target(get_turf(src)) != B || stat)
		return FALSE
	if (!seabed_diving_rating())
		free_diving = TRUE
		if (swim_breath < 0)
			swim_breath = swim_breath_max()
		swim_breath = max(1, swim_breath - FREE_DIVE_DESCENT / 10)
	forceMove(B)
	if (seabed_diving_rating())
		to_chat(src, SPAN_NOTICE("You sink to the seabed. Your suit holds the water out."))
	else if (scuba_ready())
		to_chat(src, SPAN_NOTICE("You reach the seabed, breathing from your scuba set. Use Ascend Slowly to come up after a long dive in open water."))
	else
		to_chat(src, SPAN_NOTICE("You reach the seabed, holding your breath: [round(swim_breath)] seconds. Use Surface before it runs out."))
	return TRUE

// Swims back up to the open sea above. forced: the breath has run out.
/mob/living/human/proc/free_dive_surface(forced = FALSE)
	var/turf/T = get_turf(src)
	if (!free_diving || !sea_layer_cell(T))
		free_diving = FALSE
		return FALSE
	var/turf/up = locate(T.x, T.y, multiz_level_above(T.z))
	if (!sea_layer_open_surface(up) || up.iscovered())
		if (!forced)
			to_chat(src, SPAN_WARNING("Something floats on the water above you. Swim clear of it first."))
		return FALSE
	if (!forced)
		var/ascent = sea_zone_of(T) >= SEA_ZONE_OPEN ? FREE_DIVE_ASCENT_OPEN : FREE_DIVE_ASCENT_SHELF
		visible_message(SPAN_NOTICE("[src] kicks for the surface."))
		// Life keeps spending the breath on the way up.
		if (!do_after(src, ascent, src))
			return FALSE
		if (!free_diving)
			return FALSE // the breath ran out on the way and forced it
		T = get_turf(src)
		up = sea_layer_cell(T) ? locate(T.x, T.y, multiz_level_above(T.z)) : null
		if (!sea_layer_open_surface(up) || up.iscovered())
			return FALSE
	free_diving = FALSE
	forceMove(up)
	scuba_surfaced()
	if (forced)
		adjustOxyLoss(FREE_DIVE_SPENT_OXYLOSS)
		to_chat(src, SPAN_DANGER("Your lungs burn and you claw for the surface, gasping and choking!"))
	else
		to_chat(src, SPAN_NOTICE("You break the surface and gulp air."))
	return TRUE

// One life tick of a free dive (from handle_drowning).
/mob/living/human/proc/free_dive_tick(turf/T)
	drowning = FALSE
	if (water_overlay)
		water_overlay = FALSE
		if (plane == FLOOR_PLANE)
			plane = GAME_PLANE
		if (!on_fire)
			overlays_standing[25] = null
	if (stat)
		// Passed out down here: no breath, no way up.
		drowning = TRUE
		adjustOxyLoss(10)
		return
	if (scuba_ready())
		// Breathing from the set (scuba.dm): the held breath stays full.
		scuba_breathe(T)
		swim_refill_breath()
		swim_train(T, sea_zone_of(T) >= SEA_ZONE_OPEN ? FREE_DIVE_OPEN_TRAIN : 1)
		return
	if (nitrogen_load > 0)
		scuba_nitrogen_step(T)
	if (swim_breath < 0)
		swim_breath = swim_breath_max()
	swim_breath = max(0, swim_breath - 1)
	if (swim_breath <= 0)
		if (!free_dive_surface(TRUE))
			drowning = TRUE
			to_chat(src, SPAN_DANGER("You are out of breath and there is a hull above you! You are drowning!"))
			adjustOxyLoss(10)
		return
	if (swim_breath <= FREE_DIVE_WARN_AT && swim_breath > FREE_DIVE_WARN_AT - 1)
		to_chat(src, SPAN_DANGER("Your chest is burning. Surface now!"))
	swim_train(T, sea_zone_of(T) >= SEA_ZONE_OPEN ? FREE_DIVE_OPEN_TRAIN : 1)

/mob/living/human/verb/dive_verb()
	set name = "Dive"
	set desc = "Dive from the open sea to the seabed below on one breath."
	set category = "IC"
	free_dive()

/mob/living/human/verb/surface_verb()
	set name = "Surface"
	set desc = "Swim back up from the seabed to the open sea."
	set category = "IC"
	surface_from_seabed()

// Surface on a held breath or scuba, or drop a suit's weights. Shared by the
// Surface verb and the HUD up button (multiz/floor_buttons.dm).
/mob/living/human/proc/surface_from_seabed()
	if (!free_diving)
		if (sea_layer_cell(get_turf(src)) && seabed_diving_rating())
			return seabed_ascend()
		to_chat(src, SPAN_WARNING("You are not under the water."))
		return FALSE
	return free_dive_surface()

// What the HUD up and down buttons do in the sea: "Surface" on the seabed,
// "Dive" swimming over the seabed, else null. Looks at the water only, so a
// tired swimmer still sees Dive lit and pressing it says why not.
/mob/living/human/proc/sea_updown_offer(direction)
	var/turf/T = get_turf(src)
	if (direction == UP)
		if (free_diving || (sea_layer_cell(T) && seabed_diving_rating()))
			return "Surface"
		return null
	if (direction == DOWN && !free_diving && can_swim_deep() && free_dive_target(T))
		return "Dive"
	return null

#undef FREE_DIVE_DESCENT
#undef FREE_DIVE_ASCENT_SHELF
#undef FREE_DIVE_ASCENT_OPEN
#undef FREE_DIVE_OPEN_SKILL
#undef FREE_DIVE_WARN_AT
#undef FREE_DIVE_SPENT_OXYLOSS
#undef FREE_DIVE_OPEN_TRAIN

// Wild animal feeding and the wildlife death tally.
//
// Grazing: a bite of grass no longer turns the tile to dirt for good. The
// tile is grazed down and grows back after WILD_GRAZE_REGROW; herds move on to
// fresh grass meanwhile. Winter grass counts as pasture too.
//
// Foraging: seed eaters (rabbits, birds, monkeys, wild boar) peck seeds from
// pasture and browse wild plants, and grazers browse bushes and desert shrubs
// where there is no grass, so wild animals far from any farm can still eat.
//
// Deaths: every animal that dies is counted by cause (starvation, predators,
// people, other). The tally is written to the game log once an hour and shown
// in Debug > Ecology Spawning Status. Nothing is saved.
// Design notes: docs/wild-animal-feeding.md.

#define WILD_GRAZE_REGROW (20 MINUTES)
#define WILD_FORAGE_GAIN 350
#define WILD_DEATH_REPORT_EVERY (60 MINUTES)
// A cause noted this long before death still explains it.
#define WILD_HARM_MEMORY (60 SECONDS)

/turf/floor/var/tmp/grazed_until = 0

// Grass an animal can graze: ordinary, jungle and winter grass that is not grazed down.
/turf/floor/proc/pasture_ready()
	if (!istype(src, /turf/floor/grass) && !istype(src, /turf/floor/winter/grass))
		return FALSE
	return world.time >= grazed_until

/turf/floor/proc/graze_down()
	grazed_until = world.time + WILD_GRAZE_REGROW

// Wild plants an animal browses: shrubs, tall grass, jungle growth and cacti.
// Berry bushes stay for people; dead and burned plants feed nothing.
/proc/wild_browse_plant(obj/structure/wild/W)
	if (!istype(W) || istype(W, /obj/structure/wild/berrybush) || istype(W, /obj/structure/wild/burnedbush) || istype(W, /obj/structure/wild/burnedtree))
		return FALSE
	if (istype(W, /obj/structure/wild/jungle/acacia/dead) || istype(W, /obj/structure/wild/jungle/cherry/dead) || istype(W, /obj/structure/wild/jungle/medpine/dead))
		return FALSE
	return istype(W, /obj/structure/wild/smallbush) || istype(W, /obj/structure/wild/bush) || istype(W, /obj/structure/wild/tallgrass) || istype(W, /obj/structure/wild/junglebush) || istype(W, /obj/structure/wild/jungle) || istype(W, /obj/structure/wild/palm) || istype(W, /obj/structure/wild/tree/cactus) || istype(W, /obj/structure/wild/flowers)

/mob/living/simple_animal/proc/wild_forager()
	return herbivore || granivore

// Eats from pasture (seed eaters) or a wild plant within one tile. TRUE when it ate.
/mob/living/simple_animal/proc/forage_wild()
	if (!wild_forager() || !isturf(loc))
		return FALSE
	if (granivore && !herbivore)
		for (var/turf/floor/F in range(1, src))
			if (F.pasture_ready() && prob(40))
				npc_subtile_stop_continuous_walk()
				F.graze_down()
				visible_message("\The [src] forages for seeds in the grass.")
				finish_eating(WILD_FORAGE_GAIN)
				return TRUE
	for (var/obj/structure/wild/W in range(1, src))
		if (wild_browse_plant(W) && prob(40))
			npc_subtile_stop_continuous_walk()
			visible_message("\The [src] nibbles at \the [W].")
			finish_eating(WILD_FORAGE_GAIN)
			return TRUE
	return FALSE

// Walks toward pasture (seed eaters) or a wild plant. TRUE when it set off.
/mob/living/simple_animal/proc/seek_wild_forage(range = 6)
	if (!wild_forager() || !isturf(loc))
		return FALSE
	if (granivore && !herbivore)
		for (var/turf/floor/F in range(range, src))
			if (F.pasture_ready())
				smart_step_towards(F)
				return TRUE
	for (var/obj/structure/wild/W in range(range, src))
		if (wild_browse_plant(W))
			smart_step_towards(W)
			return TRUE
	return FALSE

// ---- Death tally ----

/mob/living/simple_animal/var/tmp/harm_cause = null
/mob/living/simple_animal/var/tmp/harm_time = 0

/mob/living/simple_animal/proc/note_harm(cause)
	harm_cause = cause
	harm_time = world.time

/mob/living/simple_animal/proc/death_cause()
	var/recent = harm_cause && world.time - harm_time <= WILD_HARM_MEMORY
	// The blow that killed it, this very tick.
	if (recent && harm_time == world.time)
		return harm_cause
	if (ishuman(lastattacker))
		return "people"
	if (recent)
		return harm_cause
	return "other"

var/global/datum/wildlife_deaths/wildlife_deaths = new

/datum/wildlife_deaths
	should_save = FALSE
	var/tmp/list/causes = list() // cause -> deaths since the last report
	var/tmp/list/starved = list() // species -> starvation deaths since the last report
	var/tmp/period_start = 0
	var/tmp/last_report = "no report yet"

/datum/wildlife_deaths/proc/record(mob/living/simple_animal/A)
	if (!istype(A) || A.client || istype(A, /mob/living/simple_animal/hostile/human))
		return
	var/cause = A.death_cause()
	causes[cause] = (causes[cause] || 0) + 1
	if (cause == "starvation")
		var/datum/ecology_species/S = ecology_species_for_type(A.type)
		var/kind = S ? S.name : "[initial(A.name)]"
		starved[kind] = (starved[kind] || 0) + 1

/datum/wildlife_deaths/proc/summary()
	var/total = 0
	var/list/parts = list()
	for (var/cause in list("starvation", "predators", "people", "other"))
		var/n = causes[cause] || 0
		total += n
		parts += "[cause] [n]"
	var/text = "[total] animal deaths ([jointext(parts, ", ")])"
	if (starved.len)
		var/list/kinds = list()
		for (var/kind in starved)
			kinds += "[kind] [starved[kind]]"
		text += "; starved: [jointext(kinds, ", ")]"
	return text

// Called every ecology cycle; writes and resets the tally once an hour.
/datum/wildlife_deaths/proc/tick()
	if (!period_start)
		period_start = world.time
		return FALSE
	if (world.time - period_start < WILD_DEATH_REPORT_EVERY)
		return FALSE
	var/minutes = round((world.time - period_start) / 600)
	last_report = "[summary()] in the last [minutes] minutes"
	log_game("Wildlife: [last_report].")
	causes = list()
	starved = list()
	period_start = world.time
	return TRUE

#undef WILD_GRAZE_REGROW
#undef WILD_FORAGE_GAIN
#undef WILD_DEATH_REPORT_EVERY
#undef WILD_HARM_MEMORY

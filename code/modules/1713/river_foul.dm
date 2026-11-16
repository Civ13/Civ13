// Pollution carried downstream (docs/river-foul.md).
//
// Two scales. Close by, sewer outfalls, ditches and cesspits foul wells and
// aqueduct intakes within a few tiles (sewers.dm); on a river an outfall only
// fouls water downstream of it, so a town can take its water above its own
// outfall. Further away, each river reach carries a foul load: every minute
// the sources lying in a reach add to it, a tenth of it breaks down, and the
// rest leaves with the water in the same share as the water itself
// (RIVER_FLOOD_RELEASE). The germs a reach adds to its water are its load over
// the water it holds, so a big river dilutes what fouls a stream.
//
// Sources are an untreated outfall that has carried waste lately, and waste or
// dead bodies lying in river water. Nothing here loops over tiles.

// Germ level from foul load at which water looks and counts as foul.
#define RIVER_FOUL_THRESHOLD 0.5
// Germ level below a scum step at which that step clears again.
#define RIVER_FOUL_SCUM_GIVE 0.2
// Share of a reach's foul load that breaks down each minute.
#define RIVER_FOUL_DECAY 0.1
// Load a minute from each kind of source.
#define RIVER_FOUL_OUTFALL 1
#define RIVER_FOUL_CARCASS 0.25
#define RIVER_FOUL_WASTE 0.05
// Germ level per unit of load over the water a reach holds, and its cap.
#define RIVER_FOUL_GERMS_PER_LOAD 28
#define RIVER_FOUL_GERM_CAP 2
// Water a reach is taken to hold at the least, so a trickle does not spike.
#define RIVER_FOUL_MIN_STORAGE 5
// Loose things in water tracked as sources at most.
#define RIVER_FOUL_TRACK_LIMIT 600

// Things that went into river water and may foul it (pruned every minute).
var/global/list/river_foul_items = list()

/datum/river_flood/var/list/foul = list()
/datum/river_flood/var/list/foul_shown = list()
/datum/river_flood/var/foul_scum_anywhere = FALSE
var/global/river_scum_revision = 0

/datum/river_flood/proc/foul_ready()
	if (!islist(foul) || foul.len != count)
		foul = new /list(count)
		for (var/i in 1 to count)
			foul[i] = 0

// Load a minute that A lying in water adds, or 0.
/proc/river_foul_rate_of(atom/movable/A)
	if (istype(A, /obj/item/weapon/reagent_containers/food/snacks/poo))
		return istype(A, /obj/item/weapon/reagent_containers/food/snacks/poo/fertilizer) ? 0 : RIVER_FOUL_WASTE
	if (istype(A, /mob/living/human) || istype(A, /mob/living/simple_animal))
		var/mob/living/L = A
		return L.stat == DEAD ? RIVER_FOUL_CARCASS : 0
	return 0

// Whether A is worth watching while it lies in this water.
/proc/river_foul_trackable(atom/movable/A)
	return istype(A, /obj/item/weapon/reagent_containers/food/snacks/poo) || istype(A, /mob/living/human) || istype(A, /mob/living/simple_animal)

/turf/floor/beach/water/Entered(atom/movable/A)
	. = ..()
	if (!salty && river_foul_items.len < RIVER_FOUL_TRACK_LIMIT && river_foul_trackable(A))
		river_foul_items |= A

/datum/river_flood/proc/add_foul_rate(list/rate, turf/T, amount)
	if (!T || T.z != z_level || T.x < 1 || T.x > maxx || T.y < 1 || T.y > maxy)
		return
	var/r = reach_at(T.x, T.y)
	if (r)
		rate[r] = (rate[r] || 0) + amount

// Load a minute entering each reach from its sources.
/datum/river_flood/proc/foul_rates()
	var/list/rate = new /list(count)
	for (var/obj/structure/sewer_piece/drain/D in sewer_drains)
		if (QDELETED(D) || D.z != z_level || !D.recently_fouled())
			continue
		var/d = D.outfall_dir()
		if (d)
			add_foul_rate(rate, get_step(D, d), RIVER_FOUL_OUTFALL)
	for (var/atom/movable/A in river_foul_items.Copy())
		if (QDELETED(A) || !istype(A.loc, /turf/floor/beach/water))
			river_foul_items -= A
			continue
		var/amount = river_foul_rate_of(A)
		if (amount)
			add_foul_rate(rate, A.loc, amount)
	return rate

// One minute of foul load, upstream reaches first like the water.
/datum/river_flood/proc/step_foul()
	foul_ready()
	var/list/rate = foul_rates()
	var/list/incoming = new /list(count)
	for (var/i in 1 to count)
		var/load = foul[i] * (1 - RIVER_FOUL_DECAY) + (rate[i] || 0) + (incoming[i] || 0)
		if (load < 0.001)
			load = 0
		var/out = load * RIVER_FLOOD_RELEASE
		foul[i] = load - out
		if (down[i] && out)
			incoming[down[i]] = (incoming[down[i]] || 0) + out
	foul_update_shown()

// Scum each reach shows (0 to 3), with some give so it does not flicker as the load drifts.
/datum/river_flood/proc/foul_update_shown()
	if (!islist(foul_shown) || foul_shown.len != count)
		foul_shown = new /list(count)
		for (var/i in 1 to count)
			foul_shown[i] = 0
	var/changed = FALSE
	var/any = FALSE
	for (var/i in 1 to count)
		var/g = foul_germs(i)
		var/level = foul_shown[i]
		var/rise_at = level < 3 ? RIVER_FOUL_THRESHOLD * (level + 1) : null
		var/fall_at = level > 0 ? RIVER_FOUL_THRESHOLD * level - RIVER_FOUL_SCUM_GIVE : null
		var/target = level
		if (!isnull(rise_at) && g >= rise_at)
			target = min(3, round(g / RIVER_FOUL_THRESHOLD))
		else if (!isnull(fall_at) && g < fall_at)
			target = max(0, round((g + RIVER_FOUL_SCUM_GIVE) / RIVER_FOUL_THRESHOLD))
		if (target != level)
			foul_shown[i] = target
			changed = TRUE
		if (foul_shown[i])
			any = TRUE
	foul_scum_anywhere = any
	if (changed)
		river_scum_revision++

// Germ level reach r's load adds to its water.
/datum/river_flood/proc/foul_germs(r)
	if (!r || r > foul.len || !foul[r])
		return 0
	return min(RIVER_FOUL_GERM_CAP, foul[r] / max(storage[r], RIVER_FOUL_MIN_STORAGE) * RIVER_FOUL_GERMS_PER_LOAD)

// Germ level the river's foul load adds at T (0 off a charted river).
/proc/river_foul_germs(turf/T)
	if (!T || !map)
		return 0
	var/datum/river_flood/F = map.river_flood()
	if (!F || T.z != F.z_level || T.x < 1 || T.x > F.maxx || T.y < 1 || T.y > F.maxy)
		return 0
	return F.foul_germs(F.reach_at(T.x, T.y))

// TRUE when the river's load at T makes it foul to look at and to take water from.
/proc/river_fouled_at(turf/T)
	return river_foul_germs(T) >= RIVER_FOUL_THRESHOLD

// Tiles from a fouled river within which a well draws its filth.
#define RIVER_FOUL_WELL_SEEP 3

// TRUE when non-salt river water within `radius` tiles of T is foul.
/proc/river_fouled_near(turf/T, radius)
	if (!T || !map)
		return FALSE
	var/datum/river_flood/F = map.river_flood()
	if (!F || !F.foul_scum_anywhere || T.z != F.z_level)
		return FALSE
	for (var/turf/floor/beach/water/W in range(radius, T))
		if (!W.salty && river_fouled_at(W))
			return TRUE
	return FALSE

// A well or dug hole near a fouled river draws the river's filth through the
// bank. Mapped sinks and fountains do not.
/obj/structure/sink/proc/well_river_seepage()
	if (!dug_depth && !istype(src, /obj/structure/sink/well))
		return FALSE
	return river_fouled_near(get_turf(src), RIVER_FOUL_WELL_SEEP)

// Share of its usual regrowth a fishing ground gets in foul water.
/proc/river_foul_fish_factor(x, y, z)
	var/turf/T = locate(x, y, z)
	return max(0.25, 1 - river_foul_germs(T) / RIVER_FOUL_GERM_CAP)

// ---- drawing ----------------------------------------------------
// A film of scum on fouled river water (icons/effects/water_scum.dmi, drawn
// with tests/sprites/create_water_scum.py), as images only the viewer's
// client holds, like the floodwater. Rebuilt when the viewer has moved a few
// tiles or a reach's scum has changed.

/client
	var/tmp/list/scum_images = null
	var/tmp/scum_drawn_revision = -1
	var/tmp/scum_drawn_x = 0
	var/tmp/scum_drawn_y = 0
	var/tmp/scum_drawn_z = 0

/client/proc/scum_clear_images()
	if (scum_images)
		images -= scum_images
		scum_images = null

/client/proc/scum_refresh_view()
	var/turf/centre = get_turf(eye)
	var/datum/river_flood/F = centre && map ? map.river_flood() : null
	if (!F || !F.foul_scum_anywhere || centre.z != F.z_level)
		if (scum_images)
			scum_clear_images()
		scum_drawn_revision = -1
		return
	if (scum_drawn_revision == river_scum_revision && scum_drawn_z == centre.z && abs(scum_drawn_x - centre.x) < 4 && abs(scum_drawn_y - centre.y) < 4)
		return
	scum_drawn_revision = river_scum_revision
	scum_drawn_x = centre.x
	scum_drawn_y = centre.y
	scum_drawn_z = centre.z
	scum_clear_images()
	var/list/drawn = list()
	for (var/y in max(1, centre.y - 12) to min(F.maxy, centre.y + 12))
		for (var/x in max(1, centre.x - 12) to min(F.maxx, centre.x + 12))
			var/r = F.reach_at(x, y)
			if (!r || !F.foul_shown[r])
				continue
			var/turf/floor/beach/water/W = locate(x, y, centre.z)
			if (!istype(W) || W.salty || istype(W, /turf/floor/beach/water/ice))
				continue
			var/image/I = image('icons/effects/water_scum.dmi', W, "scum[F.foul_shown[r]]", 2.03)
			I.mouse_opacity = 0
			drawn += I
	if (drawn.len)
		scum_images = drawn
		images += drawn

// An outfall onto a river with a current fouls only what lies downstream of it.
/obj/structure/sewer_piece/proc/fouls_toward(atom/A)
	return TRUE

/obj/structure/sewer_piece/drain/fouls_toward(atom/A)
	var/d = outfall_dir()
	if (!d || !A)
		return TRUE
	var/turf/W = get_step(src, d)
	var/flow = river_current_direction(W)
	if (!flow)
		return TRUE
	var/fx = (flow & EAST) ? 1 : ((flow & WEST) ? -1 : 0)
	var/fy = (flow & NORTH) ? 1 : ((flow & SOUTH) ? -1 : 0)
	return (A.x - W.x) * fx + (A.y - W.y) * fy >= 0

#undef RIVER_FOUL_DECAY
#undef RIVER_FOUL_OUTFALL
#undef RIVER_FOUL_CARCASS
#undef RIVER_FOUL_WASTE
#undef RIVER_FOUL_GERMS_PER_LOAD
#undef RIVER_FOUL_MIN_STORAGE
#undef RIVER_FOUL_TRACK_LIMIT
#undef RIVER_FOUL_SCUM_GIVE
#undef RIVER_FOUL_WELL_SEEP

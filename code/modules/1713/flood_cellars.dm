// Cellars, mines and seepage (docs/river-flood.md, "Cellars"). The level
// under the flood level is dug ground. When a river rises close under the
// surface above, groundwater seeps into the open tiles below it; where the
// surface above is under floodwater and a way down opens there, the flood
// pours down too. Bailing with a bucket keeps the tiles around you dry for a
// while; pumps (cellar_pumps) keep a cellar dry while they work.
//
// Like the flood itself, depth is worked out only when asked. Nothing ticks.
//
// Tunnels: floodwater pouring down a tunnel mouth does not stay under the
// hole. It runs along the open tunnel, filling it to the roof a few tiles a
// minute (TUNNEL_FILL_RATE), and anyone caught in roof-high water must hold
// their breath and get out or drown (flood_airless). Solid ground, packed
// earth included, stops it. When the mouth stops pouring, because the river
// fell or someone filled the hole in, the water soaks away a tile a minute.
// The water is worked out at most once a minute, when someone asks, and is not
// saved.

// Levels under the bank at which a rising river starts to seep into the
// ground below it, and how deep seepage can stand.
#define SEEP_REACH 2
#define SEEP_MAX 0.45
// Floodwater pouring down a way down stands at most this deep below.
#define POUR_MAX 1
#define BAIL_DRY_TIME 6000
#define CELLAR_Z_RECHECK 600
// Roof-high water in a flooded tunnel, and the shallower edge of it.
#define TUNNEL_FULL 1.5
#define TUNNEL_EDGE 0.8
// Tiles of tunnel a pouring mouth floods a minute, the most it reaches, the
// tiles a minute it soaks away once the pouring stops, and the most tiles one
// mouth can flood.
#define TUNNEL_FILL_RATE 3
#define TUNNEL_FILL_MAX 30
#define TUNNEL_DRAIN_RATE 1
#define TUNNEL_FILL_TILES 400
#define TUNNEL_RECHECK 600
// Extra seconds of held breath caught in a flooded tunnel, on top of the
// swimmer's own (10 untrained), so a new player gets about 20 s to get out.
#define TUNNEL_BREATH_BONUS 10

// Every tunnel mouth (dug holes and mapped tunnel entrances).
var/global/list/tunnel_mouths = list()
// Underground cells opened under a lake or a river (dug_underground.dm,
// underground_opened): each pours like a mouth while the water above stays.
// Unsaved; underground_breach_scan() finds them again after a load.
var/global/list/tunnel_breaches = list()
// Depth that seeps into an opened cell under shallows, swamp or coast water.
#define MUD_SEEP 0.3

/obj/structure/multiz/ladder/ww2/tunneltop/New()
	..()
	tunnel_mouths |= src

/obj/structure/multiz/ladder/ww2/tunneltop/Destroy()
	tunnel_mouths -= src
	return ..()

// Pumps that keep the cellar tiles within cellar_reach of them dry while
// cellar_pumping() is TRUE.
var/global/list/cellar_pumps = list()

/obj/structure/var/cellar_reach = 0

/obj/structure/proc/cellar_pumping()
	return FALSE

/datum/river_flood
	var/tmp/cellar_z_cache = 0
	var/tmp/cellar_z_checked = -CELLAR_Z_RECHECK
	// turf -> world.time until which bailing keeps it dry. Unsaved.
	var/list/cellar_dry = list()
	// Tunnel flooding, unsaved: tile under a mouth -> how far the water reaches
	// from it, and each flooded tunnel tile -> its depth.
	var/tmp/list/tunnel_fill = list()
	var/tmp/list/tunnel_water = list()
	var/tmp/tunnel_checked = 0
	var/tmp/tunnel_started = FALSE

// The dug level under the flood level, or 0.
/datum/river_flood/proc/cellar_z()
	if (world.time - cellar_z_checked >= CELLAR_Z_RECHECK)
		cellar_z_checked = world.time
		cellar_z_cache = z_level ? multiz_level_below(z_level) : 0
	return cellar_z_cache

// TRUE when a way down from surface tile S lets floodwater pour below.
/proc/flood_way_down(turf/S)
	// Open air (multiz/open_space.dm), a ladder, stairs or a tunnel mouth.
	if (istype(S, /turf/floor/broken_floor))
		return TRUE
	return locate(/obj/structure/multiz) in S

// Depth of water on cellar tile T. ignore_pumps: as if nothing kept it dry.
/datum/river_flood/proc/seep_depth_at(turf/T, ignore_pumps = FALSE)
	if (!cellar_holds_water(T) || T.x < 1 || T.x > maxx || T.y < 1 || T.y > maxy)
		return 0
	var/r = reach_at(T.x, T.y)
	var/turf/S = locate(T.x, T.y, z_level)
	// Shallows, swamp and coast water above seep in a little, whatever the river does.
	if (underground_above(S) == "mud")
		. = (ignore_pumps || !cellar_kept_dry(T)) ? MUD_SEEP : 0
		var/tunnel_mud = tunnel_depth_at(T)
		if (tunnel_mud > . && (ignore_pumps || !cellar_pumped(T)))
			. = tunnel_mud
		return .
	var/bank = S ? effective_threshold(S) : null
	// No river here, or under the river, the lake or the sea (not a cellar):
	// only tunnel water.
	if (!r || stage[r] <= 0 || isnull(bank))
		var/tunnel_only = tunnel_depth_at(T)
		if (tunnel_only > 0 && !ignore_pumps && cellar_pumped(T))
			return 0
		return tunnel_only
	. = 0
	var/gap = stage[r] - (bank - SEEP_REACH)
	if (gap > 0)
		. = min(SEEP_MAX, gap * 0.25)
	if (stage[r] > bank && flood_way_down(S))
		. = max(., min(POUR_MAX, flood_depth_at(S)))
	if (. > 0 && !ignore_pumps && cellar_kept_dry(T))
		. = 0
	// Floodwater run along a tunnel. Bailing cannot keep that back; a pump can.
	var/tunnel = tunnel_depth_at(T)
	if (tunnel > . && (ignore_pumps || !cellar_pumped(T)))
		. = tunnel

// TRUE for an open floor below ground that water can stand on. Rock nobody
// has dug into yet (/turf/sky/building/unformed) is not dense, but it is
// solid: water neither stands in it nor runs through it.
/proc/cellar_holds_water(turf/T)
	return T && !T.density && istype(T, /turf/floor)

// Bailed lately, or near a working cellar pump.
/datum/river_flood/proc/cellar_kept_dry(turf/T)
	if (cellar_dry.len)
		var/until = cellar_dry[T]
		if (until && until > world.time)
			return TRUE
	return cellar_pumped(T)

/datum/river_flood/proc/cellar_pumped(turf/T)
	for (var/obj/structure/P in cellar_pumps)
		if (P.z == T.z && get_dist(P, T) <= P.cellar_reach && P.cellar_pumping())
			return TRUE
	return FALSE

// ---- tunnels ----

// TRUE while floodwater pours down tunnel mouth M.
/datum/river_flood/proc/tunnel_mouth_pouring(obj/structure/multiz/M)
	var/turf/S = get_turf(M)
	if (!S || S.z != z_level)
		return FALSE
	var/r = reach_at(S.x, S.y)
	if (!r || stage[r] <= 0)
		return FALSE
	var/bank = effective_threshold(S)
	return !isnull(bank) && stage[r] > bank && flood_depth_at(S) > 0

// Grows the water under pouring mouths and soaks it away under the rest, then
// works out which tunnel tiles stand flooded. At most once a minute.
/datum/river_flood/proc/tunnel_flood_update()
	if (tunnel_started && world.time - tunnel_checked < TUNNEL_RECHECK)
		return
	var/minutes = tunnel_started ? min(10, (world.time - tunnel_checked) / 600) : 1
	tunnel_started = TRUE
	tunnel_checked = world.time
	var/below = cellar_z()
	if (!below)
		tunnel_fill.Cut()
		tunnel_water.Cut()
		return
	var/list/pouring = list()
	for (var/turf/B in tunnel_breaches.Copy())
		if (B.z != below || underground_above_cell(B) != "wet")
			tunnel_breaches -= B
		else if (!B.density)
			pouring[B] = TRUE
	for (var/obj/structure/multiz/M in tunnel_mouths)
		if (!tunnel_mouth_pouring(M))
			continue
		var/turf/B = locate(M.x, M.y, below)
		if (B)
			pouring[B] = TRUE
	for (var/turf/B in pouring)
		tunnel_fill[B] = min(TUNNEL_FILL_MAX, tunnel_fill[B] + TUNNEL_FILL_RATE * minutes)
	for (var/turf/B in tunnel_fill.Copy())
		if (pouring[B])
			continue
		tunnel_fill[B] -= TUNNEL_DRAIN_RATE * minutes
		if (tunnel_fill[B] <= 0)
			tunnel_fill -= B
	var/changed = tunnel_water.len || tunnel_fill.len
	tunnel_water.Cut()
	for (var/turf/B in tunnel_fill)
		tunnel_spread(B, tunnel_fill[B])
	if (changed)
		flood_draw_revision++

// Floods the open tunnel within reach steps of B, roof-high but for the edge.
/datum/river_flood/proc/tunnel_spread(turf/B, reach)
	if (!cellar_holds_water(B))
		return
	var/list/dist = list()
	dist[B] = 0
	var/list/queue = list(B)
	var/i = 1
	while (i <= queue.len && dist.len <= TUNNEL_FILL_TILES)
		var/turf/T = queue[i++]
		var/d = dist[T]
		var/depth = d <= reach - 1 ? TUNNEL_FULL : TUNNEL_EDGE
		if (tunnel_water[T] < depth)
			tunnel_water[T] = depth
		if (d + 1 > reach)
			continue
		for (var/dir in cardinal)
			var/turf/N = get_step(T, dir)
			if (!cellar_holds_water(N) || !isnull(dist[N]))
				continue
			dist[N] = d + 1
			queue += N

/datum/river_flood/proc/tunnel_depth_at(turf/T)
	tunnel_flood_update()
	if (!tunnel_water.len)
		return 0
	var/depth = tunnel_water[T]
	return depth ? depth : 0

// TRUE where water stands to the roof below ground: there is no air to swim up to.
/proc/flood_airless(turf/T)
	if (!T || !map)
		return FALSE
	var/datum/river_flood/F = map.river_flood()
	return F && T.z == F.cellar_z() && flood_depth_at(T) > 1

// A life tick under roof-high tunnel water. Returns TRUE while the held breath lasts.
/mob/living/human/proc/tunnel_hold_breath()
	if (stat)
		return FALSE
	if (swim_breath < 0)
		swim_breath = swim_breath_max() + TUNNEL_BREATH_BONUS
		to_chat(src, SPAN_DANGER("The tunnel is flooded to the roof! Hold your breath and find a way up!"))
	swim_breath = max(0, swim_breath - 1)
	return swim_breath > 0

// Bailing at T keeps it and the tiles around it dry for a while.
/datum/river_flood/proc/bail_cellar(turf/T)
	if (cellar_dry.len > 200)
		for (var/turf/K in cellar_dry.Copy())
			if (cellar_dry[K] <= world.time)
				cellar_dry -= K
	for (var/turf/N in range(1, T))
		cellar_dry[N] = world.time + BAIL_DRY_TIME
	flood_draw_revision++

// Bail out seepage with an open container.
/obj/item/weapon/reagent_containers/glass/proc/try_bail(turf/T, mob/user)
	if (!istype(T) || !is_open_container() || istype(src, /obj/item/weapon/reagent_containers/glass/fire_extinguisher) || user.a_intent == I_HARM)
		return FALSE
	var/datum/river_flood/F = map ? map.river_flood() : null
	if (!F || T.z != F.cellar_z() || F.seep_depth_at(T) <= 0)
		return FALSE
	if (F.tunnel_depth_at(T) > SEEP_MAX)
		to_chat(user, SPAN_WARNING("The tunnel is flooded far too deep to bail out. Fill in the hole it pours through, or pump it."))
		return TRUE
	if (reagents.total_volume >= reagents.maximum_volume)
		to_chat(user, SPAN_WARNING("\The [src] is full. Empty it outside first."))
		return TRUE
	user.visible_message(SPAN_NOTICE("[user] starts bailing water with \the [src]."), SPAN_NOTICE("You start bailing out the water."))
	if (!do_after(user, 20, T))
		return TRUE
	reagents.add_reagent("water", min(amount_per_transfer_from_this, reagents.maximum_volume - reagents.total_volume))
	F.bail_cellar(T)
	playsound(user, 'sound/effects/watersplash.ogg', 60, TRUE)
	user.visible_message(SPAN_NOTICE("[user] bails out the water."), SPAN_NOTICE("You bail the water out around you. It will seep back while the river stays high."))
	return TRUE

#undef SEEP_REACH
#undef SEEP_MAX
#undef POUR_MAX
#undef BAIL_DRY_TIME
#undef CELLAR_Z_RECHECK
#undef TUNNEL_FULL
#undef TUNNEL_EDGE
#undef TUNNEL_FILL_RATE
#undef TUNNEL_FILL_MAX
#undef TUNNEL_DRAIN_RATE
#undef TUNNEL_FILL_TILES
#undef TUNNEL_RECHECK
#undef TUNNEL_BREATH_BONUS

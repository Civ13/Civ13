// ============================================================
// Observing as a spirit on persistent worlds.
// ------------------------------------------------------------
// On a persistent world every player ghost - the dead and those who chose
// Observe in the lobby - is a spirit, not an all-seeing observer:
//   * Limited dark vision: the dark is lifted only a few tiles around the
//     spirit, and the darkness toggle is gone.
//   * Spirits hear speech and see emotes only near themselves.
//   * Spirits may Haunt (follow) or Jump to living players, listed by the
//     name others see them as. A spirit bound to its body or lingering stays
//     leashed: it can't reach anyone beyond its range, and a haunt breaks
//     when they leave it.
//   * Solid walls and closed doors stop a spirit drifting through them.
//   * Death notices no longer say where someone died.
// Staff (admin or moderator rights) and admin ghosts keep the full observer.
// Round maps are unchanged.
// ============================================================

#define SPIRIT_SIGHT_RANGE 4
#define SPIRIT_MOVE_DELAY 1.5

/mob/observer/ghost
	var/tmp/obj/screen/spirit_sight/spirit_sight = null

/obj/screen/spirit_sight
	name = ""
	icon = 'icons/effects/spirit_sight.dmi'
	icon_state = "sight"
	screen_loc = "CENTER-4,CENTER-4"
	mouse_opacity = FALSE
	plane = LIGHTING_MASK_PLANE
	layer = 20 // above every lighting mask overlay
	blend_mode = BLEND_ADD
	appearance_flags = NO_CLIENT_COLOR | RESET_COLOR | RESET_TRANSFORM | RESET_ALPHA

// TRUE when this ghost observes as a limited spirit.
/mob/observer/ghost/proc/is_spirit()
	if (!map || !map.persistence || admin_ghosted)
		return FALSE
	if (client && client.holder && (client.holder.rights & (R_ADMIN|R_MOD)))
		return FALSE
	return TRUE

// Any mob: TRUE for a dead mob that hears and sees everything on the map.
/mob/proc/ghost_hears_everywhere(pref = /datum/client_preference/ghost_ears)
	if (stat != DEAD || !is_preference_enabled(pref))
		return FALSE
	if (isghost(src))
		var/mob/observer/ghost/G = src
		if (G.is_spirit())
			return FALSE
	return TRUE

/mob/proc/is_spirit_observer()
	return FALSE

/mob/observer/ghost/is_spirit_observer()
	return is_spirit()

// Sight: called from Login and whenever staff rights may have changed.
/mob/observer/ghost/proc/spirit_update_sight()
	if (!client)
		return
	spirit_hud_refresh() // spirit_hud.dm
	if (!is_spirit())
		if (spirit_sight)
			client.screen -= spirit_sight
		if (see_in_dark < 100)
			see_in_dark = 100
		return
	see_in_dark = SPIRIT_SIGHT_RANGE
	if (!seedarkness)
		seedarkness = TRUE
		updateghostsight()
	if (!spirit_sight)
		spirit_sight = new /obj/screen/spirit_sight
	client.screen |= spirit_sight

// Living players a spirit may haunt or jump to, by the name others see.
/proc/spirit_haunt_targets(mob/observer/ghost/G)
	var/list/out = list()
	var/list/counts = list()
	for (var/mob/living/human/H in human_mob_list)
		if (H.stat == DEAD || !H.ckey || !isturf(H.loc) || QDELETED(H))
			continue
		if (G && G.mind && G.mind.current == H)
			continue
		var/label = H.get_visible_name()
		if (counts[label])
			counts[label]++
			label = "[label] ([counts[label]])"
		else
			counts[label] = 1
		out[label] = H
	return sortList(out)

// The follow/jump list this ghost is offered.
/mob/observer/ghost/proc/observer_targets()
	if (is_spirit())
		return spirit_haunt_targets(src)
	return ghost_follow_targets()

// For verb argument lists, which are built before src is known.
/proc/observer_targets_for(mob/M)
	var/mob/observer/ghost/G = M
	if (istype(G))
		return G.observer_targets()
	return ghost_follow_targets()

// A spirit drifts at walking pace instead of gathering speed.
/mob/observer/ghost/movement_delay()
	if (is_spirit())
		return SPIRIT_MOVE_DELAY
	return ..()

// Walls and closed doors stop a drifting spirit.
/mob/proc/incorporeal_step_allowed(turf/T)
	return TRUE

/mob/observer/ghost/incorporeal_step_allowed(turf/T)
	if (!T || !is_spirit())
		return TRUE
	return !spirit_turf_solid(T)

/proc/spirit_turf_solid(turf/T)
	if (!T)
		return TRUE
	if (T.density)
		return TRUE
	for (var/obj/O in T)
		if (O.density && O.opacity && O.anchored)
			return TRUE
	return FALSE

// A haunt breaks when the haunted moves beyond a leashed spirit's reach.
/mob/observer/ghost/move_to_turf(atom/movable/am, old_loc, new_loc)
	var/turf/T = get_turf(new_loc)
	if (T && arcane_anchor && !arcane_in_anchor_range(T)) // arcane_spirits.dm
		to_chat(src, SPAN_NOTICE("[am] goes beyond your reach."))
		stop_following()
		return
	return ..()

// Where a lobby observer appears on a persistent world: open ground where new
// players start, not the corner of the map.
/proc/spirit_observer_start_turf()
	if (!map || !map.persistence)
		return null
	if (istype(map, /obj/map_metadata/nomads))
		var/obj/map_metadata/nomads/N = map
		var/turf/ground = N.pick_new_player_ground()
		if (ground)
			return ground
	for (var/spot in list("JoinLateCiv", "JoinLate"))
		var/list/starts = latejoin_turfs ? latejoin_turfs[spot] : null
		if (length(starts))
			return pick(starts)
	return null

/mob/observer/ghost/proc/spirit_refuse(what)
	to_chat(src, SPAN_WARNING("A spirit can't [what]."))

#undef SPIRIT_SIGHT_RANGE
#undef SPIRIT_MOVE_DELAY

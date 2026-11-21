// ============================================================
// Repository reach (Val, 2026-11-19/21). Hidden mechanic: keep it out of
// changelog lines, the wiki and anything an ordinary player sees.
// ------------------------------------------------------------
// The area a repository's wards and effects can cover grows with its tier:
//   1 personal     its keeper's body and what is right around it
//   2 shrine       the land plot it stands on (or a small radius off-plot)
//   3 settlement   the seat radius of its faction (province_near_faction_seat)
//   4 provincial   the whole province it stands in
//   5 national     every province its nation holds where the nation keeps a
//                  provincial repository, plus its own
//
// Interface for the binding-law plan (PR 9):
//   ward_reach(repo)          list("tier", "kind", ...) describing its reach
//   ward_covers(repo, turf)   TRUE when a law of this repository applies there
//   wards_at(turf)            every live repository whose reach covers turf
//   ward_drain() warns online keepers once charge falls below a quarter.
//
// A shrine or greater repository can be carried or dragged only by a keeper,
// and a settlement or greater one cannot be unfastened at all.
// ============================================================

/proc/magic_reach_value(field, fallback)
	var/list/R = magic_balance("reach")
	return islist(R) && isnum(R[field]) ? R[field] : fallback

/proc/ward_reach(obj/repo)
	if (!istype(repo) || !repo.magic_repo_finished())
		return null
	var/turf/T = get_turf(repo)
	. = list("tier" = repo.magic_repo_tier)
	switch (repo.magic_repo_tier)
		if (1)
			.["kind"] = "body"
			.["radius"] = magic_reach_value("personal_radius", 3)
		if (2)
			var/list/plot = T && map ? map.land_plot_at(T) : null
			if (islist(plot))
				.["kind"] = "plot"
				.["plot"] = plot
			else
				.["kind"] = "radius"
				.["radius"] = magic_reach_value("shrine_radius", 7)
		if (3)
			.["kind"] = "seat"
			.["faction"] = repo.magic_repo_faction
		if (4)
			.["kind"] = "province"
			.["province"] = magic_repo_province_at(T)
		if (5)
			.["kind"] = "nation"
			.["group"] = repo.magic_repo_group

/proc/magic_repo_province_at(turf/T)
	if (!T || !map)
		return null
	var/datum/province_map/P = map.province_map()
	return P ? P.char_at(T.x, T.y) : null

// A live provincial or national repository of this group stands in province c.
/proc/magic_repo_group_keeps_province(group, c)
	if (!group || !c)
		return FALSE
	for (var/id in magic_repo_index)
		var/obj/O = magic_repo_find(id)
		if (O && O.magic_repo_tier >= 4 && O.magic_repo_group == group && !O.magic_repo_dormant() && magic_repo_province_at(get_turf(O)) == c)
			return TRUE
	return FALSE

/proc/ward_covers(obj/repo, turf/T)
	if (!istype(repo) || !istype(T) || !repo.magic_repo_finished() || repo.magic_repo_dormant())
		return FALSE
	var/turf/home = get_turf(repo)
	if (!home)
		return FALSE
	switch (repo.magic_repo_tier)
		if (1)
			return home.z == T.z && get_dist(home, T) <= magic_reach_value("personal_radius", 3)
		if (2)
			var/list/plot = map ? map.land_plot_at(home) : null
			if (islist(plot))
				var/list/there = map.land_plot_at(T)
				return islist(there) && there[1] == plot[1] && there[2] == plot[2]
			return home.z == T.z && get_dist(home, T) <= magic_reach_value("shrine_radius", 7)
		if (3)
			return istext(repo.magic_repo_faction) && province_near_faction_seat(repo.magic_repo_faction, T)
		if (4)
			var/c = magic_repo_province_at(home)
			return c && magic_repo_province_at(T) == c
		if (5)
			var/c = magic_repo_province_at(T)
			if (!c || province_holder_of(c) != repo.magic_repo_group)
				return FALSE
			return c == magic_repo_province_at(home) || magic_repo_group_keeps_province(repo.magic_repo_group, c)
	return FALSE

/proc/wards_at(turf/T)
	. = list()
	if (!istype(T))
		return
	for (var/id in magic_repo_index)
		var/obj/O = magic_repo_find(id)
		if (O && ward_covers(O, T))
			. += O

// ward_drain(): tell the keepers who are playing, once, when it falls below a quarter.
/proc/ward_low_warning(obj/repo, before)
	if (!istype(repo) || repo.magic_repo_capacity <= 0)
		return
	var/line = repo.magic_repo_capacity * magic_reach_value("warning_fraction", 0.25)
	if (before < line || repo.magic_repo_charge >= line)
		return
	for (var/client/C in clients)
		var/mob/living/human/H = C.mob
		if (istype(H) && H.magic_allowed() && repo.magic_repo_is_keeper(H))
			to_chat(H, CHAT_TYPED(CHAT_PRAYER, SPAN_WARNING("You feel \the [repo] grow thin, far below what it can hold.")))

// ---------- moving it ----------

// TRUE (after telling them) when user may not carry or drag this repository.
/obj/proc/magic_repo_move_refused(mob/user)
	if (!magic_repo_finished() || magic_repo_tier < 2)
		return FALSE
	var/mob/living/human/H = user
	if (magic_repo_tier < 3 && istype(H) && magic_repo_is_keeper(H))
		return FALSE
	to_chat(user, SPAN_WARNING("It won't budge!"))
	return TRUE

// toggle_anchor() and timed_toggle_anchor(): a settlement or greater
// repository stays fastened where its seat is.
/obj/proc/magic_repo_unfasten_refused(mob/user)
	if (!anchored || !magic_repo_finished() || magic_repo_tier < 3)
		return FALSE
	if (user)
		to_chat(user, SPAN_WARNING("It won't budge!"))
	return TRUE

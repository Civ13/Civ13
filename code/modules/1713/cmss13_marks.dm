// Spot Enemy and rally points, a death recap, personal round stats and the
// searchlight. Ideas from CM-SS13 (cmss13-devs/cmss13, AGPL-3.0): spotting
// pings, squad leader waypoints, the death recap, end-of-round personal
// statistics and the searchlight. Reimplemented for Civ13.

//////////////////////////////////////////////////////////////////////////////
// FIELD MARKS: short-lived markers only a group sees, drawn by the field HUD.
//////////////////////////////////////////////////////////////////////////////

#define SPOT_LIFETIME 300      // 30 seconds
#define SPOT_COOLDOWN 50
#define RALLY_LIFETIME 6000    // 10 minutes

var/global/list/field_marks = list()

/datum/field_mark
	var/kind = "spot"                 // "spot" or "rally"
	var/turf/where
	var/mob/living/human/owner
	var/expires = 0
	var/list/scope                    // who sees it: list(type, key...)

/datum/field_mark/New(kind, turf/T, mob/living/human/H, list/scope, lifetime)
	src.kind = kind
	where = T
	owner = H
	src.scope = scope
	expires = world.time + lifetime

/datum/field_mark/proc/expired()
	return world.time > expires || !where || !owner || QDELETED(owner)

// Scopes: list("squad", key), list("fireteam", kind, group, team),
// list("faction", civilization), list("self").
/proc/field_scope_includes(list/scope, mob/living/human/owner, mob/living/human/H)
	if (!istype(H) || H.stat == DEAD)
		return FALSE
	if (H == owner)
		return TRUE
	switch (scope[1])
		if ("squad")
			return team_round_active() && H.in_squad() && squad_group_key(H) == scope[2]
		if ("fireteam")
			return H.has_fire_team() && H.fire_team_kind == scope[2] && H.fire_team_group == scope[3] && H.fire_team == scope[4]
		if ("faction")
			return map && map.civilizations && H.civilization == scope[2]
	return FALSE

/proc/field_mark_visible_to(datum/field_mark/M, mob/living/human/H)
	if (field_scope_includes(M.scope, M.owner, H))
		return TRUE
	// Spots also reach everyone who shares any group with the spotter.
	if (M.kind == "spot")
		for (var/list/S in spot_scopes(M.owner))
			if (field_scope_includes(S, M.owner, H))
				return TRUE
	return FALSE

/proc/prune_field_marks()
	for (var/datum/field_mark/M in field_marks.Copy())
		if (M.expired())
			field_marks -= M

/proc/field_marks_for(mob/living/human/H)
	var/list/out = list()
	if (!field_marks.len)
		return out
	prune_field_marks()
	for (var/datum/field_mark/M in field_marks)
		if (M.where.z == H.z && field_mark_visible_to(M, H))
			out += M
	return out

// The rally point this person should head for, if any (not their own).
/proc/rally_point_for(mob/living/human/H)
	if (!field_marks.len)
		return null
	prune_field_marks()
	for (var/datum/field_mark/M in field_marks)
		if (M.kind == "rally" && M.owner != H && field_scope_includes(M.scope, M.owner, H))
			return M
	return null

// Every group a spotter shares, nearest first.
/proc/spot_scopes(mob/living/human/H)
	var/list/out = list()
	if (H.has_fire_team())
		out += list(list("fireteam", H.fire_team_kind, H.fire_team_group, H.fire_team))
	if (team_round_active() && H.in_squad())
		out += list(list("squad", squad_group_key(H)))
	if (map && map.civilizations && H.civilization && H.civilization != "none")
		out += list(list("faction", H.civilization))
	return out

/proc/field_mark_audience(datum/field_mark/M)
	var/list/out = list()
	for (var/mob/living/human/H in human_clients_mob_list)
		if (H != M.owner && field_mark_visible_to(M, H))
			out += H
	return out

//////////////////////////////////////////////////////////////////////////////
// SPOT ENEMY
//////////////////////////////////////////////////////////////////////////////

/mob/living/human/var/tmp/last_spot_time = -1000

/mob/living/human/persistence_runtime_var(key)
	return key == "last_spot_time" || ..()

/mob/living/human/proc/spot_enemy_at(turf/T)
	if (!isturf(T) || stat != CONSCIOUS)
		return null
	if (world.time - last_spot_time < SPOT_COOLDOWN)
		to_chat(src, "<span class='warning'>Wait a moment before spotting again.</span>")
		return null
	var/list/scopes = spot_scopes(src)
	if (!scopes.len)
		to_chat(src, "<span class='warning'>You have no squad, fire team or faction to warn.</span>")
		return null
	last_spot_time = world.time
	var/datum/field_mark/M = new("spot", T, src, scopes[1], SPOT_LIFETIME)
	field_marks += M
	for (var/mob/living/human/H in field_mark_audience(M))
		var/turf/HT = get_turf(H)
		var/where = HT && HT.z == T.z ? "[get_dist(HT, T)] m [dir2text(get_dir(HT, T))] of you" : "on another level"
		to_chat(H, "<span class='danger'>[real_name] spots enemies [where]!</span>")
	to_chat(src, "<span class='notice'>You mark enemies for your [scopes[1][1] == "fireteam" ? "fire team" : scopes[1][1]].</span>")
	return M

/mob/living/human/verb/spot_enemy(atom/A as mob|obj|turf in view())
	set name = "Spot Enemy"
	set category = null
	spot_enemy_at(get_turf(A))

//////////////////////////////////////////////////////////////////////////////
// RALLY POINTS: leaders plant a waypoint their people are pointed to.
//////////////////////////////////////////////////////////////////////////////

// list(title = scope) of the groups this person leads.
/mob/living/human/proc/rally_scopes()
	var/list/out = list()
	if (has_fire_team() && fire_team_lead)
		out["Fire team [fire_team]"] = list("fireteam", fire_team_kind, fire_team_group, fire_team)
	if (team_round_active() && in_squad() && original_job && original_job.is_squad_leader)
		out["Squad [squad]"] = list("squad", squad_group_key(src))
	if (map && map.civilizations && civilization && civilization != "none" && map.is_faction_leader(src, civilization))
		out[civilization] = list("faction", civilization)
	return out

/proc/same_scope(list/A, list/B)
	if (!A || !B || A.len != B.len)
		return FALSE
	for (var/i = 1 to A.len)
		if (A[i] != B[i])
			return FALSE
	return TRUE

/mob/living/human/proc/set_rally_point(list/scope, turf/T)
	if (!scope || !isturf(T))
		return null
	clear_rally_point(scope)
	var/datum/field_mark/M = new("rally", T, src, scope, RALLY_LIFETIME)
	field_marks += M
	for (var/mob/living/human/H in field_mark_audience(M))
		to_chat(H, "<span class='notice'><b>[real_name]</b> sets a rally point. Follow your tracker arrow.</span>")
	return M

/mob/living/human/proc/clear_rally_point(list/scope)
	for (var/datum/field_mark/M in field_marks.Copy())
		if (M.kind == "rally" && same_scope(M.scope, scope))
			field_marks -= M

/mob/living/human/verb/rally_point()
	set name = "Rally Point"
	set category = "IC"
	set desc = "Leaders plant a rally point here; their people see it and their tracker arrow points to it for ten minutes."
	var/list/scopes = rally_scopes()
	if (!scopes.len)
		to_chat(src, "<span class='warning'>Only squad, fire team and faction leaders can set a rally point.</span>")
		return
	var/title = scopes[1]
	if (scopes.len > 1)
		title = input(src, "Rally point for whom?", "Rally Point") as null|anything in scopes
		if (!title)
			return
	var/choice = WWinput(src, "Rally point for [title]:", "Rally Point", "Here", list("Here", "Clear", "Cancel"))
	if (choice == "Here")
		set_rally_point(scopes[title], get_turf(src))
		to_chat(src, "<span class='notice'>Rally point set for [title].</span>")
	else if (choice == "Clear")
		clear_rally_point(scopes[title])
		to_chat(src, "<span class='notice'>Rally point cleared.</span>")

#undef SPOT_LIFETIME
#undef SPOT_COOLDOWN
#undef RALLY_LIFETIME

//////////////////////////////////////////////////////////////////////////////
// DEATH RECAP
//////////////////////////////////////////////////////////////////////////////

#define RECAP_WINDOW 600
#define RECAP_MAX_HITS 30

/mob/living/human/var/tmp/list/recent_hits = null // list(list(time, name, weapon))

/mob/living/human/persistence_runtime_var(key)
	return key == "recent_hits" || ..()

/datum/round_facts/var/list/hits = list()             // attacker name -> hits landed
/datum/round_facts/var/list/medals_received = list()  // name -> medals

// Called from record_hit() in round_facts.dm.
/datum/round_facts/proc/record_personal_hit(mob/living/human/victim, mob/living/human/attacker, weapon)
	var/name = round_fact_name(attacker)
	hits[name] = (hits[name] || 0) + 1
	if (!victim.recent_hits)
		victim.recent_hits = list()
	victim.recent_hits += list(list(world.time, name, weapon ? "[weapon]" : null))
	if (victim.recent_hits.len > RECAP_MAX_HITS)
		victim.recent_hits.Cut(1, 2)

/mob/living/human/proc/death_recap_lines()
	var/list/out = list()
	var/list/by_name = list()
	var/list/weapons = list()
	for (var/list/hit in recent_hits)
		if (world.time - hit[1] > RECAP_WINDOW)
			continue
		var/name = hit[2]
		by_name[name] = (by_name[name] || 0) + 1
		if (!weapons[name])
			weapons[name] = list()
		if (hit[3])
			weapons[name] |= hit[3]
	if (!by_name.len)
		out += "No one hurt you in your last minute."
		return out
	for (var/name in by_name)
		var/list/W = weapons[name]
		out += "<b>[name]</b> hit you [by_name[name] == 1 ? "once" : "[by_name[name]] times"][W.len ? " ([jointext(W, ", ")])" : ""]."
	var/list/last = recent_hits[recent_hits.len]
	if (world.time - last[1] <= RECAP_WINDOW)
		out += "Killing blow: <b>[last[2]]</b>[last[3] ? " with \a [last[3]]" : ""]."
	return out

/hook/death/proc/death_recap(mob/living/human/H, gibbed)
	if (istype(H) && H.client)
		to_chat(H, "<span class='notice'><b>How you died</b><br>[jointext(H.death_recap_lines(), "<br>")]</span>")
	return TRUE

#undef RECAP_WINDOW
#undef RECAP_MAX_HITS

//////////////////////////////////////////////////////////////////////////////
// PERSONAL ROUND STATS: each player's own numbers at round end.
//////////////////////////////////////////////////////////////////////////////

/datum/round_facts/proc/personal_line(name)
	if (!name)
		return null
	var/list/parts = list()
	if (shots[name])
		parts += round_fact_plural(shots[name], "shot")
	if (hits[name])
		parts += round_fact_plural(hits[name], "hit")
	if (kills[name])
		parts += round_fact_plural(kills[name], "kill")
	if (deaths[name])
		parts += round_fact_plural(deaths[name], "death")
	if (friendly_hits[name])
		parts += "[friendly_hits[name]] friendly hit\s"
	if (medals_received[name])
		parts += round_fact_plural(medals_received[name], "medal")
	if (!parts.len)
		return null
	return "Your round as <b>[name]</b>: [jointext(parts, ", ")]."

/hook/roundend/proc/personal_round_stats()
	if (!round_facts)
		return TRUE
	for (var/client/C in clients)
		var/mob/M = C.mob
		if (!M)
			continue
		var/line = round_facts.personal_line(M.real_name ? M.real_name : M.name)
		if (line)
			to_chat(C, "<span class='notice'>[line]</span>")
	return TRUE

//////////////////////////////////////////////////////////////////////////////
// SEARCHLIGHT: switch it on and turn it; it lights the ground up to six
// tiles ahead, stopping at walls.
//////////////////////////////////////////////////////////////////////////////

#define SEARCHLIGHT_REACH 6

/obj/effect/searchlight_beam
	name = ""
	mouse_opacity = 0
	anchored = TRUE
	invisibility = 101
	var/tmp/obj/structure/searchlight/source

/obj/effect/searchlight_beam/persistence_runtime_var(key)
	return key == "source" || ..()

// A beam saved with the world comes back without its light; the light makes
// a new one.
/obj/effect/searchlight_beam/after_load()
	..()
	if (!source)
		qdel(src)

/obj/structure/searchlight
	name = "searchlight"
	desc = "A big electric lamp on a tripod. Switch it on by hand and turn it to light the ground far ahead."
	icon = 'icons/obj/cmss13_ports.dmi'
	icon_state = "searchlight"
	anchored = TRUE
	density = TRUE
	dir = NORTH
	var/on = FALSE
	var/tmp/obj/effect/searchlight_beam/beam

/obj/structure/searchlight/persistence_runtime_var(key)
	return key == "beam" || ..()

/obj/structure/searchlight/after_load()
	..()
	update_beam()

/obj/structure/searchlight/Destroy()
	if (beam)
		qdel(beam)
		beam = null
	return ..()

/obj/structure/searchlight/proc/beam_turf()
	var/turf/T = get_turf(src)
	if (!T)
		return null
	var/turf/last = T
	for (var/i = 1 to SEARCHLIGHT_REACH)
		var/turf/next = get_step(last, dir)
		if (!next || next.opacity || next.density)
			break
		var/blocked = FALSE
		for (var/atom/movable/AM in next)
			if (AM.opacity)
				blocked = TRUE
				break
		if (blocked)
			break
		last = next
	return last

/obj/structure/searchlight/proc/update_beam()
	icon_state = on ? "searchlight_on" : "searchlight"
	if (!on)
		set_light(0)
		if (beam)
			qdel(beam)
			beam = null
		return null
	set_light(2, 1, "#fff6d8")
	var/turf/T = beam_turf()
	if (!beam || QDELETED(beam))
		beam = new /obj/effect/searchlight_beam(T)
		beam.source = src
	else
		beam.forceMove(T)
	beam.set_light(4, 2, "#fff6d8")
	return T

/obj/structure/searchlight/attack_hand(mob/user)
	on = !on
	update_beam()
	playsound(get_turf(src), 'sound/machines/button.ogg', 30, TRUE)
	to_chat(user, "<span class='notice'>You switch \the [src] [on ? "on" : "off"].</span>")

/obj/structure/searchlight/verb/turn_searchlight()
	set name = "Turn Searchlight"
	set category = null
	set src in view(1)
	if (!ishuman(usr) || usr.stat != CONSCIOUS)
		return
	set_dir(turn(dir, -90))
	update_beam()

/obj/structure/searchlight/examine(mob/user)
	..()
	to_chat(user, "It is [on ? "on" : "off"], pointing [dir2text(dir)]. Right-click it and choose Turn Searchlight to turn it.")

#undef SEARCHLIGHT_REACH

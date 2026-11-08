// Fire teams and the roster, friendly-fire notices, machine gun overheating
// and autoinjectors. Ideas from CM-SS13 (cmss13-devs/cmss13, AGPL-3.0):
// squad fire teams, the Overwatch roster, friendly-fire messages, M56/M2C
// barrel heat and autoinjectors. Reimplemented for Civ13. Fire teams also work
// in player factions and companies.

//////////////////////////////////////////////////////////////////////////////
// GROUPS: a squad in a team round, a player faction, or a company.
//////////////////////////////////////////////////////////////////////////////

#define FIRE_TEAM_COUNT 3

// Saved with the character, so faction and company fire teams survive a
// restart on persistent worlds. Squad teams lapse with their round.
/mob/living/human/var/fire_team = 0           // 0 for none, else 1 to FIRE_TEAM_COUNT
/mob/living/human/var/fire_team_kind = null   // "squad", "faction" or "company"
/mob/living/human/var/fire_team_group = null  // squad key, faction name or company name
/mob/living/human/var/fire_team_lead = FALSE

/proc/squad_group_key(mob/living/human/H)
	return "[H.faction_text]#[H.squad]"

/proc/company_majority_holder(company)
	if (!map || !company || !map.custom_company)
		return null
	var/list/holders = map.custom_company[company]
	if (!istype(holders))
		return null
	var/mob/living/human/best = null
	var/best_share = 0
	for (var/list/entry in holders)
		if (entry.len >= 2 && ishuman(entry[1]) && entry[2] > best_share)
			best = entry[1]
			best_share = entry[2]
	return best

/proc/fire_team_group_member(mob/living/human/H, kind, group)
	if (!istype(H) || !kind || !group || istype(H, /mob/living/human/corpse))
		return FALSE
	switch (kind)
		if ("squad")
			return team_round_active() && H.in_squad() && squad_group_key(H) == group
		if ("faction")
			return map && map.civilizations && H.civilization == group && group != "none"
		if ("company")
			return map && map.civilizations && find_company_member(H, group)
	return FALSE

/proc/fire_team_group_title(kind, group)
	if (kind == "squad")
		var/list/parts = splittext(group, "#")
		return parts.len == 2 ? "Squad [parts[2]]" : "your squad"
	return group

// Who runs a group's fire teams: the squad leader (or an officer or the
// commander of that side), the faction leader, or the company's majority holder.
/proc/fire_team_organizer(mob/living/human/H, kind, group)
	if (!istype(H) || H.stat == DEAD)
		return FALSE
	switch (kind)
		if ("squad")
			if (!team_round_active() || !H.original_job)
				return FALSE
			if (H.original_job.is_commander || H.original_job.is_officer)
				var/list/parts = splittext(group, "#")
				return parts.len == 2 && parts[1] == H.faction_text
			return H.original_job.is_squad_leader && fire_team_group_member(H, kind, group)
		if ("faction")
			return fire_team_group_member(H, kind, group) && map.is_faction_leader(H, group)
		if ("company")
			return fire_team_group_member(H, kind, group) && company_majority_holder(group) == H
	return FALSE

// list(list(kind, group)) for every group this person can organize.
/mob/living/human/proc/organized_groups()
	var/list/out = list()
	if (team_round_active() && original_job)
		if (original_job.is_commander || original_job.is_officer)
			var/list/keys = list()
			for (var/mob/living/human/M in human_mob_list)
				if (M.faction_text == faction_text && M.in_squad())
					keys |= squad_group_key(M)
			for (var/key in keys)
				out += list(list("squad", key))
		else if (original_job.is_squad_leader && in_squad())
			out += list(list("squad", squad_group_key(src)))
	if (map && map.civilizations)
		if (civilization && civilization != "none" && fire_team_organizer(src, "faction", civilization))
			out += list(list("faction", civilization))
		if (map.custom_company_nr)
			for (var/company in map.custom_company_nr)
				if (fire_team_organizer(src, "company", company))
					out += list(list("company", company))
	return out

/proc/fire_team_group_members(kind, group)
	var/list/out = list()
	for (var/mob/living/human/M in human_mob_list)
		if (fire_team_group_member(M, kind, group))
			out += M
	return out

// Fire team state is dropped once its owner leaves the group.
/mob/living/human/proc/has_fire_team()
	if (!fire_team)
		return FALSE
	if (!fire_team_group_member(src, fire_team_kind, fire_team_group))
		clear_fire_team()
		return FALSE
	return TRUE

/mob/living/human/proc/clear_fire_team()
	fire_team = 0
	fire_team_kind = null
	fire_team_group = null
	fire_team_lead = FALSE

/mob/living/human/proc/same_fire_team(mob/living/human/other)
	return istype(other) && other != src && has_fire_team() && other.has_fire_team() && other.fire_team == fire_team && other.fire_team_kind == fire_team_kind && other.fire_team_group == fire_team_group

/mob/living/human/proc/fire_team_leader()
	if (!has_fire_team())
		return null
	if (fire_team_lead)
		return src
	for (var/mob/living/human/M in human_mob_list)
		if (M.fire_team_lead && M.stat != DEAD && same_fire_team(M))
			return M
	return null

// team: 0 removes. Returns TRUE when it changed something.
/proc/assign_fire_team(mob/living/human/organizer, mob/living/human/M, kind, group, team, make_lead = FALSE)
	if (!fire_team_organizer(organizer, kind, group) || !fire_team_group_member(M, kind, group))
		return FALSE
	if (!isnum(team) || team < 0 || team > FIRE_TEAM_COUNT)
		return FALSE
	if (!team)
		M.clear_fire_team()
		return TRUE
	if (make_lead)
		for (var/mob/living/human/other in human_mob_list)
			if (other != M && other.fire_team_lead && other.fire_team == team && other.fire_team_kind == kind && other.fire_team_group == group)
				other.fire_team_lead = FALSE
	M.fire_team = team
	M.fire_team_kind = kind
	M.fire_team_group = group
	M.fire_team_lead = make_lead ? TRUE : (M.fire_team_lead && M.fire_team == team)
	to_chat(M, "<span class='notice'>You are now in <b>fire team [team]</b> of [fire_team_group_title(kind, group)][make_lead ? ", as its leader" : ""].</span>")
	return TRUE

/mob/living/human/examine(mob/user)
	. = ..()
	if (has_fire_team())
		to_chat(user, "<span class='notice'>[src] is in fire team [fire_team] of [fire_team_group_title(fire_team_kind, fire_team_group)][fire_team_lead ? ", as its leader" : ""].</span>")

//////////////////////////////////////////////////////////////////////////////
// ROSTER: leaders see their people and assign fire teams; anyone in a fire
// team sees their team.
//////////////////////////////////////////////////////////////////////////////

/proc/roster_condition(mob/living/human/M)
	switch (M.medic_health_state())
		if ("health_dead")
			return "<font color='#999'>dead</font>"
		if ("health_critical")
			return "<font color='#f55'>down</font>"
		if ("health_bleeding", "health_hurt")
			return "<font color='#fc4'>wounded</font>"
	return "<font color='#6d6'>fine</font>"

/proc/roster_where(mob/living/human/viewer, mob/living/human/M)
	if (M == viewer)
		return "you"
	var/turf/A = get_turf(viewer)
	var/turf/B = get_turf(M)
	if (!A || !B || A.z != B.z)
		return "elsewhere"
	var/dist = get_dist(A, B)
	return dist ? "[dist] m [dir2text(get_dir(A, B))]" : "here"

/datum/roster_view
	var/mob/living/human/viewer

/datum/roster_view/New(mob/living/human/H)
	viewer = H

/datum/roster_view/proc/member_row(mob/living/human/M, kind, group, can_assign)
	var/team = M.has_fire_team() && M.fire_team_kind == kind && M.fire_team_group == group ? M.fire_team : 0
	var/lead = team && M.fire_team_lead
	var/row = "<tr><td>[M.real_name][lead ? " &#9733;" : ""]</td><td>[team ? "FT [team]" : "-"]</td><td>[roster_condition(M)]</td><td>[roster_where(viewer, M)]</td>"
	if (can_assign)
		var/links = ""
		var/gref = url_encode(group)
		for (var/t = 0 to FIRE_TEAM_COUNT)
			links += "<a href='byond://?src=\ref[src];m=\ref[M];k=[kind];g=[gref];t=[t]'>[t ? t : "none"]</a> "
		if (team)
			links += "<a href='byond://?src=\ref[src];m=\ref[M];k=[kind];g=[gref];t=[team];lead=1'>lead</a>"
		row += "<td>[links]</td>"
	return row + "</tr>"

/datum/roster_view/proc/html()
	var/list/sections = list()
	for (var/list/G in viewer.organized_groups())
		var/kind = G[1]
		var/group = G[2]
		var/list/rows = list()
		for (var/mob/living/human/M in fire_team_group_members(kind, group))
			rows += member_row(M, kind, group, TRUE)
		sections += "<h3>[fire_team_group_title(kind, group)]</h3><table><tr><th>Name</th><th>Team</th><th>Condition</th><th>Where</th><th>Fire team</th></tr>[jointext(rows, "")]</table>"
	if (!sections.len && viewer.has_fire_team())
		var/list/rows = list(member_row(viewer, viewer.fire_team_kind, viewer.fire_team_group, FALSE))
		for (var/mob/living/human/M in human_mob_list)
			if (viewer.same_fire_team(M))
				rows += member_row(M, viewer.fire_team_kind, viewer.fire_team_group, FALSE)
		sections += "<h3>Fire team [viewer.fire_team], [fire_team_group_title(viewer.fire_team_kind, viewer.fire_team_group)]</h3><table><tr><th>Name</th><th>Team</th><th>Condition</th><th>Where</th></tr>[jointext(rows, "")]</table>"
	if (!sections.len)
		return null
	return "<html><head><title>Roster</title></head><body style='font-family:Verdana;font-size:12px;background:#1b1b1b;color:#ddd'>[jointext(sections, "")]<p style='font-size:10px;color:#aaa'>&#9733; marks a fire team leader. The tracker arrow points fire team members to their leader.</p></body></html>"

/datum/roster_view/proc/show()
	var/page = html()
	if (!page)
		to_chat(viewer, "<span class='warning'>You do not lead a squad, faction or company, and you are not in a fire team.</span>")
		return FALSE
	viewer << browse(page, "window=roster;size=560x480")
	return TRUE

/datum/roster_view/Topic(href, list/href_list)
	if (!viewer || usr != viewer)
		return
	var/mob/living/human/M = locate(href_list["m"])
	var/kind = href_list["k"]
	var/group = href_list["g"]
	var/team = text2num(href_list["t"])
	if (!istype(M) || !(kind in list("squad", "faction", "company")))
		return
	if (assign_fire_team(viewer, M, kind, group, team, href_list["lead"] ? TRUE : FALSE))
		show()

/mob/living/human/var/tmp/datum/roster_view/roster_view = null

/mob/living/human/persistence_runtime_var(key)
	return key == "roster_view" || ..()

/mob/living/human/verb/open_roster()
	set name = "Roster"
	set category = "IC"
	set desc = "Leaders see their squad, faction or company and assign fire teams; fire team members see their team."
	if (!roster_view || roster_view.viewer != src)
		roster_view = new(src)
	roster_view.show()

#undef FIRE_TEAM_COUNT

//////////////////////////////////////////////////////////////////////////////
// FRIENDLY FIRE: tell both people, and count it for the round facts.
//////////////////////////////////////////////////////////////////////////////

#define FRIENDLY_FIRE_NOTICE_GAP 30

/proc/same_side(mob/living/human/A, mob/living/human/B)
	if (!istype(A) || !istype(B) || A == B)
		return FALSE
	if (team_round_active())
		return A.faction_text && A.faction_text == B.faction_text
	return A.civilization && A.civilization != "none" && A.civilization == B.civilization

/mob/living/human/var/tmp/friendly_fire_notice_time = -1000

/mob/living/human/persistence_runtime_var(key)
	return key == "friendly_fire_notice_time" || ..()

/datum/round_facts/var/list/friendly_hits = list() // attacker name -> hits on own side

// Called from record_hit() in round_facts.dm.
/datum/round_facts/proc/record_friendly_fire(mob/living/human/victim, mob/living/human/attacker, weapon)
	if (!same_side(victim, attacker) || victim.stat == DEAD)
		return
	var/name = round_fact_name(attacker)
	friendly_hits[name] = (friendly_hits[name] || 0) + 1
	if (world.time - attacker.friendly_fire_notice_time < FRIENDLY_FIRE_NOTICE_GAP)
		return
	attacker.friendly_fire_notice_time = world.time
	to_chat(attacker, "<span class='danger'>Friendly fire! You hit [victim], who is on your side.</span>")
	to_chat(victim, "<span class='danger'>Friendly fire! [attacker] hit you[weapon ? " with \the [weapon]" : ""].</span>")

// Called from fact_lines() in round_facts.dm; null when there is nothing to say.
/datum/round_facts/proc/friendly_fire_line()
	var/total = 0
	for (var/name in friendly_hits)
		total += friendly_hits[name]
	if (total >= 3)
		var/list/top = round_fact_top(friendly_hits)
		return "Friendly fire: [round_fact_plural(total, "hit")] on people's own side. The worst offender was <b>[top[1]]</b>, with [top[2]]."

#undef FRIENDLY_FIRE_NOTICE_GAP

//////////////////////////////////////////////////////////////////////////////
// MACHINE GUN HEAT: every shot heats the barrel; at 100 the gun stops until it
// has cooled to 40. Mounted guns heat more slowly.
//////////////////////////////////////////////////////////////////////////////

#define GUN_HEAT_MAX 100
#define GUN_HEAT_RESUME 40
#define GUN_COOL_PER_SECOND 8

/obj/item/weapon/gun/var/tmp/heat = 0
/obj/item/weapon/gun/var/tmp/heat_time = 0
/obj/item/weapon/gun/var/tmp/overheated = FALSE

/obj/item/weapon/gun/persistence_runtime_var(key)
	return (key in list("heat", "heat_time", "overheated")) || ..()

/obj/item/weapon/gun/proc/heat_per_shot()
	// Light and mounted machine guns only; rifles share their skill but not this.
	if (!istype(src, /obj/item/weapon/gun/projectile/automatic) || istype(src, /obj/item/weapon/gun/projectile/automatic/laser) || istype(src, /obj/item/weapon/gun/projectile/automatic/stationary/laser))
		return 0
	if (istype(src, /obj/item/weapon/gun/projectile/automatic/stationary))
		return 2
	return 4

/obj/item/weapon/gun/proc/current_heat()
	if (heat > 0)
		heat = max(0, heat - (world.time - heat_time) / 10 * GUN_COOL_PER_SECOND)
	heat_time = world.time
	if (overheated && heat <= GUN_HEAT_RESUME)
		overheated = FALSE
	return heat

/obj/item/weapon/gun/proc/add_heat(mob/user)
	var/step = heat_per_shot()
	if (!step)
		return
	var/before = current_heat()
	heat = min(GUN_HEAT_MAX, before + step)
	if (heat >= GUN_HEAT_MAX && !overheated)
		overheated = TRUE
		if (user)
			to_chat(user, "<span class='danger'>\The [src]'s barrel is red hot! Let it cool before firing again.</span>")
	else if (before < 70 && heat >= 70 && user)
		to_chat(user, "<span class='warning'>\The [src]'s barrel is getting hot.</span>")

/obj/item/weapon/gun/special_check(mob/user)
	. = ..()
	if (. && heat_per_shot())
		current_heat()
		if (overheated)
			to_chat(user, "<span class='warning'>\The [src] is too hot to fire. Wait for the barrel to cool.</span>")
			return FALSE

/obj/item/weapon/gun/handle_post_fire(mob/user, atom/target, pointblank = 0, reflex = 0)
	. = ..()
	add_heat(user)

/obj/item/weapon/gun/examine(mob/user)
	. = ..()
	if (heat_per_shot())
		var/h = current_heat()
		if (overheated)
			to_chat(user, "<span class='danger'>The barrel is too hot to fire.</span>")
		else if (h >= 70)
			to_chat(user, "<span class='warning'>The barrel is hot.</span>")
		else if (h >= 30)
			to_chat(user, "The barrel is warm.")

#undef GUN_HEAT_MAX
#undef GUN_HEAT_RESUME
#undef GUN_COOL_PER_SECOND

//////////////////////////////////////////////////////////////////////////////
// AUTOINJECTORS: one-use pens that inject someone else in one second.
//////////////////////////////////////////////////////////////////////////////

/datum/reagent/clotting_agent
	name = "Clotting agent"
	id = "clotting_agent"
	description = "A fast-acting coagulant that seals bleeding wounds."
	taste_description = "metal"
	reagent_state = LIQUID
	color = "#8b1a1a"
	metabolism = REM * 0.5
	overdose = 16
	scannable = TRUE

// Each dose tick seals one bleeding wound.
/datum/reagent/clotting_agent/affect_blood(mob/living/human/M, alien, removed)
	if (!istype(M))
		return
	for (var/obj/item/organ/external/E in M.organs)
		for (var/datum/wound/W in E.wounds)
			if (W.bleeding())
				W.bandage()
				return

/obj/item/weapon/reagent_containers/syringe/autoinjector
	name = "autoinjector"
	desc = "A spring-loaded pen. Press it to someone and it injects its whole dose in a second. It works only once."
	icon_state = "single_use0"
	w_class = ITEM_SIZE_TINY
	volume = 10
	amount_per_transfer_from_this = 10
	single_use = TRUE
	time = 10
	var/fill_reagent = null
	var/fill_amount = 0
	var/full_state = "single_use0"

/obj/item/weapon/reagent_containers/syringe/autoinjector/New()
	..()
	if (fill_reagent && reagents)
		reagents.add_reagent(fill_reagent, fill_amount)
		mode = TRUE // inject
	update_icon()

/obj/item/weapon/reagent_containers/syringe/autoinjector/update_icon()
	if (reagents && reagents.total_volume > 0)
		icon_state = full_state
	else
		icon_state = "[full_state]_empty"
		if (fill_reagent)
			used = TRUE

/obj/item/weapon/reagent_containers/syringe/autoinjector/morphine
	name = "morphine autoinjector"
	desc = "A one-use pen with 5 units of morphine for severe pain. It injects someone else in a second."
	fill_reagent = "morphine"
	fill_amount = 5
	full_state = "single_use0"

/obj/item/weapon/reagent_containers/syringe/autoinjector/adrenaline
	name = "adrenaline autoinjector"
	desc = "A one-use pen with a dose of adrenaline, to get someone in shock back on their feet. It injects someone else in a second."
	volume = 30
	amount_per_transfer_from_this = 30
	fill_reagent = "adrenaline"
	fill_amount = 30
	full_state = "single_use3"

/obj/item/weapon/reagent_containers/syringe/autoinjector/clotting
	name = "clotting autoinjector"
	desc = "A one-use pen with a clotting agent that seals bleeding wounds over the next minute. It injects someone else in a second."
	fill_reagent = "clotting_agent"
	fill_amount = 10
	full_state = "single_use2"

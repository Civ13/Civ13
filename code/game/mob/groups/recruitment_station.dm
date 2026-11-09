// Faction recruitment stations and the recruitment panel (#4237 stage 3).
//
// A station is a buildable stall a faction leader designates for their
// faction. It is only an entry point: the policy, applications and offers live
// in map.faction_recruitment (faction_recruitment.dm), so destroying, moving or
// stealing a station never loses or hands over a queue. Applicants act only
// while standing next to a designated station; leaders and recruiters can also
// open the review panel from the Faction tab anywhere.

/obj/structure/recruitment_station
	name = "recruitment station"
	desc = "A stall where people can apply to join a faction. Its faction's leader designates it."
	icon = 'icons/obj/vending.dmi'
	icon_state = "market_stall"
	density = TRUE
	anchored = TRUE
	flammable = TRUE
	// The faction this station recruits for, by name. faction_rename.dm
	// rewrites vars called "faction", so a rename keeps the binding.
	var/faction = null

/obj/structure/recruitment_station/New()
	..()
	update_icon()

/obj/structure/recruitment_station/update_icon()
	overlays.Cut()
	name = faction ? "[faction] recruitment station" : initial(name)
	if (!faction || !map)
		return
	var/list/civ_data = map.custom_civs[faction]
	if (!islist(civ_data) || civ_data.len < 8)
		return
	var/image/primary = image(icon = icon, icon_state = "[icon_state]_overlay_primary")
	primary.color = civ_data[7]
	var/image/secondary = image(icon = icon, icon_state = "[icon_state]_overlay_secondary")
	secondary.color = civ_data[8]
	overlays += primary
	overlays += secondary

/obj/structure/recruitment_station/examine(mob/user)
	..()
	if (!faction)
		to_chat(user, "It has not been designated for a faction yet.")
	else if (!map || !map.recruitment_supported(faction))
		to_chat(user, "It is marked for [faction], which is not recruiting here.")
	else
		to_chat(user, "It recruits for [faction]: [recruitment_policy_summary(map.recruitment_policy(faction))].")

// Valid for recruiting: designated for a faction that can recruit here.
/obj/structure/recruitment_station/proc/valid_for_recruitment()
	return faction && map && map.recruitment_supported(faction) && isturf(loc)

/obj/structure/recruitment_station/attack_hand(mob/living/human/user)
	if (!ishuman(user))
		return
	user.open_recruitment_panel(src)

// --- Panel -----------------------------------------------------------------

/datum/recruitment_panel
	var/mob/living/human/viewer
	// null: the remote review panel from the Faction tab.
	var/obj/structure/recruitment_station/station

/datum/recruitment_panel/New(mob/living/human/H, obj/structure/recruitment_station/S)
	viewer = H
	station = S

/mob/living/human/var/tmp/datum/recruitment_panel/recruitment_panel = null

/mob/living/human/proc/open_recruitment_panel(obj/structure/recruitment_station/S = null)
	if (!client || !map)
		return
	if (S && !Adjacent(S))
		return
	if (recruitment_panel && recruitment_panel.station != S)
		GLOB.nanomanager.close_uis(recruitment_panel)
		recruitment_panel = null
	if (!recruitment_panel)
		recruitment_panel = new /datum/recruitment_panel(src, S)
	recruitment_panel.ui_interact(src)

/mob/living/human/proc/recruitment_applications()
	set name = "Recruitment Applications"
	set category = "Faction"
	set desc = "Review your faction's recruitment applications and rules."
	if (!map || !map.allows_custom_factions())
		return
	if (!civilization || civilization == "none" || !map.can_recruit_for_faction(src, civilization))
		to_chat(src, SPAN_WARNING("Only your faction's leader and members with the Recruitment permission can review applications."))
		return
	open_recruitment_panel(null)

/datum/topic_state/recruitment_panel/can_use_topic(var/datum/recruitment_panel/P, var/mob/user)
	if (!istype(P) || !user || user != P.viewer || !user.client || !map)
		return STATUS_CLOSE
	var/mob/living/human/H = user
	if (H.stat || H.restrained())
		return STATUS_DISABLED
	if (P.station)
		// Station panels need the viewer next to the station, every time.
		if (QDELETED(P.station) || !isturf(P.station.loc) || !H.Adjacent(P.station))
			return STATUS_CLOSE
		return STATUS_INTERACTIVE
	// The remote panel is only for current reviewers of their own faction.
	if (!H.civilization || H.civilization == "none" || !map.can_recruit_for_faction(H, H.civilization))
		return STATUS_CLOSE
	return STATUS_INTERACTIVE

/datum/recruitment_panel/proc/panel_faction()
	if (station)
		return station.faction
	return viewer.civilization

/datum/recruitment_panel/ui_interact(mob/user, ui_key = "main", var/datum/nanoui/ui = null, var/force_open = TRUE, var/datum/nanoui/master_ui = null, var/datum/topic_state/state = null)
	if (user != viewer)
		return
	var/list/data = build_data()
	ui = GLOB.nanomanager.try_update_ui(user, src, ui_key, ui, data, force_open)
	if (!ui)
		var/datum/topic_state/recruitment_panel/panel_state = new()
		ui = new /datum/nanoui/tgui(user, src, ui_key, "recruitment_station.tmpl", station ? "Recruitment Station" : "Recruitment Applications", 520, 640, _state = panel_state)
		ui.set_initial_data(data)
		ui.open()

/proc/recruitment_time_text(deciseconds)
	if (deciseconds <= 0)
		return "now"
	var/minutes = round(deciseconds / 600)
	if (minutes < 60)
		return "[max(1, minutes)] minute\s"
	var/hours = round(minutes / 60)
	if (hours < 48)
		return "[hours] hour\s"
	return "[round(hours / 24)] day\s"

/proc/recruitment_status_text(list/A)
	switch (A["status"])
		if (RECRUIT_PENDING)
			return "Waiting for review"
		if (RECRUIT_APPROVED)
			return "Approved: confirm at a station to join"
		if (RECRUIT_REJECTED)
			return "Turned down"
		if (RECRUIT_WITHDRAWN)
			return "Withdrawn"
		if (RECRUIT_EXPIRED)
			return "Expired"
		if (RECRUIT_INVALIDATED)
			return "No longer valid"
		if (RECRUIT_REVOKED)
			return "Offer withdrawn"
		if (RECRUIT_ENROLLED)
			return "Joined"
	return "Unknown"

/proc/recruitment_encoded_list(list/L)
	var/list/result = list()
	for (var/text in L)
		result += html_encode("[text]")
	return result

/datum/recruitment_panel/proc/build_data()
	map.recruitment_expire()
	var/faction = panel_faction()
	var/now = recruitment_now()
	var/list/data = list("station" = station ? 1 : 0, "faction" = faction ? html_encode(faction) : "", "bound" = 0, "supported" = 0)
	// Unbound station: only a leader can designate it, for their own faction.
	if (station && !faction)
		var/own = viewer.civilization
		data["can_designate"] = (own && own != "none" && map.is_faction_leader(viewer, own) && map.recruitment_supported(own)) ? 1 : 0
		data["designate_faction"] = data["can_designate"] ? html_encode(own) : ""
		return data
	data["bound"] = 1
	data["supported"] = map.recruitment_supported(faction) ? 1 : 0
	var/list/P = map.recruitment_policy(faction)
	data["summary"] = html_encode(recruitment_policy_summary(P))
	data["motto"] = map.faction_motto[faction] ? map.faction_motto[faction] : ""
	data["expiry_days"] = config && isnum(config.recruitment_expiry_days) ? config.recruitment_expiry_days : 7
	var/is_member = viewer.civilization == faction
	var/is_leader = is_member && map.is_faction_leader(viewer, faction)
	var/can_review = is_member && map.can_recruit_for_faction(viewer, faction)
	data["is_leader"] = is_leader ? 1 : 0
	data["can_review"] = can_review ? 1 : 0
	data["can_unbind"] = (station && is_leader) ? 1 : 0

	// Applicant view: only at a station, only for non-members.
	if (station && !is_member)
		var/list/applicant = list("results" = list(), "action" = "", "application" = null)
		var/blocked = map.recruitment_mandatory_block(viewer, faction)
		var/list/A = map.recruitment_active_for(viewer, faction)
		if (A)
			applicant["application"] = list("id" = A["id"], "status" = A["status"], "status_text" = recruitment_status_text(A), "reason" = html_encode(A["reason"]), "expires" = recruitment_time_text(A["expires"] - now))
			applicant["text"] = A["status"] == RECRUIT_APPROVED ? "You have an approved offer from [html_encode(faction)]." : "Your application is waiting for review. You can leave; come back to any [html_encode(faction)] station."
			if (A["status"] == RECRUIT_APPROVED && !A["seen"])
				A["seen"] = 1
		else if (blocked)
			applicant["text"] = html_encode(blocked)
		else if (!P || P["mode"] == RECRUIT_MODE_CLOSED)
			applicant["text"] = "[html_encode(faction)] is not taking applications right now."
		else
			var/list/evaluation = recruitment_evaluate(viewer, P)
			applicant["results"] = recruitment_encoded_list(evaluation["results"])
			if (P["mode"] == RECRUIT_MODE_AUTO && evaluation["match"])
				applicant["action"] = "join"
				applicant["text"] = "You meet the requirements and can join right away."
			else if (!evaluation["match"] && P["nonmatch"] == RECRUIT_NONMATCH_REFUSE && length(evaluation["results"]))
				applicant["text"] = "You do not meet the requirements, and [html_encode(faction)] does not review other applicants."
			else
				applicant["action"] = "apply"
				applicant["text"] = "Your application will be reviewed by the leader or a recruiter. You don't need to wait here."
		data["applicant"] = applicant

	if (can_review)
		var/list/queue = list()
		for (var/list/A in map.recruitment_queue(faction, list(RECRUIT_PENDING, RECRUIT_APPROVED)))
			queue += list(list("id" = A["id"], "name" = html_encode(A["name"]), "status" = A["status"], "status_text" = recruitment_status_text(A), "submitted" = recruitment_time_text(now - A["submitted"]), "expires" = recruitment_time_text(A["expires"] - now), "intro" = html_encode(A["intro"]), "results" = recruitment_encoded_list(A["results"]), "match" = A["match"], "exception" = A["exception"], "reviewer" = html_encode(A["reviewer"])))
		data["queue"] = queue
	if (is_leader)
		var/list/policy = list("mode" = P ? P["mode"] : "", "open" = P ? P["open"] : 0, "language" = P ? html_encode(P["language"]) : "", "nonmatch" = P ? P["nonmatch"] : RECRUIT_NONMATCH_REVIEW)
		var/list/skills = list()
		for (var/skill in recruitment_skill_labels)
			var/list/levels = P ? P["skills"] : null
			skills += list(list("key" = skill, "label" = recruitment_skill_labels[skill], "level" = (levels && levels[skill]) ? levels[skill] : 0))
		policy["skills"] = skills
		data["policy"] = policy
		var/list/audit = list()
		var/list/S = map.recruitment_state()
		var/list/entries = S["audit"][faction]
		if (islist(entries))
			for (var/i = entries.len, i >= 1 && audit.len < 10, i--)
				var/list/entry = entries[i]
				if (islist(entry) && entry.len >= 2)
					audit += html_encode("[recruitment_time_text(now - entry[1])] ago: [entry[2]]")
		data["audit"] = audit
	return data

// Every action rechecks who is acting and where, after any prompt too.
/datum/recruitment_panel/proc/still_valid(mob/living/human/H)
	if (H != viewer || QDELETED(H) || H.stat || H.restrained() || !H.client)
		return FALSE
	if (station && (QDELETED(station) || !isturf(station.loc) || !H.Adjacent(station)))
		return FALSE
	return TRUE

/datum/recruitment_panel/Topic(href, href_list, state)
	var/mob/living/human/H = usr
	if (!istype(H) || !still_valid(H))
		return FALSE
	var/faction = panel_faction()
	var/message = null
	if (href_list["designate"])
		if (!station || station.faction)
			return FALSE
		var/own = H.civilization
		if (!own || own == "none" || !map.is_faction_leader(H, own) || !map.recruitment_supported(own))
			message = "Only a faction's leader can designate a station for it."
		else
			station.faction = own
			map.recruitment_ensure_policy(own)
			map.recruitment_audit(own, "[H.real_name] designated a recruitment station.", H.persistence_owner_ckey || "")
			station.update_icon()
			message = "This station now recruits for [own]. New stations start with every application reviewed."
	else if (href_list["unbind"])
		if (!station || !faction || H.civilization != faction || !map.is_faction_leader(H, faction))
			return FALSE
		station.faction = null
		station.update_icon()
		map.recruitment_audit(faction, "[H.real_name] released a recruitment station.", H.persistence_owner_ckey || "")
		message = "The station no longer recruits for [faction]. Applications are kept."
	else if (href_list["apply"])
		if (!station || !station.valid_for_recruitment() || H.civilization == faction)
			return FALSE
		var/list/P = map.recruitment_policy(faction)
		var/intro = ""
		var/list/evaluation = P ? recruitment_evaluate(H, P) : null
		var/needs_review = P && !(P["mode"] == RECRUIT_MODE_AUTO && evaluation["match"])
		var/confirm = WWinput(H, needs_review ? "Apply to join [faction]? A leader or recruiter will review it." : "Join [faction] now? You will become an ordinary member.", "Recruitment", "Cancel", list(needs_review ? "Apply" : "Join", "Cancel"))
		if (confirm != "Apply" && confirm != "Join")
			return TRUE
		if (needs_review)
			var/written = input(H, "Optional: a short introduction for [faction] (up to [RECRUITMENT_INTRO_MAX] characters).", "Recruitment") as text|null
			intro = istext(written) ? written : ""
		if (!still_valid(H) || !station.valid_for_recruitment() || station.faction != faction)
			return TRUE
		var/list/result = map.recruitment_submit(H, faction, intro)
		message = result["text"]
	else if (href_list["withdraw"])
		if (!station)
			return FALSE
		message = map.recruitment_withdraw(H, href_list["withdraw"]) || "You withdrew your application."
	else if (href_list["confirm"])
		if (!station || !station.valid_for_recruitment())
			return FALSE
		var/list/A = map.recruitment_app(href_list["confirm"])
		if (!A || A["faction"] != faction)
			return FALSE
		if (WWinput(H, "Join [faction] now? You will become an ordinary member.", "Recruitment", "Cancel", list("Join", "Cancel")) != "Join")
			return TRUE
		if (!still_valid(H) || !station.valid_for_recruitment() || station.faction != faction)
			return TRUE
		message = map.recruitment_confirm(H, href_list["confirm"]) || "You are now part of [faction]."
	else if (href_list["approve"] || href_list["reject"] || href_list["revoke"])
		var/decision = href_list["approve"] ? "approve" : href_list["reject"] ? "reject" : "revoke"
		var/id = href_list[decision]
		var/list/A = map.recruitment_app(id)
		if (!A || A["faction"] != faction || !map.can_recruit_for_faction(H, faction))
			return FALSE
		var/written = input(H, "Optional: a short reason the applicant will see (up to [RECRUITMENT_REASON_MAX] characters).", "Recruitment") as text|null
		if (!still_valid(H))
			return TRUE
		message = map.recruitment_decide(H, id, decision, istext(written) ? written : "") || "Done."
	else if (href_list["set_mode"] || href_list["set_open"] || href_list["set_nonmatch"])
		var/list/changes = list()
		if (href_list["set_mode"])
			changes["mode"] = href_list["set_mode"]
		if (href_list["set_open"])
			changes["open"] = text2num(href_list["set_open"]) ? 1 : 0
		if (href_list["set_nonmatch"])
			changes["nonmatch"] = href_list["set_nonmatch"]
		message = map.recruitment_set_policy(H, faction, changes) || "Recruitment rules updated."
	else if (href_list["set_language"])
		var/list/choices = list("No language rule")
		for (var/name in all_languages)
			choices += name
		var/choice = WWinput(H, "Which language must applicants know?", "Recruitment", "No language rule", choices)
		if (!choice || !still_valid(H))
			return TRUE
		message = map.recruitment_set_policy(H, faction, list("language" = choice == "No language rule" ? "" : choice)) || "Recruitment rules updated."
	else if (href_list["set_skill"])
		var/skill = href_list["set_skill"]
		if (!(skill in recruitment_skill_labels))
			return FALSE
		var/list/levels = list()
		for (var/i = 0, i <= RECRUITMENT_SKILL_LEVEL_MAX, i++)
			levels += "[i]"
		var/choice = WWinput(H, "Minimum [recruitment_skill_labels[skill]] level (0-[RECRUITMENT_SKILL_LEVEL_MAX], as shown by Skill Progress). 0 removes the rule.", "Recruitment", "0", levels)
		if (!choice || !still_valid(H))
			return TRUE
		message = map.recruitment_set_policy(H, faction, list("skill" = list(skill, text2num(choice)))) || "Recruitment rules updated."
	else if (!href_list["refresh"])
		return FALSE
	if (message)
		to_chat(H, html_encode(message))
	return TRUE

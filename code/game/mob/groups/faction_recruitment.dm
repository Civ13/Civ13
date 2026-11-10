// Faction recruitment applications (#4237 stage 2).
//
// A faction's recruitment policy, its applications and approved offers live in
// one durable map field, map.faction_recruitment, keyed by faction name so a
// rename (faction_rename.dm) carries them. Records hold only text and numbers:
// no object references, so they save, load and survive a restart unchanged.
// Stations (recruitment_station.dm) are entry points only; they own nothing.
//
// Every state change goes through the procs below. None of them sleep, so the
// checks and the change they guard happen in the same tick.

#define RECRUITMENT_SCHEMA 1

#define RECRUIT_MODE_CLOSED "closed"
#define RECRUIT_MODE_MANUAL "manual"
#define RECRUIT_MODE_AUTO "auto"

#define RECRUIT_NONMATCH_REVIEW "review"
#define RECRUIT_NONMATCH_REFUSE "refuse"

#define RECRUIT_PENDING "pending"
#define RECRUIT_APPROVED "approved"
#define RECRUIT_REJECTED "rejected"
#define RECRUIT_WITHDRAWN "withdrawn"
#define RECRUIT_EXPIRED "expired"
#define RECRUIT_INVALIDATED "invalidated"
#define RECRUIT_REVOKED "revoked"
#define RECRUIT_ENROLLED "enrolled"

#define RECRUITMENT_INTRO_MAX 300
#define RECRUITMENT_REASON_MAX 150
#define RECRUITMENT_SKILL_LEVEL_MAX 10
#define RECRUITMENT_AUDIT_MAX 40
// Terminal records are kept this long after their last change so applicants
// see the outcome, then pruned so the field stays bounded.
#define RECRUITMENT_TERMINAL_KEEP (14 * 24 * 60 * 60 * 10)

/obj/map_metadata/var/list/faction_recruitment = list()

// A character's identity for applications. Assigned on first application and
// saved with the body. A new life is a new body with no token; death clears it;
// a cross-region arrival builds a fresh body, so an old offer never matches.
/mob/living/human/var/recruitment_life_id = null

// The skills a policy may require, shown to players with these labels. Levels
// are the 0-10 practice levels from "Skill Progress": they come from trained
// (permanent) skill, never current effectiveness, mood or equipment.
var/global/list/recruitment_skill_labels = list("crafting" = "Crafting", "farming" = "Farming", "medical" = "Medical", "combat" = "Combat (best weapon skill)")
var/global/list/recruitment_combat_skills = list("rifle", "pistol", "swords", "bows", "machinegun")

/proc/recruitment_text(value, max_length)
	if (!istext(value))
		return ""
	// Stored as plain text and encoded wherever it is shown.
	var/clean = sanitize(value, max_length + 1, FALSE)
	return istext(clean) ? clean : ""

/proc/recruitment_now()
	return world.realtime

/proc/recruitment_expiry_time()
	var/days = config && isnum(config.recruitment_expiry_days) ? config.recruitment_expiry_days : 7
	return days * 24 * 60 * 60 * 10

// --- State ---------------------------------------------------------------

// Returns the normalized state root. Malformed parts (from a damaged or
// hand-edited save) are dropped, never trusted; a missing root starts empty.
/obj/map_metadata/proc/recruitment_state()
	var/list/S = faction_recruitment
	if (!islist(S) || S["schema"] != RECRUITMENT_SCHEMA)
		S = list("schema" = RECRUITMENT_SCHEMA, "seq" = 0, "policies" = list(), "applications" = list(), "audit" = list())
		faction_recruitment = S
	if (!isnum(S["seq"]) || S["seq"] < 0)
		S["seq"] = 0
	for (var/key in list("policies", "applications", "audit"))
		if (!islist(S[key]))
			S[key] = list()
	return S

/proc/recruitment_valid_policy(list/P)
	if (!islist(P) || !(P["mode"] in list(RECRUIT_MODE_CLOSED, RECRUIT_MODE_MANUAL, RECRUIT_MODE_AUTO)))
		return FALSE
	if (!(P["nonmatch"] in list(RECRUIT_NONMATCH_REVIEW, RECRUIT_NONMATCH_REFUSE)))
		return FALSE
	if (!isnum(P["revision"]) || !(P["open"] in list(0, 1)) || !istext(P["language"]) || !islist(P["skills"]))
		return FALSE
	var/list/skills = P["skills"]
	for (var/skill in skills)
		if (!(skill in recruitment_skill_labels) || !isnum(skills[skill]) || skills[skill] < 1 || skills[skill] > RECRUITMENT_SKILL_LEVEL_MAX)
			return FALSE
	return TRUE

/proc/recruitment_valid_application(list/A)
	if (!islist(A))
		return FALSE
	for (var/key in list("id", "faction", "life", "account", "name", "status", "intro", "reason", "reviewer", "reviewer_account"))
		if (!istext(A[key]))
			return FALSE
	for (var/key in list("submitted", "changed", "expires", "revision", "match", "exception", "seen"))
		if (!isnum(A[key]))
			return FALSE
	if (!(A["status"] in list(RECRUIT_PENDING, RECRUIT_APPROVED, RECRUIT_REJECTED, RECRUIT_WITHDRAWN, RECRUIT_EXPIRED, RECRUIT_INVALIDATED, RECRUIT_REVOKED, RECRUIT_ENROLLED)))
		return FALSE
	return islist(A["results"])

// Drop anything malformed. Called after a load and before any use.
/obj/map_metadata/proc/recruitment_normalize()
	var/list/S = recruitment_state()
	var/list/policies = S["policies"]
	for (var/faction in policies.Copy())
		if (!istext(faction) || !recruitment_valid_policy(policies[faction]))
			policies -= faction
	var/list/apps = S["applications"]
	for (var/id in apps.Copy())
		var/list/A = apps[id]
		if (!istext(id) || !recruitment_valid_application(A) || A["id"] != id)
			apps -= id
	var/list/audit = S["audit"]
	for (var/faction in audit.Copy())
		if (!istext(faction) || !islist(audit[faction]))
			audit -= faction
	return S

/obj/map_metadata/proc/recruitment_audit(faction, text, account = "")
	var/list/S = recruitment_state()
	var/list/audit = S["audit"]
	var/list/entries = audit[faction]
	if (!islist(entries))
		entries = list()
		audit[faction] = entries
	// Account identity stays internal for administrators; players see text.
	entries += list(list(recruitment_now(), text, account))
	while (entries.len > RECRUITMENT_AUDIT_MAX)
		entries.Cut(1, 2)

// A faction a station may recruit for: player-founded on a map that allows
// them, and still in existence (some member alive).
/obj/map_metadata/proc/recruitment_supported(faction)
	if (!istext(faction) || faction == "none" || !allows_custom_factions())
		return FALSE
	if (!(faction in custom_faction_nr) || !(faction in custom_civs))
		return FALSE
	return faction_is_extant(faction)

/obj/map_metadata/proc/recruitment_policy(faction)
	var/list/S = recruitment_state()
	var/list/policies = S["policies"]
	var/list/P = policies[faction]
	return recruitment_valid_policy(P) ? P : null

// First designated station: manual approval, no rules, closed to non-matches
// only by choice. A missing policy means no station recruitment at all.
/obj/map_metadata/proc/recruitment_ensure_policy(faction)
	var/list/P = recruitment_policy(faction)
	if (P)
		return P
	var/list/S = recruitment_state()
	var/list/policies = S["policies"]
	P = list("mode" = RECRUIT_MODE_MANUAL, "open" = 0, "language" = "", "skills" = list(), "nonmatch" = RECRUIT_NONMATCH_REVIEW, "revision" = 1)
	policies[faction] = P
	return P

// --- Policy (leader only) ------------------------------------------------

// changes: any of mode, open, language, skills (skill = level), nonmatch.
// Invalid values are refused as a whole; nothing is half-applied. Returns
// null on success, otherwise a reason.
/obj/map_metadata/proc/recruitment_set_policy(mob/living/human/H, faction, list/changes)
	if (!is_faction_leader(H, faction) || H.stat == DEAD)
		return "Only your faction's leader can change recruitment rules."
	if (!recruitment_supported(faction))
		return "Your faction cannot recruit at stations here."
	if (!islist(changes))
		return "Nothing to change."
	var/list/P = recruitment_ensure_policy(faction)
	var/list/next = P.Copy()
	var/list/old_skills = P["skills"]
	next["skills"] = old_skills.Copy()
	for (var/key in changes)
		var/value = changes[key]
		switch (key)
			if ("mode")
				if (!(value in list(RECRUIT_MODE_CLOSED, RECRUIT_MODE_MANUAL, RECRUIT_MODE_AUTO)))
					return "Unknown recruitment mode."
				next["mode"] = value
			if ("open")
				if (!(value in list(0, 1, TRUE, FALSE)))
					return "Invalid open recruitment setting."
				next["open"] = value ? 1 : 0
			if ("nonmatch")
				if (!(value in list(RECRUIT_NONMATCH_REVIEW, RECRUIT_NONMATCH_REFUSE)))
					return "Invalid rule for applicants who do not match."
				next["nonmatch"] = value
			if ("language")
				if (!istext(value))
					return "Invalid language."
				if (value != "" && !(value in all_languages))
					return "Unknown language."
				next["language"] = value
			if ("skill")
				// value: list(skill, level); level 0 removes the requirement.
				if (!islist(value) || length(value) != 2)
					return "Invalid skill rule."
				var/skill = value[1]
				var/level = value[2]
				if (!(skill in recruitment_skill_labels) || !isnum(level) || level != round(level) || level < 0 || level > RECRUITMENT_SKILL_LEVEL_MAX)
					return "Invalid skill rule."
				var/list/skills = next["skills"]
				if (level == 0)
					skills -= skill
				else
					skills[skill] = level
			else
				return "Unknown recruitment setting."
	// Automatic acceptance needs an explicit choice of what to accept: open
	// recruitment, or at least one rule. Empty rules never mean "everyone".
	if (next["mode"] == RECRUIT_MODE_AUTO && !next["open"] && next["language"] == "" && !length(next["skills"]))
		return "Automatic acceptance needs open recruitment or at least one rule."
	next["revision"] = P["revision"] + 1
	var/list/S = recruitment_state()
	var/list/policies = S["policies"]
	policies[faction] = next
	recruitment_audit(faction, "[H.real_name] changed the rules: [recruitment_policy_summary(next)].", H.persistence_owner_ckey || "")
	return null

/proc/recruitment_policy_summary(list/P)
	if (!P)
		return "station recruitment is not set up"
	var/list/parts = list()
	switch (P["mode"])
		if (RECRUIT_MODE_CLOSED)
			parts += "closed"
		if (RECRUIT_MODE_MANUAL)
			parts += "every application is reviewed"
		if (RECRUIT_MODE_AUTO)
			parts += "matching applicants join at once"
	if (P["open"])
		parts += "open to anyone eligible"
	for (var/text in recruitment_rule_texts(P))
		parts += text
	if (!P["open"] && (P["language"] != "" || length(P["skills"])))
		parts += P["nonmatch"] == RECRUIT_NONMATCH_REVIEW ? "others are reviewed" : "others cannot apply"
	return jointext(parts, "; ")

/proc/recruitment_rule_texts(list/P)
	var/list/texts = list()
	if (!P || P["open"])
		return texts
	if (P["language"] != "")
		texts += "speaks [P["language"]]"
	var/list/skills = P["skills"]
	for (var/skill in skills)
		texts += "[recruitment_skill_labels[skill]] level [skills[skill]]/[RECRUITMENT_SKILL_LEVEL_MAX] or higher"
	return texts

// --- Rules ---------------------------------------------------------------

/mob/living/human/proc/recruitment_skill_level(skill)
	if (skill == "combat")
		var/best = 0
		for (var/S in recruitment_combat_skills)
			best = max(best, practice_level(S))
		return best
	return practice_level(skill)

/mob/living/human/proc/recruitment_speaks(language_name)
	for (var/datum/language/L in languages)
		if (L.name == language_name)
			return TRUE
	return FALSE

// Returns list("match" = TRUE/FALSE, "results" = list of "met"/"not met" lines).
/proc/recruitment_evaluate(mob/living/human/H, list/P)
	var/list/results = list()
	var/match = TRUE
	if (!P)
		return list("match" = FALSE, "results" = results)
	if (P["open"])
		results += "Open recruitment: met"
		return list("match" = TRUE, "results" = results)
	if (P["language"] != "")
		var/ok = H.recruitment_speaks(P["language"])
		results += "Speaks [P["language"]]: [ok ? "met" : "not met"]"
		match = match && ok
	var/list/skills = P["skills"]
	for (var/skill in skills)
		var/level = H.recruitment_skill_level(skill)
		var/ok = level >= skills[skill]
		results += "[recruitment_skill_labels[skill]] [level]/[RECRUITMENT_SKILL_LEVEL_MAX], needs [skills[skill]]: [ok ? "met" : "not met"]"
		match = match && ok
	// Manual mode with no rules: nothing to match, everyone is reviewed.
	if (!results.len)
		match = FALSE
	return list("match" = match, "results" = results)

// --- Identity ------------------------------------------------------------

/mob/living/human/proc/recruitment_account()
	if (!client || client.mob != src || IsGuestKey(client.key) || !client.ckey)
		return null
	if (persistence_owner_ckey && persistence_owner_ckey != client.ckey)
		return null
	return client.ckey

/mob/living/human/proc/recruitment_identity()
	if (!recruitment_life_id)
		var/list/S = map.recruitment_state()
		recruitment_life_id = "[world.realtime]-[S["seq"]]-[rand(100000, 999999)]"
	return recruitment_life_id

/proc/recruitment_identity_matches(mob/living/human/H, list/A)
	if (!H || !A || !H.recruitment_life_id || H.recruitment_life_id != A["life"])
		return FALSE
	return H.recruitment_account() == A["account"]

// Mandatory checks at submission and at enrollment. A faction rule can never
// bypass them. Returns null when they pass, otherwise a reason.
/obj/map_metadata/proc/recruitment_mandatory_block(mob/living/human/H, faction)
	if (!istype(H) || H.stat == DEAD)
		return "Only the living can join a faction."
	if (!H.recruitment_account())
		return "Only a signed-in player controlling their own character can apply."
	if (persistence_save_in_progress || persistence_active_operation || persistence_load_recovery_required)
		return "The world is being saved. Try again in a moment."
	if (!recruitment_supported(faction))
		return "[faction] is not recruiting here."
	if (H.civilization && H.civilization != "none" && H.civilization != faction)
		return "Leave [H.civilization] first."
	var/blocked = H.faction_enrollment_block(faction, FALSE)
	if (blocked)
		return replacetext(replacetext(blocked, "They are", "You are"), "They ", "You ")
	return null

// --- Applications --------------------------------------------------------

/obj/map_metadata/proc/recruitment_app(id)
	var/list/S = recruitment_state()
	var/list/apps = S["applications"]
	var/list/A = apps[id]
	return recruitment_valid_application(A) ? A : null

/proc/recruitment_active_status(status)
	return status == RECRUIT_PENDING || status == RECRUIT_APPROVED

/obj/map_metadata/proc/recruitment_set_status(list/A, status, reason = null)
	A["status"] = status
	A["changed"] = recruitment_now()
	A["seen"] = 0
	if (!isnull(reason))
		A["reason"] = reason

// Expire overdue records, end offers from disbanded factions and prune old
// terminal records. Bounded by the queue.
/obj/map_metadata/proc/recruitment_expire()
	var/list/S = recruitment_normalize()
	recruitment_invalidate_disbanded()
	var/list/apps = S["applications"]
	var/now = recruitment_now()
	for (var/id in apps.Copy())
		var/list/A = apps[id]
		if (recruitment_active_status(A["status"]))
			if (A["expires"] <= now)
				recruitment_set_status(A, RECRUIT_EXPIRED)
		else if (A["changed"] + RECRUITMENT_TERMINAL_KEEP <= now)
			apps -= id

// This character's active application to faction, if any.
/obj/map_metadata/proc/recruitment_active_for(mob/living/human/H, faction)
	var/list/S = recruitment_state()
	var/list/apps = S["applications"]
	for (var/id in apps)
		var/list/A = apps[id]
		if (A["faction"] == faction && recruitment_active_status(A["status"]) && recruitment_identity_matches(H, A))
			return A
	return null

/obj/map_metadata/proc/recruitment_queue(faction, statuses = null)
	var/list/result = list()
	var/list/S = recruitment_state()
	var/list/apps = S["applications"]
	for (var/id in apps)
		var/list/A = apps[id]
		if (A["faction"] == faction && (!statuses || (A["status"] in statuses)))
			result += list(A)
	return result

// Submit at a station. Returns list("result" = ..., "text" = ..., "id" = ...).
// result is one of: "joined", "pending", "existing", "refused".
/obj/map_metadata/proc/recruitment_submit(mob/living/human/H, faction, intro = "")
	recruitment_expire()
	var/blocked = recruitment_mandatory_block(H, faction)
	if (blocked)
		return list("result" = "refused", "text" = blocked)
	var/list/existing = recruitment_active_for(H, faction)
	if (existing)
		// A duplicate click returns the record it already made.
		return list("result" = "existing", "text" = "You already have an application to [faction].", "id" = existing["id"])
	var/list/P = recruitment_policy(faction)
	if (!P || P["mode"] == RECRUIT_MODE_CLOSED)
		return list("result" = "refused", "text" = "[faction] is not taking applications right now.")
	var/list/evaluation = recruitment_evaluate(H, P)
	var/match = evaluation["match"]
	if (!match && P["mode"] == RECRUIT_MODE_AUTO && P["nonmatch"] == RECRUIT_NONMATCH_REFUSE)
		return list("result" = "refused", "text" = "You do not meet [faction]'s requirements.")
	if (!match && P["mode"] == RECRUIT_MODE_MANUAL && P["nonmatch"] == RECRUIT_NONMATCH_REFUSE && length(evaluation["results"]))
		return list("result" = "refused", "text" = "You do not meet [faction]'s requirements.")
	if (match && P["mode"] == RECRUIT_MODE_AUTO)
		if (!H.enroll_in_faction(faction))
			return list("result" = "refused", "text" = "You can't join [faction] right now.")
		recruitment_after_enrollment(H, faction)
		recruitment_audit(faction, "[H.real_name] joined automatically at a recruitment station.", H.recruitment_account() || "")
		return list("result" = "joined", "text" = "You are now part of [faction].")
	var/list/S = recruitment_state()
	var/list/apps = S["applications"]
	var/active = 0
	var/last = 0
	for (var/id in apps)
		var/list/A = apps[id]
		if (A["faction"] == faction && A["status"] == RECRUIT_PENDING)
			active++
		if (A["account"] == H.recruitment_account() && A["submitted"] > last)
			last = A["submitted"]
	var/limit = config && isnum(config.recruitment_queue_limit) ? config.recruitment_queue_limit : 50
	if (active >= limit)
		return list("result" = "refused", "text" = "[faction]'s application queue is full. Try again later.")
	var/cooldown = (config && isnum(config.recruitment_cooldown_minutes) ? config.recruitment_cooldown_minutes : 5) * 600
	if (last && last + cooldown > recruitment_now())
		return list("result" = "refused", "text" = "You applied somewhere very recently. Wait a few minutes before applying again.")
	S["seq"] = S["seq"] + 1
	var/id = "app[S["seq"]]"
	var/now = recruitment_now()
	var/list/A = list("id" = id, "faction" = faction, "life" = H.recruitment_identity(), "account" = H.recruitment_account(), "name" = H.real_name, "status" = RECRUIT_PENDING, "intro" = recruitment_text(intro, RECRUITMENT_INTRO_MAX), "reason" = "", "reviewer" = "", "reviewer_account" = "", "submitted" = now, "changed" = now, "expires" = now + recruitment_expiry_time(), "revision" = P["revision"], "match" = match ? 1 : 0, "exception" = 0, "seen" = 1, "results" = evaluation["results"])
	apps[id] = A
	recruitment_notify_reviewers(faction, "<span class='notice'>[html_encode(H.real_name)] applied to join [html_encode(faction)]. Open the recruitment panel to review it.</span>")
	return list("result" = "pending", "text" = "Your application to [faction] was submitted. You can leave; check back at any [faction] recruitment station.", "id" = id)

// Approve, reject or revoke. reviewer must be able to recruit for the
// application's faction now. Returns null on success, otherwise a reason.
/obj/map_metadata/proc/recruitment_decide(mob/living/human/R, id, decision, reason = "")
	recruitment_expire()
	var/list/A = recruitment_app(id)
	if (!A)
		return "That application no longer exists."
	var/faction = A["faction"]
	if (!can_recruit_for_faction(R, faction))
		return "You can't review applications for [faction]."
	reason = recruitment_text(reason, RECRUITMENT_REASON_MAX)
	switch (decision)
		if ("approve")
			if (A["status"] != RECRUIT_PENDING)
				return "That application is no longer pending."
			var/list/P = recruitment_policy(faction)
			if (!P || P["mode"] == RECRUIT_MODE_CLOSED)
				return "Reopen recruitment before approving applications."
			if (!A["match"] && P["nonmatch"] == RECRUIT_NONMATCH_REFUSE && length(recruitment_rule_texts(P)))
				return "Your rules do not allow approving applicants who don't meet them."
			A["revision"] = P["revision"]
			A["exception"] = A["match"] ? 0 : 1
			A["expires"] = recruitment_now() + recruitment_expiry_time()
			recruitment_set_status(A, RECRUIT_APPROVED, reason)
		if ("reject")
			if (A["status"] != RECRUIT_PENDING)
				return "That application is no longer pending."
			recruitment_set_status(A, RECRUIT_REJECTED, reason)
		if ("revoke")
			if (A["status"] != RECRUIT_APPROVED)
				return "Only an approved offer can be revoked."
			recruitment_set_status(A, RECRUIT_REVOKED, reason)
		else
			return "Unknown decision."
	A["reviewer"] = R.real_name
	A["reviewer_account"] = R.persistence_owner_ckey || ""
	recruitment_audit(faction, "[R.real_name] [decision == "approve" ? "approved" : decision == "reject" ? "rejected" : "revoked"] [A["name"]]'s application.", A["reviewer_account"])
	recruitment_notify_applicant(A)
	return null

/obj/map_metadata/proc/recruitment_withdraw(mob/living/human/H, id)
	var/list/A = recruitment_app(id)
	if (!A || !recruitment_identity_matches(H, A))
		return "That is not your application."
	if (!recruitment_active_status(A["status"]))
		return "That application is already closed."
	recruitment_set_status(A, RECRUIT_WITHDRAWN)
	A["seen"] = 1
	recruitment_audit(A["faction"], "[A["name"]] withdrew their application.", A["account"])
	return null

// Join on an approved offer. Every condition is checked again now, and the
// membership change and the record change happen together.
/obj/map_metadata/proc/recruitment_confirm(mob/living/human/H, id)
	recruitment_expire()
	var/list/A = recruitment_app(id)
	if (!A || !recruitment_identity_matches(H, A))
		return "That offer is not yours."
	if (A["status"] != RECRUIT_APPROVED)
		return "That offer is no longer open."
	var/faction = A["faction"]
	var/blocked = recruitment_mandatory_block(H, faction)
	if (blocked)
		return blocked
	var/list/P = recruitment_policy(faction)
	if (!P || P["mode"] == RECRUIT_MODE_CLOSED)
		return "[faction] has paused recruitment. Your offer is kept until it expires."
	if (P["revision"] != A["revision"])
		// Changed rules need the offer reviewed again before it can be used.
		A["status"] = RECRUIT_PENDING
		A["changed"] = recruitment_now()
		A["revision"] = P["revision"]
		var/list/evaluation = recruitment_evaluate(H, P)
		A["match"] = evaluation["match"] ? 1 : 0
		return "[faction] changed its rules since your approval, so your application is back in review."
	if (!H.enroll_in_faction(faction))
		return "You can't join [faction] right now."
	recruitment_set_status(A, RECRUIT_ENROLLED)
	A["seen"] = 1
	recruitment_after_enrollment(H, faction)
	recruitment_audit(faction, "[H.real_name] joined on an approved offer.", A["account"])
	return null

// Joining any faction ends this character's other applications.
/obj/map_metadata/proc/recruitment_after_enrollment(mob/living/human/H, faction)
	var/list/S = recruitment_state()
	var/list/apps = S["applications"]
	for (var/id in apps)
		var/list/A = apps[id]
		if (recruitment_active_status(A["status"]) && A["life"] == H.recruitment_life_id)
			recruitment_set_status(A, A["faction"] == faction ? RECRUIT_ENROLLED : RECRUIT_INVALIDATED, A["faction"] == faction ? null : "You joined another faction.")
			A["seen"] = 1

// --- Lifecycle -----------------------------------------------------------

/obj/map_metadata/proc/recruitment_rename_faction(old_name, new_name)
	var/list/S = recruitment_state()
	faction_rename_assoc_key(S["policies"], old_name, new_name)
	faction_rename_assoc_key(S["audit"], old_name, new_name)
	var/list/apps = S["applications"]
	for (var/id in apps)
		var/list/A = apps[id]
		if (islist(A) && A["faction"] == old_name)
			A["faction"] = new_name

// A faction with nobody left alive is disbanded: its open offers end.
/obj/map_metadata/proc/recruitment_invalidate_disbanded()
	var/list/S = recruitment_state()
	var/list/apps = S["applications"]
	var/list/checked = list()
	for (var/id in apps)
		var/list/A = apps[id]
		if (!recruitment_active_status(A["status"]))
			continue
		var/faction = A["faction"]
		if (!(faction in checked))
			checked[faction] = faction_is_extant(faction)
		if (!checked[faction])
			recruitment_set_status(A, RECRUIT_INVALIDATED, "[faction] disbanded.")

// --- Notifications -------------------------------------------------------

/obj/map_metadata/proc/recruitment_notify_reviewers(faction, message)
	for (var/mob/living/human/H in human_mob_list)
		if (H.client && can_recruit_for_faction(H, faction))
			to_chat(H, message)

/obj/map_metadata/proc/recruitment_notify_applicant(list/A)
	for (var/mob/living/human/H in human_mob_list)
		if (H.client && recruitment_identity_matches(H, A))
			to_chat(H, recruitment_decision_text(A))
			A["seen"] = 1
			return

/proc/recruitment_decision_text(list/A)
	var/faction = html_encode(A["faction"])
	var/reason = A["reason"] != "" ? " Reason: [html_encode(A["reason"])]" : ""
	switch (A["status"])
		if (RECRUIT_APPROVED)
			return "<span class='notice'><b>[faction] approved your application.</b> Go to any [faction] recruitment station and confirm to join.[reason]</span>"
		if (RECRUIT_REJECTED)
			return "<span class='warning'>[faction] turned down your application.[reason]</span>"
		if (RECRUIT_REVOKED)
			return "<span class='warning'>[faction] withdrew its offer to you.[reason]</span>"
		if (RECRUIT_EXPIRED)
			return "<span class='warning'>Your application to [faction] expired.</span>"
		if (RECRUIT_INVALIDATED)
			return "<span class='warning'>Your application to [faction] is no longer valid.[reason]</span>"
	return null

// On login: unread decisions for the applicant, pending counts for reviewers.
/mob/living/human/proc/recruitment_login_notices()
	if (!map || !client || !islist(map.faction_recruitment) || !length(map.faction_recruitment))
		return
	map.recruitment_expire()
	var/list/S = map.recruitment_state()
	var/list/apps = S["applications"]
	var/pending = 0
	var/can_review = civilization && civilization != "none" && map.can_recruit_for_faction(src, civilization)
	for (var/id in apps)
		var/list/A = apps[id]
		if (!A["seen"] && recruitment_identity_matches(src, A))
			var/text = recruitment_decision_text(A)
			if (text)
				to_chat(src, text)
			A["seen"] = 1
		if (can_review && A["faction"] == civilization && A["status"] == RECRUIT_PENDING)
			pending++
	if (pending)
		to_chat(src, "<span class='notice'>[pending] application\s to [html_encode(civilization)] [pending == 1 ? "is" : "are"] waiting for review. Use Recruitment Applications in the Faction tab.</span>")

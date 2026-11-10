// Stubs for the recruitment code's world dependencies; the logic under test is
// the production code copied next to this file by run.py.
var/global/obj/map_metadata/map
var/global/datum/configuration/config
var/global/list/probe_failures = list()
var/global/list/human_mob_list = list()
var/global/list/living_mob_list = list()
var/global/list/all_languages = list("English" = 1, "Russian" = 1)
var/global/persistence_save_in_progress = FALSE
var/global/persistence_active_operation = null
var/global/persistence_load_recovery_required = FALSE

/proc/IsGuestKey(key)
	return FALSE
/proc/to_chat(target, message)
	return
/proc/sanitize(input, max_length = 1024, encode = TRUE)
	if (!input)
		return
	return copytext(input, 1, max_length)

/datum/configuration
	var/recruitment_expiry_days = 7
	var/recruitment_queue_limit = 3
	var/recruitment_cooldown_minutes = 0

/datum/language
	var/name = ""

/mob/living/human
	var/civilization = "none"
	var/leader = FALSE
	var/list/faction_perms = list(0,0,0,0)
	var/list/left_factions = list()
	var/title = ""
	var/real_name = ""
	var/research_role = null
	var/stat = 0
	var/persistence_owner_ckey = null
	var/probe_account = null
	var/list/languages = list()
	var/list/levels = list()

// No clients exist in this fixture: the account is the probe's.
/mob/living/human/recruitment_account()
	return probe_account
/mob/living/human/proc/practice_level(skill)
	return levels[skill] ? levels[skill] : 0
/mob/living/human/proc/remove_commander()
	return
/mob/living/human/proc/remove_title_changer()
	return
/mob/living/human/proc/remove_faction_symbol_editor()
	return

/obj/map_metadata
	var/list/custom_civs = list()
	var/list/custom_faction_nr = list()
	var/list/faction_research_director = list()
/obj/map_metadata/proc/allows_custom_factions()
	return TRUE

/proc/check(condition, label)
	if (!condition)
		probe_failures += label

var/global/probe_people = 0
/proc/person(name, faction, account)
	var/mob/living/human/H = new
	H.real_name = name
	H.name = name
	H.civilization = faction
	H.probe_account = account
	H.persistence_owner_ckey = account
	human_mob_list += H
	living_mob_list += H
	return H

/proc/speaks(mob/living/human/H, language)
	var/datum/language/L = new
	L.name = language
	H.languages += L

/proc/found(name, mob/living/human/leader)
	map.custom_faction_nr += name
	map.custom_civs[name] = list(0, 0, 0, leader, 0)
	leader.civilization = name
	leader.leader = TRUE
	leader.faction_perms = list(1,1,1,1)

/proc/result(list/R)
	return R["result"]

/world/New()
	..()
	try
		run_probe()
	catch(var/exception/E)
		probe_failures += "runtime: [E.name] line [E.line]"
	text2file(probe_failures.len ? "FAIL: [jointext(probe_failures, "; ")]\n" : "PASS\n", "result.txt")
	del(world)

/proc/run_probe()
	map = new
	config = new
	// Nobody here has a client: the whole faction is offline.
	var/mob/living/human/L = person("Lea", "none", "lea")
	found("Alpha", L)
	var/mob/living/human/R = person("Rex", "Alpha", "rex")
	R.faction_perms = list(0,0,0,1)
	var/mob/living/human/O = person("Oli", "none", "oli")
	found("Beta", O)

	// No policy: no station recruitment at all.
	var/mob/living/human/A = person("Ann", "none", "ann")
	check(result(map.recruitment_submit(A, "Alpha")) == "refused", "no policy refuses")

	// Only the leader sets rules; empty automatic acceptance is refused.
	check(map.recruitment_set_policy(R, "Alpha", list("mode" = RECRUIT_MODE_AUTO, "open" = 1)), "recruiter cannot change rules")
	check(map.recruitment_set_policy(L, "Alpha", list("mode" = RECRUIT_MODE_AUTO)), "automatic acceptance needs an explicit choice")
	check(isnull(map.recruitment_set_policy(L, "Alpha", list("mode" = RECRUIT_MODE_AUTO, "open" = 1))), "leader sets open automatic acceptance")
	check(map.recruitment_set_policy(L, "Alpha", list("skill" = list("magic", 3))), "unsupported skill refused")
	check(map.recruitment_set_policy(L, "Alpha", list("language" = "Klingon")), "unknown language refused")
	check(map.recruitment_set_policy(L, "Alpha", list("bogus" = 1)), "unknown setting refused")

	// Auto join with the whole faction offline.
	var/list/joined = map.recruitment_submit(A, "Alpha")
	check(result(joined) == "joined" && A.civilization == "Alpha" && !A.leader && A.faction_perms[4] == 0, "eligible applicant auto-joins with the faction offline")
	check(result(map.recruitment_submit(A, "Alpha")) == "refused", "member cannot apply again")

	// Rules: language + skill, non-matches refused.
	check(isnull(map.recruitment_set_policy(L, "Alpha", list("open" = 0, "language" = "Russian", "skill" = list("combat", 4), "nonmatch" = RECRUIT_NONMATCH_REFUSE))), "leader sets rules")
	var/mob/living/human/B = person("Ben", "none", "ben")
	check(result(map.recruitment_submit(B, "Alpha")) == "refused" && B.civilization == "none", "non-match refused under refuse rule")
	speaks(B, "Russian")
	B.levels["swords"] = 4
	check(result(map.recruitment_submit(B, "Alpha")) == "joined", "matching rules auto-join (combat is best weapon skill)")

	// Manual approval: pending, duplicate click, recruiter approves with leader offline.
	check(isnull(map.recruitment_set_policy(L, "Alpha", list("mode" = RECRUIT_MODE_MANUAL, "nonmatch" = RECRUIT_NONMATCH_REVIEW))), "manual mode")
	var/mob/living/human/C = person("Cat", "none", "cat")
	var/list/first = map.recruitment_submit(C, "Alpha", "<b>Hi</b> I farm")
	var/list/again = map.recruitment_submit(C, "Alpha")
	check(result(first) == "pending" && result(again) == "existing" && again["id"] == first["id"], "duplicate submission returns the same record")
	check(C.civilization == "none", "pending application does not change faction")
	var/id = first["id"]
	check(map.recruitment_decide(O, id, "approve"), "outsider cannot decide")
	check(isnull(map.recruitment_decide(R, id, "approve", "welcome")), "recruiter approves without the leader")
	check(map.recruitment_decide(L, id, "approve"), "second decision cannot repeat")
	check(C.civilization == "none", "approval does not enroll an offline character")
	var/list/record = map.recruitment_app(id)
	check(record["status"] == RECRUIT_APPROVED && record["seen"] == 0 && record["reviewer"] == "Rex", "approved offer recorded unseen")

	// Identity: another body on the same account cannot use the offer.
	var/mob/living/human/C2 = person("Cat Two", "none", "cat")
	check(map.recruitment_confirm(C2, id), "a different body cannot use the offer")
	check(isnull(map.recruitment_confirm(C, id)) && C.civilization == "Alpha" && !C.leader, "applicant confirms and joins as a plain member")
	check(map.recruitment_app(id)["status"] == RECRUIT_ENROLLED, "record enrolled")
	check(map.recruitment_confirm(C, id), "an enrolled offer cannot enroll twice")

	// Revoked recruiter cannot decide.
	var/mob/living/human/D = person("Dan", "none", "dan")
	var/did = map.recruitment_submit(D, "Alpha")["id"]
	R.faction_perms[4] = 0
	check(map.recruitment_decide(R, did, "reject"), "former recruiter cannot decide")
	R.faction_perms[4] = 1

	// Rule change sends an approved offer back to review.
	check(isnull(map.recruitment_decide(R, did, "approve")), "approve Dan")
	check(isnull(map.recruitment_set_policy(L, "Alpha", list("language" = "English"))), "rules change")
	check(map.recruitment_confirm(D, did) && map.recruitment_app(did)["status"] == RECRUIT_PENDING && D.civilization == "none", "changed rules require review again")

	// Closed pauses enrollment but keeps the offer.
	check(isnull(map.recruitment_decide(R, did, "approve")), "approve Dan again")
	check(isnull(map.recruitment_set_policy(L, "Alpha", list("mode" = RECRUIT_MODE_CLOSED))), "close")
	check(map.recruitment_confirm(D, did) && map.recruitment_app(did)["status"] == RECRUIT_APPROVED, "closed pauses but keeps the offer")
	var/mob/living/human/E = person("Eve", "none", "eve")
	check(result(map.recruitment_submit(E, "Alpha")) == "refused", "closed refuses new applications")
	check(isnull(map.recruitment_set_policy(L, "Alpha", list("mode" = RECRUIT_MODE_MANUAL))), "reopen")

	// The rejoin cooldown applies at the final commit.
	var/did2 = did
	map.recruitment_app(did2)["revision"] = map.recruitment_policy("Alpha")["revision"]
	D.left_factions += list(list("Alpha", world.realtime + 1000))
	check(map.recruitment_confirm(D, did2) && D.civilization == "none", "rejoin cooldown blocks a delayed approval")
	D.left_factions = list()

	// Death ends the life: the old offer no longer matches.
	D.recruitment_life_id = null
	check(map.recruitment_confirm(D, did2), "death/new life cannot reuse an offer")

	// Joining elsewhere invalidates other offers.
	var/mob/living/human/F = person("Fay", "none", "fay")
	var/fid = map.recruitment_submit(F, "Alpha")["id"]
	check(isnull(map.recruitment_decide(L, fid, "approve")), "approve Fay")
	check(isnull(map.recruitment_set_policy(O, "Beta", list("mode" = RECRUIT_MODE_AUTO, "open" = 1))), "Beta open")
	check(result(map.recruitment_submit(F, "Beta")) == "joined", "Fay joins Beta")
	check(map.recruitment_app(fid)["status"] == RECRUIT_INVALIDATED, "joining elsewhere invalidates the offer")
	check(result(map.recruitment_submit(F, "Alpha")) == "refused", "a member of another faction must leave first")

	// Rename carries policy and queue.
	var/mob/living/human/G = person("Gus", "none", "gus")
	var/gid = map.recruitment_submit(G, "Alpha")["id"]
	map.custom_faction_nr[map.custom_faction_nr.Find("Alpha")] = "Gamma"
	faction_rename_assoc_key(map.custom_civs, "Alpha", "Gamma")
	for (var/mob/living/human/H in human_mob_list)
		if (H.civilization == "Alpha")
			H.civilization = "Gamma"
	map.recruitment_rename_faction("Alpha", "Gamma")
	check(map.recruitment_policy("Gamma") && !map.recruitment_policy("Alpha"), "rename moves the policy")
	check(map.recruitment_app(gid)["faction"] == "Gamma" && isnull(map.recruitment_decide(R, gid, "approve")), "rename keeps the queue reviewable")

	// Expiry continues offline.
	map.recruitment_app(gid)["expires"] = world.realtime - 1
	map.recruitment_expire()
	check(map.recruitment_app(gid)["status"] == RECRUIT_EXPIRED && map.recruitment_confirm(G, gid), "expired offer cannot be used")

	// Disbanding: nobody left alive ends offers.
	var/mob/living/human/P = person("Pip", "none", "pip")
	var/pid = map.recruitment_submit(P, "Beta")["id"]
	check(!pid, "auto-open Beta enrolls instead of queueing")
	check(isnull(map.recruitment_set_policy(O, "Beta", list("mode" = RECRUIT_MODE_MANUAL))), "Beta manual")
	var/mob/living/human/Q = person("Quin", "none", "quin")
	var/qid = map.recruitment_submit(Q, "Beta")["id"]
	for (var/mob/living/human/H in human_mob_list)
		if (H.civilization == "Beta")
			H.stat = DEAD
			living_mob_list -= H
	map.recruitment_expire()
	check(map.recruitment_app(qid)["status"] == RECRUIT_INVALIDATED, "disbanding invalidates applications")

	// Queue limit (3 in this fixture) and malformed state.
	for (var/i = 1, i <= 4, i++)
		var/mob/living/human/W = person("W[i]", "none", "w[i]")
		var/list/res = map.recruitment_submit(W, "Gamma")
		if (i == 4)
			check(result(res) == "refused", "queue limit refuses")
	var/list/S = map.recruitment_state()
	S["applications"]["junk"] = list("id" = "junk")
	S["policies"]["Bad"] = list("mode" = "everyone")
	map.recruitment_normalize()
	check(!S["applications"]["junk"] && !S["policies"]["Bad"], "malformed records are dropped")
	map.faction_recruitment = list("schema" = 99)
	check(!length(map.recruitment_state()["policies"]), "unknown schema starts empty")
	check(!map.recruitment_policy("Gamma"), "no policy after reset means no station recruitment")

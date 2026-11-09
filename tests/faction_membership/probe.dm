// Stubs for the membership helpers' world dependencies; the logic under test
// is the production code copied next to this file by run.py.
#define DEAD 2
#define QDELETED(X) (!X)
var/global/obj/map_metadata/map
var/global/list/probe_failures = list()

/proc/to_chat(target, message)
	return

/mob/living/human
	var/civilization = "none"
	var/leader = FALSE
	var/list/faction_perms = list(0,0,0,0)
	var/list/left_factions = list()
	var/title = ""
	var/real_name = ""
	var/research_role = null
	var/stat = 0
	var/title_verbs = TRUE

/mob/living/human/proc/remove_commander()
	return
/mob/living/human/proc/remove_title_changer()
	title_verbs = FALSE
/mob/living/human/proc/remove_faction_symbol_editor()
	return

/obj/map_metadata
	var/list/custom_civs = list()
	var/list/faction_research_director = list()

/proc/check(condition, label)
	if (!condition)
		probe_failures += label

/proc/make_human(name, faction, list/perms)
	var/mob/living/human/H = new
	H.real_name = name
	H.name = name
	H.civilization = faction
	if (perms)
		H.faction_perms = perms.Copy()
	return H

/proc/plain(mob/living/human/H)
	return !H.leader && H.title == "" && !H.research_role && H.faction_perms[1] == 0 && H.faction_perms[2] == 0 && H.faction_perms[3] == 0 && H.faction_perms[4] == 0

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
	var/mob/living/human/L = make_human("Lea", "Alpha", list(1,1,1,1))
	L.leader = TRUE
	var/mob/living/human/R = make_human("Rex", "Alpha", list(0,0,0,1))
	// An old save: Recruitment used to set the leader flag too.
	var/mob/living/human/S = make_human("Sam", "Alpha", list(0,0,0,1))
	S.leader = TRUE
	var/mob/living/human/M = make_human("Mia", "Alpha", list(0,0,0,0))
	M.leader = TRUE
	var/mob/living/human/B = make_human("Bo", "Beta", list(1,1,1,1))
	B.leader = TRUE
	B.title = "Chief"
	B.name = "Chief Bo"
	B.research_role = "researcher"
	map.custom_civs["Alpha"] = list(0, 0, 0, L, 0)
	map.custom_civs["Beta"] = list(0, 0, 0, B, 0)
	map.faction_research_director["Beta"] = B

	// Who may recruit and who may manage permissions.
	check(map.can_recruit_for_faction(L, "Alpha"), "leader can recruit")
	check(map.can_recruit_for_faction(R, "Alpha"), "recruiter can recruit")
	check(map.can_recruit_for_faction(S, "Alpha"), "old-save recruiter can recruit")
	check(!map.can_recruit_for_faction(M, "Alpha"), "stale leader flag without Recruitment cannot recruit")
	check(!map.can_recruit_for_faction(B, "Alpha"), "outsider cannot recruit for another faction")
	check(!map.can_recruit_for_faction(R, "Beta"), "recruiter only recruits for their own faction")
	check(map.can_manage_faction_permissions(L, "Alpha"), "leader manages permissions")
	check(!map.can_manage_faction_permissions(R, "Alpha"), "recruiter cannot manage permissions")
	check(!map.can_manage_faction_permissions(S, "Alpha"), "old-save leader flag cannot manage permissions")
	// Permission Management covers Announcements and Titles, never Recruitment or itself.
	var/mob/living/human/P = make_human("Pat", "Alpha", list(1,0,0,0))
	check(map.can_manage_faction_permissions(P, "Alpha"), "permission manager opens the menu")
	check(map.can_manage_faction_permissions(P, "Alpha", 2) && map.can_manage_faction_permissions(P, "Alpha", 3), "permission manager manages announcements and titles")
	check(!map.can_manage_faction_permissions(P, "Alpha", 1), "permission manager cannot hand out Permission Management")
	check(!map.can_manage_faction_permissions(P, "Alpha", 4), "permission manager cannot appoint recruiters")
	check(!map.can_manage_faction_permissions(P, "Beta", 2), "permission manager only acts in their own faction")
	check(map.can_manage_faction_permissions(L, "Alpha", 4), "leader appoints recruiters")
	check(!map.can_manage_faction_permissions(S, "Alpha", 2), "old-save leader flag manages nothing")
	R.stat = DEAD
	check(!map.can_recruit_for_faction(R, "Alpha"), "dead recruiter cannot recruit")
	R.stat = 0

	// A nomad joins as an ordinary member.
	var/mob/living/human/N = make_human("Ned", "none", list(1,1,1,1))
	N.leader = TRUE
	check(isnull(N.faction_enrollment_block("Alpha")), "nomad may join")
	check(N.enroll_in_faction("Alpha"), "nomad enrolls")
	check(N.civilization == "Alpha" && plain(N), "new member carries no privileges")
	check(N.faction_enrollment_block("Alpha"), "member is already in the faction")
	check(!N.enroll_in_faction("Alpha"), "member cannot enroll twice")

	// Switching factions needs consent, records the cooldown and sheds every privilege.
	check(!B.enroll_in_faction("Alpha"), "member of another faction must leave first")
	check(B.civilization == "Beta" && B.leader, "refused enrollment changes nothing")
	check(B.enroll_in_faction("Alpha", TRUE), "consenting switch enrolls")
	check(B.civilization == "Alpha" && plain(B), "switched member carries no privileges")
	check(B.name == "Bo" && !B.title_verbs, "switched member lost title and title verbs")
	check(isnull(map.custom_civs["Beta"][4]), "old faction lost its leader record")
	check(isnull(map.faction_research_director["Beta"]), "old research appointment cleared")
	check(!map.can_recruit_for_faction(B, "Alpha"), "switched leader cannot recruit in new faction")

	// The 24-hour rejoin cooldown holds, and expires.
	check(B.faction_rejoin_blocked("Beta"), "leaving records the cooldown")
	check(!B.enroll_in_faction("Beta", TRUE), "cooldown blocks rejoining")
	check(B.civilization == "Alpha", "blocked rejoin keeps current faction")
	B.left_factions = list(list("Beta", world.realtime - 10))
	check(B.enroll_in_faction("Beta", TRUE), "expired cooldown allows rejoining")

	// The dead cannot enroll.
	var/mob/living/human/D = make_human("Dee", "none", null)
	D.stat = DEAD
	check(!D.enroll_in_faction("Alpha"), "dead character cannot enroll")
	check(D.civilization == "none", "dead character stays factionless")

/datum/live_group_gate_observer
	var/list/members = list()
	proc/check(datum/extraction_service/S)
		if (S.open("livegroupvisitor")) return FALSE
		for (var/datum/extraction_session/member in members)
			if (member.active()) return FALSE
		return TRUE

/proc/extraction_group_probe(obj/map_metadata/extraction_survival/M)
	world.log << "GROUP: start"
	var/list/bodies = list()
	var/list/guns = list()
	for (var/i in 1 to 5)
		var/mob/living/human/H = new(locate(3,3,1))
		H.m_intent = "stealth"
		M.test_owners[H] = "partyplayer[i]"
		equipment_assert(M.admit(H), "group member admitted to exclusive private house")
		var/obj/item/weapon/gun/G
		for (var/obj/item/weapon/gun/candidate in M.home_roots(H.extraction_session)) G = candidate
		equipment_assert(G, "group test uses actual issued starter gun")
		G.forceMove(H)
		bodies += H
		guns += G
	var/mob/living/human/A = bodies[1]
	var/mob/living/human/B = bodies[2]
	var/datum/extraction_party/P = M.create_party(A)
	equipment_assert(P && !M.create_party(A), "one group per owner")
	M.test_party_confirmation = "decline"
	equipment_assert(!M.invite_party(A, B) && P.members.len == 1, "declined invitation cannot enroll a player")
	M.test_party_confirmation = "stale"
	equipment_assert(!M.invite_party(A, B) && P.members.len == 1, "invitation invalidated during confirmation cannot enroll")
	M.test_party_confirmation = "accept"
	equipment_assert(M.invite_party(A, B) && M.ready_party(A) && M.ready_party(B), "two consenting members can ready their loadouts")
	equipment_assert(M.invite_party(A, bodies[3]) && !P.ready.len, "membership change invalidates earlier readiness")
	equipment_assert(M.invite_party(A, bodies[4]), "fourth member explicitly accepts invitation")
	equipment_assert(P.members.len == 4 && !M.invite_party(A, bodies[5]), "group capped at four")
	equipment_assert(!M.deploy_party(A) && !M.deploy_party(B), "missing readiness and nonleader deployment rejected")
	for (var/i in 1 to 4) equipment_assert(M.ready_party(bodies[i]), "each account readies its own exact loadout")
	equipment_assert(M.leave_party(B.extraction_session.owner) && !P.ready.len && M.invite_party(A, B), "withdrawal clears every ready vote and rejoin requires fresh consent")
	for (var/i in 1 to 4) equipment_assert(M.ready_party(bodies[i]), "every member readies after membership replacement")
	var/obj/item/weapon/gun/changed = guns[1]
	changed.health--
	equipment_assert(!M.deploy_party(A), "changed physical condition invalidates group readiness before any debit")
	for (var/i in 1 to 4) equipment_assert(bodies[i]:z == 2 && bodies[i]:extraction_session.profile["state"] == "home", "readiness rejection leaves all members home")
	equipment_assert(M.ready_party(A), "changed member can explicitly ready revised condition")
	M.accounts.group_journal.test_fail_at = "before_receipt"
	equipment_assert(!M.deploy_party(A), "pre-receipt failure cannot partially deploy group")
	for (var/i in 1 to 4) equipment_assert(bodies[i]:z == 2 && !bodies[i]:extraction_session.transitioning && bodies[i]:extraction_session.profile["state"] == "home", "pre-receipt failure releases all transition flags without account debit")
	M.accounts.group_journal.test_fail_at = null
	for (var/i in 1 to 4) equipment_assert(M.ready_party(bodies[i]), "all members renew readiness after failed request")
	var/datum/live_group_gate_observer/observer = new
	for (var/i in 1 to 4) observer.members += bodies[i]:extraction_session
	M.accounts.group_journal.test_access_observer = observer
	world.log << "GROUP: ready, starting observed commit"
	equipment_assert(M.deploy_party(A), "four-account durable group deployment succeeds")
	world.log << "GROUP: observed commit complete"
	M.accounts.group_journal.test_access_observer = null
	for (var/i in 1 to 4)
		var/mob/living/human/H = bodies[i]
		var/obj/item/weapon/gun/G = guns[i]
		equipment_assert(H.z == 1 && get_turf(H) == get_turf(A) && H.extraction_session.profile["state"] == "raid" && H.extraction_session.profile["stash"].len == 3 && G.loc == H, "all members enter same raid spawn with original atoms after all debits")
	equipment_assert(!P.alive && !M.deploy_party(A), "deployed party cannot replay")
	for (var/i in 1 to 4)
		var/mob/living/human/H = bodies[i]
		var/obj/effect/extraction_exit/exit
		for (var/obj/effect/extraction_exit/E in world)
			if (E.type == /obj/effect/extraction_exit) exit = E
		equipment_assert(exit, "ordinary extraction exists for each group member")
		H.forceMove(get_turf(exit))
		equipment_assert(M.extract_player(H, exit) && H.extraction_session.profile["stash"].len == 4, "group members independently extract exactly their carried gear")
		equipment_assert(M.release(H.extraction_session), "group account released after extraction")
		qdel(H)
	var/mob/living/human/last = bodies[5]
	var/datum/extraction_party/expired = M.create_party(last)
	expired.expires = world.time
	M.tick_parties()
	equipment_assert(!expired.alive && !M.party_by_owner[last.extraction_session.owner], "expired party releases membership and readiness")
	equipment_assert(M.release(last.extraction_session), "unused invite target released")
	qdel(last)
	world.log << "GROUP: complete"

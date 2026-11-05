// Home worlds for a region group (tools/transfer_storage/README.md, "Home
// worlds"). The group coordinator keeps one home region per account; a player
// may start or take back a character only in their home. Everyone starts on
// the mainland region, travel moves the home with the character, and a death
// sends it back to the mainland unless the player has an assigned bed in the
// land they died in: then the home stays and the next character starts at that
// bed. Off unless this world is in a region group
// with travel (shard_region.json plus transfer_agent.json).

#define REGION_HOME_WAIT 300 // deciseconds to wait for the coordinator's next pass

/mob/new_player/var/region_home_checking = FALSE // a Join is waiting on region_home_admit

/proc/region_home_enabled()
	return shard_group && shard_group.enabled && transfer_bridge && transfer_bridge.enabled()

// The agent's verdict for one account: list("verdict" = HOME, ELSEWHERE or
// PENDING, "home" = region id or null), or null when the agent cannot answer.
/proc/region_home_ask(account, op = "claim", region = null)
	var/list/body = list("ckey" = account, "op" = op)
	if(region) body["region"] = region
	// A claim for an account with a living character here asks the coordinator
	// to keep it here if it has no home (a lost ledger), never to start fresh.
	if(op == "claim" && region_home_living_body(account)) body["body"] = TRUE
	var/list/answer = transfer_bridge.request("/account", body)
	if(!answer || !answer["ok"] || !islist(answer["result"])) return null
	return answer["result"]

/proc/region_home_living_body(account)
	for(var/mob/living/human/H in human_mob_list)
		if(H.persistence_owner_ckey == account && H.stat != DEAD && !QDELETED(H))
			return H
	return null

// Records a trip, departure or death for the coordinator. Keeps trying, less
// often over time, until the agent has it (the agent keeps it from then on).
/proc/region_home_note(account, op, region = null)
	if(!region_home_enabled() || !istext(account) || !length(account)) return FALSE
	var/delay = 100
	for(var/attempt = 1, TRUE, attempt++)
		if(region_home_ask(account, op, region)) return TRUE
		if(attempt == 6)
			log_game("Region home: still cannot record [op] for [account]; retrying every few minutes.")
		sleep(delay)
		delay = min(delay * 2, 3000)

/proc/region_home_tell(mob/new_player/lobby, home)
	var/list/peer = home ? shard_group.peers[home] : null
	if(!peer)
		to_chat(lobby, SPAN_WARNING("Your character belongs to another land in this world group. Join that server to play."))
		return
	var/link = peer["address"] ? " <a href='byond://[peer["address"]]'>Go there</a>" : ""
	to_chat(lobby, SPAN_WARNING("Your character belongs to [html_encode(peer["name"])]. New and fallen characters start there, and reach other lands only by travelling.[link]"))

// TRUE when this lobby's account may play here. With wait, a first-time
// question waits up to REGION_HOME_WAIT for the coordinator; without it (the
// login reclaim paths, which must not stall), anything but HOME refuses now.
/proc/region_home_admit(mob/new_player/lobby, wait = TRUE)
	if(!region_home_enabled()) return TRUE
	if(!lobby || !lobby.client) return FALSE
	var/client/C = lobby.client
	// Guests own no durable character and cannot travel.
	if(IsGuestKey(C.key)) return TRUE
	var/deadline = world.time + REGION_HOME_WAIT
	var/told = FALSE
	while(TRUE)
		var/list/result = region_home_ask(C.ckey)
		if(!lobby || lobby.client != C) return FALSE
		if(!result)
			if(wait) to_chat(lobby, SPAN_WARNING("This land cannot reach its world directory right now, so no character can start here. Try again in a minute."))
			return FALSE
		switch(result["verdict"])
			if("HOME")
				return TRUE
			if("ELSEWHERE")
				region_home_tell(lobby, result["home"])
				return FALSE
		if(!wait) return FALSE
		if(world.time >= deadline)
			to_chat(lobby, SPAN_WARNING("The world directory has not answered yet. Try Join again in a moment."))
			return FALSE
		if(!told)
			to_chat(lobby, SPAN_NOTICE("Checking which land your character belongs to..."))
			told = TRUE
		sleep(20)

// The login and restore paths take a saved body back only in the account's
// home land. They must not wait; Join asks again (and waits) before
// allow_new_character reclaims.
/proc/region_home_reclaim_ok(mob/new_player/lobby)
	if(!region_home_enabled() || !lobby || !lobby.client) return TRUE
	var/account = lobby.client.ckey
	var/has_body = FALSE
	for(var/mob/living/human/H in human_mob_list)
		if(H.persistence_owner_ckey == account && !QDELETED(H))
			has_body = TRUE
			break
	return !has_body || region_home_admit(lobby, FALSE)

// The account's assigned bed in this land (Sleep in a bed assigns it), or null.
/proc/region_home_bed(account)
	if(!account) return null
	for(var/obj/structure/bed/B in world)
		if(B.persistence_bed_owner_ckey == account && !QDELETED(B) && B.anchored && isturf(B.loc))
			return B
	return null

// A new character of an account with a bed here starts at that bed.
/proc/region_home_bed_spawn(mob/living/human/H)
	if(!istype(H) || !H.client || IsGuestKey(H.client.key) || !region_home_enabled()) return FALSE
	var/obj/structure/bed/B = region_home_bed(H.client.ckey)
	if(!B || !B.valid_character_bed(H)) return FALSE
	H.forceMove(get_turf(B))
	to_chat(H, SPAN_NOTICE("You start out beside your bed."))
	return TRUE

// A death sends the home back to the mainland, unless the account still has a
// living character here or a bed here (the coordinator ignores a release from
// elsewhere).
/proc/region_home_death(mob/living/human/H)
	var/account = H && H.persistence_owner_ckey
	if(!account || !region_home_enabled()) return
	if(region_home_bed(account)) return
	for(var/mob/living/human/other in human_mob_list)
		if(other != H && other.persistence_owner_ckey == account && other.stat != DEAD && !QDELETED(other))
			return
	spawn(0)
		region_home_note(account, "release")

#undef REGION_HOME_WAIT

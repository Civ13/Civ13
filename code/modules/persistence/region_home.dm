// Home worlds for a region group (tools/transfer_storage/README.md, "Home
// worlds"). The group coordinator keeps one home region per account; a player
// may start or take back a character only in their home. Everyone starts in
// the start region (the mainland unless the host names another), travel moves
// the home with the character, and a death sends it back to the start region
// unless the player has an assigned bed in the
// land they died in: then the home stays and the next character starts at that
// bed. Off unless this world is in a region group
// with travel (shard_region.json plus transfer_agent.json).

#define REGION_HOME_WAIT 300 // deciseconds to wait for the coordinator's next pass

/mob/new_player/var/region_home_checking = FALSE // a Join is waiting on region_home_admit

/proc/region_home_enabled()
	// The TDM Barracks and battle world share a transfer agent only for OOC:
	// everyone plays in both, so no account has a home there.
	// An event region (region_event.dm) keeps no homes either: characters wait in their own land.
	// Nobody lives in the tutorial region: it only runs practice rooms.
	if(shard_group && (shard_group.kind in list("BARRACKS", "BATTLE", "EVENT", "TUTORIAL"))) return FALSE
	return shard_group && shard_group.enabled && transfer_bridge && transfer_bridge.enabled()

// The agent's verdict for one account: list("verdict" = HOME, ELSEWHERE or
// PENDING, "home" = region id or null), or null when the agent cannot answer.
/proc/region_home_ask(account, op = "claim", region = null, faction = null)
	var/list/body = list("ckey" = account, "op" = op)
	if(region) body["region"] = region
	if(faction) body["faction"] = faction
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

// Accounts that lately asked for their parked land: ckey = world.time.
var/global/list/region_home_summoned = list()

// "x,y" when home names a parked land across the sea ("land:x,y": its world
// was laid up while nobody was there, expedition-slots.md), else null.
/proc/region_home_parked_land(home)
	if(!istext(home) || findtext(home, "land:") != 1) return null
	var/list/xy = splittext(copytext(home, 6), ",")
	if(length(xy) != 2 || !isnum(text2num(xy[1])) || !isnum(text2num(xy[2]))) return null
	return "[text2num(xy[1])],[text2num(xy[2])]"

// Asks the world directory to make the account's parked land ready again, at
// most once a minute. TRUE when the request was taken (now or just before).
/proc/region_home_summon(account, home)
	var/key = region_home_parked_land(home)
	if(!key || !istext(account)) return FALSE
	if(region_home_summoned[account] && world.time < region_home_summoned[account] + 600) return TRUE
	var/list/xy = splittext(key, ",")
	var/list/answer = transfer_bridge.request("/chart/request", list("op" = "summon", "x" = text2num(xy[1]), "y" = text2num(xy[2]), "admin" = account))
	if(!answer || !answer["ok"]) return FALSE
	region_home_summoned[account] = world.time
	log_game("Region home: [account] asked for the parked land at [key] to be made ready.")
	return TRUE

/proc/region_home_tell(mob/new_player/lobby, home)
	var/list/peer = home ? shard_group.peers[home] : null
	if(region_home_parked_land(home))
		if(lobby.client && region_home_summon(lobby.client.owner_key(), home))
			to_chat(lobby, SPAN_NOTICE("Your character is on a land across the sea whose harbour was laid up while nobody was there. It is being made ready now, which takes a few minutes. Press Join again then and you are shown the way."))
		else
			to_chat(lobby, SPAN_WARNING("Your character is on a land across the sea that is laid up, and no word can be sent to make it ready right now. Try Join again in a minute."))
		return
	if(peer && peer["kind"] == "EXPEDITION" && peer["state"] != "UP" && !shard_group.peer_wakeable(home))
		to_chat(lobby, SPAN_NOTICE("Your character is on a land across the sea that is being made ready. Press Join again in a few minutes."))
		return
	if(!peer)
		to_chat(lobby, SPAN_WARNING("Your character belongs to another land in this world group. Join that server to play."))
		return
	var/link = peer["address"] ? " <a href='[shard_group.player_href(home)]'>Go there</a>" : ""
	// Only the start region is where new and fallen characters start; any other
	// home is a land the character travelled to (or chose to start in).
	if(home == shard_group.start_region)
		to_chat(lobby, SPAN_WARNING("Your character belongs to [html_encode(peer["name"])]. New and fallen characters start there, and reach other lands only by travelling.[link]"))
	else
		to_chat(lobby, SPAN_WARNING("Your character is in [html_encode(peer["name"])] now. Join that land to play them.[link]"))

// TRUE when this lobby's account may play here. With wait, a first-time
// question waits up to REGION_HOME_WAIT for the coordinator; without it (the
// login reclaim paths, which must not stall), anything but HOME refuses now.
// Told once that travel into this land is paused (region_home_admit).
/mob/new_player/var/tmp/transfer_hold_warned = FALSE

/proc/region_home_admit(mob/new_player/lobby, wait = TRUE)
	// Nobody plays in the gateway, not even a guest: it sends them on instead.
	if(region_gateway_here())
		if(lobby && lobby.client)
			if(wait) to_chat(lobby, SPAN_NOTICE("Nobody plays here: this is the way in. You are being sent on to your land."))
			region_gateway_forward(lobby)
		return FALSE
	if(!region_home_enabled()) return TRUE
	if(!lobby || !lobby.client) return FALSE
	var/client/C = lobby.client
	if(train_escrow_account_held(C.owner_key()))
		to_chat(lobby, SPAN_WARNING("Your train is still on its way. Wait for it to arrive before joining."))
		return FALSE
	// Guests own no durable character and cannot travel.
	if(IsGuestKey(C.key)) return TRUE
	var/deadline = world.time + REGION_HOME_WAIT
	var/told = FALSE
	while(TRUE)
		var/list/result = region_home_ask(C.owner_key())
		if(!lobby || lobby.client != C) return FALSE
		if(!result)
			if(wait) to_chat(lobby, SPAN_WARNING("This land cannot reach its world directory right now, so no character can start here. Try again in a minute."))
			return FALSE
		switch(result["verdict"])
			if("HOME")
				// A colony start granted here (colony_charter.dm, faction_start.dm).
				var/grant = colony_parent_valid(result["colony_grant"]) ? result["colony_grant"] : null
				// A home here with nothing left to play (the world was reset, or the
				// character was lost before any death was recorded) goes back to the
				// start region, so the next character starts there like everyone else.
				if(wait && !grant && region_home_stranded(C.owner_key()) && region_home_ask(C.owner_key(), "release"))
					log_game("Region home: [C.owner_key()] has no character or bed in [shard_group.region]; their home goes back to [shard_group.start_region].")
					if(!told)
						to_chat(lobby, SPAN_NOTICE("You have no character or bed here any more, so your next character starts in the start land..."))
						told = TRUE
					sleep(20)
					continue
				// While the agent here is on hold nobody can arrive: a character sent
				// here waits in the land it left. Joining now would start a second
				// character in its place, so the player is told first and Join must
				// be pressed again to go ahead.
				if(wait && transfer_bridge.held() && !lobby.transfer_hold_warned && !region_home_living_body(C.owner_key()))
					lobby.transfer_hold_warned = TRUE
					to_chat(lobby, SPAN_DANGER("Travel into this land is paused. If your character was travelling here, it is safe in the land it left and will arrive once an admin reopens the way: do not start a new character, ask an admin instead. If you are new here, press Join again to start."))
					message_admins("[C.owner_key()] has no character in [shard_group.name] while travel into it is paused ([transfer_bridge.hold_reason]). If they were travelling here, their character is waiting in the land it left.")
					return FALSE
				lobby.colony_start_grant = grant
				return TRUE
			if("ELSEWHERE")
				region_home_tell(lobby, result["home"])
				return FALSE
			if("TRAVELLING")
				// Their character is in another land's escrow or about to be built
				// here; a new character now would take its place.
				if(wait)
					var/list/from = istext(result["from"]) ? shard_group.peers[result["from"]] : null
					to_chat(lobby, SPAN_NOTICE("Your character is still on its way here[from ? " from [html_encode(from["name"])]" : ""]. It is safe, and you take it over as soon as it arrives: press Join again in a moment.[transfer_bridge.held() ? " Travel into this land is paused right now, so ask an admin to reopen the way." : ""]"))
				return FALSE
		if(!wait) return FALSE
		if(world.time >= deadline)
			to_chat(lobby, SPAN_WARNING("The world directory has not answered yet. Try Join again in a moment."))
			return FALSE
		if(!told)
			to_chat(lobby, SPAN_NOTICE("Checking which land your character belongs to..."))
			told = TRUE
		sleep(20)

// TRUE when the account's home is this land but nothing of theirs is here: no
// living character and no bed. This land is not where new characters start (the
// start region, or an OPEN land whose wilds they may choose), so a new character
// belongs in the start region. A character still on its way here sends "arrive"
// once it is built, which takes the home back.
/proc/region_home_stranded(account)
	var/start = shard_group.start_region
	if(!istext(account) || !start || start == shard_group.region) return FALSE
	// Lands across the sea and raid worlds keep their own home rules.
	if(shard_group.kind in list("EXPEDITION", "RAID")) return FALSE
	// Until the stage list is read, this land might be open to wild starts.
	if(!land_stages_checked || land_stage(shard_group.region) == "OPEN") return FALSE
	return !region_home_living_body(account) && !region_home_bed(account)

// The login and restore paths take a saved body back only in the account's
// home land. They must not wait; Join asks again (and waits) before
// allow_new_character reclaims.
/proc/region_home_reclaim_ok(mob/new_player/lobby)
	if(!region_home_enabled() || !lobby || !lobby.client) return TRUE
	var/account = lobby.client.owner_key()
	var/has_body = FALSE
	for(var/mob/living/human/H in human_mob_list)
		if(H.persistence_owner_ckey == account && !QDELETED(H))
			has_body = TRUE
			break
	return !has_body || region_home_admit(lobby, FALSE)

/map_storage/reclaim_allowed(mob/new_player/lobby)
	return region_home_reclaim_ok(lobby)

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
	var/obj/structure/bed/B = region_home_bed(H.client.owner_key())
	if(!B || !B.valid_character_bed(H)) return FALSE
	H.forceMove(get_turf(B))
	to_chat(H, SPAN_NOTICE("You start out beside your bed."))
	return TRUE

// A death sends the home back to the start region, unless the account still has a
// living character here or a bed here (the coordinator ignores a release from
// elsewhere).
/proc/region_home_death(mob/living/human/H)
	var/account = H && H.persistence_owner_ckey
	if(!account || !region_home_enabled()) return
	// A raider who dies in a raid world goes home, not to the start region.
	var/origin = region_raid_death_origin(H)
	if(!origin)
		// On a land across the sea nobody has settled yet, a bed does not keep the home (land_choices.dm).
		if(region_home_bed(account) && !expedition_land_unsettled()) return
		for(var/mob/living/human/other in human_mob_list)
			if(other != H && other.persistence_owner_ckey == account && other.stat != DEAD && !QDELETED(other))
				return
	spawn(0)
		region_home_note(account, origin ? "depart" : "release", origin)

#undef REGION_HOME_WAIT

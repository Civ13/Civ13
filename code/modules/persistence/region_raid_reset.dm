// Resetting raid worlds (docs/persistence-raids.md). A RAID region with
// reset_minutes (scripts/shard-group) never saves. Each boot is a new map; at
// the end of each cycle everyone still inside is lost with what they carry,
// their home goes back to the land they came from, the agent's journal is
// confirmed so nobody comes back on the next map, and the world reboots.
// A crash before the reset is different: the next boot replays the journal,
// so raiders who were inside are rebuilt on the new map with their gear.

#define RAID_RESET_NOTE_TRIES 5

var/global/datum/region_raid_reset/region_raid_reset = new

/proc/region_raid_resets()
	return region_raid_world() && shard_group.reset_minutes > 0

/datum/region_raid_reset
	var/deadline = 0          // world.time of the reset; 0 = not running
	var/list/warned = list()  // minutes already announced
	var/resetting = FALSE
	var/reboot = TRUE         // a probe turns this off
	var/lost_last = 0         // raiders lost in the last reset

/datum/region_raid_reset/proc/start(minutes)
	if(deadline || minutes <= 0) return FALSE
	deadline = world.time + minutes MINUTES
	warned = list()
	addtimer(CALLBACK(src, PROC_REF(tick)), 10 SECONDS, TIMER_LOOP)
	log_game("Raid reset: this raid world resets in [minutes] minutes.")
	return TRUE

/datum/region_raid_reset/proc/minutes_left()
	return deadline ? max(0, round((deadline - world.time) / (1 MINUTES), 1)) : null

/datum/region_raid_reset/proc/tick()
	if(!deadline || resetting) return
	var/left = deadline - world.time
	for(var/minutes in list(15, 5, 1))
		if(left <= minutes MINUTES && !(minutes in warned))
			warned += minutes
			to_chat(world, SPAN_DANGER("This zone collapses in [minutes] minute\s. Reach an open extraction point or lose everything you carry."))
	if(left <= 0)
		collapse()

// Everyone still inside is lost: body and gear go, home goes back to where
// they came from. Then the journal is settled and the world reboots.
/datum/region_raid_reset/proc/collapse()
	if(resetting) return
	resetting = TRUE
	to_chat(world, SPAN_DANGER("The zone collapses. Anyone still inside is lost."))
	var/list/notes = list()
	for(var/mob/living/human/H in human_mob_list.Copy())
		if(QDELETED(H) || H.stat == DEAD || !H.persistence_owner_ckey) continue
		var/account = H.persistence_owner_ckey
		var/origin = istext(H.raid_origin) && (H.raid_origin in shard_group.peers) ? H.raid_origin : null
		if(origin) notes[account] = origin
		log_game("Raid reset: [account]'s character [H.real_name] was inside at the collapse and is lost[origin ? "; home goes back to [origin]" : ""].")
		var/client/C = H.client
		if(C)
			var/mob/new_player/lobby = new
			lobby.key = C.key
			var/list/peer = origin ? shard_group.peers[origin] : null
			to_chat(C, SPAN_DANGER("You were caught in the collapse and lost everything you carried."))
			if(peer && peer["address"])
				to_chat(C, SPAN_NOTICE("Your next character starts at home in [peer["name"]]."))
				C << link("byond://[peer["address"]]")
		for(var/obj/item/I in H.GetAllContents())
			if(!QDELETED(I)) qdel(I)
		qdel(H)
		lost_last++
	// Tell the coordinator before the reboot; region_home_note retries forever,
	// so give each a bounded number of tries here.
	if(region_home_enabled())
		for(var/account in notes)
			for(var/attempt in 1 to RAID_RESET_NOTE_TRIES)
				if(region_home_ask(account, "depart", notes[account])) break
				sleep(20)
	settle_journal()
	if(reboot)
		log_game("Raid reset: rebooting on a new map.")
		world.Reboot("raid reset")

// Confirms every applied effect with the agent, so the next boot (a new map)
// replays none of this cycle's trips.
/datum/region_raid_reset/proc/settle_journal()
	if(!transfer_bridge.enabled() || isnull(transfer_bridge.ledger_base)) return FALSE
	for(var/attempt in 1 to RAID_RESET_NOTE_TRIES)
		var/list/answer = transfer_bridge.request("/save", list("generation" = "raid-reset-[world.realtime]-[attempt]", "effects" = transfer_bridge.applied.Copy(), "ledger_seq" = transfer_bridge.ledger_base))
		if(answer && answer["ok"])
			transfer_bridge.applied = list()
			return TRUE
		sleep(20)
	message_admins("Raid reset: the transfer agent did not confirm this cycle's trips; the next map may replay them.")
	return FALSE

/hook/roundstart/proc/region_raid_reset_start()
	if(region_raid_resets())
		region_raid_reset.start(shard_group.reset_minutes)
	return TRUE

/mob/living/human/Stat()
	. = ..()
	if(region_raid_reset.deadline && statpanel("Status"))
		stat("Zone collapse in:", "[region_raid_reset.minutes_left()] min")

#undef RAID_RESET_NOTE_TRIES

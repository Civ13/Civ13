/obj/map_metadata/extraction_survival
	var/next_map_id
	var/datum/vote_handle/hub_vote
	proc/hub_map_catalog()
		// IDs match actual DMM basenames accepted by the existing launcher.
		return list(MAP_EXTRACTION_SURVIVAL = 0, MAP_EXTRACTION_CITY = 0, MAP_EXTRACTION_MALL = 0, MAP_ALLEYWAY = 0, MAP_BANK_ROBBERY = 0)
	proc/start_map_vote(mob/living/human/H)
		if (!owned(H) || H.z != 3 || H.stat != CONSCIOUS || player_roots(H).len) return FALSE
		hub_vote = vote.request_vote("safehouse map", H.extraction_session.owner, FALSE, list(src, "accept_map_vote"))
		return !!hub_vote
	proc/accept_map_vote(selection)
		var/list/catalog = hub_map_catalog()
		if (round_closing || !istext(selection) || !(selection in catalog)) return FALSE
		next_map_id = selection
		world << "Next round selected: [map_id_to_title[selection] ? map_id_to_title[selection] : selection]. Private stash settlement finishes before the map changes."
		return TRUE

/process/mapswap/proc/execute_map_swap(winner)
	return processes.python.execute("mapswap.py", list(winner))

/process/mapswap/proc/selected_extraction_map()
	var/obj/map_metadata/extraction_survival/M = map
	if (!istype(M) || !M.game_over || !M.next_map_id) return null
	var/list/catalog = M.hub_map_catalog()
	if (!(M.next_map_id in catalog)) return null
	return M.next_map_id

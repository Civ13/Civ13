// Expedition slots: an EXPEDITION region holds one generated land at a time
// (scripts/shard-group/expedition_slots.py, docs/expedition-slots.md). The host
// compiles the land's map as the slot's map and writes what the world should
// know about it to config/expedition_land.json. A free slot runs its
// placeholder map (maps/expedition/slot.dmm), open sea over bedrock.

#define EXPEDITION_LAND_FILE "config/expedition_land.json"
// The land's hill levels; its river currents and flood reaches lie beside it
// (.flow.txt, .flood.txt). The host copies all three from the land's folder.
#define EXPEDITION_HEIGHT_FILE "config/expedition_heights.txt"

var/global/list/expedition_land_info = null

/obj/map_metadata/nomads/expedition
	title = "A New Land"
	description = "A land across the sea, reached only by ship."
	battle_name = "new land"
	mission_start_message = "<big>A land across the sea. Whoever came here came by ship.</big>"

/obj/map_metadata/nomads/expedition/New()
	..()
	var/list/info = expedition_land()
	if(info)
		title = "A New Land ([expedition_land_text(info)])"
	// A free slot and a land made without them stay flat.
	if(fexists(EXPEDITION_HEIGHT_FILE))
		terrain_height_file = EXPEDITION_HEIGHT_FILE

// The land this slot holds, as the host described it, or null for a free slot.
/proc/expedition_land()
	if(!isnull(expedition_land_info))
		return length(expedition_land_info) ? expedition_land_info : null
	expedition_land_info = list()
	if(!fexists(EXPEDITION_LAND_FILE))
		return null
	var/list/info = null
	try
		info = json_decode(file2text(EXPEDITION_LAND_FILE))
	catch
		info = null
	if(!islist(info) || !istext(info["biome"]) || !istext(info["land_type"]) || !istext(info["size"]))
		log_game("Expedition land: [EXPEDITION_LAND_FILE] is not a land description.")
		return null
	expedition_land_info = info
	return info

// "small temperate forest coastal plain"
/proc/expedition_land_text(list/info)
	if(!islist(info))
		return "unknown land"
	return lowertext(replacetext("[info["size"]] [info["biome"]] [info["land_type"]]", "_", " "))

#undef EXPEDITION_LAND_FILE
#undef EXPEDITION_HEIGHT_FILE

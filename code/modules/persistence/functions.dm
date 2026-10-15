//from https://github.com/Persistent-SS13/Persistent-SS13/blob/master/code/modules/world_save/Map%20Storage.dm
//7-september-2021

//////////////////////////////////
///PERSISTENCE STUFF/////////////
/////////////////////////////////

//needs to be defined for some atoms
/datum/proc/after_load()
	return
/datum/proc/before_save()
	return

// Custom persistence iterates vars, including tmp. Runtime fields require explicit exclusion.
/datum/proc/persistence_runtime_var(key)
	return key == "persistence_export_frame"

/datum/proc/get_saved_vars()
	var/list/to_save = list()
	var/partial = FALSE

	if (!istype(src, /mob) && ((istype(src, /turf) || istype(src, /obj/structure/wild) || (!istype(src, /obj/item) && !istype(src, /obj/structure) && !istype(src, /obj/map_metadata) && !istype(src, /obj/covers)))))
		partial = TRUE
	if (istype(src, /datum) && !istype(src, /mob) && !istype(src, /obj) && !istype(src, /turf))
		partial = FALSE
	if (partial)
		to_save |= params2list(map_storage_saved_vars)
	else
		for (var/key in src.vars)
			if (persistence_runtime_var(key))
				continue
			if (src.vars[key] != initial(src.vars[key]) && key != "verbs" && key != "locs" && key != "group")
				to_save |= key
			to_save |= "name"
	return to_save

// The composite appearance is not a supported saved datum. Restoring its null
// envelope resets independently restored fields such as transform and color.
/atom/persistence_runtime_var(key)
	return (key in list("appearance", "light", "light_sources")) || ..()

// Lighting graphs belong to the current map/owners and are rebuilt after import.
// The custom serializer enumerates tmp fields as well as durable fields.
/datum/light_source
	should_save = FALSE

/datum/lighting_corner
	should_save = FALSE

/atom/movable/lighting_overlay
	should_save = FALSE

/turf/persistence_runtime_var(key)
	return (key in list("affecting_lights", "lighting_overlay", "corners", "has_opaque_atom", "window_coeff_dirty", "next_calculate_window_coeff")) || ..()

// HUD objects belong to a client session and are rebuilt by the normal HUD path.
// The custom saver visits tmp vars too; exclude these on both export and import.
/mob/persistence_runtime_var(key)
	return (key in list("hud_used", "HUDneed", "HUDinventory", "HUDfrippery", "HUDprocess", "HUDtech", "hands", "pullin", "purged", "i_select", "m_select", "zone_sel")) || ..()

/obj/screen
	should_save = FALSE

/datum/hud
	should_save = FALSE

// Dirt uses the turf allowlist rather than the object changed-vars encoder.
// Preserve finite fertility across exports without serializing recovery tokens.
/turf/floor/dirt/get_saved_vars()
	. = ..()
	. |= "soil_nutrition"

var/map_storage/map_storage = new("SS13")

/proc/string_explode(var/string, var/separator = "")
	//writepanic("[__FILE__].[__LINE__] \\/proc/string_explode() called tick#: [world.time]")
	if(istext(string) && (istext(separator) || isnull(separator)))
		return splittext(string, separator)
        
/proc/start_watch()
	return TimeOfGame

/proc/stop_watch(wh)
	return round(0.1 * (TimeOfGame - wh), 0.1)

/proc/log_startup_progress(var/message)
	to_chat(world, "<span class='danger'>[message]</span>")

//Key thing that stops lag. Cornerstone of performance in ss13, Just sitting here, in unsorted.dm.
/proc/stoplag()
	. = 1
	sleep(world.tick_lag)
	if(world.tick_usage > TICK_LIMIT_TO_RUN) //woke up, still not enough tick, sleep for more.
		. += 2
		sleep(world.tick_lag*2)
		if(world.tick_usage > TICK_LIMIT_TO_RUN) //woke up, STILL not enough tick, sleep for more.
			. += 4
			sleep(world.tick_lag*4)
			//you might be thinking of adding more steps to this, or making it use a loop and a counter var
			//	not worth it.

/*************************************************************************
ATOM ADDITIONS
**************************************************************************/
datum
	var
		load_contents = 0
		should_save = 1
		map_storage_saved_vars = ""
		safe_list_vars = ""
atom
	map_storage_saved_vars = "density;icon_state;dir;name;pixel_x;pixel_y;id"
	load_contents = 1
/*************************************************************************
MAP STORAGE DATUM
**************************************************************************/
map_storage

	var
		// These are atom types for the map saver to ignore. Objects of these type will
		// not be saved with everything else.
		list/ignore_types = list(/mob/new_player, /atom/movable/lighting_overlay)

		// This text string is tacked onto all saved passwords so that their md5 values
		// will be different than what the password's hash would normally be, providing
		// a bit of extra protection against md5 hash directories.
		game_id = "SS13"

		// INTERNAL VARIABLES - SHOULD NOT BE ALTERED BY USERS

		// List of object types. This will be converted to params and encrypted when saved.
		list/object_reference = list()
		list/obj_references = list()
		list/existing_references = list()
		list/saving_references = list()
		list/saving_export_frames = list()
		list/saving_export_stack = list()
		list/all_loaded = list()
		list/found_types = list()
		list/saved_turfs = list()
		list/saving_lists = list()
		list/saving_reference_pins = list()
		list/saving_list_pins = list()
		list/loaded_lists = list()
		var/saving_z = 0
		var/last_error = null
		var/round_restored = FALSE
		var/per_pause = 200
		var/so_far = 0
	New(game_id, backdoor, ignore)
		..()
		if(game_id)
			src.game_id = game_id
		if(ignore)
			src.ignore_types = ignore
		return

// Drops the save/load bookkeeping references so qdel'd atoms can be garbage
// collected - these lists otherwise pin every atom they touched until the next
// save/load runs. Called after a save or load finishes, successfully or not.
/map_storage/proc/clear_bookkeeping()
	for(var/datum/save_export_frame/frame in saving_export_stack.Copy())
		release_export_frame(frame)
	saving_export_frames = list()
	saving_export_stack = list()
	saving_references = list()
	existing_references = list()
	found_types = list()
	all_loaded = list()
	saving_lists = list()
	saving_reference_pins = list()
	saving_list_pins = list()
	loaded_lists = list()
	saved_turfs = list()

// Returns true if the value is purely numeric, return false if there are non-numeric
// characters contained within the text string.
/map_storage/proc/IsNumeric(text)
	if(isnum(text))
		return 1
	for(var/n in 1 to length(text))
		var/ascii = text2ascii(text, n)
		if(ascii < 45 || ascii > 57)
			return 0
		if(ascii == 47)
			return 0
	return 1

// If the value is numeric, convert it to a number and return the number value. If
// the value is text, then return it as it is.
/map_storage/proc/Numeric(text)
	if(islist(text))
		return text
	if(IsNumeric(text))
		return text2num(text)
	else
		if(findtext(text, "e+"))
			var/list/nums = string_explode(text, "e+")
			if(nums.len > 1 && nums.len < 3)
				var/integer = text2num(nums[1])
				var/exp = text2num(nums[2])
				if(IsNumeric(integer) && IsNumeric(exp))
					return integer*10**exp
		return text

	// This is called when loading a map after all the verification and
	// password stuff is completed so that the map can have a fresh template
	// to work with.
/map_storage/proc/ClearMap()
	sleep(1)
	world.log << "Clearing mobs..."
	for (var/mob/mob in world)
		if (!istype(mob, /mob/new_player))
			qdel(mob)
	sleep(1)
	world.log << "Clearing objects..."
	for (var/obj/object in world)
		if(istype(object, /obj/map_metadata) || istype(object, /atom/movable/lighting_overlay))
			continue
		qdel(object)
	return

/datum/data/record
	var/name = "record"
	var/size = 5.0
	var/list/fields = list(  )
	map_storage_saved_vars = "fields"
	safe_list_vars = "fields"
//////////////////////////////////////////
//////////////////GAMETICKER/////////////
//////////////////////////////////////////

var/global/persistence_save_in_progress = FALSE

/map_storage
	var/compiled_maxz = 0
	var/validation_maxz = 0
	var/dimension_bootstrap_busy = FALSE
	var/dimension_recovery_required = FALSE

/map_storage/proc/record_compiled_dimensions()
	if(!compiled_maxz) compiled_maxz = building_base_maxz()

/map_storage/proc/save_validation_maxz()
	return validation_maxz ? validation_maxz : world.maxz

/map_storage/proc/save_validation_coordinate(x, y, z)
	return isnum(x) && isnum(y) && isnum(z) && x == round(x) && y == round(y) && z == round(z) && x >= 1 && x <= world.maxx && y >= 1 && y <= world.maxy && z >= 1 && z <= save_validation_maxz()

/map_storage/proc/save_validation_area_type(x, y, z)
	if(!save_validation_coordinate(x, y, z)) return null
	if(z > world.maxz) return world.area
	var/turf/T = locate(x, y, z)
	return T ? T.loc.type : null

/map_storage/proc/save_validation_area_key(x, y, z)
	if(!save_validation_coordinate(x, y, z)) return null
	if(z <= world.maxz)
		var/turf/T = locate(x, y, z)
		return T ? "\ref[T.loc]" : null
	var/area/A = locate(world.area)
	return A ? "\ref[A]" : "prospective:[world.area]"

/datum/controller/gameticker/proc/savemap(datum/persistence_restart_transaction/transaction)
	if (persistence_save_in_progress || persistence_restart.startup_hold || (persistence_restart.busy && transaction != persistence_restart) || (!transaction && persistence_restart.exists()))
		return 0
	persistence_save_in_progress = TRUE
	var/watch = start_watch()
	to_chat(world, "<FONT color='yellow'><B>SAVING THE MAP! THIS USUALLY TAKES UNDER A MINUTE</B></FONT>")
	sleep(5)
	try
		if(!map_storage.Save_World())
			throw EXCEPTION("Save_World did not complete")
	catch(var/exception/e)
		map_storage.clear_bookkeeping()
		map_storage.release_durable_world()
		persistence_save_in_progress = FALSE
		map_storage.last_error = "[e] on [e.file]:[e.line]"
		world.log << "World-save export failed: [map_storage.last_error]"
		message_admins("EXCEPTION IN MAP SAVING!! [e] on [e.file]:[e.line]")
		return 0
	persistence_save_in_progress = FALSE
	log_startup_progress("	Saved the map in [stop_watch(watch)]s.")
	return 1

/datum/controller/gameticker/proc/loadmap(datum/persistence_restart_transaction/transaction)
	if(persistence_save_in_progress || ((persistence_restart.startup_hold || persistence_restart.busy || persistence_restart.exists()) && transaction != persistence_restart))
		return FALSE
	map_storage.reset_player_restoration()
	persistence_save_in_progress = TRUE
	if(!map_storage.prepare_saved_dimensions())
		persistence_save_in_progress = FALSE
		return FALSE
	if(!map_storage.validate_world_save())
		persistence_save_in_progress = FALSE
		return FALSE
	var/watch = start_watch()
	log_startup_progress("Starting map load...")
	try
		// Snapshot the validated header before any destructive restoration.
		var/list/saved_round = map_storage.read_round_state()
		if(transaction && saved_round["generation"] != transaction.expected_generation)
			throw EXCEPTION("Restart generation changed before import")
		map_storage.suspend_durable_world()
		map_storage.ClearMap()
		if(!map_storage.Load_World())
			map_storage.release_durable_world()
			map_storage.reset_player_restoration()
			persistence_save_in_progress = FALSE
			return FALSE
		if(!map_storage.load_map_metadata())
			throw EXCEPTION("Saved world metadata restoration failed")
		map_storage.restore_durable_world()
		map_storage.restore_round_state(src, saved_round)
	catch(var/exception/e)
		map_storage.clear_bookkeeping()
		map_storage.release_durable_world()
		map_storage.reset_player_restoration()
		map_storage.last_error = "[e] on [e.file]:[e.line]"
		world.log << "World-save import failed: [map_storage.last_error]"
		message_admins("Import failed during restoration; restart from the original map before retrying: [e]")
		persistence_save_in_progress = FALSE
		return FALSE
	persistence_save_in_progress = FALSE
	log_startup_progress("	Loaded the map in [stop_watch(watch)]s.")
	// Restart recovery releases its generation-bound hold only after consuming
	// the intent. Its waiting clients must be reclaimed at that later boundary.
	if(!transaction) map_storage.finish_player_restoration()
	return 1

// The completion marker and each level carry the same generation nonce. Legacy
// markers have no historical round identity/clock; owned bodies allow a bounded
// phase-only fallback after the rest of their world has loaded successfully.
/map_storage/proc/capture_round_state(generation)
	if(ticker && ticker.current_state == GAME_STATE_SETTING_UP)
		throw EXCEPTION("Cannot save during fresh round setup")
	var/elapsed = (round_start_time || round_elapsed_offset) ? max(0, world.time - round_start_time) + round_elapsed_offset : 0
	var/phase = ticker ? ticker.current_state : GAME_STATE_PREGAME
	return list("version" = 1, "generation" = generation, "map" = map.ID, "maxx" = world.maxx, "maxy" = world.maxy, "maxz" = world.maxz, "game_id" = global.game_id, "state" = phase, "elapsed" = phase == GAME_STATE_PREGAME ? 0 : elapsed, "roundstart_time" = phase == GAME_STATE_PREGAME ? 0 : roundstart_time)

/map_storage/proc/read_round_state()
	var/marker = trim(file2text("map_saves/save_complete.txt"))
	var/version = copytext(marker, 1, 10) == "round-v2:" ? 2 : 1
	if(copytext(marker, 1, 10) != "round-v1:" && version != 2) return list()
	if(!fexists("map_saves/round.json"))
		throw EXCEPTION("Completed generation is missing round state")
	var/list/state = json_decode(file2text("map_saves/round.json"))
	if(!islist(state) || state.len != (version == 2 ? 12 : 11) || state["version"] != version || state["generation"] != marker || state["metadata"] != md5(file2text("map_saves/map.txt")) || state["map"] != map.ID || state["maxx"] != world.maxx || state["maxy"] != world.maxy || state["maxz"] != save_validation_maxz())
		throw EXCEPTION("Round state does not match completed generation")
	if(version == 2 && !islist(state["world_state"]))
		throw EXCEPTION("Completed generation is missing durable world state")
	if(!istext(state["game_id"]) || !length(state["game_id"]) || length(state["game_id"]) > 128)
		throw EXCEPTION("Invalid saved round identity")
	if(!(state["state"] in list(GAME_STATE_PREGAME, GAME_STATE_PLAYING, GAME_STATE_FINISHED)))
		throw EXCEPTION("Invalid saved round phase")
	for(var/key in list("elapsed", "roundstart_time"))
		var/value = state[key]
		if(!isnum(value) || value < 0 || value > 1e15)
			throw EXCEPTION("Invalid saved round clock")
	if(state["state"] == GAME_STATE_PREGAME && (state["elapsed"] || state["roundstart_time"]))
		throw EXCEPTION("Unstarted round has an active clock")
	return state

/map_storage/proc/restore_round_state(datum/controller/gameticker/target, list/state)
	if(!state.len)
		// Owned characters establish a previously playable legacy generation,
		// but cannot reconstruct its historical ID or elapsed time.
		var/legacy_player = FALSE
		for(var/account in persistence_restored_bodies)
			var/list/bodies = persistence_restored_bodies[account]
			if(bodies.len != 1) continue
			var/mob/living/human/H = bodies[1]
			if(H && H.persistence_restored && H.persistence_owner_ckey == account && get_turf(H) && H.stat != DEAD)
				legacy_player = TRUE
				break
		if(!legacy_player) return
		world.log << "Legacy player save: resuming active phase; historical round ID and duration unavailable."
		if(!round_start_time) round_start_time = world.time
		if(!roundstart_time) roundstart_time = world.realtime
		round_restored = TRUE
		target.current_state = GAME_STATE_PLAYING
		stop_lobby_music()
		target.finished = FALSE
		target.minds = list()
		target.collect_minds()
		TOD_loop()
		return
	global.game_id = state["game_id"]
	round_elapsed_offset = state["elapsed"]
	round_start_time = state["state"] == GAME_STATE_PREGAME ? 0 : world.time
	roundstart_time = state["roundstart_time"]
	next_duration_update = 0
	next_duration_update_days = 0
	last_roundduration2text = 0
	last_roundduration2text_days = 0
	if(processes.ticker) processes.ticker.playtime_elapsed = state["elapsed"]
	round_restored = state["state"] != GAME_STATE_PREGAME
	target.current_state = state["state"]
	if(round_restored) stop_lobby_music()
	target.finished = state["state"] == GAME_STATE_FINISHED
	if(round_restored)
		target.minds = list()
		target.collect_minds()
		TOD_loop()

/datum/proc/before_save_context(map_storage/exporter, datum/save_export_frame/frame)
	return before_save()

/turf/var/tmp/datum/save_export_frame/persistence_export_frame

/datum/save_export_frame
	var/map_storage/exporter
	var/savefile/file
	var/datum/source
	var/source_identity
	var/entry
	var/accepts_children = FALSE
	var/active = TRUE
	var/list/content_refs = list()
	var/list/content_seen = list()
	var/list/declared_children = list()
	var/list/declared_seen = list()
	var/declared_cursor = 1
	var/list/tickets = list()

/datum/save_transfer
	var/datum/save_export_frame/producer
	var/datum/save_export_frame/parent
	var/atom/origin
	var/turf/destination
	var/list/items = list()
	var/committed = FALSE

/map_storage/proc/require_export_frame(datum/save_export_frame/frame)
	if(!frame || !frame.active || frame.exporter != src || !frame.source || "\ref[frame.source]" != frame.source_identity || saving_references[frame.source_identity] != frame.entry || saving_reference_pins[frame.entry] != frame.source || saving_export_frames["[frame.entry]"] != frame)
		throw EXCEPTION("Save export frame is no longer valid")
	if(isturf(frame.source) && frame.source:persistence_export_frame != frame)
		throw EXCEPTION("Save export turf was replaced")
	return TRUE

/map_storage/proc/prepare_save_transfer(datum/save_export_frame/frame, atom/origin, turf/destination, list/items)
	require_export_frame(frame)
	if(saving_export_stack[saving_export_stack.len] != frame || !istype(frame.source, /atom/movable) || !origin || origin.loc != frame.source || !destination)
		throw EXCEPTION("Save transfer requires the current producer and its owned storage")
	var/atom/movable/producer = frame.source
	var/parent_ref = saving_references["\ref[destination]"]
	var/datum/save_export_frame/parent = saving_export_frames["[parent_ref]"]
	if(!parent || parent == frame || parent.file != frame.file || !parent.accepts_children || parent.source != destination || producer.loc != destination)
		throw EXCEPTION("Save transfer requires an active direct owning turf")
	require_export_frame(parent)
	if(frame.tickets.len || !islist(items) || !items.len || items.len > 12)
		throw EXCEPTION("Save transfer exceeds its twelve-item bound")
	var/datum/save_transfer/ticket = new
	ticket.producer = frame
	ticket.parent = parent
	ticket.origin = origin
	ticket.destination = destination
	var/list/seen = list()
	for(var/obj/item/I in items)
		if(!I || I.loc != origin || !I.should_save || saving_references["\ref[I]"])
			throw EXCEPTION("Save transfer item is unavailable or already captured")
		for(var/ignored in ignore_types)
			if(istype(I, ignored))
				throw EXCEPTION("Save transfer item is excluded from persistence")
		var/identity = "\ref[I]"
		if(!seen[identity])
			seen[identity] = TRUE
			ticket.items += I
	if(ticket.items.len != items.len)
		throw EXCEPTION("Save transfer requires unique item handles")
	frame.tickets += ticket
	return ticket

/map_storage/proc/commit_save_transfer(datum/save_transfer/ticket)
	if(!ticket)
		throw EXCEPTION("Missing save transfer ticket")
	require_export_frame(ticket.producer)
	require_export_frame(ticket.parent)
	if(saving_export_stack[saving_export_stack.len] != ticket.producer || ticket.producer.source:loc != ticket.destination || !(ticket in ticket.producer.tickets) || !ticket.origin || ticket.origin.loc != ticket.producer.source || ticket.destination != ticket.parent.source)
		throw EXCEPTION("Save transfer ticket is not owned by the current hook")
	for(var/obj/item/I in ticket.items)
		if(!I || I.loc != ticket.destination)
			throw EXCEPTION("Paid save transfer did not reach its declared turf")
	if(ticket.committed)
		return TRUE
	for(var/obj/item/I in ticket.items)
		var/identity = "\ref[I]"
		if(!ticket.parent.declared_seen[identity])
			ticket.parent.declared_seen[identity] = I
			ticket.parent.declared_children += I
	ticket.committed = TRUE
	return TRUE

/map_storage/proc/add_export_content(datum/save_export_frame/frame, ref)
	if(!ref) return
	var/key = "[ref]"
	if(!frame.content_seen[key])
		frame.content_seen[key] = TRUE
		frame.content_refs += key

/map_storage/proc/drain_save_transfers(datum/save_export_frame/frame)
	require_export_frame(frame)
	while(frame.declared_cursor <= frame.declared_children.len)
		var/obj/item/I = frame.declared_children[frame.declared_cursor++]
		if(!I || I.loc != frame.source)
			throw EXCEPTION("Declared paid child moved or disappeared during export")
		var/ref = BuildVarDirectory(frame.file, I, 1)
		require_export_frame(frame)
		if(!I || I.loc != frame.source || !ref)
			throw EXCEPTION("Declared paid child could not be saved in its owning turf")
		add_export_content(frame, ref)
	for(var/obj/item/I in frame.declared_children)
		if(!I || I.loc != frame.source)
			throw EXCEPTION("Declared paid child changed before content publication")
	return TRUE

/map_storage/proc/release_export_frame(datum/save_export_frame/frame)
	if(!frame) return
	if(isturf(frame.source) && frame.source:persistence_export_frame == frame)
		frame.source:persistence_export_frame = null
	if(saving_export_frames["[frame.entry]"] == frame)
		saving_export_frames -= "[frame.entry]"
	saving_export_stack -= frame
	for(var/datum/save_transfer/ticket in frame.tickets)
		ticket.producer = null
		ticket.parent = null
		ticket.origin = null
		ticket.destination = null
		ticket.items = list()
	frame.tickets = list()
	frame.declared_children = list()
	frame.declared_seen = list()
	frame.content_refs = list()
	frame.content_seen = list()
	frame.active = FALSE
	frame.source = null
	frame.source_identity = null
	frame.file = null
	frame.exporter = null

// A candidate validation context describes prospective empty levels without
// allocating turfs. Normal validation continues to use actual world dimensions.
/map_storage/proc/saved_dimension_target()
	if(!fexists("map_saves/save_complete.txt") || !fexists("map_saves/map.txt"))
		throw EXCEPTION("Dimension bootstrap requires a completed generation")
	var/marker = trim(file2text("map_saves/save_complete.txt"))
	if(copytext(marker, 1, 10) != "round-v2:" && copytext(marker, 1, 10) != "round-v1:")
		return world.maxz // Historical map-only saves retain the exact old path.
	var/list/R = json_decode(file2text("map_saves/round.json"))
	if(!islist(R) || R["maxx"] != world.maxx || R["maxy"] != world.maxy)
		throw EXCEPTION("Saved horizontal dimensions differ from the compiled map")
	var/z = R["maxz"]
	if(z == world.maxz) return z // Matching saves need no expansion policy or allocator.
	if(!isnum(z) || z != round(z) || z < world.maxz || z > BUILDING_MAX_Z || !compiled_maxz || z > compiled_maxz + BUILDING_EXTRA_LEVELS)
		throw EXCEPTION("Saved level count exceeds the building expansion policy")
	if(z > world.maxz && world.maxx * world.maxy > BUILDING_MAX_LEVEL_CELLS)
		throw EXCEPTION("Saved added level exceeds the building cell budget")
	return z

/map_storage/proc/allocate_saved_level(target_z)
	return building_allocate_level(target_z, TRUE)

/map_storage/proc/prepare_saved_dimensions(list/expected_intent)
	if(dimension_recovery_required)
		last_error = "Saved level allocation previously failed; restart from the original map before retrying"
		return FALSE
	if(!persistence_save_in_progress || dimension_bootstrap_busy || validation_maxz || building_allocating_z)
		last_error = "Dimension validation already owns recovery"
		return FALSE
	dimension_bootstrap_busy = TRUE
	var/target_z
	try
		if(expected_intent && (expected_intent["generation"] != trim(file2text("map_saves/save_complete.txt")) || expected_intent["metadata"] != md5(file2text("map_saves/map.txt")) || expected_intent["round"] != md5(file2text("map_saves/round.json"))))
			throw EXCEPTION("Restart intent differs before dimension allocation")
		target_z = saved_dimension_target()
		if(target_z == world.maxz)
			dimension_bootstrap_busy = FALSE
			return TRUE
		validation_maxz = target_z
		var/valid = validate_world_save()
		validation_maxz = 0
		if(!valid) throw EXCEPTION("Prospective saved world failed validation: [last_error]")
		// Full structural/coordinate/metadata validation has completed before the
		// first allocation. Allocation may append only, never replace mapped turfs.
		dimension_recovery_required = TRUE
		for(var/z = world.maxz + 1, z <= target_z, z++)
			if(!allocate_saved_level(z) || world.maxz != z)
				throw EXCEPTION("Saved level allocation failed; preserve files and restart before retrying")
		if(!validate_world_save())
			throw EXCEPTION("Allocated saved world failed exact validation: [last_error]")
		dimension_recovery_required = FALSE
		dimension_bootstrap_busy = FALSE
		return TRUE
	catch(var/exception/e)
		validation_maxz = 0
		dimension_bootstrap_busy = FALSE
		release_durable_world()
		last_error = "[e] on [e.file]:[e.line]"
		return FALSE

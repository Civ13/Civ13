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

// Atom transform reads return matrix copies. Persist the complete affine value,
// rather than relying on changed-variable detection for an engine-created copy.
/matrix/get_saved_vars()
	. = ..()
	. |= list("a", "b", "c", "d", "e", "f")

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

/datum/controller/gameticker/proc/savemap()
	if (persistence_save_in_progress)
		return 0
	persistence_save_in_progress = TRUE
	var/watch = start_watch()
	to_chat(world, "<FONT color='yellow'><B>SAVING THE MAP! THIS USUALLY TAKES UNDER A MINUTE</B></FONT>")
	sleep(5)
	try
		map_storage.Save_World()
	catch(var/exception/e)
		map_storage.clear_bookkeeping()
		persistence_save_in_progress = FALSE
		map_storage.last_error = "[e] on [e.file]:[e.line]"
		world.log << "World-save export failed: [map_storage.last_error]"
		message_admins("EXCEPTION IN MAP SAVING!! [e] on [e.file]:[e.line]")
		return 0
	persistence_save_in_progress = FALSE
	log_startup_progress("	Saved the map in [stop_watch(watch)]s.")
	return 1

/datum/controller/gameticker/proc/loadmap()
	if(persistence_save_in_progress)
		return FALSE
	persistence_save_in_progress = TRUE
	if(!map_storage.validate_world_save())
		persistence_save_in_progress = FALSE
		return FALSE
	var/watch = start_watch()
	log_startup_progress("Starting map load...")
	try
		map_storage.ClearMap()
		if(!map_storage.Load_World())
			persistence_save_in_progress = FALSE
			return FALSE
		map_storage.load_map_metadata()
	catch(var/exception/e)
		map_storage.clear_bookkeeping()
		map_storage.last_error = "[e] on [e.file]:[e.line]"
		world.log << "World-save import failed: [map_storage.last_error]"
		message_admins("Import failed during restoration; restart from the original map before retrying: [e]")
		persistence_save_in_progress = FALSE
		return FALSE
	persistence_save_in_progress = FALSE
	log_startup_progress("	Loaded the map in [stop_watch(watch)]s.")
	return 1

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
